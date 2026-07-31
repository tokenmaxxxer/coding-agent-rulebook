---
subject: issue-53
role: implementation
---

# Current-state survey — core canon reference transition

## This repo's current tree (`coding/`)

| File | Status vs core canon |
|---|---|
| `agents/warrant-hunter.md` | Vendored copy, fully written (not a skeleton). Byte-for-byte identical to core's `warrant/agents/warrant-hunter.md` (installed by the standalone `warrant` plugin) except that core's copy additionally documents size-proportional cap/tier budgeting, miss-streak reduction, and per-section instrumentation fields (`cap_seconds`, `tier`, `diff_stat_lines`, `started_at`/`ended_at`) that this repo's copy never picked up. No role-unique content — every sentence in this repo's copy also appears in core's, so nothing here needs preserving; core's copy is a pure superset. |
| `hooks/trailer-gate.sh` | Vendored copy, role-token-substituted from the shared design (hardcodes `coding`/`CODING_CYCLE_OFF` instead of reading `CLAUDE_ROLE` at runtime). Same logic shape as core's `core/hooks/trailer-gate.sh`, which now derives role identity from `CLAUDE_ROLE` and is registered globally in `core/hooks/hooks.json`'s `PreToolUse` (`matcher: ".*"`). |
| `hooks/record-fields-gate.sh` | Vendored copy implementing the real §20 field set (what-was-done / why / upstream-basis / loop_state / open-findings, terminal-state-conditional next-steps) — same substantive checks as core's canon copy, just hardcoded to role `coding` instead of reading `CLAUDE_ROLE`. Terminal set is `{"landed"}`, identical to core's default (`RECORD_FIELDS_TERMINAL_STATES` env var default is `landed`) — no divergence, no override needed. |
| `hooks/handbook-trigger-gate.sh` | Vendored copy, role-token-substituted only; core's canon copy at `core/hooks/handbook-trigger-gate.sh` is registered globally and carries the same §21 logic. |
| `hooks/directive.sh` | 91-line role directive: opening/kill-switch/closing boilerplate (now factored into `core/hooks/lib/role-directive.sh`'s `core_role_directive`) wrapping **six** role-unique content sections (YOU DECIDE, RESEARCH, CURRENT-STATE SURVEY, PROPOSAL, ISSUE REFERENCE, EXECUTION JUDGMENT with 7 sub-bullets including hunt cadence, RECORD REQUIREMENT) — substantially more content than `core_role_directive`'s four-argument signature (`you_decide, use_when, produces, hand_off`) was sized for in the one sibling transition already observed (data-engineering-rulebook issue #2, whose directive was a flat 4-liner). See "Open question" in the proposal. |
| `hooks/hooks.json` | Registers `directive.sh` (SessionStart) + `state.sh` (SessionStart, role-unique, untouched) + `record-fields-gate.sh` (PreToolUse, Write\|Edit\|MultiEdit\|NotebookEdit) + `handbook-trigger-gate.sh`/`trailer-gate.sh`/`coding-progress-gate.sh` (PreToolUse, Bash) + `hunt-guard.sh` (PreToolUse, Agent\|Task). The three canon gates now fire globally from `core/hooks/hooks.json`, making this file's entries for them redundant double-firing — exactly the drift shape `stub-check.sh` polices. `coding-progress-gate.sh` and `hunt-guard.sh` are **not** in `stub-check.sh`'s `CANON_GATES` list and stay. |
| `hooks/hunt-guard.sh`, `hooks/hunt-state.sh`, `hooks/state.sh` | Vendored copies of the standalone `warrant` plugin's own hook mechanics (single-flight lock, session dispatch cap, nesting guard). **Not named in issue #53's item 1** (which scopes to `agents/warrant-hunter.md` and the hunt-cadence *directive text*, not the guard/state scripts). Diffed against core's `warrant/hooks/hunt-guard.sh` for this survey anyway, since it sits right next to the file the issue does ask about: this repo's copy is **not** a strict subset of core's — it carries a fail-closed `trap` wrapper, case-insensitive `agent_type` matching, and a documented removal of the `WARRANT_IN_HUNT` runtime check (replaced by a tool-list argument, per a `docs/decisions/` entry this repo carries) that core's own copy does not have. Flagged in the proposal as a real divergence to raise, not silently resolved — issue #53 does not ask this session to touch these three files, and deleting them would regress behavior core does not yet carry. |
| `hooks/coding-progress-gate.sh` | Role-unique (§15 blocking-finding enforcement tied to coding's own record). Not a canon gate. Untouched. |
| `.claude-plugin/plugin.json` | Role identity + companion-plugin listing (blueprint, no-mock, no-footgun) in its `description`. No gate/agent path references. No change needed. |

## Core canon state (read from the sibling checkout, read-only)

- `core/hooks/hooks.json` — `PreToolUse` (`matcher: ".*"`) already fires `board-gate.sh`, `approval-gate.sh`, `gh-guard.sh`, `trailer-gate.sh`, `record-fields-gate.sh`, `handbook-trigger-gate.sh` for every session with the `core` plugin installed (session/harness-level install — this session's own transcript already carries `core`'s protocol directive, confirming `core` is present without this repo's `marketplace.json` declaring it).
- `core/hooks/lib/role-directive.sh` — exposes `core_role_directive you_decide use_when produces hand_off`; reads `CLAUDE_ROLE`, per-role kill switch `<ROLE>_CYCLE_OFF` (uppercased via `tr`, bash-3.2-safe); emits the closing `RECORD: docs/issue-<n>/reports/${role}.md, phase-gated per contract v3 s19` line automatically.
- `core/hooks/tests/stub-check.sh` — the drift detector issue #53 item 5 asks this record to confirm passing. Two checks: (a) absence of any vendored `trailer-gate.sh`/`record-fields-gate.sh`/`handbook-trigger-gate.sh`/`parse-check.sh` under `hooks/` (maxdepth 3, so `hooks/tests/` is covered too); (b) `directive.sh` structural check — must source `role-directive.sh`, call `core_role_directive`, and contain no other non-blank/non-comment line (plain `VAR=value` assignments are allowed, which is how a multi-section directive can still pass the check — see proposal).
- `warrant/agents/warrant-hunter.md` — canon warrant-hunter, shipped by the standalone `warrant` plugin (marketplace-registered in `tokenmaxxxer-core`, per core issue #63). Core issue #63's own record states the per-rulebook vendored-copy removal is tracked but not executed by core — i.e. exactly this issue's item 1.
- `docs/issue-66/reports/implementation.md` (core) — states the per-rulebook follow-up: delete vendored `trailer-gate.sh`/`record-fields-gate.sh`/`handbook-trigger-gate.sh`/`parse-check.sh` and any `hooks.json` entry referencing them; replace `directive.sh` with the lib-call stub; drop `stub-check.sh` into the rulebook and run it; set `RECORD_FIELDS_TERMINAL_STATES` first if a non-`landed` terminal state is in use (not the case here).
- `docs/issue-63/reports/implementation.md` (core) — confirms the vendored `agents/warrant-hunter.md` removal is the matching per-rulebook follow-up for the warrant side, batched with #66's.

## Comparable sibling transition (already open, same shape)

`tokenmaxxxer/data-engineering-rulebook#2` (open PR #3) ran this exact
five-item transition for a report-only role whose `directive.sh` was a
flat 4-line skeleton — a 1:1 fit for `core_role_directive`'s signature,
with no mapping decision needed. `coding`'s directive is materially
larger (six sections, one — EXECUTION JUDGMENT — itself seven sub-bullets
including the hunt-cadence integration issue #53 explicitly calls out as
role-unique to preserve), so the sibling's stub shape is the right
target but not a direct copy-paste; see the proposal's mapping and open
question.

## Gap line

- Present in core, absent in this repo: real `CLAUDE_ROLE`-driven role
  resolution in the three gates (irrelevant post-removal — core's copy
  fires instead), the `role-directive.sh` boilerplate factoring,
  `stub-check.sh` drift detection, core's size-proportional/miss-streak/
  instrumentation additions to the warrant-hunter stance protocol
  (inherited automatically once this repo stops vendoring its own copy).
- Present in this repo, redundant once canon fires: the three vendored
  gate scripts, their `hooks.json` `PreToolUse` entries, the vendored
  `warrant-hunter.md`.
- Present in this repo, genuinely ahead of core, out of this issue's
  scope: `hunt-guard.sh`'s fail-closed trap and case-insensitive
  `agent_type` match (not named in issue #53's item 1; not touched by
  this proposal).
- Role-unique and to be preserved: all six directive sections' content
  (mapped, not dropped, into the new stub — see proposal), `plugin.json`,
  `coding-progress-gate.sh`, `state.sh`.
- No `RECORD_FIELDS_TERMINAL_STATES` override needed: this role's
  directive and its own `record-fields-gate.sh` both already use
  `{"landed"}`, the core default.
