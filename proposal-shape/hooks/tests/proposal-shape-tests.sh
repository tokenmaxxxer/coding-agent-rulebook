#!/usr/bin/env bash
# Standalone test harness for proposal-shape-gate.sh, exercised as a real
# subprocess against a scratch git repo.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../proposal-shape-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-28s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-28s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

run() { # want name file content [env]
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$3")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" ${5:-} /bin/bash "$GATE" >/dev/null 2>&1
  rc=${PIPESTATUS[1]}; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

PROP=docs/issue-9/proposals/2026-08-01-example.md

COMPLETE='files:
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

OUT_OF_ORDER='files:
  - src/example.py

## Request
Do the thing.

## Constraints
Keep it small.

## What will be done
Write the function.

## Rationale
We considered a queue-based approach rather than a direct call, and rejected it because it added latency.

## Out of scope
Nothing else.

## How you'\''ll know it worked
Tests pass.'

TRIVIAL_RATIONALE='files:
  - src/example.py

## Request
Do the thing.

## Constraints
Keep it small.

## Rationale
We chose this approach because it fits well.

## What will be done
Write the function.

## Out of scope
Nothing else.

## How you'\''ll know it worked
Tests pass.'

run allow complete-in-order      "$PROP" "$COMPLETE"
run deny  missing-rationale      "$PROP" "$MISSING_RATIONALE"
run deny  headings-out-of-order  "$PROP" "$OUT_OF_ORDER"
run deny  trivial-rationale-body "$PROP" "$TRIVIAL_RATIONALE"
run allow foreign-path           "docs/issue-7/reports/qa.md" "$MISSING_RATIONALE"
run allow kill-switch-off        "$PROP" "$MISSING_RATIONALE" "PROPOSAL_SHAPE_GATE_OFF=1"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
