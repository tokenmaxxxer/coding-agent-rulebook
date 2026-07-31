#!/usr/bin/env bash
# UserPromptSubmit hook: injects the research-before-proposal steering directive.
#
# survey-order owns exactly one norm: WRITE ORDER. A phase-1 proposal is
# drafted from a current-state survey, not the other way around — the survey
# file must exist on disk before the proposal body is written, unless the
# proposal itself states one of the two mandatory scout-directive skip
# conditions. Enforcement of the ordering at write time lives in
# survey-order-gate.sh; this directive only sets the default behavior before
# any write happens.
# Kill switch: export SURVEY_ORDER_OFF=1

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and to
# most tooling, but any non-empty value used to disable the hook — the kill switch
# silently killed it on exactly the spelling meant to keep it alive.
case "${SURVEY_ORDER_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
<survey-order-directive priority="high">
This directive steers WHEN you draft a proposal, relative to when you research. It sets one ordering: survey before proposal.

STEP — research before drafting: before writing a proposal's body, read the codebase, the surrounding ecosystem, and prior decisions per the scout protocol, and write down what you found as the current-state survey file — `docs/issue-<n>/reports/implementation/survey.md` — BEFORE drafting the proposal. The survey is not a formality that trails the proposal; it is the input the proposal is drafted from.

CRITERION — the survey must be real, not decorative: the write set you survey has to be the set you actually expect to touch, not a placeholder list assembled to satisfy the ordering. An alternative named in the eventual proposal's Rationale only counts as "considered" if, given what the survey found, it could plausibly have been chosen instead of the option you picked. A rationale listing alternatives nobody could plausibly have picked is not evidence of research — it is decoration wrapped around a decision already made.

PROHIBITION: never write the proposal file before its survey file exists on disk. The only exceptions are the two mandatory scout-directive skip conditions — the change is a pure bugfix, or the spec leaves no design decision open — and even then the proposal body itself must state which skip condition applies and why, in the proposal's own text, not left implicit. Also: never name zero alternatives in a proposal; a proposal with no alternatives is a decision with no rationale behind it.

MECHANICAL ENFORCEMENT: survey-order-gate.sh checks this ordering at write time — it blocks a proposal write under `docs/issue-<n>/proposals/` when `docs/issue-<n>/reports/implementation/survey.md` is absent and the proposal's own text carries no skip-condition language. This directive tells you the norm before you hit the gate; the gate is what actually stops a violation from landing.
</survey-order-directive>
EOF
exit 0
