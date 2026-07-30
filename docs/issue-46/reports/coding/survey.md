# Current-state survey — issue #46

Scout: skipped. Skip condition: spec leaves no design decision open — the
issue states the exact rule text and its two homes (proposal PR body,
role directive) verbatim; there is no product-shaped or comparable-system
choice to scout.

## Write set

- `coding/hooks/directive.sh` — coding role's own PROPOSAL guidance;
  add the phase-1 "plain #n, never Closes" rule and the phase-2
  closed-issue-anomaly rule. (edited)
- `docs/issue-46/reports/coding/survey.md`, `docs/issue-46/proposals/2026-07-30-proposal-pr-issue-reference.md`
  — this survey and proposal.

## Evidence the bug is live in this repo

PR #44 (`issue-43`'s phase-1 proposal PR, merged) closed with body text
"Closes #43 (phase 1; phase 2 pending approval)." — a GitHub closing
keyword on a phase-1-only PR, which auto-closed issue #43 on merge. This
is the exact failure class issue #46 describes, reproduced in this
repo's own history.

## Root cause

`coding/hooks/directive.sh`'s PROPOSAL section names the required body
fields but says nothing about how to reference the issue or that closing
keywords are forbidden on phase-1 PRs. Nothing else in this repo governs
PR body wording (checked `coding/hooks/*.sh`, `docs/specs/handoff-protocol.md`
— no hits for "Closes" or issue-reference wording).

## Out of scope

- The role-handoff contract v3 text (phase boundaries, Approve gate) is
  core's, not this repo's — this repo only carries `coding`'s own
  directive.
- No enforcement hook (e.g. scanning PR body for closing keywords) is
  proposed; the rule is steering text, matching how every other
  phase-1/phase-2 rule in this file is expressed.
