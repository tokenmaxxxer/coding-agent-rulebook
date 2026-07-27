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

# =========================================================================
# Cases 4-6: fail-closed on ANY internal error (contract:
# docs/proposals/2026-07-26-gates-fail-closed-on-internal-error.md).
# A null byte embedded in tool_input.file_path makes os.path.realpath raise
# an uncaught ValueError (-> exit 1 = fail-OPEN before the fix); it must now
# resolve to exit 2 (DENY), the only code a PreToolUse hook blocks on.
# =========================================================================
RECORD_FIELDS_GATE="$HOOK_DIR/record-fields-gate.sh"

expect_deny2() {
  # $1 name, $2 gate, $3 root, $4 payload — asserts EXACTLY exit 2.
  local name="$1" gate="$2" root="$3" payload="$4" out rc
  out="$(CLAUDE_PROJECT_DIR="$root" DOCTRINE_OFF= bash "$gate" <<<"$payload" 2>&1)"
  rc=$?
  if [ "$rc" -eq 2 ]; then
    echo "PASS: $name (exit 2 DENY)"
    pass=$((pass+1))
  else
    echo "FAIL: $name -- expected exit 2 (DENY/fail-closed), got exit $rc. Output: $out"
    fail=$((fail+1))
  fi
}

# --- (4) placement-gate.sh: null byte in file_path -> DENY (exit 2) -------
root="$(mktemp -d -p "$WORKDIR")"
payload="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/docs/decisions/x\\u0000.md","content":"x"}}' "$root")"
expect_deny2 "(4) placement-gate null-byte file_path fails closed" "$GATE" "$root" "$payload"

# --- (5) record-fields-gate.sh: null byte in file_path -> DENY (exit 2) ---
root="$(mktemp -d -p "$WORKDIR")"
payload="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/docs/reports/records/subj/coding\\u0000.md","content":"x"}}' "$root")"
expect_deny2 "(5) record-fields null-byte file_path fails closed" "$RECORD_FIELDS_GATE" "$root" "$payload"

# --- (6) record-fields-gate.sh: malformed JSON -> DENY (exit 2) -----------
root="$(mktemp -d -p "$WORKDIR")"
expect_deny2 "(6) record-fields malformed JSON fails closed" "$RECORD_FIELDS_GATE" "$root" 'not json {{{'

# =========================================================================
# Cases 7-8: fail-closed trap-at-top on a PRE-LOGIC abort (contract:
# docs/proposals/2026-07-26-gates-fail-closed-trap-at-top.md).
#
# The EXIT trap installed as each gate's FIRST executable statement must
# convert ANY abnormal termination BEFORE the verdict logic runs — a failed
# source, a set -u abort, an unbound var, a stray non-2 exit — into exit 2
# (DENY). A PreToolUse hook treats any non-2 exit as NON-BLOCKING
# (fail-OPEN), so this class must fail closed. We produce a temp copy of the
# gate with a self-contained abort snippet spliced in immediately after
# `trap __fc EXIT` (above every set/source/verdict statement) and assert the
# copy still exits 2.
# =========================================================================
expect_prelogic_abort_deny2() {
  # $1 = name, $2 = gate script path
  local name="$1" gate="$2" tmp out rc
  tmp="$(mktemp -p "$WORKDIR" prelogic-XXXXXX.sh)"
  awk '
    { print }
    /^trap __fc EXIT$/ && !done {
      print "set -u; : \"${__FC_TEST_UNBOUND_VAR__}\"  # induced pre-logic abort"
      done=1
    }
  ' "$gate" > "$tmp"
  if ! grep -q "__FC_TEST_UNBOUND_VAR__" "$tmp"; then
    echo "FAIL: $name -- could not splice pre-logic abort (no 'trap __fc EXIT' line found in $gate)"
    fail=$((fail+1))
    return
  fi
  out="$(CLAUDE_PROJECT_DIR="$WORKDIR" DOCTRINE_OFF= bash "$tmp" <<<'{"tool_name":"Write","tool_input":{"file_path":"/x.md","content":"x"}}' 2>&1)"
  rc=$?
  if [ "$rc" -eq 2 ]; then
    echo "PASS: $name (pre-logic abort forced to exit 2 DENY)"
    pass=$((pass+1))
  else
    echo "FAIL: $name -- pre-logic abort expected exit 2 (fail-closed), got exit $rc. Output: $out"
    fail=$((fail+1))
  fi
}

expect_prelogic_abort_deny2 "(7) placement-gate pre-logic abort fails closed" "$GATE"
expect_prelogic_abort_deny2 "(8) record-fields pre-logic abort fails closed" "$RECORD_FIELDS_GATE"

# =========================================================================
# Cases 9-12: no-path-allow (contract:
# docs/proposals/2026-07-27-placement-gate-no-path-allow.md). A well-formed
# tool_input with no file_path/notebook_path is not a write this gate has
# jurisdiction over -- it must ALLOW (exit 0), not refuse.
# =========================================================================

# --- (9) Bash tool_input with no file_path -> ALLOW -----------------------
root="$(mktemp -d -p "$WORKDIR")"
payload='{"tool_name":"Bash","tool_input":{"command":"git log"}}'
expect_allow "(9) placement-gate Bash tool call with no file_path allowed" "$root" "$payload"

# --- (10) Agent/Task dispatch with no file_path -> ALLOW -------------------
root="$(mktemp -d -p "$WORKDIR")"
payload='{"tool_name":"Task","tool_input":{"description":"dispatch","prompt":"do the thing"}}'
expect_allow "(10) placement-gate Agent/Task dispatch with no file_path allowed" "$root" "$payload"

# --- (11) Write with file_path under docs/ outside the six buckets is still
# refused -- unchanged behavior when a path IS present. ---------------------
root="$(mktemp -d -p "$WORKDIR")"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/docs/not-a-bucket/y.md","content":"x\n"}}
JSON
)
expect_deny "(11) placement-gate Write outside the six buckets still refused" "$root" "$payload"

# --- (12) Write tool call with no file_path at all (malformed tool call) ->
# now ALLOWS rather than denies -- intentional behavior change: a missing
# path means the gate has no jurisdiction, regardless of tool_name.
# ----------------------------------------------------------------------------
root="$(mktemp -d -p "$WORKDIR")"
payload='{"tool_name":"Write","tool_input":{"content":"x\n"}}'
expect_allow "(12) placement-gate Write with no file_path now allowed (was denied)" "$root" "$payload"

# =========================================================================
# Cases 13-14: MultiEdit tool_input carries the path in the same
# `file_path` key as Edit/Write (record-fields-gate.sh:106 treats MultiEdit
# as a write tool the same way). placement-gate.sh does not branch on
# tool_name, only on tool_input.file_path, so MultiEdit must be judged
# identically to Write/Edit -- confirms the matcher revert to `.*` in
# hooks.json (b0f7a661's enumerated-matcher gap, and the MultiEdit omission
# from it) is covered by the script-level check, not by hooks.json alone.
# =========================================================================

# --- (13) MultiEdit writing outside the six buckets -> DENY ---------------
root="$(mktemp -d -p "$WORKDIR")"
payload=$(cat <<JSON
{"tool_name":"MultiEdit","tool_input":{"file_path":"$root/docs/not-a-bucket/z.md","edits":[{"old_string":"a","new_string":"b"}]}}
JSON
)
expect_deny "(13) placement-gate MultiEdit outside the six buckets refused" "$root" "$payload"

# --- (14) MultiEdit writing inside a recognized bucket -> ALLOW -----------
root="$(mktemp -d -p "$WORKDIR")"
mkdir -p "$root/docs/decisions"
payload=$(cat <<JSON
{"tool_name":"MultiEdit","tool_input":{"file_path":"$root/docs/decisions/z.md","edits":[{"old_string":"a","new_string":"b"}]}}
JSON
)
expect_allow "(14) placement-gate MultiEdit inside a recognized bucket allowed" "$root" "$payload"

echo ""
echo "=== tally: ${pass} passed, ${fail} failed (of $((pass+fail)) cases) ==="
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
