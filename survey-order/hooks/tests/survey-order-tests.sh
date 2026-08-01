#!/usr/bin/env bash
# survey-order's gate, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../survey-order-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

# gate-lib.sh/gate-lib.py (core issue #72) are referenced, never vendored —
# resolve the core plugin root for the gate subprocess.
if [ -z "${CLAUDE_PLUGIN_ROOT_CORE:-}" ]; then
  for _cand in "$HOME/tokenmaxxxer/tokenmaxxxer-core/core" "$HERE/../../../core"; do
    if [ -f "$_cand/hooks/lib/gate-lib.sh" ]; then export CLAUDE_PLUGIN_ROOT_CORE="$_cand"; break; fi
  done
fi

raw_run() { # want name raw_payload [precreate_survey]
  local want="$1" name="$2" raw="$3" precreate="${4:-}"
  local td; td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  if [ "$precreate" = "survey" ]; then
    mkdir -p "$td/docs/issue-7/reports/implementation"
    printf 'current-state survey\n' > "$td/docs/issue-7/reports/implementation/survey.md"
  fi
  local payload_file; payload_file="$(mktemp)"; printf '%s' "$raw" > "$payload_file"
  env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" < "$payload_file" >/dev/null 2>&1
  local rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td" "$payload_file"; report "$want" "$got" "$name"
}

# run WANT NAME FILEPATH CONTENT [PRECREATE_SURVEY] [EXTRA_ENV_ASSIGNMENT]
# PRECREATE_SURVEY: "survey" to pre-create docs/issue-7/reports/implementation/survey.md
# EXTRA_ENV_ASSIGNMENT: e.g. "SURVEY_ORDER_GATE_OFF=1" — set alongside CLAUDE_PROJECT_DIR
run() {
  local want="$1" name="$2" file="$3" content="$4" precreate="${5:-}" extra_env="${6:-}"
  local td
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$file")"
  if [ "$precreate" = "survey" ]; then
    mkdir -p "$td/docs/issue-7/reports/implementation"
    printf 'current-state survey\n' > "$td/docs/issue-7/reports/implementation/survey.md"
  fi
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$file" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" ${extra_env:+"$extra_env"} /bin/bash "$GATE" >/dev/null 2>&1
  local rc=${PIPESTATUS[1]}
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"
  report "$want" "$got" "$name"
}

PROPOSAL=docs/issue-7/proposals/2026-08-01-some-change.md

# (a) allow: survey.md exists on disk for issue 7, proposal write proceeds
run allow survey-exists-allows "$PROPOSAL" "# Proposal\nSome content with an alternative considered." survey

# (b) deny: survey.md absent, proposal body has no skip-record language
run deny survey-absent-no-skip "$PROPOSAL" "# Proposal\nJust a proposal, no survey, no skip language." ""

# (c) allow: survey.md absent, proposal body explicitly states the skip condition
run allow survey-absent-skip-stated "$PROPOSAL" "# Proposal\nThis is a pure bugfix; scouting was skipped." ""

# (d) allow: foreign path passes through untouched
run allow foreign-path docs/issue-7/reports/qa.md "unrelated qa notes" ""

# (e) allow: kill switch set, otherwise-denying content passes through
run allow kill-switch "$PROPOSAL" "# Proposal\nno survey, no skip language" "" "SURVEY_ORDER_GATE_OFF=1"

# -- mandatory cases (issue-64 point 3) --

# Edit replace_all:true over a multiply-occurring string (survey already
# precreated so the shape check passes regardless; this exercises reconstruct).
EDIT_PAYLOAD="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"TBD","new_string":"final text","replace_all":true},"cwd":"x"}' "$PROPOSAL")"
raw_run allow edit-replace-all-true "$EDIT_PAYLOAD" survey

# MultiEdit with mixed replace_all true/false.
MULTIEDIT_PAYLOAD="$(python3 -c '
import json
ti = {"file_path": "'"$PROPOSAL"'", "edits": [
  {"old_string": "TBD", "new_string": "final", "replace_all": True},
  {"old_string": "X", "new_string": "Y", "replace_all": False},
]}
print(json.dumps({"tool_name": "MultiEdit", "tool_input": ti, "cwd": "x"}))
')"
raw_run allow multiedit-mixed-replace-all "$MULTIEDIT_PAYLOAD" survey

# Malformed JSON: truncated, empty, non-object all deny.
raw_run deny malformed-json-truncated '{"tool_name":"Write","tool_input":{' survey
raw_run deny malformed-json-empty     '' survey
raw_run deny malformed-json-non-object '[1,2,3]' survey

# Kill-switch unrecognized value stays ACTIVE (issue-72-confirmed fail-open fix).
run deny kill-switch-unrecognized-stays-active "$PROPOSAL" "# Proposal\nno survey, no skip language" "" "SURVEY_ORDER_GATE_OFF=banana"

# Absolute file_path denies the same as the relative fixture (no survey precreated).
_td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$_td"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/%s","content":"# Proposal\\nno survey, no skip language"},"cwd":"%s"}' \
  "$_td" "$PROPOSAL" "$_td" > "$_td/payload.json"
env CLAUDE_PROJECT_DIR="$_td" /bin/bash "$GATE" < "$_td/payload.json" >/dev/null 2>&1
_rc=$?; case "$_rc" in 0) _got=allow ;; 2) _got=deny ;; *) _got="exit-$_rc" ;; esac
rm -rf "$_td"; report deny "$_got" absolute-path-denies-like-relative

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
