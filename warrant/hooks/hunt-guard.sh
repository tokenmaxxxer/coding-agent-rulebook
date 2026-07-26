#!/usr/bin/env bash
# PreToolUse hook: bounds the background hunters.
#
# Three limits, all mechanical, all enforced here rather than asked for in a
# prompt — a runaway agent is exactly the failure a prompt cannot prevent:
#
#   1. single flight — one hunter at a time, per project directory
#   2. session cap  — WARRANT_HUNT_MAX dispatches (default 3), then no more
#   3. no nesting   — a hunter may not dispatch anything at all
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

# A hunter cannot dispatch: its own tool list omits Agent/Task/Workflow, and this
# refuses the case where it is dispatched under some other type.
if os.environ.get("WARRANT_IN_HUNT") == "1":
    print("warrant: a hunter may not dispatch agents. It probes one stance and returns.",
          file=sys.stderr)
    sys.exit(2)

if agent_type != "warrant-hunter":
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
PY

exit $?
