#!/usr/bin/env bash
# PreToolUse gate (Bash matching `git commit`) — contract §21, handbook half.
#
# When a commit's STAGED file set introduces or changes an operational
# surface (env var example, config key, dependency manifest, migration, or a
# run/setup/deploy script — coding's own path heuristics below) AND the same
# commit does not also touch docs/handbooks/<component>.md, refuse the commit.
# §21 requires the handbook to be updated in the same unit of work.
#
# Conservative component derivation: if ANY handbook file under
# docs/handbooks/ is staged, the obligation is treated as met (the gate
# enforces STRUCTURE — that a handbook was touched alongside operational
# change — never which component, a human-owned judgment).
#
# Additive sibling to scope-gate.sh; never edits it. FAIL-CLOSED on every
# malformed/missing-input branch (modeled on ops-cycle/state-gate.sh).
set -uo pipefail

deny() { echo "warrant: refused — $*" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || deny "handbook-trigger-gate.sh requires python3, which is not on PATH; denying rather than guessing."
command -v git >/dev/null 2>&1 || deny "handbook-trigger-gate.sh requires git, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; failing closed (§21 handbook-trigger cannot be judged)."

HT_PAYLOAD="$payload" HT_ROOT="$root" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, subprocess, sys

    def deny(m):
        sys.stderr.write("warrant: refused — " + m + "\n"); sys.exit(2)

    raw = os.environ.get("HT_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; failing closed on §21.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on §21.")

    if ev.get("tool_name") != "Bash":
        sys.exit(0)
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a commit it cannot parse (§21).")
    cmd = ti.get("command")
    if not isinstance(cmd, str) or not cmd.strip():
        sys.exit(0)
    if not re.search(r'\bgit\b[^\n]*\bcommit\b', cmd):
        sys.exit(0)

    root = posixpath.normpath(os.environ["HT_ROOT"].replace("\\", "/"))

    def git(*args):
        try:
            return subprocess.run(["git", "-C", root, *args],
                                  capture_output=True, text=True, timeout=30)
        except Exception:
            return None

    r = git("diff", "--cached", "--name-only")
    if r is None or r.returncode != 0:
        deny("could not read the staged file set (`git diff --cached`); failing closed on §21.")
    staged = [ln.strip() for ln in r.stdout.splitlines() if ln.strip()]
    if not staged:
        sys.exit(0)

    # operational-surface path heuristics (coding-agent-rulebook's declared list)
    OP_PATTERNS = [
        (re.compile(r'(^|/)package\.json$'), "dependency manifest"),
        (re.compile(r'(^|/)package-lock\.json$'), "dependency lockfile"),
        (re.compile(r'(^|/)pyproject\.toml$'), "dependency manifest"),
        (re.compile(r'(^|/)requirements[^/]*\.txt$'), "dependency manifest"),
        (re.compile(r'(^|/)go\.mod$'), "dependency manifest"),
        (re.compile(r'(^|/)Cargo\.toml$'), "dependency manifest"),
        (re.compile(r'(^|/)Gemfile$'), "dependency manifest"),
        (re.compile(r'(^|/)Dockerfile$'), "container/build config"),
        (re.compile(r'(^|/)docker-compose\.ya?ml$'), "container/build config"),
        (re.compile(r'\.env(\.[A-Za-z0-9_.-]+)?$'), "environment config"),
        (re.compile(r'(^|/)migrations?/'), "database migration"),
        (re.compile(r'(^|/)\.github/workflows/'), "CI/deploy workflow"),
        (re.compile(r'(^|/)(deploy|setup|run|install)[^/]*\.sh$'), "run/setup/deploy script"),
    ]

    op_hits = []
    for f in staged:
        for rx, kind in OP_PATTERNS:
            if rx.search(f):
                op_hits.append((f, kind))
                break

    if not op_hits:
        sys.exit(0)  # no operational surface changed — not this gate's business

    handbook_touched = any(re.match(r'^docs/handbooks/.+', f) for f in staged)
    if handbook_touched:
        sys.exit(0)

    path, kind = op_hits[0]
    deny(
        "this commit changes %s (operational surface: %s) but does not touch any "
        "docs/handbooks/<component>.md. Per contract §21, update the handbook in the same "
        "unit of work." % (path, kind)
    )
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("handbook-trigger-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "handbook-trigger-gate.sh: fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"