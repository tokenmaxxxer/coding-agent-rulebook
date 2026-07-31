---
subject: issue-52
role: implementation
code_under_review: <pending: set to this branch's HEAD sha before PR>
loop_state: landed
---

# Record — implementation-domain proposal & deliverable norms (phase 2)

## What was done

Reflected the approved proposal
(`docs/issue-52/proposals/2026-07-31-implementation-domain-norms.md`)
into `coding/hooks/directive.sh` per plan item (d).1:

1. `USE_WHEN`'s PROPOSAL paragraph now requires a `## Rationale` section
   (why this approach and not another: at least one alternative
   considered and rejected, with the reason) between `## Constraints`
   and `## What will be done`.
2. `PRODUCES`' EXECUTION JUDGMENT list now carries a
   `## Rationale for deviations` bullet, conditional on divergence from
   the approved phase-1 proposal, matching the record norm this record
   itself follows below.

Both additions are sentence-level, inside the existing `$'...'`
single-physical-line variables, and slot into the current six-argument
`core_role_directive` call unchanged (issue-53's four-arg restructuring
had not yet reached this file's argument count at write time — no
rework was needed).

Per plan item (d).2, no new gate was added. Per item (d).3, no new field
was added to any record-fields required list — item (b).4 stays
directive guidance, not a required field.

## Why

The proposal's rationale (section (c)) already justifies both
additions: ADR's Context/Decision/Consequences shape is the only
scouted pattern reinforced rather than contradicted by independent SRS
and RFC conventions, kept to a single added section to avoid the
documented Google RFC-template bloat failure mode; the DoD literature's
structural point (criteria must be explicit and recoverable, not just
narrated) is applied only to the completion criteria this role owns,
leaving verification-specific criteria to qa/review/verify per this
role's existing scope boundary.

## Upstream basis

- Issue: #52.
- Approved proposal: `docs/issue-52/proposals/2026-07-31-implementation-domain-norms.md`.
- Approval: issue-52 comment `APPROVE issue-52/implementation` (single-account mode).
- Survey / scout brief: `docs/issue-52/reports/implementation/survey.md`,
  `docs/issue-52/reports/implementation/scout-brief.md`.

## closed_checks

None run this cycle — a two-sentence directive-text edit with no new
control flow; nothing to hunt.

## What did not work

(none)

## Open findings

(none)

## Doc placement outcomes

- No env var, config key, dependency, or migration introduced —
  handbook placement not applicable.
- No library/format choice or changed public signature/wire format —
  `docs/issue-<n>/decisions/` placement not applicable.
- No benchmark or investigation numbers produced this cycle.

## How you'll know it worked

- `coding/hooks/directive.sh` still passes `bash -n`.
- The `## What was done`/`## Why`/`## Upstream basis` sections above are
  the dogfooded proof: this record itself satisfies the completion-
  criteria structure the proposal adopted (named, recoverable sections;
  `## Rationale for deviations` present-when-needed and correctly
  omitted here since no deviation occurred).
