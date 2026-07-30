---
kind: build-proposal
loop_state: proposed
---

# Build proposal — issue-43

files:
- coding/hooks/directive.sh
- docs/specs/handoff-protocol.md

## Request

Strip wake/board-routing vocabulary ("wake", `WAKES-ON`, board-as-routing-
device framing, downstream-role references, pointers to
`docs/specs/wake-routing.md`) from coding's own rulebook (`directive.sh`,
`handoff-protocol.md`), restating every record obligation purely as a
record-format requirement: path, kind, `loop_state` vocabulary, required
fields, write-record-first-in-phase-2, update `loop_state` every
transition, commit on branch. Historical docs (`docs/issue-41/`,
`docs/proposals/`, `docs/reports/records/`) stay untouched.

## Constraints

- Phase 1 only: this proposal, no execution, no self-approval.
- No mention of wake/waking/WAKES-ON/board-as-routing/downstream roles/
  wake-routing.md pointers in the two target files afterward.
- Record-format substance (path, kind, loop_state vocabulary, required
  fields, write-first-in-phase-2, update-on-every-transition,
  commit-on-branch) must remain fully stated — this is a reframing, not a
  deletion of obligations.
- Historical docs untouched.

## What will be done

- `coding/hooks/directive.sh`: replace the "YOUR RECORD IS THE BOARD"
  block (lines 73-80) with a record-format statement: record path is
  `docs/issue-<n>/reports/coding.md`; write it as the first act of phase 2;
  update `loop_state` at every transition; the record must be committed on
  the branch — ending phase 2 without it committed leaves the obligation
  unmet.
- `docs/specs/handoff-protocol.md`:
  - Section 3 ("Wakes-on"): replace with a section stating only the
    record-format fact that was previously buried in routing framing (no
    SHA pin / no external original applies to coding's own repo) — drop
    the `WAKES-ON`/wake-routing.md pointer entirely; retitle the section
    away from "Wakes-on".
  - Section 5: reword the `loop_state` bullet to state the board-write
    completion rule without "downstream role" or "WAKES-ON": a transition
    is not complete for contract purposes until `loop_state` reflects it
    on the board.
  - Section 7: reword the cycle-termination sentence to drop "which role a
    fix commit wakes" and the `wake-routing.md` pointer, keeping only the
    `loop_state: verified-fixed` / new-finding termination condition.
  - Section 8: reword "a wake is consumed" language to a plain record-write
    requirement (an action under this document requires a record write;
    leaving the board unchanged does not satisfy it).

## Out of scope

- `docs/specs/wake-routing.md` and any other on-the-record-owned routing
  doc — not coding's file to edit.
- Historical docs under `docs/issue-41/`, `docs/proposals/`,
  `docs/reports/records/`.
- Any behavior change to gates, hooks, or tests — wording only.
- Phase 2 execution, approval, or merge — this PR stops after the
  proposal.

## How you'll know it worked

`grep -rIn -e "wake" -e "WAKES-ON" -e "wake-routing" -e "board-as-routing" -e "downstream role" coding/hooks/directive.sh docs/specs/handoff-protocol.md` returns nothing, while both files still state the record path, kind, `loop_state` vocabulary, required fields, write-first-in-phase-2, per-transition update, and commit-on-branch obligations.
