---
code_under_review:
  - coding/hooks/hunt-guard.sh
  - coding/hooks/hunt-state.sh
  - coding/hooks/state.sh
  - coding/hooks/tests/hunt-guard-tests.sh
  - coding/hooks/tests/hunt-state-tests.sh
  - README.md
loop_state: landed
---

## What was done

Phase 2 delivery for issue #70, executing the "What will be done" section of
`docs/issue-70/proposals/proposal.md` (merged as PR #71) exactly as written.
Closes all three audit blocking reasons: (1) inconsistent missing-core
failure modes in `hunt-guard.sh`/`hunt-state.sh` plus missing regression
tests, (2) `state.sh`'s dead `coding`/`issue-*/coding` branch, (3) the
README repo-name typo. Concretely: added an explicit `[ -f gate-lib.sh ]`
source guard to both `hunt-guard.sh` (fail-closed, exit 2, explicit stderr
message) and `hunt-state.sh` (skip kill-switch check only, cleanup still
runs — per its "informing only; never blocks" design); corrected
`state.sh`'s role/branch match from `coding`/`issue-*/coding` to
`implementation`/`issue-*/implementation`; corrected the README repo name
from `coding-agent-rulebook` to `implementation-rulebook` (both
occurrences); added a missing-core test case to `hunt-guard-tests.sh` and a
new `hunt-state-tests.sh` suite.

## Why

Issue #70's 2026-08-01 certification audit named these exact three blocking
reasons as the only remaining items standing between this repo and A+
certification (see `## Request` in the linked issue and the approved
proposal's `## Rationale`). The proposal was approved via the issue comment
`APPROVE issue-70/implementation` from `JiwonJung94`, who is listed in
`docs/specs/approvers.md` — the single-account-mode approval path per
contract v3 §19 — authorizing this phase-2 execution.

## Closed checks

### 1. hunt-guard.sh — explicit fail-closed on missing core

- code_sha: working tree on top of `d42b6003deaa7b731892b9dba8285b8460f57059`
  (the merged proposal commit this branch was rebased onto)
- Change: added a `[ -f "$_gate_lib" ]` guard immediately before the
  `gate-lib.sh` source line. On failure, prints
  `hunt-guard.sh: fail-closed: core plugin not found (gate-lib.sh missing at ...)`
  to stderr and exits 2, instead of relying on the generic `__fc` trap's raw
  "gate aborted (rc=...)" message.
- Resolution evidence — new test case `missing-core-fails-closed` /
  `missing-core-message-explicit` in `hunt-guard-tests.sh`, run via
  `bash coding/hooks/tests/hunt-guard-tests.sh`:

  ```
  ok     workflow-tool-hunter-dispatch-allowed  allow
  ok     workflow-tool-non-hunter-allowed       allow
  ok     agent-tool-non-hunter-allowed          allow
  ok     workflow-tool-session-cap-denies-4th   deny
  ok     missing-core-fails-closed              deny
  ok     missing-core-message-explicit          explicit

  == 6 passed, 0 failed ==
  ```
  (Exit code of the full suite: 0.)

### 2. hunt-state.sh — explicit missing-core handling, cleanup preserved

- code_sha: same working tree as above.
- Change: same `[ -f "$_gate_lib" ]` guard. If gate-lib.sh is missing, the
  script logs
  `hunt-state.sh: core plugin not found (gate-lib.sh missing at ...); skipping kill-switch check, cleanup still runs`
  to stderr, skips `gate_kill_switch_active`, and falls through to the
  existing `release`/`reset` `rm -f` logic (which never depended on any core
  function). This matches the proposal's "informing only; never blocks"
  design intent — the hook still performs lock/count cleanup with core
  absent, and still honors the kill switch normally when core is present.
- Resolution evidence — new file `coding/hooks/tests/hunt-state-tests.sh`,
  run via `bash coding/hooks/tests/hunt-state-tests.sh`:

  ```
  ok     missing-core-reset-exits-zero          allow
  ok     missing-core-reset-clears-files        cleared
  ok     missing-core-message-explicit          explicit
  ok     missing-core-release-clears-lock       cleared
  ok     missing-core-release-preserves-count   preserved
  ok     core-present-kill-switch-exits-zero    allow
  ok     core-present-kill-switch-skips-cleanup lock untouched

  == 7 passed, 0 failed ==
  ```
  (Exit code of the full suite: 0. Ran with a real `CLAUDE_PLUGIN_ROOT_CORE`
  present locally, so both the missing-core cases — via a forced
  nonexistent override — and the core-present kill-switch regression case
  executed for real, not skipped.)

### 3. state.sh — coding branch corrected to implementation

- code_sha: same working tree as above.
- Change: `[ "${CLAUDE_ROLE:-}" = "coding" ]` → `[ "${CLAUDE_ROLE:-}" =
  "implementation" ]`; `case "$branch" in issue-*/coding)` →
  `issue-*/implementation)`. No other logic touched (PR status lookup,
  record-existence hint left as-is per proposal).
- Resolution evidence — manual run on this branch/role, per the proposal's
  "How you'll know it worked" §3 (`state.sh` run under
  `CLAUDE_ROLE=implementation` on `issue-70/implementation`):

  ```
  $ CLAUDE_ROLE=implementation CLAUDE_PROJECT_DIR=<repo> bash coding/hooks/state.sh < /dev/null
  [coding] Resuming issue-70/implementation: subject issue-70.
  [coding] PR #71 (MERGED); approvals:
  RC=0
  ```

  No longer a no-op: it now prints the resumption line and looks up PR #71
  via `gh`, confirming the branch/role match fires under the actual
  `issue-70/implementation` naming in use.

### 4. README.md — repo name corrected

- code_sha: same working tree as above.
- Change: both occurrences of `coding-agent-rulebook` (title, line 1, and
  the `claude plugin marketplace add` example, line 66) replaced with
  `implementation-rulebook`.
- Resolution evidence:

  ```
  $ grep -n "implementation-rulebook\|coding-agent-rulebook" README.md
  1:# tokenmaxxxer / implementation-rulebook
  66:    claude plugin marketplace add tokenmaxxxer/implementation-rulebook
  ```
  No remaining occurrence of `coding-agent-rulebook`.

## Doc-placement-ladder outputs

- No new decision docs, handbook updates, or additional report docs were
  required by the proposal beyond this record. The proposal's "How you'll
  know it worked" section names exactly this file
  (`docs/issue-70/reports/implementation.md`) as the sole required output;
  nothing else on the ladder (decisions/, handbooks/) was in scope.

## What did not work

None. All four blocking-reason fixes landed as specified in the proposal's
"What will be done" section, and both test suites (existing
`hunt-guard-tests.sh` plus new `hunt-state-tests.sh`) are green.

## Open findings

None. The proposal's "Out of scope" list (core repo's `gate-lib.sh` itself,
sales-track core #78, hunt-guard.sh's session-cap/lock logic, and other
hooks' role/branch naming) remains untouched, as specified — no follow-up
work was identified within this issue's scope.
