---
kind: coding-record
loop_state: landed
---

# Coding record — issue-43

proposal: docs/issue-43/proposals/2026-07-30-build-strip-wake-routing-vocabulary.md

## Why

Issue #43: coding's own rulebook (`directive.sh`, `handoff-protocol.md`)
leaked routing-side vocabulary (wake, WAKES-ON, board-as-routing framing,
downstream-role references, wake-routing.md pointers) that belongs to
on-the-record's canon, not the subject role. Phase-1 proposal (PR #44)
approved this build.

## What was done

Rewriting the two frozen files (`coding/hooks/directive.sh`,
`docs/specs/handoff-protocol.md`) to restate every record obligation as a
plain record-format requirement, with routing vocabulary removed.

## What did not work

Nothing deviated from the proposal — both files edited as scoped.

## Open findings

None addressed to coding as of this record.

## Next steps

None — build complete per proposal scope. Commit, push, open PR.

## Open-finding resolution path

No open findings against coding for this subject; none to resolve.

## commits

(this branch's commit implementing the proposal)
