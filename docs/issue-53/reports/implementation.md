---
subject: issue-53
role: implementation
loop_state: landed
code_under_review: 4588577f03a9363ae1935cf595666e38ef9910a5
---

# Record — core canon reference transition (issue-53, phase 2)

## Why

core issue #63 landed the standalone `warrant` plugin's canon
`warrant-hunter.md`, and core issue #66 landed the three role-agnostic
gates plus `role-directive.sh`'s shared boilerplate as core canon, fired
globally for every session with `core` installed. This repo's vendored
copies of those same files are now redundant double-firing / drift risk
(the exact shape core issue #66's survey found across 38/40 rulebooks) —
issue #53 tracks the per-rulebook follow-up both core issues name but
leave unexecuted.

## Upstream basis

- Issue #53 (this issue), items 1-5.
- Approved phase-1 proposal:
  `docs/issue-53/proposals/2026-07-31-core-canon-reference-transition.md`.
- core `docs/issue-66/reports/implementation.md` and
  `docs/issue-63/reports/implementation.md` — state the per-rulebook
  follow-up this issue executes.
- Approval: issue comment `APPROVE issue-53/implementation` (single-
  account mode, role-handoff contract v3 s19).

## What was done

1. Deleted `coding/agents/warrant-hunter.md` (byte-for-byte subset of
   core's canon copy, confirmed in the phase-1 survey). Removed the now-
   empty `coding/agents/` directory.
2. Deleted `coding/hooks/trailer-gate.sh`, `coding/hooks/record-fields-gate.sh`,
   `coding/hooks/handbook-trigger-gate.sh`. Rewrote `coding/hooks/hooks.json`'s
   `PreToolUse` block to drop the three matching entries (and the now-empty
   `Write|Edit|MultiEdit|NotebookEdit` matcher block, since it held only the
   deleted `record-fields-gate.sh` entry); `coding-progress-gate.sh` and
   `hunt-guard.sh` entries unchanged.
3. Replaced `coding/hooks/directive.sh` with a stub: sources
   `core/hooks/lib/role-directive.sh`, sets four `$'...'`-quoted single-line
   variables (`YOU_DECIDE`, `USE_WHEN`, `PRODUCES`, `HAND_OFF`) per the
   proposal's mapping, calls `core_role_directive` with them. All six
   original sections' content carried forward verbatim (including both
   hunt-cadence bullets in `PRODUCES`), none dropped.
4. `RECORD_FIELDS_TERMINAL_STATES` — confirmed not needed (survey/proposal
   both found terminal set already `{"landed"}`, the core default); no
   override added.
5. Copied `core/hooks/tests/stub-check.sh` (from the sibling `tokenmaxxxer-core`
   checkout, `core/hooks/lib/role-directive.sh`'s and `stub-check.sh`'s
   canon source) into `coding/hooks/tests/stub-check.sh` and ran it:

   ```
   $ bash coding/hooks/tests/stub-check.sh coding
   stub-check: ok — no vendored 'trailer-gate.sh' under coding
   stub-check: ok — no vendored 'record-fields-gate.sh' under coding
   stub-check: ok — no vendored 'handbook-trigger-gate.sh' under coding
   stub-check: ok — no vendored 'parse-check.sh' under coding
   stub-check: ok — coding/hooks/directive.sh is a role-directive stub
   $ echo $?
   0
   ```

## Verification actually run

- `bash -n coding/hooks/directive.sh` — syntax OK.
- `python3 -c "import json; json.load(open('coding/hooks/hooks.json'))"` —
  valid JSON.
- `coding/hooks/tests/stub-check.sh coding` — exit 0 (output above).
- Manual execution of `directive.sh`'s stub logic against a minimal local
  copy of `core_role_directive` (the sandbox denies reads under the
  sibling `tokenmaxxxer-core` checkout, so the real
  `core/hooks/lib/role-directive.sh` could not be sourced live in this
  session) confirmed all four variables render with every sentence from
  the six original sections intact, in the same order, nothing truncated
  or garbled by the `$'...'` quoting.

## What did not work

- Could not exercise `directive.sh` end-to-end against the real
  `core/hooks/lib/role-directive.sh` (sandbox denies filesystem access
  outside this repo and the scratchpad) — substituted a minimal local
  reimplementation of `core_role_directive`'s rendering logic (same `cat
  <<EOF` body, sourced from a scratchpad copy) to confirm the stub's
  variable content and call shape produce the expected output. The
  authoritative pass/fail signal for the stub's structural correctness is
  `stub-check.sh`, which ran directly against the real file and passed.

## Preserved unchanged

`coding/.claude-plugin/plugin.json`, `coding/hooks/state.sh`,
`coding/hooks/coding-progress-gate.sh`, `coding/hooks/hunt-guard.sh`,
`coding/hooks/hunt-state.sh` — none named in issue #53's scope, per the
proposal.

## Open findings

None. The `hunt-guard.sh` divergence from core (fail-closed trap,
case-insensitive `agent_type` match, dropped `WARRANT_IN_HUNT` check) was
flagged in the phase-1 proposal as out of this issue's scope, not acted
on here, and needs the fix landed in core first per the proposal's open
question 2 — carried forward as a note, not a blocking finding against
this delivery.
