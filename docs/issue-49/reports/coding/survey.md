# Current-state survey — issue #49

Scout: skipped. Skip condition: spec leaves no design decision open — the
issue names the exact clause text to add and its exact reference source
(`ux-design-rulebook`'s `ux-design/hooks/directive.sh` RECORD FORMAT
section, post issue-12 state); there is no product-shaped or
comparable-system choice to scout.

## Write set

- `coding/hooks/directive.sh` — RECORD REQUIREMENT section; strengthen
  the enforcement clause and cite the measured evidence, wording aligned
  to the reference. (edited)
- `docs/issue-49/reports/coding/survey.md`,
  `docs/issue-49/proposals/2026-07-30-record-discipline-strong-form.md`
  — this survey and proposal.

## Current state

`coding/hooks/directive.sh`'s RECORD REQUIREMENT section (lines 80-85)
reads:

> Ending phase 2 without your record committed on the branch means the
> obligation is unmet. (Measured: a phase-1-only issue left no record
> committed.)

The reference (`ux-design/hooks/directive.sh` RECORD FORMAT section,
current on `main` as of commit `44b628a`) reads:

> Ending phase 2 without your record committed on the branch means the
> record was never written. (Measured: a phase-1-only issue left the
> record empty.)

Both sentences carry the same rule; the reference's wording is stronger
("was never written" vs. "obligation is unmet" — the record's existence
is denied outright, not just marked unmet) and its evidence citation is
more specific ("left the record empty" vs. "left no record committed").
No other clause in coding's RECORD REQUIREMENT section (the file path,
first-act timing, loop_state-update rule) differs from the reference in
substance — only these two clauses need alignment.

## Out of scope

- The role-specific record fields (loop_state, closed_checks,
  resolved_findings, ## What did not work) — issue #49 explicitly scopes
  this to a wording-strength alignment, not a format change.
- Any other section of `directive.sh` (PROPOSAL, EXECUTION JUDGMENT,
  etc.) — untouched.
- `ux-design-rulebook` itself — read-only reference, not edited from this
  repo.
