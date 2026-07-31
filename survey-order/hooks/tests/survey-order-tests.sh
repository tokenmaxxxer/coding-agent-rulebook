#!/usr/bin/env bash
# survey-order's gate, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../survey-order-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

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

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
