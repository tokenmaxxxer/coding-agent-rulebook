#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit|NotebookEdit|Bash) — contract §11.
#
# Generalizes warrant/scope-gate.sh's write-set shape to the STATIC,
# role-permanent owned-path table: coding owns exactly its own record file
# docs/reports/records/<subject>/coding.md (and a coding/ sub-tree) under any
# subject. A write whose resolved target lands on ANOTHER role's record file
# under docs/reports/records/<subject>/<other-role>.md is refused — coding
# reports the conflict, it never overwrites or merges into another role's
# record.
#
# Additive sibling to scope-gate.sh; never edits it. Modeled on the
# FAIL-CLOSED ops-cycle/state-gate.sh: every malformed/missing-input branch
# denies (exit 2), never `|| exit 0`.
set -uo pipefail

deny() { echo "warrant: refused — $*" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || deny "path-ownership-gate.sh requires python3, which is not on PATH; denying rather than guessing."

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
[ -z "$root" ] && deny "no project root could be determined; failing closed (§11 ownership cannot be judged)."

PO_PAYLOAD="$payload" PO_ROOT="$root" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("warrant: refused — " + m + "\n"); sys.exit(2)

    raw = os.environ.get("PO_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge §11 ownership on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on §11 ownership.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (§11).")

    root = posixpath.normpath(os.environ["PO_ROOT"].replace("\\", "/"))
    OWN = "coding.md"
    RECORDS_RE = re.compile(r'^docs/reports/records/([^/]+)/(.+)$')

    def resolve(p):
        n = p.replace("\\", "/")
        a = n if posixpath.isabs(n) else posixpath.join(root, n)
        a = posixpath.normpath(a)
        try:
            return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
        except OSError:
            return a

    def check(path_str):
        r = resolve(path_str)
        if not (r == root or r.startswith(root + "/")):
            return
        rel = r[len(root):].lstrip("/")
        m = RECORDS_RE.match(rel)
        if not m:
            return
        subject, tail = m.group(1), m.group(2)
        if tail == OWN or tail.startswith("coding/"):
            return
        if "/" not in tail or tail.endswith(".md"):
            deny(
                "'%s' is owned by another role per contract §11 (coding owns only "
                "docs/reports/records/%s/coding.md under this subject), not coding. "
                "Report the conflict; do not overwrite or merge into another role's record."
                % (rel, subject)
            )

    LIT = re.compile(r'^[A-Za-z0-9_./+=,@%:-]+$')
    def is_literal(t):
        return bool(t) and not any(c in t for c in "$`*?[]~()") and bool(LIT.match(t))

    targets = []
    if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        p = ti.get("file_path") or ti.get("notebook_path")
        if isinstance(p, str) and p:
            targets.append(p)
    elif tool == "Bash":
        cmd = ti.get("command")
        if isinstance(cmd, str) and cmd.strip():
            refs_records = "docs/reports/records/" in cmd.replace("\\", "/")
            found = []
            for rx in (
                re.compile(r'(?:^|\s)\d?>{1,2}\s*(\S+)'),
                re.compile(r'\btee\b(?:\s+-a)?\s+(\S+)'),
                re.compile(r'\b(?:cp|mv|install)\b.*?\s(\S+)\s*$'),
                re.compile(r"\bopen\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"][wxa]"),
            ):
                for m in rx.finditer(cmd):
                    if m.groups() and m.group(1):
                        found.append(m.group(1).strip().strip("'\""))
            if refs_records:
                for m in re.finditer(r"docs/reports/records/[^\s'\"`)]+", cmd.replace("\\", "/")):
                    tok = m.group(0)
                    if is_literal(tok):
                        targets.append(tok)
                    else:
                        deny(
                            "this Bash command references the records tree with a target the "
                            "gate cannot statically resolve; failing closed on §11 ownership."
                        )
            for g in found:
                if is_literal(g):
                    targets.append(g)

    for t in targets:
        check(t)

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("path-ownership-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "path-ownership-gate.sh: fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"