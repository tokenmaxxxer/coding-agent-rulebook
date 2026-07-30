# Proposal — raise record-discipline clauses to the strong form

files: `coding/hooks/directive.sh`

## Request (paraphrased intent)

The RECORD REQUIREMENT section in coding's directive states the
record-commit obligation more weakly than the equivalent RECORD FORMAT
section already carries in `feasibility`/`verify`/`reflect`/`ux-design`.
Raise the enforcement clause and its measured-evidence citation to match
the reference wording, without changing anything else in the section.

## Constraints

- Role-specific record fields (loop_state, closed_checks,
  resolved_findings, ## What did not work) stay unchanged — wording
  strength only, not a format change.
- Reference wording source: `ux-design-rulebook`'s
  `ux-design/hooks/directive.sh` RECORD FORMAT section, post issue-12
  state.

## What will be done

- In `coding/hooks/directive.sh`'s RECORD REQUIREMENT section, replace:
  "Ending phase 2 without your record committed on the branch means the
  obligation is unmet. (Measured: a phase-1-only issue left no record
  committed.)" with: "Ending phase 2 without your record committed on
  the branch means the record was never written. (Measured: a
  phase-1-only issue left the record empty.)"

## Out of scope

- Any other clause in the RECORD REQUIREMENT section (file path,
  first-act timing, loop_state-update rule) or any other section of
  `directive.sh`.
- Editing `ux-design-rulebook` or any other rulebook repo.

## How you'll know it worked

- `coding/hooks/directive.sh`'s RECORD REQUIREMENT section reads
  byte-for-byte the same enforcement/evidence wording as
  `ux-design/hooks/directive.sh`'s RECORD FORMAT section (diffed
  manually against the reference file).
