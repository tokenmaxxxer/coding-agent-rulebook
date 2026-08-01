#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# ^ fail-closed trap-at-top: any abnormal termination before the verdict
#   logic runs is forced to exit 2 (DENY), since a PreToolUse hook treats any
#   non-2 exit as NON-BLOCKING (fail-OPEN). Installed as the first executable
#   statement, above any set/source. Legitimate exit 0 (allow) / exit 2
#   (deny) verdicts pass through unchanged; only other codes are remapped.
#
# PreToolUse gate (Write|Edit|MultiEdit) — enforces research-before-proposal
# WRITE ORDER: a phase-1 proposal file under docs/issue-<n>/proposals/*.md
# must not be written before its issue's current-state survey file
# docs/issue-<n>/reports/implementation/survey.md exists on disk, unless the
# proposal's own resulting text states a scout-skip condition.
#
# Sibling-file-as-state-signal: mirrors coding-progress-gate.sh's pattern of
# reading a sibling record file in the same issue tree as the state signal
# that gates a write, applied here at Write/Edit/MultiEdit time on the
# proposal file itself (instead of at Bash-commit time).
#
# Kill switch: export SURVEY_ORDER_GATE_OFF=1
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
set -uo pipefail

deny() { echo "survey-order: refused — $*" >&2; exit 2; }

gate_kill_switch_active "${SURVEY_ORDER_GATE_OFF:-}" || exit 0

command -v python3 >/dev/null 2>&1 || deny "survey-order-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "survey-order-gate: empty tool-use payload on stdin; cannot evaluate write order."

_target="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    for k in ("file_path","notebook_path"):
        v=ti.get(k)
        if isinstance(v,str) and v: print(v); break
' 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
_under() {
  [ -z "$2" ] && return 0
  python3 -c '
import os,posixpath,sys
r,t=sys.argv[1],sys.argv[2]
try: rr=posixpath.normpath(os.path.realpath(r).replace("\\","/"))
except Exception: sys.exit(1)
n=t.replace("\\","/"); a=n if posixpath.isabs(n) else posixpath.join(rr,n)
a=posixpath.normpath(a); real=posixpath.normpath(os.path.realpath(a).replace("\\","/"))
sys.exit(0 if (real==rr or real.startswith(rr+"/")) else 1)
' "$1" "$2"
}

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR" && _under "$CLAUDE_PROJECT_DIR" "$_target"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  d="$_target"; [ -n "$d" ] || d="$(pwd -P)"; [ -d "$d" ] || d="$(dirname "$d")"
  root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; failing closed (write order cannot be judged)."

PG_PAYLOAD="$payload" PG_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import importlib.util, json, os, posixpath, re, sys

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)

    def deny(m):
        sys.stderr.write("survey-order: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("PG_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge write order on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on write order.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (write order).")

    root = posixpath.normpath(os.environ["PG_ROOT"].replace("\\", "/"))
    PROPOSAL_RE = re.compile(r'^docs/issue-([0-9]+)/proposals/.*\.md$')

    def resolve(p):
        n = p.replace("\\", "/")
        a = n if posixpath.isabs(n) else posixpath.join(root, n)
        a = posixpath.normpath(a)
        try:
            return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
        except OSError:
            return a

    path = None
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)

    r = resolve(path)
    if not r.startswith(root + "/"):
        sys.exit(0)
    rel = r[len(root):].lstrip("/")
    m = PROPOSAL_RE.match(rel)
    if not m:
        sys.exit(0)  # not a phase-1 proposal write surface — not this gate's business

    issue_n = m.group(1)
    survey_rel = "docs/issue-%s/reports/implementation/survey.md" % issue_n
    survey_abs = posixpath.join(root, survey_rel)

    if os.path.isfile(survey_abs):
        sys.exit(0)  # survey already on disk for this issue — write order satisfied

    # Survey is absent: the proposal write is only allowed if the proposal's
    # own resulting text states a scout-skip condition.
    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on write order." % rel)

    new_text = None
    if tool in ("Write", "Edit", "MultiEdit"):
        new_text, _ok = gate_lib.gate_reconstruct_write(tool, ti, current)
        if not _ok:
            new_text = None

    if new_text is None:
        deny(
            "%s targets a phase-1 proposal but the survey file %s is absent, and the gate "
            "cannot determine the resulting content from the tool input (tool=%r) to check "
            "for scout-skip language. Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so write order can be checked." %
            (rel, survey_rel, tool)
        )

    low = new_text.lower()
    SKIP_MARKERS = (
        "skip condition",
        "scouting was skipped",
        "pure bugfix",
        "no design decision",
        "skip record",
    )
    if any(mk in low for mk in SKIP_MARKERS):
        sys.exit(0)  # proposal states its own scout-skip condition — allowed

    deny(
        "%s is a phase-1 proposal write for issue-%s, but its survey file %s does not exist "
        "on disk, and the proposal's own text states no scout-skip condition. Write the "
        "current-state survey first, or — only for a pure bugfix or a spec that leaves no "
        "design decision open — state which skip condition applies and why, in the "
        "proposal body itself." % (rel, issue_n, survey_rel)
    )
    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("survey-order-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "survey-order: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
