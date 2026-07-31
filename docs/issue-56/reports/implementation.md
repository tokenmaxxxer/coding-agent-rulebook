---
subject: issue-56
role: implementation
loop_state: landed
---

# Record — reclaim `stub-check.sh` copy (issue-56, phase 2)

## Why

core issue #69 confirmed the canon: `stub-check` runs by reference from
core's own installed copy (`core/hooks/tests/stub-check.sh`); vendoring a
copy of it into a rulebook is the drift risk core #69's canon forbids
(`docs/handbooks/canon-scripts.md`, core). Issue #56 tracks this repo's
one remaining vendored copy of that exact script (left in place when
issue-53 landed the rest of the core-canon-reference transition).

## Upstream basis

- Issue #56 (this issue).
- Approved phase-1 proposal:
  `docs/issue-56/proposals/2026-07-31-reclaim-stub-check.md`.
- core `docs/handbooks/canon-scripts.md` and
  `docs/issue-69/reports/implementation/reclaim-21-copies.md` (core) —
  the canon and reclaim procedure this issue executes.
- core `docs/handbooks/role-gates-tests.md`, "Canon invocation from a
  rulebook" — the reference-invocation shape used below.
- Approval: issue comment `APPROVE issue-56/implementation` (single-
  account mode, role-handoff contract v3 s19).

## What was done

1. Deleted `coding/hooks/tests/stub-check.sh` (the vendored copy).
2. Checked `coding/hooks/hooks.json` for a `stub-check.sh` registration —
   `grep -n stub-check coding/hooks/hooks.json` returned no match, so no
   `hooks.json` edit was needed (confirms the phase-1 survey's finding).
3. Ran core's canon copy against this repo by reference, from core's own
   install path (local sibling-checkout form — the only form this
   environment can exercise; the marketplace-install form
   `"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" coding`
   was not run, per core's own documented caveat that that resolution is
   unverified against a real marketplace install):

   ```
   $ bash /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/tests/stub-check.sh coding
   stub-check: ok — no vendored 'trailer-gate.sh' under coding
   stub-check: ok — no vendored 'record-fields-gate.sh' under coding
   stub-check: ok — no vendored 'handbook-trigger-gate.sh' under coding
   stub-check: ok — no vendored 'parse-check.sh' under coding
   stub-check: ok — no vendored 'stub-check.sh' under coding
   stub-check: ok — coding/hooks/directive.sh is a role-directive stub
   $ echo $?
   0
   ```

## Open findings

- No test-harness entry point in this repo wires the reference invocation
  in permanently (phase-1 survey gap) — out of scope: issue #56's text
  asks only for deletion plus one recorded pass, not a permanent wiring.
  Left for a future issue if wanted.
- No change made to this repo's adoption of
  `docs/handbooks/canon-scripts.md` beyond what issue #56 asks — out of
  scope per the approved proposal.
