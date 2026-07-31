---
subject: issue-53
role: implementation
---

# Proposal — transition to core canon references (core #63/#66 rollout)

Phase 1 only. No execution in this PR. Survey:
`docs/issue-53/reports/implementation/survey.md`.

## Scope

Issue #53's five items, mapped 1:1 to this repo's `coding/` tree.

1. Delete `coding/agents/warrant-hunter.md`. It is byte-for-byte a subset
   of core's `warrant/agents/warrant-hunter.md` (shipped by the
   standalone `warrant` plugin, session/harness-level install) — nothing
   role-unique to preserve. The hunt-cadence *directive text* the issue
   also names is not in this file; it lives in `hooks/directive.sh`'s
   EXECUTION JUDGMENT section (bullets "Hunt cadence: ..." and "HUNT
   RESULTS ARE VERIFY'S INPUT ..."). That text is role-unique — it
   describes how `coding` feeds hunt output into its own record
   (`closed_checks:` entries, blocking-finding interaction with verify) —
   not how the hunter itself operates, so it is carried forward into the
   new stub (see item 3), not deleted.

2. Delete `coding/hooks/trailer-gate.sh`, `record-fields-gate.sh`,
   `handbook-trigger-gate.sh`. Rewrite `coding/hooks/hooks.json`'s
   `PreToolUse` block from:

   ```json
   "PreToolUse": [
     { "matcher": "Write|Edit|MultiEdit|NotebookEdit",
       "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/record-fields-gate.sh" }] },
     { "matcher": "Bash",
       "hooks": [
         { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/handbook-trigger-gate.sh" },
         { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/trailer-gate.sh" },
         { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/coding-progress-gate.sh" }
       ] },
     { "matcher": "Agent|Task",
       "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/hunt-guard.sh" }] }
   ]
   ```

   to:

   ```json
   "PreToolUse": [
     { "matcher": "Bash",
       "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/coding-progress-gate.sh" }] },
     { "matcher": "Agent|Task",
       "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/hunt-guard.sh" }] }
   ]
   ```

   — dropping only the three canon-gate entries. `core/hooks/hooks.json`
   (`matcher: ".*"`) already fires all three globally for every session
   with `core` installed. `coding-progress-gate.sh` and `hunt-guard.sh`
   stay: neither is in `stub-check.sh`'s `CANON_GATES` list, and issue
   #53's item 1 names only the warrant-hunter *agent* and its cadence
   text, not `hunt-guard.sh`/`hunt-state.sh`/`state.sh` — left untouched
   here (see survey's flagged divergence below). `SessionStart` stays,
   pointing at the rewritten `directive.sh` and untouched `state.sh`.

3. Replace `coding/hooks/directive.sh` with a stub sourcing
   `core/hooks/lib/role-directive.sh` and calling `core_role_directive`.
   Unlike the one sibling transition already open
   (`data-engineering-rulebook#2`, whose directive was a flat 4-line
   skeleton mapping 1:1 onto `core_role_directive`'s four-argument
   signature), `coding`'s directive carries six substantive sections.
   Proposed mapping onto `you_decide / use_when / produces / hand_off`:

   - `you_decide` — the existing "YOU DECIDE: ..." paragraph, unchanged.
   - `use_when` — RESEARCH + CURRENT-STATE SURVEY + PROPOSAL + ISSUE
     REFERENCE paragraphs concatenated (all four describe *when/how phase
     1 runs* — the natural "use when" grouping).
   - `produces` — the EXECUTION JUDGMENT section's 7 bullets verbatim,
     including the two hunt-cadence bullets carried over from item 1
     (what phase-2 execution has to produce and the quality bar it's
     held to).
   - `hand_off` — the RECORD REQUIREMENT section's content (record path,
     first-act timing, loop_state-update rule, the measured-evidence
     citation) — closest fit since it's about closing out and handing
     the work off, and it carries substantive detail beyond what
     `core_role_directive`'s auto-emitted closing `RECORD:` line covers
     (that line only states the path and phase-gating, not the
     first-act/loop_state rules this role's copy currently states).

   `stub-check.sh`'s structural check permits only comment/blank lines,
   the source line, the `core_role_directive` call, and single-physical-
   line `VAR=value` assignments — no heredocs, no control flow. Content
   this size therefore has to be assigned as `$'...\n...'`-quoted
   single-physical-line variables (e.g.
   `YOU_DECIDE=$'YOU DECIDE: ...\n\n...'`), one per argument, then passed
   as `core_role_directive "$YOU_DECIDE" "$USE_WHEN" "$PRODUCES"
   "$HAND_OFF"`. This preserves every sentence but produces a long,
   escape-heavy single line per variable — mechanically valid, harder to
   diff/read than the sibling's short literal-per-arg call.

4. `RECORD_FIELDS_TERMINAL_STATES` — not needed. This role's directive
   and its current `record-fields-gate.sh` both already use `{"landed"}`,
   the core default. No override recorded in `coding/hooks/hooks.json`.

5. Once items 1-4 land (phase 2), copy `core/hooks/tests/stub-check.sh`
   into this repo (same distribution mechanism `parse-check.sh` already
   uses per that file's own header) and run
   `core/hooks/tests/stub-check.sh coding`; record its pass in
   `docs/issue-53/reports/implementation.md`.

## Preserved (role-unique, unchanged)

- `coding/.claude-plugin/plugin.json` — untouched.
- `coding/hooks/state.sh`, `coding/hooks/coding-progress-gate.sh` — not
  canon gates, untouched.
- `coding/hooks/hunt-guard.sh`, `coding/hooks/hunt-state.sh` — not named
  in issue #53's item 1, untouched (see open question below).
- All six directive sections' substantive content — mapped, not dropped,
  into the new stub per item 3.

## Open questions for the approver

1. **Directive-mapping choice (item 3).** The four-slot mapping above is
   this session's best-fit read of `core_role_directive`'s signature
   against six existing sections; core's own transition record doesn't
   cover a directive this large (the one sibling precedent was a 4-line
   skeleton). If the approver wants different grouping, or wants content
   trimmed rather than preserved verbatim in escaped single-line form,
   say so before phase 2 writes the stub.
2. **`hunt-guard.sh` divergence, flagged not acted on.** This repo's
   `coding/hooks/hunt-guard.sh` is not a strict subset of core's
   `warrant/hooks/hunt-guard.sh`: it carries a fail-closed `trap` wrapper,
   case-insensitive `agent_type` matching, and drops the `WARRANT_IN_HUNT`
   runtime check in favor of a tool-list argument (per this repo's own
   `docs/decisions/` entry) — none of which core's copy has yet. Issue
   #53 does not name `hunt-guard.sh`/`hunt-state.sh` in its item list, so
   this proposal leaves them vendored and unchanged. Noting it because
   deleting them in some later pass, the way items 1-2 delete their
   targets, would regress behavior core does not yet carry — that
   would need the fix landed in core first, not a silent drop here.

## How you'll know it worked

- `coding/agents/warrant-hunter.md`, `coding/hooks/trailer-gate.sh`,
  `coding/hooks/record-fields-gate.sh`,
  `coding/hooks/handbook-trigger-gate.sh` no longer exist.
- `coding/hooks/hooks.json`'s `PreToolUse` block no longer references any
  of the three deleted gate scripts.
- `coding/hooks/directive.sh` sources `core/hooks/lib/role-directive.sh`
  and calls `core_role_directive`; `core/hooks/tests/stub-check.sh coding`
  exits 0.
- `docs/issue-53/reports/implementation.md` (phase 2) records the
  `stub-check.sh` pass.

## Order constraint

Per the issue: this transition must land before this repo's own
"rulebook maturation" phase 2 touches `directive.sh` or a gate file.
Noted for the approver's sequencing, not enforced mechanically in this
PR.
