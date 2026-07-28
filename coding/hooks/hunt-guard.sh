#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# ^ fail-closed trap-at-top: any abnormal termination (failed source, set -u
#   abort, unbound var, etc.) before the verdict logic runs is forced to
#   exit 2 (DENY), since a PreToolUse hook treats any non-2 exit as
#   NON-BLOCKING (fail-OPEN). Installed as the FIRST executable statement,
#   above any set/source. Legitimate exit 0 (allow) / exit 2 (deny) verdicts
#   pass through unchanged; only other codes are remapped to 2.
# PreToolUse hook: bounds the background hunters.
#
# Two limits, both mechanical, both enforced here rather than asked for in a
# prompt — a runaway agent is exactly the failure a prompt cannot prevent:
#
#   1. single flight — one hunter at a time, per project directory
#   2. session cap  — WARRANT_HUNT_MAX dispatches (default 3), then no more
#
# Nesting (a hunter dispatching another agent) is not enforced by a branch in
# this hook. It is foreclosed upstream: warrant-hunter.md's frontmatter tool
# list is `Bash, Read, Grep, Glob, Write` — no `Agent`/`Task`/`Workflow` — so
# a hunter has no tool call available to it that could ever reach this gate's
# Agent/Task/Workflow branch in the first place. This hook's hooks.json wiring
# (SessionStart/SubagentStop/PreToolUse commands) has no mechanism to inject
# an environment variable into a dispatched subagent's own process, so a
# runtime "am I currently a hunter" check was never reachable either — see
# docs/decisions/2026-07-26-hunt-guard-nesting-enforcement.md for the full
# trace and why single-flight plus the tool-list omission is sufficient
# without a dedicated branch here.
#
# Both files this reads are maintained by hunt-state.sh: the lock is dropped
# when a subagent stops, and both are cleared at session start. Nothing here
# writes them a second time, so a leak in either shows up as the guard refusing
# work rather than as the guard going quiet.
#
# The fourth limit, killing a hunter that hangs, is NOT enforceable from a
# shell hook: nothing here can terminate an agent. What this does instead is
# make a stale one visible — the lock carries its start time, and a later
# dispatch reports the age so the session can stop it deliberately.
#
# Fails closed on a missing python3 or an unreadable/malformed intake
# payload (unparseable JSON, non-dict event) — the gate cannot judge a call
# it cannot parse. The core single-flight/cap logic downstream remains
# default-deny as before.
# Kill switch: export WARRANT_OFF=1

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and to
# most tooling, but any non-empty value used to disable the hook — the kill switch
# silently killed it on exactly the spelling meant to keep it alive.
case "${WARRANT_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || {
  echo "warrant: refused — hunt-guard.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat)"

WARRANT_PAYLOAD="$payload" WARRANT_HUNT_MAX="${WARRANT_HUNT_MAX:-3}" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json
    import os
    import posixpath
    import subprocess
    import sys
    import time

    # hunt-state.sh drops the lock when a subagent stops, so this is only the
    # backstop for the case where that never fires. Observed hunter runs: 36s, 69s,
    # 163s — 900s was long enough to swallow the whole span between a proposal and
    # its landing.
    STALE_SECONDS = 300


    def allow():
        sys.exit(0)


    def deny_intake(msg):
        sys.stderr.write("warrant: refused — " + msg + "\n")
        sys.exit(2)


    try:
        event = json.loads(os.environ.get("WARRANT_PAYLOAD", ""))
    except ValueError:
        deny_intake("the tool-call payload is not valid JSON; the gate cannot judge a call it cannot parse")
    if not isinstance(event, dict):
        deny_intake("the tool-call payload is not a JSON object; the gate cannot judge a call it cannot parse")

    tool = event.get("tool_name") or ""
    if tool not in ("Agent", "Task", "Workflow"):
        allow()

    tool_input = event.get("tool_input") if isinstance(event.get("tool_input"), dict) else {}
    agent_type = (tool_input.get("subagent_type") or "").strip()
    prompt = tool_input.get("prompt") or ""

    root = (os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()).replace("\\", "/")
    try:
        top = subprocess.run(["git", "-C", root, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        top = ""
    # git supplies a stable root; it is not a precondition for counting. Falling
    # through to allow() here handed every non-git directory unlimited hunters —
    # the exact failure this guard exists to prevent, silently switched off by a
    # repository layout the guard has an opinion about but does not need.
    root = posixpath.normpath((top or root).replace("\\", "/"))
    lock = posixpath.join(root, ".warrant-hunt.lock")
    count = posixpath.join(root, ".warrant-hunt.count")

    if agent_type.lower() != "warrant-hunter":
        allow()

    now = int(time.time())

    if os.path.exists(lock):
        try:
            with open(lock) as handle:
                started = int((handle.read().split()[0] or "0"))
        except (OSError, ValueError, IndexError):
            started = 0
        age = now - started
        if age < STALE_SECONDS:
            print("warrant: a hunter has been running for %ds; one at a time. Let it finish, or stop "
                  "it before dispatching another." % age, file=sys.stderr)
            sys.exit(2)
        print("warrant: the previous hunter has been running %ds (past %ds) and is presumed stuck. "
              "Stop that task before this one runs — nothing in a hook can terminate it."
              % (age, STALE_SECONDS), file=sys.stderr)
        sys.exit(2)

    try:
        with open(count) as handle:
            used = int(handle.read().strip() or "0")
    except (OSError, ValueError):
        used = 0

    cap = int(os.environ.get("WARRANT_HUNT_MAX", "3"))
    if used >= cap:
        print("warrant: %d hunters already dispatched in this repository (cap %d). No more until the "
              "count file is cleared: rm %s" % (used, cap, posixpath.relpath(count, root)),
              file=sys.stderr)
        sys.exit(2)

    try:
        with open(lock, "w") as handle:
            handle.write("%d %s\n" % (now, (prompt.splitlines() or [""])[0][:80]))
        with open(count, "w") as handle:
            handle.write(str(used + 1) + "\n")
    except OSError as exc:
        # Without a lock there is no single-flight guarantee, so decline rather than
        # dispatch unbounded.
        print("warrant: cannot write the hunter lock (%s); declining to dispatch one." % exc,
              file=sys.stderr)
        sys.exit(2)

    allow()
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("hunt-guard.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "hunt-guard.sh: fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
