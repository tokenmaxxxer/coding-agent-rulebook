#!/usr/bin/env bash
# Standalone test harness for hunt-state.sh (issue-70 closeout): confirms
# release/reset cleanup runs even when the core plugin's gate-lib.sh is
# missing (missing-core case), and that the kill-switch is still honored
# when core is present (regression guard for existing behavior).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
STATE="$HERE/../hunt-state.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-38s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-38s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

if [ -z "${CLAUDE_PLUGIN_ROOT_CORE:-}" ]; then
  for _cand in "$HOME/tokenmaxxxer/tokenmaxxxer-core/core" "$HERE/../../../core"; do
    if [ -f "$_cand/hooks/lib/gate-lib.sh" ]; then export CLAUDE_PLUGIN_ROOT_CORE="$_cand"; break; fi
  done
fi

# --- missing-core: release/reset must still clear lock/count files, and
# exit 0 (informing-only — never blocks), even though the kill-switch check
# itself cannot run without gate-lib.sh.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
: > "$td/.warrant-hunt.lock"
: > "$td/.warrant-hunt.count"
out="$(cd "$td" && env -u CLAUDE_PROJECT_DIR CLAUDE_PROJECT_DIR="$td" \
  CLAUDE_PLUGIN_ROOT_CORE="$td/no-such-core" /bin/bash "$STATE" reset 2>&1)"
rc=$?
case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
report allow "$got" missing-core-reset-exits-zero
if [ -f "$td/.warrant-hunt.lock" ] || [ -f "$td/.warrant-hunt.count" ]; then
  fail=$((fail+1)); printf 'FAIL   %-38s files still present\n' missing-core-reset-clears-files
else
  pass=$((pass+1)); printf 'ok     %-38s cleared\n' missing-core-reset-clears-files
fi
case "$out" in
  *"core plugin not found"*) pass=$((pass+1)); printf 'ok     %-38s %s\n' missing-core-message-explicit "explicit" ;;
  *) fail=$((fail+1)); printf 'FAIL   %-38s want=explicit got=%s\n' missing-core-message-explicit "$out" ;;
esac
rm -rf "$td"

# --- missing-core: release (SubagentStop) alone must still clear the lock.
td2="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td2"
: > "$td2/.warrant-hunt.lock"
: > "$td2/.warrant-hunt.count"
( cd "$td2" && env -u CLAUDE_PROJECT_DIR CLAUDE_PROJECT_DIR="$td2" \
  CLAUDE_PLUGIN_ROOT_CORE="$td2/no-such-core" /bin/bash "$STATE" release ) >/dev/null 2>&1
if [ -f "$td2/.warrant-hunt.lock" ]; then
  fail=$((fail+1)); printf 'FAIL   %-38s lock still present\n' missing-core-release-clears-lock
else
  pass=$((pass+1)); printf 'ok     %-38s cleared\n' missing-core-release-clears-lock
fi
if [ ! -f "$td2/.warrant-hunt.count" ]; then
  fail=$((fail+1)); printf 'FAIL   %-38s count should survive a release (not a reset)\n' missing-core-release-preserves-count
else
  pass=$((pass+1)); printf 'ok     %-38s preserved\n' missing-core-release-preserves-count
fi
rm -rf "$td2"

# --- core present: kill switch still honored (regression guard). With
# WARRANT_OFF set, the script exits 0 without touching the files at all —
# same as before this change, confirming the new guard branch does not
# disturb the core-present path.
if [ -f "${CLAUDE_PLUGIN_ROOT_CORE:-/nonexistent}/hooks/lib/gate-lib.sh" ]; then
  td3="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td3"
  : > "$td3/.warrant-hunt.lock"
  ( cd "$td3" && env -u CLAUDE_PROJECT_DIR CLAUDE_PROJECT_DIR="$td3" WARRANT_OFF=1 /bin/bash "$STATE" reset ) >/dev/null 2>&1
  rc=$?
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report allow "$got" core-present-kill-switch-exits-zero
  if [ -f "$td3/.warrant-hunt.lock" ]; then
    pass=$((pass+1)); printf 'ok     %-38s %s\n' core-present-kill-switch-skips-cleanup "lock untouched"
  else
    fail=$((fail+1)); printf 'FAIL   %-38s lock was cleared despite kill switch\n' core-present-kill-switch-skips-cleanup
  fi
  rm -rf "$td3"
else
  printf 'skip   %-38s core plugin not found locally; kill-switch regression case skipped\n' core-present-kill-switch-exits-zero
fi

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
