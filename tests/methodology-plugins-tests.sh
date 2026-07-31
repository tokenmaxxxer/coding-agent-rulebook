#!/usr/bin/env bash
# Repo-root harness for the issue-61 methodology plugin set: proposal-shape,
# record-shape, survey-order. Each plugin also ships its own hooks/tests/ for
# standalone/removable testing; this file additionally exercises the three
# gates together against realistic combined proposal/record fixtures, and
# does a bash -n syntax check on every hook script in the set.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$HERE/.." && pwd -P)"
PS_GATE="$ROOT/proposal-shape/hooks/proposal-shape-gate.sh"
RS_GATE="$ROOT/record-shape/hooks/record-shape-gate.sh"
SO_GATE="$ROOT/survey-order/hooks/survey-order-gate.sh"

pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-32s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-32s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

echo "-- bash -n syntax check, every plugin hook script --"
syn_fail=0
for f in \
  "$ROOT/proposal-shape/hooks/directive.sh" "$PS_GATE" "$ROOT/proposal-shape/hooks/tests/proposal-shape-tests.sh" \
  "$ROOT/record-shape/hooks/directive.sh" "$RS_GATE" "$ROOT/record-shape/hooks/tests/record-shape-tests.sh" \
  "$ROOT/survey-order/hooks/directive.sh" "$SO_GATE" "$ROOT/survey-order/hooks/tests/survey-order-tests.sh"
do
  if bash -n "$f" 2>/dev/null; then
    printf 'ok     syntax %s\n' "${f#"$ROOT"/}"
  else
    syn_fail=$((syn_fail+1)); printf 'FAIL   syntax %s\n' "${f#"$ROOT"/}"
  fi
done
fail=$((fail+syn_fail)); pass=$((pass + (9 - syn_fail)))

# run WANT NAME GATE FILE CONTENT [PRE_CMD]
# PRE_CMD, if given, runs inside the scratch repo before the gate fires
# (e.g. to pre-create a survey.md file for survey-order's allow case).
run() {
  want="$1"; name="$2"; gate="$3"; file="$4"; content="$5"; pre="${6:-}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$file")"
  if [ -n "$pre" ]; then ( cd "$td" && eval "$pre" ); fi
  payload_file="$(mktemp)"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$file" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    > "$payload_file"
  env CLAUDE_PROJECT_DIR="$td" /bin/bash "$gate" < "$payload_file" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td" "$payload_file"; report "$want" "$got" "$name"
}

runenv() { # want name gate file content envassign
  want="$1"; name="$2"; gate="$3"; file="$4"; content="$5"; envassign="$6"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$file")"
  payload_file="$(mktemp)"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$file" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    > "$payload_file"
  env CLAUDE_PROJECT_DIR="$td" "$envassign" /bin/bash "$gate" < "$payload_file" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td" "$payload_file"; report "$want" "$got" "$name"
}

PROP=docs/issue-9/proposals/2026-08-01-example.md
REC=docs/issue-9/reports/implementation.md
SURVEY=docs/issue-9/reports/implementation/survey.md

COMPLETE_PROPOSAL='files:
  - src/example.py

## Request
Do the thing.

## Constraints
Keep it small.

## Rationale
We considered a queue-based approach rather than a direct call, and rejected it because it added latency for no benefit here.

## What will be done
Write the function.

## Out of scope
Nothing else.

## How you'\''ll know it worked
Tests pass.'

MISSING_RATIONALE='files:
  - src/example.py

## Request
Do the thing.

## Constraints
Keep it small.

## What will be done
Write the function.

## Out of scope
Nothing else.

## How you'\''ll know it worked
Tests pass.'

SKIP_STATED='files:
  - src/example.py

## Request
Do the thing.

## Constraints
Keep it small.

## Rationale
Pure bugfix, no design decision to weigh; survey skipped per scout-directive skip condition.

## What will be done
Write the function.

## Out of scope
Nothing else.

## How you'\''ll know it worked
Tests pass.'

COMPLETE_RECORD='---
subject: issue-9
role: implementation
code_under_review: abc1234
loop_state: landed
---

# Record

## What was done

Built the thing.

## What did not work

None.
'

DEVIATION_NO_RATIONALE='---
code_under_review: abc1234
loop_state: landed
---

# Record

## What was done

A scope-exceeded stop triggered mid-build.

## What did not work

None.
'

echo "-- allow: complete 7-section proposal, survey.md present (proposal-shape and survey-order both allow) --"
run allow ps-complete-with-survey "$PS_GATE" "$PROP" "$COMPLETE_PROPOSAL" "mkdir -p \$(dirname $SURVEY) && echo survey > $SURVEY"
run allow so-complete-with-survey "$SO_GATE" "$PROP" "$COMPLETE_PROPOSAL" "mkdir -p \$(dirname $SURVEY) && echo survey > $SURVEY"

echo "-- deny: proposal missing ## Rationale (proposal-shape denies) --"
run deny ps-missing-rationale "$PS_GATE" "$PROP" "$MISSING_RATIONALE" "mkdir -p \$(dirname $SURVEY) && echo survey > $SURVEY"

echo "-- deny: proposal complete but survey.md absent and no skip-record language (survey-order denies) --"
run deny so-no-survey-no-skip "$SO_GATE" "$PROP" "$COMPLETE_PROPOSAL"

echo "-- allow: proposal complete, survey.md absent, but proposal body states the scout-skip condition (survey-order allows) --"
run allow so-no-survey-skip-stated "$SO_GATE" "$PROP" "$SKIP_STATED"

echo "-- allow: complete record, no deviation language, no Rationale-for-deviations section (record-shape allows) --"
run allow rs-complete "$RS_GATE" "$REC" "$COMPLETE_RECORD"

echo "-- deny: record contains deviation language but no Rationale-for-deviations section (record-shape denies) --"
run deny rs-deviation-no-rationale "$RS_GATE" "$REC" "$DEVIATION_NO_RATIONALE"

echo "-- deny: record missing ## What did not work (record-shape denies) --"
MISSING_WDNW='---
code_under_review: abc1234
loop_state: landed
---

# Record

## What was done

Built the thing.
'
run deny rs-missing-wdnw "$RS_GATE" "$REC" "$MISSING_WDNW"

echo "-- allow: foreign path passes through untouched, for all three gates --"
run allow ps-foreign-path "$PS_GATE" "docs/issue-7/reports/qa.md" "$MISSING_RATIONALE"
run allow rs-foreign-path "$RS_GATE" "docs/issue-7/proposals/x.md" "$MISSING_WDNW"
run allow so-foreign-path "$SO_GATE" "docs/issue-7/reports/qa.md" "$MISSING_RATIONALE"

echo "-- allow: each plugin's own kill switch set, otherwise-denying content passes through --"
runenv allow ps-kill-switch "$PS_GATE" "$PROP" "$MISSING_RATIONALE" PROPOSAL_SHAPE_GATE_OFF=1
runenv allow rs-kill-switch "$RS_GATE" "$REC" "$MISSING_WDNW" RECORD_SHAPE_GATE_OFF=1
runenv allow so-kill-switch "$SO_GATE" "$PROP" "$COMPLETE_PROPOSAL" SURVEY_ORDER_GATE_OFF=1

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
