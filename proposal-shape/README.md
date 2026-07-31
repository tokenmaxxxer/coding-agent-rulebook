# proposal-shape

Enforces this repo's adopted phase-1 proposal shape (issue-52, section (a)):
an ADR-style skeleton grafted onto the existing proposal fields. The failure
this targets: a proposal that reads as if it justifies itself while never
actually stating what else was considered and why it was rejected.

**proposal-shape owns one methodology**: every `docs/issue-<n>/proposals/*.md`
document carries seven sections, in order — `files:`, `## Request`,
`## Constraints`, `## Rationale`, `## What will be done`, `## Out of scope`,
`## How you'll know it worked` — and `## Rationale` must name a rejected
alternative and the reason, not just restate the chosen approach.

It ships two hooks:

- **`directive.sh`** (`UserPromptSubmit`) — steers proposal writes toward the
  seven-section shape before generation, and names the criterion and
  prohibition (never merge Rationale into What will be done).
- **`proposal-shape-gate.sh`** (`PreToolUse` on `Write|Edit|MultiEdit`) —
  checks the resulting content of any write to a phase-1 proposal path:
  all seven markers present, in the required relative order, and
  `## Rationale`'s body non-trivial. Fails closed on anything it cannot
  parse or resolve. Denies with one message naming each specific
  missing/misordered/trivial element.

## Escape hatches

- `PROPOSAL_SHAPE_OFF=1` disables the directive.
- `PROPOSAL_SHAPE_GATE_OFF=1` disables the gate.

## Relationship to the rest of the stack

This plugin is standalone and removable — it does not depend on
record-shape or survey-order.
