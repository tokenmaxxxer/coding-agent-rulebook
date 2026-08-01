#!/usr/bin/env bash
# SessionStart: rebuild coding's open-unit context from the issue branch and
# its PR — the v3 analogue of warrant's proposal-frontmatter scan. Informing
# only; never blocks. Kill switch: export CODING_CYCLE_OFF=1
trap 'rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then exit 2; fi' EXIT
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
set -uo pipefail
gate_kill_switch_active "${CODING_CYCLE_OFF:-}" || { trap - EXIT; exit 0; }
[ "${CLAUDE_ROLE:-}" = "coding" ] || { trap - EXIT; exit 0; }

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] || { trap - EXIT; exit 0; }
branch="$(git -C "$root" symbolic-ref --short HEAD 2>/dev/null || true)"
case "$branch" in issue-*/coding) ;; *) trap - EXIT; exit 0 ;; esac
issue="${branch%%/*}"

echo "[coding] Resuming ${branch}: subject ${issue}."
if command -v gh >/dev/null 2>&1; then
  pr="$(cd "$root" && gh pr view "$branch" --json number,reviews,state \
        --jq '"PR #\(.number) (\(.state)); approvals: \([.reviews[] | select(.state=="APPROVED") | .author.login] | join(", ") // "none")"' 2>/dev/null || true)"
  if [ -n "$pr" ]; then
    echo "[coding] $pr"
  else
    echo "[coding] No open PR for ${branch} yet — phase 1 (research/survey/proposal) comes first."
  fi
fi
rec="$root/docs/${issue}/reports/implementation.md"
[ -f "$rec" ] && echo "[coding] Own record exists: docs/${issue}/reports/implementation.md — read it before continuing."
trap - EXIT
exit 0
