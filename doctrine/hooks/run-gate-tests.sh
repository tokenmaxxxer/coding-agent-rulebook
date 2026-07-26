#!/usr/bin/env bash
# Gate tests for doctrine/hooks/placement-gate.sh.
#
# Companion to docs/proposals/2026-07-26-fix-fail-open-persistent-tests.md:
# placement-gate.sh was flipped fail-open -> fail-closed by
# docs/proposals/2026-07-26-fix-fail-open-hooks.md, but doctrine had no test
# harness at all, so that fix's stated success criterion (a passing test)
# was unmet for this script. This harness is the first persistent coverage
# for it.
#
# Each case asserts:
#   (1) REFUSE on malformed (unparseable) input.
#   (2) REFUSE when python3 is simulated as missing from PATH.
#   (3) PASS on a compliant, well-formed input (a write into a recognized
#       doctrine bucket).
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HOOK_DIR/placement-gate.sh"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

pass=0
fail=0

run_gate() {
  # $1 = root dir, $2 = payload json
  CLAUDE_PROJECT_DIR="$1" DOCTRINE_OFF= bash "$GATE" <<<"$2"
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

# A minimal PATH stub carrying only the coreutils placement-gate.sh's intake
# path needs before it reaches `command -v python3` — cat (payload read) —
# with python3 itself deliberately absent, to simulate "python3 is not on
# PATH" without altering the real PATH for anything else in this process.
NO_PYTHON3_STUB="$WORKDIR/no-python3-stub"
mkdir -p "$NO_PYTHON3_STUB"
for _c in cat bash; do
  _src="$(command -v "$_c" 2>/dev/null)"
  [ -n "$_src" ] && ln -sf "$_src" "$NO_PYTHON3_STUB/$_c"
done

run_gate_no_python3() {
  local root="$1" payload="$2"
  CLAUDE_PROJECT_DIR="$root" DOCTRINE_OFF= PATH="$NO_PYTHON3_STUB" "$NO_PYTHON3_STUB/bash" "$GATE" <<<"$payload"
}

expect_deny_no_python3() {
  local name="$1" root="$2" payload="$3"
  local out rc
  out="$(run_gate_no_python3 "$root" "$payload" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: $name -- expected deny (non-zero exit) on missing python3, got exit 0. Output: $out"
    fail=$((fail+1))
  elif ! printf '%s' "$out" | grep -q "python3"; then
    echo "FAIL: $name -- denied (exit $rc) but did not mention python3 in its refusal. Output: $out"
    fail=$((fail+1))
  else
    echo "PASS: $name (exit $rc)"
    pass=$((pass+1))
  fi
}

# =========================================================================
# Case 1: malformed (unparseable) input -> REFUSE.
# =========================================================================
root="$(mktemp -d -p "$WORKDIR")"
out="$(run_gate "$root" 'not json at all {{{' 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "PASS: (1) placement-gate malformed JSON input refused (exit $rc)"
  pass=$((pass+1))
else
  echo "FAIL: (1) placement-gate malformed JSON input was ALLOWED (exit 0): $out"
  fail=$((fail+1))
fi

# =========================================================================
# Case 2: simulated missing python3 -> REFUSE.
# =========================================================================
root="$(mktemp -d -p "$WORKDIR")"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/docs/decisions/x.md","content":"x\n"}}
JSON
)
expect_deny_no_python3 "(2) placement-gate simulated missing python3 refused" "$root" "$payload"

# =========================================================================
# Case 3: compliant (well-formed) input -- a write into a recognized
# doctrine bucket -> PASS.
# =========================================================================
root="$(mktemp -d -p "$WORKDIR")"
mkdir -p "$root/docs/decisions"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/docs/decisions/x.md","content":"x\n"}}
JSON
)
expect_allow "(3) placement-gate compliant write into a recognized bucket allowed" "$root" "$payload"

# Companion: a write under docs/ landing outside the six buckets is still
# refused -- proves the added intake-hardening did not weaken the
# pre-existing bucket-placement check.
root="$(mktemp -d -p "$WORKDIR")"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/docs/not-a-bucket/x.md","content":"x\n"}}
JSON
)
expect_deny "(companion) placement-gate write outside the six buckets still refused" "$root" "$payload"

echo ""
echo "=== tally: ${pass} passed, ${fail} failed (of $((pass+fail)) cases) ==="
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
