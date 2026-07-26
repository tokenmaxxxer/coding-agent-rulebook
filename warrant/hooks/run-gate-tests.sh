#!/usr/bin/env bash
# Gate tests for warrant/hooks/scope-gate.sh.
#
# Covers the write-target-resolution fix
# (docs/proposals/2026-07-26-fix-state-gate-writeop-bypass.md): scope-gate.sh
# used to blanket-allow any Bash call that didn't match its WITHHELD idiom
# list, with no check at all against the approved proposal's frozen write
# set -- a Bash call writing outside the write set (e.g. via
# `python3 -c "open(path,'w').write(...)"`) sailed through unchecked. The
# fix resolves a Bash write's target path the same way a Write/Edit call's
# file_path is resolved, and adjudicates it against the same write-set
# containment rule.
#
#  (1) a Bash write whose target resolves outside the approved write set
#      -> DENIED.
#  (2) a Bash write whose target resolves inside the approved write set
#      -> ALLOWED.
#  (3) a Bash write that is write-shaped (matches a known write idiom) but
#      whose target cannot be determined from the command text at all
#      -> DENIED (default-deny on an indeterminate write target).
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HOOK_DIR/scope-gate.sh"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

pass=0
fail=0

run_gate() {
  # $1 = root dir, $2 = payload json
  CLAUDE_PROJECT_DIR="$1" WARRANT_OFF= bash "$GATE" <<<"$2"
}

expect_deny() {
  local name="$1" root="$2" payload="$3"
  local out rc
  out="$(run_gate "$root" "$payload" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: $name -- expected deny (non-zero exit), got exit 0. Output: $out"
    fail=$((fail+1))
  else
    echo "PASS: $name (exit $rc)"
    pass=$((pass+1))
  fi
}

expect_allow() {
  local name="$1" root="$2" payload="$3"
  local out rc
  out="$(run_gate "$root" "$payload" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: $name -- expected allow (exit 0), got exit $rc. Output: $out"
    fail=$((fail+1))
  else
    echo "PASS: $name"
    pass=$((pass+1))
  fi
}

new_root() {
  # The gate now validates its resolved root (contract: docs/proposals/
  # 2026-07-26-gate-root-from-project-dir.md) — a root must either be a git
  # work-tree top-level or carry docs/specs/role-handoff-contract.md before
  # it is trusted at all. Every fixture root gets the contract file stamped
  # in so existing cases (which pass CLAUDE_PROJECT_DIR pointing straight at
  # this dir, never a git repo) continue to validate exactly as before.
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  mkdir -p "$d/docs/specs"
  printf 'role-handoff contract fixture stub\n' > "$d/docs/specs/role-handoff-contract.md"
  echo "$d"
}

# write_approved_proposal <root> <slug> <files-yaml-block>
# Creates docs/proposals/<slug>.md, status: approved, with the given `files:`
# list body (each line already formatted as "  - path"), and echoes the
# proposal's repo-relative path.
write_approved_proposal() {
  local root="$1" slug="$2" files_block="$3"
  mkdir -p "$root/docs/proposals"
  {
    printf -- '---\n'
    printf 'status: approved\n'
    printf 'files:\n'
    printf '%s\n' "$files_block"
    printf -- '---\n'
    printf '# build proposal\n'
  } > "$root/docs/proposals/${slug}.md"
  echo "docs/proposals/${slug}.md"
}

bash_payload() {
  # bash_payload <command>
  local command="$1"
  python3 - "$command" <<'PY'
import json, sys
command = sys.argv[1]
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": command}}))
PY
}

# =========================================================================
# Case 1: Bash write whose target resolves OUTSIDE the approved write set
#         -> expect DENY. Exact reproduction of the bypass: a Bash call
#         using `open(path, 'w').write(...)` never matched any WITHHELD
#         idiom and, before the fix, fell straight through to an
#         unconditional allow with no write-set check at all.
# =========================================================================
root="$(new_root)"
mkdir -p "$root/src" "$root/other"
proposal="$(write_approved_proposal "$root" "case1" '  - src')"
target="$root/other/escape.py"
payload="$(bash_payload "python3 -c \"open('${target}', 'w').write('x')\"")"
expect_deny "(1) bash write target outside approved write set" "$root" "$payload"

# =========================================================================
# Case 2: Bash write whose target resolves INSIDE the approved write set
#         -> expect ALLOW.
# =========================================================================
root="$(new_root)"
mkdir -p "$root/src"
proposal="$(write_approved_proposal "$root" "case2" '  - src')"
target="$root/src/in-scope.py"
payload="$(bash_payload "python3 -c \"open('${target}', 'w').write('x')\"")"
expect_allow "(2) bash write target inside approved write set" "$root" "$payload"

# =========================================================================
# Case 3: Bash write that is write-shaped (matches a known write idiom:
#         `.write(`) but whose target cannot be determined from the command
#         text at all (no path-shaped, slash-containing token anywhere in
#         the command) -> expect DENY (default-deny on an indeterminate
#         write target, never a silent allow).
# =========================================================================
root="$(new_root)"
mkdir -p "$root/src"
proposal="$(write_approved_proposal "$root" "case3" '  - src')"
payload="$(bash_payload "target=\$(compute_target); python3 -c \"open(target, 'w').write('x')\"")"
expect_deny "(3) bash write with indeterminate target -> default-deny" "$root" "$payload"

# =========================================================================
# Companion: an ordinary Write call inside the write set still allows --
# proves the fix does not regress the pre-existing Write/Edit path.
# =========================================================================
root="$(new_root)"
mkdir -p "$root/src"
proposal="$(write_approved_proposal "$root" "case4" '  - src')"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/src/in-scope.py","content":"x = 1\n"}}
JSON
)
expect_allow "(companion) write-tool call inside write set still allowed" "$root" "$payload"

# =========================================================================
# Companion: an ordinary Write call outside the write set still refuses --
# proves the fix left the pre-existing Write/Edit path's own check intact.
# =========================================================================
root="$(new_root)"
mkdir -p "$root/src" "$root/other"
proposal="$(write_approved_proposal "$root" "case5" '  - src')"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/other/escape.py","content":"x = 1\n"}}
JSON
)
expect_deny "(companion) write-tool call outside write set still refused" "$root" "$payload"

# =========================================================================
# Cases 6-13: path-reference default-deny (contract: docs/proposals/
# 2026-07-26-gate-nested-shell-default-deny.md). A Bash command referencing
# a path inside the owned record tree (docs/reports/records/<subject>/),
# self or foreign, is default-denied unless provably read-only. Each write
# idiom below targets a FOREIGN role's record slot -> expect deny. A plain
# self-redirection to coding's own record within the frozen write set is
# still allowed. Any reference wrapped in sh -c/bash -c/eval or command
# substitution is denied regardless of idiom.
# =========================================================================
root="$(new_root)"
mkdir -p "$root/src"
proposal="$(write_approved_proposal "$root" "case6" '  - src')"
foreign_record="$root/docs/reports/records/other-subject/qa.md"

payload="$(bash_payload "python3 -c \"open('${foreign_record}', 'w').write('x')\"")"
expect_deny "(6) path-ref-deny foreign open().write" "$root" "$payload"

payload="$(bash_payload "python3 -c \"import pathlib; pathlib.Path('${foreign_record}').write_text('x')\"")"
expect_deny "(7) path-ref-deny foreign .write_text" "$root" "$payload"

payload="$(bash_payload "python3 -c \"import pathlib; pathlib.Path('${foreign_record}').write_bytes(b'x')\"")"
expect_deny "(8) path-ref-deny foreign .write_bytes" "$root" "$payload"

payload="$(bash_payload "python3 -c \"import os; os.write(open('${foreign_record}','w').fileno(), b'x')\"")"
expect_deny "(9) path-ref-deny foreign os.write" "$root" "$payload"

payload="$(bash_payload "sh -c \"cat ${foreign_record}\"")"
expect_deny "(10) path-ref-deny foreign sh -c wrap" "$root" "$payload"

payload="$(bash_payload "bash -c \"cat ${foreign_record}\"")"
expect_deny "(11) path-ref-deny foreign bash -c wrap" "$root" "$payload"

payload="$(bash_payload "eval \"cat ${foreign_record}\"")"
expect_deny "(12) path-ref-deny foreign eval wrap" "$root" "$payload"

payload="$(bash_payload "echo \"\$(cat ${foreign_record})\"")"
expect_deny "(13) path-ref-deny foreign command substitution wrap" "$root" "$payload"

# Plain read of a foreign record -> not a write this gate refuses -> allow
# (falls through to the ordinary in-scope/out-of-scope docs/ rule below).
payload="$(bash_payload "cat ${foreign_record}")"
expect_allow "(14) path-ref-allow foreign plain read" "$root" "$payload"

# Own record, plain redirection, within docs/ (always in scope) -> allowed.
own_bash_record="$root/docs/reports/records/own-subject-bash/coding.md"
payload="$(bash_payload "printf -- 'x' > ${own_bash_record}")"
expect_allow "(15) path-ref-allow own record plain redirect" "$root" "$payload"

# =========================================================================
# Cases 16-19: gate-protection root resolution from CLAUDE_PROJECT_DIR
# (contract: docs/proposals/2026-07-26-gate-root-from-project-dir.md).
# =========================================================================

# Case 16: CLAUDE_PROJECT_DIR points at an unrelated/empty directory (no
# docs/specs/role-handoff-contract.md, not itself a git work-tree
# top-level), while the write targets a REAL project's approved write set.
# -> expect DENY (the root is INDETERMINATE; default-deny, not a silent
# stand-down that lets the write through).
root="$(new_root)"
mkdir -p "$root/src"
proposal="$(write_approved_proposal "$root" "case16" '  - src')"
unrelated="$(mktemp -d -p "$WORKDIR")"    # deliberately NOT stamped via new_root
target="$root/src/in-scope.py"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$target","content":"x = 1\n"}}
JSON
)
out="$(CLAUDE_PROJECT_DIR="$unrelated" WARRANT_OFF= bash "$GATE" <<<"$payload" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL: (16) CLAUDE_PROJECT_DIR unrelated/empty dir, real target -- expected deny, got exit 0. Output: $out"
  fail=$((fail+1))
else
  echo "PASS: (16) CLAUDE_PROJECT_DIR unrelated/empty dir, real target refused (exit $rc)"
  pass=$((pass+1))
fi

# Case 17: CLAUDE_PROJECT_DIR correctly points at the real project root ->
# normal enforcement still applies (in-scope write allowed).
root="$(new_root)"
mkdir -p "$root/src"
proposal="$(write_approved_proposal "$root" "case17" '  - src')"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/src/in-scope.py","content":"x = 1\n"}}
JSON
)
expect_allow "(17) CLAUDE_PROJECT_DIR correct root enforces normally (allowed)" "$root" "$payload"

# Case 18: CLAUDE_PROJECT_DIR correctly points at the real project root ->
# an out-of-scope write is still refused.
root="$(new_root)"
mkdir -p "$root/src" "$root/other"
proposal="$(write_approved_proposal "$root" "case18" '  - src')"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/other/escape.py","content":"x = 1\n"}}
JSON
)
expect_deny "(18) CLAUDE_PROJECT_DIR correct root enforces normally (refused)" "$root" "$payload"

# Case 19: CLAUDE_PROJECT_DIR unset -> falls back to the git top-level of
# cwd. A real git repo fixture proves the fallback resolves and enforces
# exactly as the explicit CLAUDE_PROJECT_DIR path does.
git_root="$(mktemp -d -p "$WORKDIR")"
(cd "$git_root" && git init -q && git config user.email t@example.com && git config user.name t)
mkdir -p "$git_root/src" "$git_root/other"
(
  cd "$git_root"
  mkdir -p docs/proposals
  {
    printf -- '---\n'
    printf 'status: approved\n'
    printf 'files:\n'
    printf '  - src\n'
    printf -- '---\n'
    printf '# build proposal\n'
  } > docs/proposals/case19.md
)
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$git_root/other/escape.py","content":"x = 1\n"}}
JSON
)
out="$(cd "$git_root" && CLAUDE_PROJECT_DIR= WARRANT_OFF= bash "$GATE" <<<"$payload" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL: (19) CLAUDE_PROJECT_DIR unset, git-toplevel fallback -- expected deny, got exit 0. Output: $out"
  fail=$((fail+1))
else
  echo "PASS: (19) CLAUDE_PROJECT_DIR unset, git-toplevel fallback enforces (exit $rc)"
  pass=$((pass+1))
fi

# =========================================================================
# Cases 20-23: write-set glob enforcement fix (contract: docs/proposals/
# 2026-07-26-gate-writeset-enforcement-fix.md, round-1 defects A and B).
#
# Defect A: the write-set match compared the literal string `<root>/**`
# against a path with `startswith`, which never glob-expanded `**` -- every
# real write under an approved `<root>/**` set was refused, forcing a
# Bash-heredoc workaround. Fixed by glob/fnmatch matching in
# _write_set_entry_matches().
#
# Defect B: WRITE_HINTS omitted `.write_text(` / `.write_bytes(` /
# `os.write(`, so a write via one of those idioms to a path OUTSIDE the
# write set was not recognized as a write at all and sailed through
# unchecked. Fixed by unifying WRITE_HINTS with the records-tree write
# idiom list (WRITE_IDIOM_RE, single source of truth).
# =========================================================================

# Case 20: Write/Edit call landing inside a `src/**` write set -> ALLOW.
# (Prior behavior: `**` was compared literally and never matched, so this
# was refused, forcing the heredoc workaround.)
root="$(new_root)"
mkdir -p "$root/src/nested/deep"
proposal="$(write_approved_proposal "$root" "case20" '  - src/**')"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/src/nested/deep/in-scope.py","content":"x = 1\n"}}
JSON
)
expect_allow "(20) glob write-set src/** allows a real non-docs write at depth" "$root" "$payload"

# Case 21: same `src/**` write set via a Bash write (python3 open().write) ->
# ALLOW, same glob fix applied on the Bash path (in_scope()/in_write_set()).
root="$(new_root)"
mkdir -p "$root/src/nested"
proposal="$(write_approved_proposal "$root" "case21" '  - src/**')"
target="$root/src/nested/in-scope.py"
payload="$(bash_payload "python3 -c \"open('${target}', 'w').write('x')\"")"
expect_allow "(21) glob write-set src/** allows a Bash write at depth" "$root" "$payload"

# Case 22: a `src/**` write set must NOT over-match a sibling directory
# that merely shares the `src` prefix (`src-evil/`) -> DENY.
root="$(new_root)"
mkdir -p "$root/src" "$root/src-evil"
proposal="$(write_approved_proposal "$root" "case22" '  - src/**')"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/src-evil/escape.py","content":"x = 1\n"}}
JSON
)
expect_deny "(22) glob write-set src/** does not over-match sibling src-evil/" "$root" "$payload"

# Case 23: `.write_text(` / `.write_bytes(` / `os.write(` to a path OUTSIDE
# the write set are now recognized as writes and refused (defect B) --
# before the fix these idioms were absent from WRITE_HINTS and the Bash
# call fell straight through to an unconditional allow.
root="$(new_root)"
mkdir -p "$root/src" "$root/other"
proposal="$(write_approved_proposal "$root" "case23" '  - src')"

target="$root/other/escape.py"
payload="$(bash_payload "python3 -c \"import pathlib; pathlib.Path('${target}').write_text('x')\"")"
expect_deny "(23a) .write_text( to out-of-scope path now refused" "$root" "$payload"

payload="$(bash_payload "python3 -c \"import pathlib; pathlib.Path('${target}').write_bytes(b'x')\"")"
expect_deny "(23b) .write_bytes( to out-of-scope path now refused" "$root" "$payload"

payload="$(bash_payload "python3 -c \"import os; os.write(open('${target}','w').fileno(), b'x')\"")"
expect_deny "(23c) os.write( to out-of-scope path now refused" "$root" "$payload"

echo ""
echo "=== tally: ${pass} passed, ${fail} failed (of $((pass+fail)) cases) ==="
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
