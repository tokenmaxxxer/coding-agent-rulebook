---
kind: coding-record
loop_state: landed
---

# Coding record — issue-46

proposal: docs/issue-46/proposals/2026-07-30-proposal-pr-issue-reference.md

## Why

Issue #46: two of nine phase-1 proposal PRs carried `Closes #n`, so
merging the approved proposal auto-closed the issue and the following
phase-2 session saw a closed issue and silently exited
(ops-agent-rulebook#21, coding-agent-rulebook#43). Phase-1 proposal
(PR #47) approved stating the rule in coding's own directive: phase-1
PRs reference `#n` only, never a closing keyword; only phase-2
delivery carries `Closes #n`; a phase-2 session finding its issue
closed with no delivery landed reports the anomaly instead of exiting.

## What was done

The proposal's write set (`coding/hooks/directive.sh`) was already
edited in the phase-1 commit (8bbaafb) — the "ISSUE REFERENCE,
phase-dependent" paragraph was added to the PROPOSAL section, stating
exactly what the proposal scoped. Phase 2 verified the landed text
matches the proposal's required content and wrote this record; no
further code change was needed.

## What did not work

Nothing — no code changes were needed beyond what phase-1 already
committed; only the record was missing.

## Open findings

None addressed to coding as of this record.

## Next steps

None — build complete per proposal scope. Commit, push, open PR.

## Open-finding resolution path

No open findings against coding for this subject; none to resolve.

## commits

8bbaafb docs(issue-46): phase-1 survey and build proposal (includes the
directive.sh change scoped by the proposal)
