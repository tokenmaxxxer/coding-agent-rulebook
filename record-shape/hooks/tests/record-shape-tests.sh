#!/usr/bin/env bash
# Standalone test harness for record-shape-gate.sh, exercised as a real
# subprocess (mirrors tests/run-gate-tests.sh's pattern).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../record-shape-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

# gate-lib.sh/gate-lib.py (core issue #72) are referenced, never vendored
# (docs/handbooks/canon-scripts.md) — resolve the core plugin root for the
# gate subprocess the same way the gate itself does, honoring an already-set
# CLAUDE_PLUGIN_ROOT_CORE first.
if [ -z "${CLAUDE_PLUGIN_ROOT_CORE:-}" ]; then
  for _cand in "$HOME/tokenmaxxxer/tokenmaxxxer-core/core" "$HERE/../../../core"; do
    if [ -f "$_cand/hooks/lib/gate-lib.sh" ]; then export CLAUDE_PLUGIN_ROOT_CORE="$_cand"; break; fi
  done
fi

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

# raw_run: fire an arbitrary raw JSON payload (or malformed text) directly at
# the gate, optionally against an existing file at $2 with content $3.
raw_run() { # want name file existing_content raw_payload [env...]
  want="$1"; name="$2"; file="$3"; existing="$4"; raw="$5"; shift 5
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  if [ -n "$file" ]; then mkdir -p "$td/$(dirname "$file")"; printf '%s' "$existing" > "$td/$file"; fi
  payload_file="$(mktemp)"; printf '%s' "$raw" > "$payload_file"
  env CLAUDE_PROJECT_DIR="$td" "$@" /bin/bash "$GATE" < "$payload_file" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td" "$payload_file"; report "$want" "$got" "$name"
}

json() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }

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

# -- mandatory cases (issue-64 point 3 / core's run-gate-lib-tests.sh six-group shape) --

# Edit with replace_all:true against a multiply-occurring string: every
# occurrence of "TBD" must be replaced, so the resulting text carries the
# required "## What did not work" heading (gate_reconstruct_write honoring
# replace_all, not a first-occurrence-only hand-rolled .replace()).
EDIT_BASE='---
code_under_review: abc1234
loop_state: landed
---

# Record

## What was done
TBD

## What did not work
TBD
'
raw_run allow edit-replace-all-true "$REC" "$EDIT_BASE" \
  "$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"TBD","new_string":"Built the thing.","replace_all":true},"cwd":"x"}' "$REC")"

# MultiEdit with mixed replace_all true/false: first edit replaces every
# "None." (both a real one and a decoy the section text repeats), second
# edit replaces only the first "X" — mirrors core's mixed-mode case.
MULTIEDIT_BASE='---
code_under_review: abc1234
loop_state: landed
---

# Record

## What was done
X X

## What did not work
None. None.
'
MULTIEDIT_PAYLOAD="$(python3 -c '
import json
ti = {"file_path": "'"$REC"'", "edits": [
  {"old_string": "None.", "new_string": "Nothing outstanding.", "replace_all": True},
  {"old_string": "X", "new_string": "Y", "replace_all": False},
]}
print(json.dumps({"tool_name": "MultiEdit", "tool_input": ti, "cwd": "x"}))
')"
raw_run allow multiedit-mixed-replace-all "$REC" "$MULTIEDIT_BASE" "$MULTIEDIT_PAYLOAD"

# Malformed JSON: truncated, empty, and non-object payloads must all deny
# rather than pass a write through unjudged.
raw_run deny malformed-json-truncated "$REC" "$COMPLETE" '{"tool_name":"Write","tool_input":{'
raw_run deny malformed-json-empty     "$REC" "$COMPLETE" ''
raw_run deny malformed-json-non-object "$REC" "$COMPLETE" '[1,2,3]'

# Kill-switch unrecognized value (a typo, not a real off-spelling) must stay
# ACTIVE — the issue-72-confirmed fail-open bug this migration fixes.
run deny kill-switch-unrecognized-stays-active "$REC" "$MISSING_WDNW" env RECORD_SHAPE_GATE_OFF=banana

# Absolute file_path must be judged identically to the relative-path
# fixture (same scope, same verdict) — path normalization parity.
_td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$_td"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/%s","content":"nothing to see here"},"cwd":"%s"}' \
  "$_td" "$REC" "$_td" > "$_td/payload.json"
env CLAUDE_PROJECT_DIR="$_td" /bin/bash "$GATE" < "$_td/payload.json" >/dev/null 2>&1
_rc=$?; case "$_rc" in 0) _got=allow ;; 2) _got=deny ;; *) _got="exit-$_rc" ;; esac
rm -rf "$_td"; report deny "$_got" absolute-path-denies-like-relative

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
