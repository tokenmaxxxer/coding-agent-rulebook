---
status: landed
files:
  - warrant/hooks/scope-gate.sh
  - warrant/hooks/run-gate-tests.sh
  - warrant/.claude-plugin/plugin.json
  - docs/proposals/2026-07-27-scope-gate-malformed-skip-and-deny-codes.md
---

# Proposal: scope-gate must not let a malformed proposal bypass nested-unit enforcement, and its policy denials must not ride the fail-closed trap

## Intent

The 0.4.2 fix (docs/proposals/2026-07-27-scope-gate-unknown-status-stand-down.md)
stopped a malformed/unrecognized-status proposal from self-locking a session,
but `docs/reports/2026-07-27-hunt-scope-gate-unknown-status-stand-down.md`
found the fix itself introduced two follow-on defects, both reproduced there:

- **D1**: the malformed-status branch now calls `allow()` and returns
  immediately, *before* `stand_down()`'s `nested_units()` reach check ever
  runs. One malformed `status:` value in `docs/proposals/` therefore silently
  flips the whole gate to allow-all, even when a real, out-of-reach nested
  proposals unit (e.g. `packages/foo/docs/proposals/`) exists and would
  otherwise have been flagged and denied.
- **D2**: the sibling "multiple proposals marked approved" branch, and the
  `nested_units()` branch inside `stand_down()`, still call `sys.exit(1)`.
  The `__fc` fail-closed trap at the top of the script reclassifies any exit
  code other than 0/2 into `exit 2` (deny) for the *entire session*,
  including `Read`. A second `status: approved` proposal reproduces the
  exact self-lock scenario the 0.4.2 fix was meant to eliminate, just
  through a different trigger than the one it patched.

The user reviewed both findings in conversation and approved this follow-up
fix directly — this proposal is written and landed in the same pass as its
approval, per that instruction, rather than going through a separate
propose-then-approve turn.

## Constraints

- Fail-closed on genuine internal errors (script crashes, exceptions) is a
  landed decision and stays in force; this proposal narrows what counts as a
  "genuine internal error" reaching the `__fc` trap, it does not touch the
  trap mechanism itself.
- A malformed/unrecognized-status proposal must be skipped (with a stderr
  warning) and must not disable enforcement for anything else in the
  repository — not the nested-units reach check, and not write-set
  enforcement over any other valid unit.
- "Nothing enforceable" (stand-down) is a genuinely different situation from
  "there is something to enforce and it says deny" (multiple approved units;
  a nested unit exists and is out of reach). The former may still allow with
  a warning when the reason is real absence, not reach; the latter must be a
  direct, intentional `exit 2`, not an `exit 1` laundered into `exit 2` by
  the fail-closed trap.
- 0.4.2's preserved behavior — a malformed-only repo with no nested units,
  no ambiguity — must keep allowing with a warning; this proposal must not
  regress that case back toward a self-lock.

## What will be done

1. In `warrant/hooks/scope-gate.sh`, when `len(approved) != 1`:
   - If more than one proposal is `status: approved`: print the existing
     message and call `sys.exit(2)` directly (was `sys.exit(1)`) — an
     intentional policy deny, not something routed through `__fc`.
   - If any proposal is malformed/unrecognized-status: print a warning
     naming the skipped file(s), then fall through to `stand_down()`
     instead of calling `allow()` directly. `stand_down()` still runs its
     `nested_units()` check, so a real nested unit is still caught and
     denied even when an unrelated proposal in the same directory is
     malformed.
2. In `stand_down()`'s `nested_units()` branch: print the existing message
   and call `sys.exit(2)` directly (was `sys.exit(1)`) — this is a real
   "cannot judge, and there is something plausibly in scope out of reach"
   situation, not a script fault.
3. When exactly one proposal is `status: approved` but a sibling proposal
   file is malformed: warn once (naming the skipped file) and continue —
   the approved unit's write-set enforcement is unaffected either way, this
   just makes the skip visible instead of silent.
4. Audit `scope-gate.sh` for any other `sys.exit(1)` reachable from
   malformed/ambiguous input and convert each to either warn-and-continue
   (an input problem the gate can route around) or `sys.exit(2)` (a policy
   denial) — none should remain reachable in normal operation, so `__fc`'s
   reclassification is reserved for actual crashes.
5. Add regression tests to `warrant/hooks/run-gate-tests.sh`:
   - a malformed proposal coexisting with a nested (out-of-reach) proposals
     unit, and a denying `tool_input` — still denies with exit 2 (regression
     for D1's bypass);
   - two `status: approved` proposals — exit 2 with the existing "all marked
     approved" message, not a trap-reclassified generic fail-closed message;
   - a malformed-only repo with no nested unit — still allows with a
     warning (0.4.2 behavior preserved);
   - existing cases stay green.
6. Bump `warrant/.claude-plugin/plugin.json` version 0.4.2 → 0.4.3.

## What did not work

(filled in during the build if anything surprises)

## Follow-ups

None identified yet; if the audit in step 4 surfaces another `sys.exit(1)`
call outside the two branches named in D1/D2, it will be converted in the
same pass rather than deferred.
