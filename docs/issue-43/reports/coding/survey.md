---
status: draft
---

# Survey — issue-43

## Scout skip record

Skipped. The issue specifies the exact vocabulary to remove and the exact
record-format content to keep; no open design decision remains to scout.

## Write set (current-state)

Full-repo sweep for wake/board-routing vocabulary outside historical docs
(`docs/issue-41/`, `docs/proposals/`, `docs/reports/records/` are canon-frozen
history and stay untouched per the issue). Two live files carry the
vocabulary:

- `coding/hooks/directive.sh` (lines 73-80): the "YOUR RECORD IS THE BOARD"
  block names `WAKES-ON`, "the board", "no downstream role can ever be woken",
  "machine wake-up dead".
- `docs/specs/handoff-protocol.md`: section 3 ("Wakes-on", lines 29-39) is
  entirely routing framing and points to `docs/specs/wake-routing.md` as
  canon; section 5 (lines 64-67) ties `loop_state` to "a downstream role's
  WAKES-ON check"; section 7 (lines 89-94) names the qa<->coding wake/cycle
  rule as routing canon.

No other file matched (checked `coding/agents`, `tests/`, plugin manifests,
skills, `.claude-plugin` descriptions — none reference wake vocabulary).

## What will change

- `coding/hooks/directive.sh`: rewrite the "YOUR RECORD IS THE BOARD" block
  as a pure record-format requirement — path
  (`docs/issue-<n>/reports/coding.md`), write-first-in-phase-2, update
  `loop_state` on every transition, must be committed on the branch. Drop
  `WAKES-ON`, "board", "downstream role", "wake" entirely.
- `docs/specs/handoff-protocol.md`: replace section 3 ("Wakes-on") with a
  record-format-only statement (or fold its non-routing residue — the "no
  SHA pin" line — into section 4); strip the `WAKES-ON`/downstream-role
  clause from section 5's `loop_state` line, restating it as "the board
  update is not complete until `loop_state` reflects the transition";
  reword section 7's cycle-termination line to drop "which role a fix
  commit wakes" and the `wake-routing.md` pointer, keeping only the
  `loop_state: verified-fixed` / new-finding termination condition as a
  record-state fact. Section 8 ("Loop termination") already speaks of
  "wake" as an input the record consumes — restate as: a record write is
  required whenever this document's actions are invoked, and leaving the
  board byte-identical does not satisfy that requirement.

No other files, no code, no tests — this is a docs/rulebook wording pass.
