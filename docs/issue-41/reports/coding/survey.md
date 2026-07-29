---
status: final
---

# Current-state survey — issue-41

Skip record: pure migration/cleanup task with a spec that leaves no design
decision open (repoint wording is fixed by the issue) — scout skipped
(scout-directive skip condition 2).

## Write set

- `docs/specs/handoff-protocol.md` — coding's own handoff-protocol doc.
  Section 3 ("Wakes-on") and part of section 7 ("Finding back-edge") name
  which role a record state summons (feasibility `verdict: go` -> coding,
  qa defect -> coding, coding's fix commit -> qa). Repoint to on-the-record
  `docs/specs/wake-routing.md`; keep the record-format material (loop_state
  vocabulary, required fields, produces paths, stops).
- `coding/hooks/directive.sh` — the "YOUR RECORD IS THE BOARD" paragraph
  mentions WAKES-ON but only to say *where* WAKES-ON reads from for this
  role's own record (`docs/issue-<n>/reports/coding.md`) — it names no
  other role and states no trigger condition. Left as-is.

## Excluded from the write set

- `docs/proposals/2026-07-26-contract-v2-conformance.md` — historical
  proposal record of a past decision; not a live rulebook statement.
- `docs/reports/*` — historical hunt/report records.
- Any file under `docs/issue-*/` — excluded by the issue's own grep scope.

## Method

`grep -rliE 'wakes|wake-on|WAKES-ON' --include=*.md --include=*.sh .` over
the whole repo, excluding `docs/issue-*/`, found three hits:
`docs/specs/handoff-protocol.md`, `coding/hooks/directive.sh`, and
`docs/proposals/2026-07-26-contract-v2-conformance.md` (historical, out of
scope per above).
