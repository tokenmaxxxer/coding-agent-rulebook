# survey-order

Enforces one methodology norm: research before proposal, in that order, on
disk. The failure this targets: a phase-1 proposal drafted before anyone
actually surveyed the current codebase state — a rationale built to justify a
decision already made, not from what research found.

**survey-order owns write ORDER, not content shape.** It does not check
whether a proposal or survey is well-formed (that is proposal-shape's job) —
only that, for a given issue, the survey file exists on disk before the
proposal file is written:

- **Directive** (`UserPromptSubmit`): steers research-then-draft as the
  default sequence, states the criterion for a real survey (the projected
  write set, not a placeholder list) and for a real alternative (something
  that could plausibly have been chosen), and names the two mandatory
  scout-directive skip conditions — pure bugfix, or a spec with no design
  decision open — which must be stated in the proposal body itself when used.
- **Gate** (`PreToolUse`, `survey-order-gate.sh`): mechanically blocks a
  `Write`/`Edit`/`MultiEdit` to `docs/issue-<n>/proposals/*.md` when
  `docs/issue-<n>/reports/implementation/survey.md` is absent and the
  proposal's own resulting text carries no scout-skip language. Fails closed
  on any malformed or unreadable input.

## Kill switches

- `SURVEY_ORDER_OFF=1` disables the directive.
- `SURVEY_ORDER_GATE_OFF=1` disables the gate.

## Relationship to the rest of the stack

survey-order is a standalone plugin — it composes with proposal-shape to
form the full phase-1 norm (proposal-shape governs what a proposal must
contain; survey-order governs when it may be written) but does not depend on
proposal-shape's code.
