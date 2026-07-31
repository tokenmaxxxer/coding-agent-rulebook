---
subject: issue-56
role: implementation
---

# Survey — stub-check.sh reclaim (issue-56, phase 1)

## Scout skip record

Skipped: this is a pure internal-canon-compliance fix with no product-facing
design space — core (`tokenmaxxxer-core`, sibling checkout at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`) already specifies the exact
target state and invocation line. Nothing external to scout.

## Current state (this repo, `coding/` rulebook)

- `coding/hooks/tests/stub-check.sh` — a byte-identical vendored copy of
  `core/hooks/tests/stub-check.sh`, added by issue-53's phase 2 (see
  `docs/issue-53/reports/implementation.md`, item 5). It is itself now one
  of the five files core's canon manifest treats as a "never vendor" file
  (see below) — the copy is drift by core's own current rule.
- `coding/hooks/hooks.json` — has no entry for `stub-check.sh` (it was never
  wired into `hooks.json`'s `SessionStart`/`PreToolUse` blocks; issue-53's
  record only ran it manually as a one-off verification command). So there
  is no `hooks.json` registration to remove — confirmed by reading the file
  (`SessionStart`: `directive.sh` + `state.sh`; `PreToolUse`: `coding-progress-gate.sh`
  + `hunt-guard.sh`). No test-harness entry point (no `run-*.sh` under
  `coding/hooks/tests/`) invokes `stub-check.sh` either.
- No `docs/handbooks/canon-scripts.md` exists in this repo yet (core has it;
  this repo has not adopted the "referenced, never copied" clause anywhere).

## Upstream canon (core, `tokenmaxxxer-core`)

- `docs/handbooks/canon-scripts.md`: "Canon scripts are referenced, never
  copied" — any script under `core/hooks/` or `core/hooks/tests/` is invoked
  by a rulebook through a path resolved against core's own install root;
  a rulebook tree never holds a second copy.
- `core/hooks/tests/canon-manifest.txt` lists the five files this rule is
  mechanically enforced for: `trailer-gate.sh`, `record-fields-gate.sh`,
  `handbook-trigger-gate.sh`, `parse-check.sh`, `stub-check.sh` (itself).
- `docs/handbooks/role-gates-tests.md` ("Canon invocation from a rulebook",
  issue-69) gives the exact reference-invocation line a rulebook's harness
  should use in place of a vendored copy:

  ```
  "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" "$(dirname "$0")/.."
  ```

  Flags explicitly that the `${CLAUDE_PLUGIN_ROOT}` sibling-resolution
  expression is unverified against a real marketplace install (core's own
  test run is same-checkout siblings) — confirm against one pilot rulebook
  before treating it as final.
- `docs/issue-69/reports/implementation/reclaim-21-copies.md`: the rollout
  procedure for retiring 21 vendored `stub-check.sh` copies across the
  43-repo marketplace (execution out of core's own scope — "orchestration
  batch-spawn against each affected rulebook repo"). This repo (`coding`)
  is one of the 21 (confirmed present via `find`). Steps: enumerate, delete
  vendored copy + swap in the reference-invocation line in the rulebook's
  own harness entry point, re-run that harness, record the pass.

## Gap

This repo has no harness entry point yet to swap the invocation into (no
`coding/hooks/tests/run-*.sh`) — issue-53's record ran `stub-check.sh`
directly by hand, not from a wired-in script. So step 2 of core's reclaim
procedure ("update that rulebook's own test-harness entry point") has
nothing existing to update here; the invocation instead needs to be run
directly (same shape core's own docs show: a direct `bash .../stub-check.sh
<dir>` command), recorded in this issue's phase-2 record, same as issue-53
did — just pointed at core's install path instead of a vendored copy.
