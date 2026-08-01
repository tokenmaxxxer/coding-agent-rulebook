#!/usr/bin/env bash
# Standalone test harness for coding-progress-gate.sh (issue-64 remediation):
# the §15 structural resolved_findings check, CODING_CYCLE_OFF kill switch,
# and malformed-JSON fail-closed behavior. Exercised as a real subprocess
# against a scratch git repo, mirroring tests/run-gate-tests.sh's pattern.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../coding-progress-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-38s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-38s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

if [ -z "${CLAUDE_PLUGIN_ROOT_CORE:-}" ]; then
  for _cand in "$HOME/tokenmaxxxer/tokenmaxxxer-core/core" "$HERE/../../../core"; do
    if [ -f "$_cand/hooks/lib/gate-lib.sh" ]; then export CLAUDE_PLUGIN_ROOT_CORE="$_cand"; break; fi
  done
fi

VBLOCK='loop_state: reproduced
finding:
  requirement: R1
  severity: blocking
  addressed_to: coding
  id: F1'

VBLOCK_CLEARED='loop_state: cleared
finding:
  requirement: R1
  severity: blocking
  addressed_to: coding
  id: F1'

progress() { # want name verify_content implementation_content [env...]
  want="$1"; name="$2"; vcontent="$3"; icontent="$4"; shift 4
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  ( cd "$td" && git config user.email t@t && git config user.name t \
    && mkdir -p docs/issue-7/reports src \
    && printf '%s' "$vcontent" > docs/issue-7/reports/verify.md \
    && printf '%s' "$icontent" > docs/issue-7/reports/implementation.md \
    && echo x > src/app.py && git add -A )
  payload_file="$(mktemp)"
  printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m \\"fix\\n\\nSubject: issue-7\\""},"cwd":"%s"}' "$td" > "$payload_file"
  ( cd "$td" && env -u CLAUDE_PROJECT_DIR "$@" /bin/bash "$GATE" < "$payload_file" ) >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td" "$payload_file"; report "$want" "$got" "$name"
}

# baseline behavior, unchanged by the migration
progress deny  blocking-finding-unresolved "$VBLOCK" 'loop_state: approved'
progress allow no-verify-findings "loop_state: cleared" 'loop_state: approved'

# -- §15 structural upgrade: adjacency within the finding's OWN sub-entry --

# allow: resolved_findings entry names verify.md adjacent to a sha, for the
# SAME finding id, and verify's own loop_state is cleared.
GOOD_RESOLVED='resolved_findings
- id: F1
  finder: docs/issue-7/reports/verify.md sha abc1234'
progress allow resolved-adjacent-allows "$VBLOCK_CLEARED" "$GOOD_RESOLVED"

# deny: a 7-hex token and the word "verify.md" both appear somewhere in the
# record, but NOT adjacent within the same finding's own sub-entry (this is
# the exact gap the audit's "§15 gate cavity" finding named — a block-wide
# substring match would have wrongly allowed this).
GAMED_RESOLVED='## Notes
Unrelated commit abc1234 touched something else.
resolved_findings
- id: F1
  finder: mentioned verify.md in passing, no sha here'
progress deny resolved-gamed-not-adjacent-denies "$VBLOCK_CLEARED" "$GAMED_RESOLVED"

# deny: verify's own loop_state is not cleared (still reproduced, per
# $VBLOCK), even though the implementation record's resolved_findings entry
# is otherwise well-formed.
GOOD_RESOLVED_ONLY='resolved_findings
- id: F1
  finder: docs/issue-7/reports/verify.md sha abc1234'
progress deny resolved-verify-not-cleared "$VBLOCK" "$GOOD_RESOLVED_ONLY"

# -- kill switch --
progress allow kill-switch-active "$VBLOCK" 'loop_state: approved' env CODING_CYCLE_OFF=1
progress deny  kill-switch-unrecognized-stays-active "$VBLOCK" 'loop_state: approved' env CODING_CYCLE_OFF=banana

# -- malformed JSON: fail closed --
malformed() { # want name raw_payload
  want="$1"; name="$2"; raw="$3"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  payload_file="$(mktemp)"; printf '%s' "$raw" > "$payload_file"
  ( cd "$td" && env -u CLAUDE_PROJECT_DIR CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" < "$payload_file" ) >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td" "$payload_file"; report "$want" "$got" "$name"
}
malformed deny malformed-json-truncated '{"tool_name":"Bash","tool_input":{'
malformed deny malformed-json-empty ''
malformed deny malformed-json-non-object '[1,2,3]'

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
