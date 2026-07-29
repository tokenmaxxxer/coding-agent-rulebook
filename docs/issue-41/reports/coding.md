---
kind: coding-record
loop_state: landed
---

Pointer to active build-proposal:
`docs/issue-41/proposals/2026-07-30-build-drop-wakes-on-restatements.md`

## Why

Wake-routing ownership migration step 3 (operator decision 2026-07-30):
canon for which role a record state wakes now lives at on-the-record's
`docs/specs/wake-routing.md`. This rulebook must contain nothing about
that routing; only coding's own record states/format stay here.

## What was done

- `docs/specs/handoff-protocol.md` section 3 ("Wakes-on"): removed the
  bulleted trigger list naming other roles' record states, repointed to
  on-the-record's `docs/specs/wake-routing.md` as the routing canon.
- Section 7 ("Finding back-edge"): removed the qa<->coding
  cycle-termination wording naming which role a fix commit wakes,
  repointed to the same host doc; kept the finding-response closure
  requirements (coding's own record format) untouched.

## Closed checks

- `closed_checks`: repo-wide grep sweep for `wakes|wake-on|WAKES-ON`
  (case-insensitive, `*.md` and `*.sh`, excluding `docs/issue-*/`)
  confirms remaining hits are: `coding/hooks/directive.sh` (out of
  scope — states only where WAKES-ON reads from for coding's own
  record, names no other role), `docs/specs/handoff-protocol.md`
  (remaining record-format prose, routing repointed), and
  `docs/proposals/2026-07-26-contract-v2-conformance.md` (historical
  record, untouched per constraints). code_under_review: this branch's
  working tree at commit time of this record.

## What did not work

(nothing — proposal executed as specified with no reverts)

## Open findings

None open. No blocking finding addressed to coding is outstanding for
this subject.

Commit shas landed: see this record's own commit and the sibling code
commit on `issue-41/coding`.
