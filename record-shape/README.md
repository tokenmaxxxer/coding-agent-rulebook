# record-shape

Enforces the implementation role's phase-2 record shape, adopted in
issue-52 (`docs/issue-52/proposals/2026-07-31-implementation-domain-norms.md`,
section (b)). The failure this targets: a phase-2 record at
`docs/issue-<n>/reports/implementation.md` that drops the
`code_under_review:`/`loop_state:` frontmatter, omits `## What did not
work` when nothing happened to go wrong, or narrates a deviation from the
approved proposal only in prose with no `## Rationale for deviations`
section to anchor it.

record-shape owns one methodology: the phase-2 deliverable norm itself —
frontmatter, the always-present `## What did not work` heading, and the
`## Rationale for deviations` section that is required only when execution
actually diverged from `## What will be done`, never added speculatively.

- **`directive.sh`** (`UserPromptSubmit`): steers record-writing toward
  this shape before the write happens, and names the two facets — record
  shape and when a deviation section is warranted.
- **`record-shape-gate.sh`** (`PreToolUse`, `Write|Edit|MultiEdit`):
  mechanically checks the resulting content of any write to
  `docs/issue-<n>/reports/implementation.md` for the same three elements,
  fail-closed, and denies with the specific missing item(s) named.

## Kill switches

- `RECORD_SHAPE_OFF=1` disables the directive.
- `RECORD_SHAPE_GATE_OFF=1` disables the gate.

## Standalone

This is a standalone plugin with no phase-1 dependency — it does not read
or require proposal-shape or survey-order conformance; it only inspects
the phase-2 record it is asked to write.
