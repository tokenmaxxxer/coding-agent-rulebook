#!/usr/bin/env bash
# Standalone test harness for hunt-guard.sh (issue-67 remediation): confirms
# the Workflow branch this hook's own tuple checks ("Agent", "Task",
# "Workflow") is reachable end-to-end via hooks.json's matcher, not merely
# present in source — and exercises the single-flight/session-cap logic that
# gate applies once a call reaches it.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GUARD="$HERE/../hunt-guard.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-38s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-38s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

if [ -z "${CLAUDE_PLUGIN_ROOT_CORE:-}" ]; then
  for _cand in "$HOME/tokenmaxxxer/tokenmaxxxer-core/core" "$HERE/../../../core"; do
    if [ -f "$_cand/hooks/lib/gate-lib.sh" ]; then export CLAUDE_PLUGIN_ROOT_CORE="$_cand"; break; fi
  done
fi

dispatch() { # want name tool_name agent_type [env...]
  want="$1"; name="$2"; tool="$3"; agent_type="$4"; shift 4
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  payload_file="$(mktemp)"
  printf '{"tool_name":"%s","tool_input":{"subagent_type":"%s","prompt":"hunt for bugs"},"cwd":"%s"}' \
    "$tool" "$agent_type" "$td" > "$payload_file"
  ( cd "$td" && env -u CLAUDE_PROJECT_DIR CLAUDE_PROJECT_DIR="$td" "$@" /bin/bash "$GUARD" < "$payload_file" ) >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td" "$payload_file"; report "$want" "$got" "$name"
}

# a hunter dispatched via the Workflow tool must reach the same accounting
# as Agent/Task — this is the branch hooks.json's matcher was previously not
# routing to this gate at all (§ matcher/coverage mismatch, issue-67 (e)).
dispatch allow workflow-tool-hunter-dispatch-allowed Workflow warrant-hunter

# non-hunter agent types and other tools pass through regardless of which
# tool name dispatched them.
dispatch allow workflow-tool-non-hunter-allowed Workflow general-purpose
dispatch allow agent-tool-non-hunter-allowed Agent general-purpose

# session cap applies identically once reached via Workflow: a 4th hunter
# dispatch in the same project directory, cap 3, is refused.
cap_td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$cap_td"
for i in 1 2 3; do
  payload_file="$(mktemp)"
  printf '{"tool_name":"Workflow","tool_input":{"subagent_type":"warrant-hunter","prompt":"hunt %s"},"cwd":"%s"}' "$i" "$cap_td" > "$payload_file"
  ( cd "$cap_td" && env -u CLAUDE_PROJECT_DIR CLAUDE_PROJECT_DIR="$cap_td" WARRANT_HUNT_MAX=3 /bin/bash "$GUARD" < "$payload_file" ) >/dev/null 2>&1
  rc=$?
  rm -f "$payload_file"
  rm -f "$cap_td/.warrant-hunt.lock"  # simulate SubagentStop release between dispatches
done
payload_file="$(mktemp)"
printf '{"tool_name":"Workflow","tool_input":{"subagent_type":"warrant-hunter","prompt":"hunt 4"},"cwd":"%s"}' "$cap_td" > "$payload_file"
( cd "$cap_td" && env -u CLAUDE_PROJECT_DIR CLAUDE_PROJECT_DIR="$cap_td" WARRANT_HUNT_MAX=3 /bin/bash "$GUARD" < "$payload_file" ) >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
report deny "$got" workflow-tool-session-cap-denies-4th
rm -rf "$cap_td" "$payload_file"

# missing-core: force CLAUDE_PLUGIN_ROOT_CORE to a nonexistent path so the
# source guard's [ -f ... ] check trips before gate-lib.sh is sourced. Must
# fail-closed (exit 2) with a human-readable "core plugin not found" message,
# not the trap's generic raw-error remap (issue-70 blocking reason 1).
missing_core_td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$missing_core_td"
payload_file="$(mktemp)"
printf '{"tool_name":"Agent","tool_input":{"subagent_type":"warrant-hunter","prompt":"hunt for bugs"},"cwd":"%s"}' \
  "$missing_core_td" > "$payload_file"
missing_core_out="$(cd "$missing_core_td" && env -u CLAUDE_PROJECT_DIR CLAUDE_PROJECT_DIR="$missing_core_td" \
  CLAUDE_PLUGIN_ROOT_CORE="$missing_core_td/no-such-core" /bin/bash "$GUARD" < "$payload_file" 2>&1 >/dev/null)"
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
report deny "$got" missing-core-fails-closed
case "$missing_core_out" in
  *"core plugin not found"*) pass=$((pass+1)); printf 'ok     %-38s %s\n' missing-core-message-explicit "explicit" ;;
  *) fail=$((fail+1)); printf 'FAIL   %-38s want=explicit got=%s\n' missing-core-message-explicit "$missing_core_out" ;;
esac
rm -rf "$missing_core_td" "$payload_file"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
