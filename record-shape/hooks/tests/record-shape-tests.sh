#!/usr/bin/env bash
# Standalone test harness for record-shape-gate.sh, exercised as a real
# subprocess (mirrors tests/run-gate-tests.sh's pattern).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../record-shape-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

run() { # want name file content [env...]
  want="$1"; name="$2"; file="$3"; content="$4"; shift 4
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$file")"
  payload_file="$(mktemp)"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$file" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    > "$payload_file"
  env CLAUDE_PROJECT_DIR="$td" "$@" /bin/bash "$GATE" < "$payload_file" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td" "$payload_file"; report "$want" "$got" "$name"
}

REC=docs/issue-9/reports/implementation.md

COMPLETE='---
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

MISSING_WDNW='---
code_under_review: abc1234
loop_state: landed
---

# Record

## What was done

Built the thing, no deviation section needed here.
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

DEVIATION_WITH_RATIONALE='---
code_under_review: abc1234
loop_state: landed
---

# Record

## What was done

A scope-exceeded stop triggered mid-build.

## What did not work

None.

## Rationale for deviations

Stopped at the scope boundary; swapped to plan B per proposal alternative.
'

MISSING_FRONTMATTER='---
loop_state: landed
---

# Record

## What did not work

None.
'

run allow record-complete "$REC" "$COMPLETE"
run deny  missing-wdnw-heading "$REC" "$MISSING_WDNW"
run deny  deviation-no-rationale "$REC" "$DEVIATION_NO_RATIONALE"
run allow deviation-with-rationale "$REC" "$DEVIATION_WITH_RATIONALE"
run deny  missing-frontmatter-key "$REC" "$MISSING_FRONTMATTER"
run allow foreign-path "docs/issue-7/reports/qa.md" "nothing to see here"
run allow kill-switch-bypass "$REC" "$MISSING_WDNW" env RECORD_SHAPE_GATE_OFF=1

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
