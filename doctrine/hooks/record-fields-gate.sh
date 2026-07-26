#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — contract §20.
#
# On a write whose resolved target is coding's own record
# docs/reports/records/<subject>/coding.md, parse the PROPOSED content and
# require §20's minimum fields: a "what was done" section, a "why" section,
# the upstream basis (a commit sha or record path), the record's own
# loop_state, and an open-findings section. Additionally, whenever loop_state
# shows work is left OPEN (a non-terminal state — not cleared/reported/
# round-done), require a next-steps section and an open-finding resolution
# path. Missing any required-for-this-state section => refuse.
#
# Additive doctrine-family sibling; reads the SAME proposed content
# state-gate.sh reads (no new content-read mechanism). Modeled on the
# FAIL-CLOSED ops-cycle/state-gate.sh: every malformed/missing-input branch
# denies (exit 2), never `|| exit 0`.
set -uo pipefail

deny() { echo "doctrine: refused — $*" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || deny "record-fields-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"

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
[ -z "$root" ] && deny "no project root could be determined; failing closed (§20 field check cannot run)."

RF_PAYLOAD="$payload" RF_ROOT="$root" python3 <<'PY'
import json, os, posixpath, re, sys

def deny(m):
    sys.stderr.write("doctrine: refused — " + m + "\n"); sys.exit(2)

raw = os.environ.get("RF_PAYLOAD", "")
try:
    ev = json.loads(raw) if raw else {}
except ValueError:
    deny("the tool-call payload is not valid JSON; the gate cannot judge §20 fields on an unparseable write.")
if not isinstance(ev, dict):
    deny("the tool-call payload is not a JSON object; failing closed on §20.")

tool = ev.get("tool_name")
ti = ev.get("tool_input")
if not isinstance(ti, dict):
    deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (§20).")

root = posixpath.normpath(os.environ["RF_ROOT"].replace("\\", "/"))
RECORDS_RE = re.compile(r'^docs/reports/records/([^/]+)/coding\.md$')

def resolve(p):
    n = p.replace("\\", "/")
    a = n if posixpath.isabs(n) else posixpath.join(root, n)
    a = posixpath.normpath(a)
    try:
        return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
    except OSError:
        return a

# Only Write/Edit/MultiEdit reach coding.md in a form whose full resulting
# content we can read. A Bash write to the record is out of this gate's scope
# (path-ownership-gate/scope-gate handle Bash); this gate passes it through.
path = None
if tool in ("Write", "Edit", "MultiEdit"):
    p = ti.get("file_path")
    if isinstance(p, str) and p:
        path = p
if path is None:
    sys.exit(0)

r = resolve(path)
if not (r.startswith(root + "/")):
    sys.exit(0)
rel = r[len(root):].lstrip("/")
if not RECORDS_RE.match(rel):
    sys.exit(0)  # not coding's own record — not this gate's business

# --- reconstruct the proposed resulting content ---------------------------
current = None
if os.path.isfile(r):
    try:
        with open(r, encoding="utf-8-sig") as fh:
            current = fh.read(1 << 20)
    except OSError:
        deny("coding.md exists but cannot be read; failing closed on §20.")

new_text = None
if tool == "Write":
    c = ti.get("content")
    if isinstance(c, str):
        new_text = c
elif tool == "Edit":
    o, n = ti.get("old_string"), ti.get("new_string")
    if isinstance(o, str) and isinstance(n, str) and current is not None and o in current:
        new_text = current.replace(o, n, 1)
elif tool == "MultiEdit":
    edits = ti.get("edits")
    text = current
    if isinstance(edits, list) and text is not None:
        ok = True
        for e in edits:
            if not isinstance(e, dict):
                ok = False; break
            o, n = e.get("old_string"), e.get("new_string")
            if not isinstance(o, str) or not isinstance(n, str) or o not in text:
                ok = False; break
            text = text.replace(o, n, 1)
        if ok:
            new_text = text

if new_text is None:
    deny(
        "this write targets coding.md but the gate cannot determine the resulting content "
        "from the tool input (tool=%r). Write the full record with Write, or use an "
        "Edit/MultiEdit whose old_string matches, so §20 fields can be checked." % tool
    )

low = new_text.lower()

def has_any(*needles):
    return any(nd in low for nd in needles)

missing = []
# what was done
if not has_any("what was done", "what i did", "## done", "work done", "summary of work"):
    missing.append("what-was-done")
# why
if not has_any("why", "rationale", "reason:"):
    missing.append("why")
# upstream basis (commit sha or record path)
if not (has_any("upstream", "based on", "basis:")
        or re.search(r'\b[0-9a-f]{7,40}\b', new_text)
        or "docs/reports/records/" in new_text):
    missing.append("upstream-basis")
# loop_state
m_ls = re.search(r'^\s*loop_state:\s*([A-Za-z0-9_-]+)\s*$', new_text, re.M)
if not m_ls:
    missing.append("loop_state")
# open findings
if not has_any("open findings", "open_findings", "open finding"):
    missing.append("open-findings")

if missing:
    deny(
        "record is missing required section(s): %s. Per contract §20 every role record "
        "must state what was done, why, the concrete upstream basis, its own loop_state, "
        "and open findings." % ", ".join(missing)
    )

TERMINAL = {"cleared", "reported", "round-done"}
loop_state = m_ls.group(1).strip().lower()
if loop_state not in TERMINAL:
    open_missing = []
    if not has_any("next steps", "next-steps", "next_steps"):
        open_missing.append("next-steps")
    if not has_any("resolution path", "resolution-path", "resolution_path"):
        open_missing.append("open-finding-resolution-path")
    if open_missing:
        deny(
            "record shows loop_state '%s' (work left open) but is missing: %s. Per §20, an "
            "open-state record must additionally give next-steps and an open-finding "
            "resolution path." % (loop_state, ", ".join(open_missing))
        )

sys.exit(0)
PY
