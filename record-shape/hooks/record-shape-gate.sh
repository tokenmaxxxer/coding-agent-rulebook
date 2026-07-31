#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — enforces the implementation
# role's phase-2 record shape adopted in issue-52
# (docs/issue-52/proposals/2026-07-31-implementation-domain-norms.md,
# section (b)).
#
# Target: docs/issue-<n>/reports/implementation.md only — this role's
# phase-2 record surface. Requires `code_under_review:` and `loop_state:`
# frontmatter keys and a `## What did not work` heading always. Requires a
# `## Rationale for deviations` heading only when the record's body
# otherwise signals a deviation occurred (scope-exceeded / diverged
# language); its absence when no deviation language is present is not an
# error, since the section is a conditional response to divergence, not a
# mandatory section on every record.
#
# Kill switch: export RECORD_SHAPE_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-record-shape}"
deny() { echo "${role}: refused — $1" >&2; exit 2; }

case "${RECORD_SHAPE_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "record-shape-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "record-shape-gate: empty tool-use payload on stdin; cannot evaluate the record-shape gate."

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
[ -z "$root" ] && deny "no project root could be determined; failing closed (record-shape check cannot run)."

PG_PAYLOAD="$payload" PG_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("record-shape: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("PG_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge record shape on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on record shape.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (record shape).")

    root = posixpath.normpath(os.environ["PG_ROOT"].replace("\\", "/"))
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/implementation\.md$')

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
    if not RECORD_RE.match(rel):
        sys.exit(0)  # not this role's phase-2 record write surface — not this gate's business

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on record shape." % rel)

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
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so the record shape can be "
            "checked." % (rel, tool)
        )

    missing = []

    # 1. Frontmatter: text between the first two `---` lines (or the whole
    #    text, for a fresh Write with no frontmatter delimiters at all —
    #    treated as start-of-file with an empty frontmatter block).
    lines = new_text.split("\n")
    frontmatter = ""
    if lines[:1] == ["---"]:
        end = None
        for i in range(1, len(lines)):
            if lines[i] == "---":
                end = i
                break
        if end is not None:
            frontmatter = "\n".join(lines[1:end])
        else:
            frontmatter = ""
    else:
        frontmatter = new_text

    has_code_under_review = re.search(r'(?m)^code_under_review:', frontmatter) is not None
    has_loop_state = re.search(r'(?m)^loop_state:', frontmatter) is not None
    if not has_code_under_review:
        missing.append("frontmatter key `code_under_review:`")
    if not has_loop_state:
        missing.append("frontmatter key `loop_state:`")

    # 2. `## What did not work` heading present somewhere in the body.
    has_wdnw = re.search(r'(?m)^##\s+What did not work\s*$', new_text) is not None
    if not has_wdnw:
        missing.append("`## What did not work` heading (present even when empty, e.g. \"None.\")")

    # 3. Conditional: deviation language in the body (excluding the
    #    `## Rationale for deviations` heading's own line) requires a
    #    `## Rationale for deviations` heading.
    body_without_heading = re.sub(r'(?m)^##\s+Rationale for deviations\s*$', '', new_text)
    low = body_without_heading.lower()
    deviation_signaled = any(
        needle in low
        for needle in ("scope-exceeded", "scope exceeded", "diverged from the proposal", "deviation")
    )
    has_rationale_heading = re.search(r'(?m)^##\s+Rationale for deviations\s*$', new_text) is not None
    if deviation_signaled and not has_rationale_heading:
        missing.append("`## Rationale for deviations` heading (required: the record signals a deviation occurred)")

    if missing:
        deny(
            "phase-2 record write to %s is missing required element(s): %s. Per "
            "docs/issue-52/proposals/2026-07-31-implementation-domain-norms.md "
            "section (b), every phase-2 implementation record must carry "
            "`code_under_review:`/`loop_state:` frontmatter, a `## What did not "
            "work` heading present even when empty, and a `## Rationale for "
            "deviations` section whenever the record signals a divergence from "
            "the approved phase-1 proposal." % (rel, "; ".join(missing))
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("record-shape-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "record-shape: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
