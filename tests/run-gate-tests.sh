#!/usr/bin/env bash
# Coding's surviving gates, exercised as real subprocesses.
#
# History (issue-64 remediation): this file used to shell out to
# record-fields-gate.sh and trailer-gate.sh under coding/hooks/ — both were
# deleted when coding's record/commit checks were consolidated (issue-61's
# proposal flagged this exact staleness and deferred the fix to this issue).
# record-fields-gate.sh's job (required record fields/headings) now lives in
# record-shape-gate.sh, targeting docs/issue-<n>/reports/implementation.md —
# repointed below, same allow/deny intent, new gate and path.
# trailer-gate.sh's job (require a `Subject: issue-<n>` commit trailer) has
# no successor anywhere in this repo: contract v3's own specs
# (docs/specs/*.md) no longer state that requirement, and no gate reads a
# commit message for it. Resurrecting a trailer check here would invent
# behavior the current contract does not ask for, so those three cases are
# retired rather than repointed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$HERE/.." && pwd -P)"
CODING_HOOKS="$ROOT/coding/hooks"
RECORD_SHAPE_GATE="$ROOT/record-shape/hooks/record-shape-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

if [ -z "${CLAUDE_PLUGIN_ROOT_CORE:-}" ]; then
  for _cand in "$HOME/tokenmaxxxer/tokenmaxxxer-core/core" "$ROOT/../core"; do
    if [ -f "$_cand/hooks/lib/gate-lib.sh" ]; then export CLAUDE_PLUGIN_ROOT_CORE="$_cand"; break; fi
  done
fi

REC=docs/issue-7/reports/implementation.md
run() { # want name gate_abspath file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$4" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$5")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$3" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
GOOD='---
code_under_review: abc1234
loop_state: landed
---

# Record

## What was done

Built the feature.

## What did not work

First cut of the parser broke on empty input.'
run allow record-complete "$RECORD_SHAPE_GATE" "$REC" "$GOOD"
run deny  record-empty    "$RECORD_SHAPE_GATE" "$REC" "nothing"
run allow foreign-path    "$RECORD_SHAPE_GATE" "docs/issue-7/reports/qa.md" "x"

# coding-progress: blocking finding without resolution denies the commit
progress() { # want name verify_content implementation_content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  ( cd "$td" && git config user.email t@t && git config user.name t \
    && mkdir -p docs/issue-7/reports src \
    && printf '%s' "$3" > docs/issue-7/reports/verify.md \
    && printf '%s' "$4" > docs/issue-7/reports/implementation.md \
    && echo x > src/app.py && git add -A )
  printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m \\"fix\\n\\nSubject: issue-7\\""},"cwd":"%s"}' "$td" \
    | ( cd "$td" && env -u CLAUDE_PROJECT_DIR /bin/bash "$CODING_HOOKS/coding-progress-gate.sh" ) >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
VBLOCK='loop_state: reproduced
finding:
  requirement: R1
  severity: blocking
  addressed_to: coding'
progress deny  blocking-finding-unresolved "$VBLOCK" 'loop_state: approved'
progress allow no-verify-findings "loop_state: cleared" 'loop_state: approved'

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
