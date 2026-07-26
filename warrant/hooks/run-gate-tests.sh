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
  local d
  d="$(mktemp -d -p "$WORKDIR")"
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

echo ""
echo "=== tally: ${pass} passed, ${fail} failed (of $((pass+fail)) cases) ==="
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
