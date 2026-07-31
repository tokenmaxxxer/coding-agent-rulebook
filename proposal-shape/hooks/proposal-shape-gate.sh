#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — mechanizes issue-52 section (a),
# the adopted phase-1 proposal shape: seven ADR-grafted sections, in order,
# with a non-trivial Rationale naming a rejected alternative.
#
# Targets: docs/issue-<n>/proposals/*.md (phase-1 proposals) only.
#
# Kill switch: export PROPOSAL_SHAPE_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-proposal-shape}"
deny() { echo "${role}: refused — $1" >&2; exit 2; }

case "${PROPOSAL_SHAPE_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "proposal-shape-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "proposal-shape-gate: empty tool-use payload on stdin; cannot evaluate the proposal shape gate."

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
[ -z "$root" ] && deny "no project root could be determined; failing closed (proposal shape check cannot run)."

PG_PAYLOAD="$payload" PG_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("proposal-shape: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("PG_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge proposal shape on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on proposal shape.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (proposal shape).")

    root = posixpath.normpath(os.environ["PG_ROOT"].replace("\\", "/"))
    PROPOSAL_RE = re.compile(r'^docs/issue-[0-9]+/proposals/.*\.md$', re.I)

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
    if not PROPOSAL_RE.match(rel):
        sys.exit(0)  # not a phase-1 proposal write surface — not this gate's business

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on proposal shape." % rel)

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
            "Edit/MultiEdit whose old_string matches, so the proposal shape can be "
            "checked." % (rel, tool)
        )

    # The seven required markers, in required relative order. Each is a
    # (label, regex) pair; regex matched case-insensitively, line-anchored
    # where the exemplar shape expects it (headings start a line).
    MARKERS = [
        ("files:", re.compile(r'^\s*files:', re.I | re.M)),
        ("## Request", re.compile(r'^##\s*request\b', re.I | re.M)),
        ("## Constraints", re.compile(r'^##\s*constraints\b', re.I | re.M)),
        ("## Rationale", re.compile(r'^##\s*rationale\b', re.I | re.M)),
        ("## What will be done", re.compile(r'^##\s*what will be done\b', re.I | re.M)),
        ("## Out of scope", re.compile(r'^##\s*out of scope\b', re.I | re.M)),
        ("## How you'll know it worked", re.compile(r"^##\s*how you'?ll know it worked\b", re.I | re.M)),
    ]

    missing = []
    positions = {}
    for label, rx in MARKERS:
        m = rx.search(new_text)
        if not m:
            missing.append("%s (missing)" % label)
        else:
            positions[label] = m.start()

    # Order check: only meaningful among markers that are present.
    present_labels = [label for label, _ in MARKERS if label in positions]
    for i in range(1, len(present_labels)):
        prev, cur = present_labels[i - 1], present_labels[i]
        if positions[cur] < positions[prev]:
            missing.append("%s (out of order — must follow %s)" % (cur, prev))

    # Non-trivial Rationale: its body (text between the heading and the
    # next "##" heading, or end of document) must name a rejected
    # alternative and the reason — presence-check only.
    if "## Rationale" in positions:
        start = positions["## Rationale"]
        after_heading = re.search(r'^##\s*rationale\b.*\n', new_text[start:], re.I)
        body_start = start + (after_heading.end() if after_heading else 0)
        next_heading = re.search(r'^##\s', new_text[body_start:], re.M)
        body_end = body_start + next_heading.start() if next_heading else len(new_text)
        body = new_text[body_start:body_end]
        body_low = body.lower()
        rejection_markers = (
            "rejected", "considered and rejected", "instead of", "rather than",
            "alternative considered",
        )
        if not any(nd in body_low for nd in rejection_markers):
            missing.append(
                "## Rationale (trivial — does not name a rejected alternative and the "
                "reason; must include language such as 'rejected', 'considered and "
                "rejected', 'instead of', 'rather than', or 'alternative considered')"
            )

    if missing:
        deny(
            "phase-1 proposal write to %s is missing or misshapen required element(s): %s. "
            "Per docs/issue-52/proposals/2026-07-31-implementation-domain-norms.md (a), "
            "every phase-1 proposal must carry these seven sections in order — files:, "
            "## Request, ## Constraints, ## Rationale, ## What will be done, "
            "## Out of scope, ## How you'll know it worked — and ## Rationale must name "
            "a rejected alternative and the reason it was rejected." % (rel, "; ".join(missing))
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("proposal-shape-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "proposal-shape: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
