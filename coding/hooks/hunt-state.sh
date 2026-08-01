#!/usr/bin/env bash
# Maintains the two files hunt-guard.sh reads. Without this, the guard's own
# limits are the state nothing maintains: the lock got written and never cleared,
# so the second of the directive's two dispatches was always refused, and the
# count only ever climbed, so WARRANT_HUNT_MAX was a repository-lifetime cap
# wearing the name "session cap".
#
#   release  (SubagentStop)  a subagent finished — drop the lock
#   reset    (SessionStart)  new session — drop the lock and zero the count
#
# `release` is approximate on purpose. SubagentStop does not say WHICH subagent
# stopped, so an unrelated worker finishing can drop a live hunter's lock. That
# degrades single-flight from a guarantee to the common case — it never becomes
# unbounded, because the thing that actually bounds cost is the session cap, and
# that is untouched. An exact release would need the agent's identity in the
# stop payload; claiming exactness without it would be the same kind of lie the
# header of hunt-guard.sh used to tell.
#
# Kill switch: export WARRANT_OFF=1

_gate_lib="${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
if [ -f "$_gate_lib" ]; then
  . "$_gate_lib"
  gate_kill_switch_active "${WARRANT_OFF:-}" || exit 0
else
  # core plugin missing: this hook is informing-only (never blocks — see
  # header), so the kill-switch check is skipped rather than failing closed.
  # The release/reset cleanup below does not depend on any core function
  # (plain rm on lock/count files), so it still runs in full.
  echo "hunt-state.sh: core plugin not found (gate-lib.sh missing at $_gate_lib); skipping kill-switch check, cleanup still runs" >&2
fi

# Root resolution is shared with hunt-guard.sh and must stay identical: the
# project directory, normalized to the git top level when there is one. A
# directory that is not a repository still gets bounded — git supplies a stable
# location, not permission to count.
root="${CLAUDE_PROJECT_DIR:-$PWD}"
top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)"
[ -n "$top" ] && root="$top"
[ -d "$root" ] || exit 0

case "${1:-release}" in
  release)
    rm -f "$root/.warrant-hunt.lock" 2>/dev/null
    ;;
  reset)
    rm -f "$root/.warrant-hunt.lock" "$root/.warrant-hunt.count" 2>/dev/null
    ;;
esac

exit 0
