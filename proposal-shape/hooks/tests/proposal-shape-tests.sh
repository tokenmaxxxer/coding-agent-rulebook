#!/usr/bin/env bash
# Standalone test harness for proposal-shape-gate.sh, exercised as a real
# subprocess against a scratch git repo.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../proposal-shape-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-28s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-28s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

# gate-lib.sh/gate-lib.py (core issue #72) are referenced, never vendored —
# resolve the core plugin root for the gate subprocess.
if [ -z "${CLAUDE_PLUGIN_ROOT_CORE:-}" ]; then
  for _cand in "$HOME/tokenmaxxxer/tokenmaxxxer-core/core" "$HERE/../../../core"; do
    if [ -f "$_cand/hooks/lib/gate-lib.sh" ]; then export CLAUDE_PLUGIN_ROOT_CORE="$_cand"; break; fi
  done
fi

raw_run() { # want name file existing_content raw_payload_template (with %s for the resolved file path)
  local want="$1" name="$2" file="$3" existing="$4" raw_tmpl="$5"
  local td; td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  if [ -n "$file" ]; then mkdir -p "$td/$(dirname "$file")"; printf '%s' "$existing" > "$td/$file"; fi
  local payload_file; payload_file="$(mktemp)"
  printf "$raw_tmpl" "$file" > "$payload_file"
  env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" < "$payload_file" >/dev/null 2>&1
  local rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td" "$payload_file"; report "$want" "$got" "$name"
}

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

# -- mandatory cases (issue-64 point 3) --

# Edit replace_all:true: both "TBD" placeholders (one in Rationale's
# rejected-alternative sentence, one decorative) must be replaced for
# gate_reconstruct_write's replace_all-honoring behavior to be exercised.
EDIT_BASE="${COMPLETE/rejected it because it added latency for no benefit here./TBD it added latency TBD}"
raw_run allow edit-replace-all-true "$PROP" "$EDIT_BASE" \
  '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"TBD","new_string":"rejected because","replace_all":true},"cwd":"x"}'

# MultiEdit mixed replace_all true/false, applied to the same base.
MULTIEDIT_PAYLOAD="$(python3 -c '
import json
ti = {"file_path": "PLACEHOLDER", "edits": [
  {"old_string": "TBD", "new_string": "rejected because", "replace_all": True},
  {"old_string": "example.py", "new_string": "example.py", "replace_all": False},
]}
print(json.dumps({"tool_name": "MultiEdit", "tool_input": ti, "cwd": "x"}))
')"
raw_run allow multiedit-mixed-replace-all "$PROP" "$EDIT_BASE" "${MULTIEDIT_PAYLOAD/PLACEHOLDER/%s}"

raw_run deny malformed-json-truncated "$PROP" "$COMPLETE" '{"tool_name":"Write","tool_input":{'
raw_run deny malformed-json-empty     "$PROP" "$COMPLETE" ''
raw_run deny malformed-json-non-object "$PROP" "$COMPLETE" '[1,2,3]'

run deny kill-switch-unrecognized-stays-active "$PROP" "$MISSING_RATIONALE" "PROPOSAL_SHAPE_GATE_OFF=banana"

_td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$_td"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/%s","content":%s},"cwd":"%s"}' \
  "$_td" "$PROP" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$MISSING_RATIONALE")" "$_td" > "$_td/payload.json"
env CLAUDE_PROJECT_DIR="$_td" /bin/bash "$GATE" < "$_td/payload.json" >/dev/null 2>&1
_rc=$?; case "$_rc" in 0) _got=allow ;; 2) _got=deny ;; *) _got="exit-$_rc" ;; esac
rm -rf "$_td"; report deny "$_got" absolute-path-denies-like-relative

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
