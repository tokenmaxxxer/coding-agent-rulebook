---
subject: issue-61
role: implementation
---

# Current-state survey — methodology enforcement gap (issue #61)

## Write surfaces this issue touches

- `coding/hooks/directive.sh` — the plugin instantiating the
  `implementation` role (plugin name still `coding`; role name
  `implementation` per the `subject:`/`role:` convention). Currently a
  four-`$'...'`-line stub (`YOU_DECIDE`/`USE_WHEN`/`PRODUCES`/`HAND_OFF`)
  sourcing `core/hooks/lib/role-directive.sh`'s `core_role_directive`
  (landed issue-53).
- `coding/hooks/hooks.json`, `coding/hooks/coding-progress-gate.sh`,
  `coding/hooks/hunt-guard.sh` + `hunt-state.sh`, `coding/hooks/state.sh`
  — the plugin's live gates.
- `tests/*.sh` — repo-root gate tests (never installed).
- `docs/issue-52/proposals/2026-07-31-implementation-domain-norms.md` —
  the "직전 성숙화 이슈" this issue's directive names: adopted the ADR
  Context/Decision/Consequences skeleton for phase-1 proposals and named,
  recoverable completion criteria for phase-2 records.

## What exists today (as of `main`, `9abd01b`)

1. **Directive text is already deepened for issue-52's norm.**
   `USE_WHEN`'s PROPOSAL paragraph carries `## Rationale (why this
   approach and not another: at least one alternative considered and
   rejected, with the reason)`; `PRODUCES` carries a `## Rationale for
   deviations` bullet, conditional on divergence. Both landed in
   `9abd01b`/`553270f` (issue-52 phase 2) exactly as that proposal's
   (d).1 planned. So the "directive 한 줄(PRODUCES 요약)" issue #61
   opens with is no longer accurate for this specific norm — it reads
   accurately for the *prior* state issue-52 itself inherited, and
   remains accurate for the *general* claim: nothing downstream of the
   directive text checks that a written proposal or record actually
   contains these sections.
2. **No methodology gate exists.** Issue-52's own phase-1 proposal (d).2
   explicitly declined one ("a mechanical section-presence check … is
   out of proportion to a single added section … conformance stays
   directive-text discipline"). That was a reasoned call scoped to one
   additive section; issue #61 now asks for the `implementation-rulebook`
   hook-machine level (matching `coding-progress-gate.sh`'s mechanical
   enforcement of process state) applied to *document shape*, which is a
   materially larger ask than the one section issue-52 weighed.
3. **`coding-progress-gate.sh` is the closest existing pattern** — a
   PreToolUse `Bash`-matcher gate, fail-closed trap-at-top, that reads
   `docs/issue-<n>/reports/verify.md` and the coding record to block a
   `git commit`. It gates *process state* (blocking findings), not
   *document content* — no existing hook in this repo parses a
   proposal/record body for required sections.
4. **Record path mismatch, discovered in this survey.** `directive.sh`'s
   `HAND_OFF` text still says the record "lives at
   `docs/issue-<n>/reports/coding.md`" — but every landed record
   (`docs/issue-52/reports/implementation.md`,
   `docs/issue-53/reports/implementation.md`,
   `docs/issue-56/reports/implementation.md`) is filed at
   `reports/implementation.md`, matching the role-handoff contract v3
   convention (`docs/issue-<n>/reports/<role>.md`, role = `implementation`).
   Any methodology gate targeting "the phase-2 record" must target the
   path actually in use (`reports/implementation.md`), not the stale
   `coding.md` string in `HAND_OFF` — this proposal's directive-text plan
   corrects that string alongside the deepening, since a gate built
   against the wrong path would silently never fire.
5. **`tests/run-gate-tests.sh` is stale.** It still exercises
   `record-fields-gate.sh`, `trailer-gate.sh`, and
   `handbook-trigger-gate.sh` by path under `coding/hooks/`, but issue-53
   phase 2 deleted all three local copies (now core canon, referenced not
   vendored) and rewrote `coding/hooks/hooks.json` accordingly — the test
   file itself was not updated in that same commit. Running it today
   would fail every one of those cases (file-not-found, not a gate
   verdict). Out of this issue's write set (issue-53's follow-through,
   not issue-61's), but material to where a *new* methodology-gate test
   should live: a fresh file (e.g. `tests/methodology-gate-tests.sh`),
   not an addition to the already-broken `run-gate-tests.sh`.
6. **Canon-reference constraint.** `core`'s
   `docs/handbooks/canon-scripts.md` (core issue-69): any script under
   `core/hooks/` or `core/hooks/tests/` must be invoked by path against
   core's install root, never copied into a rulebook tree;
   `stub-check.sh` + `canon-manifest.txt` enforce this mechanically. A
   *new* `methodology-gate.sh`, scoped entirely to this role's own
   proposal/record shape, is not a canon file and is not covered by the
   manifest — it is this repo's own artifact, same footing as
   `coding-progress-gate.sh` and `hunt-guard.sh` today.
7. **Order constraint already exists but is directive-only.** The
   `scout-directive` (core, installed globally) already mandates
   survey-before-sweep and a mandatory `scout-brief.md`/skip-record; nothing
   in this repo's own hooks checks that a proposal write is preceded by a
   `docs/issue-<n>/reports/implementation/survey.md` (or an explicit
   skip note) on disk.

## Comparable prior art inside this codebase family

- `pricing-rulebook`'s `pricing/hooks/methodology-gate.sh` — a
  PreToolUse gate on `Write|Edit|MultiEdit` that resolves the target path
  against the project root, restricts itself to
  `docs/issue-<n>/proposals/*pricing*.md` and
  `docs/issue-<n>/reports/pricing.md`, reconstructs the post-write text
  (Write=content, Edit/MultiEdit=apply the diff to current content, deny
  if unresolvable), and greps the resulting text for named required
  elements, denying (exit 2) if any are absent. Fail-closed trap-at-top,
  same convention as `coding-progress-gate.sh`. This is the load-bearing
  exemplar for issue #61's ask ("pricing-rulebook의 methodology-gate.sh
  참조").

## Gaps this issue is meant to close

- No mechanical check that a phase-1 proposal contains all seven
  required sections (files:/Request/Constraints/Rationale/What will be
  done/Out of scope/How you'll know it worked), in order.
- No mechanical check that a phase-2 record contains
  `code_under_review:`+`loop_state:`, `## What did not work` (even
  empty), and `## Rationale for deviations` when a deviation is claimed
  elsewhere in the record.
- No state-tracked order enforcement that a proposal write is preceded
  by a current-state survey on disk (methodology order: research/survey
  → proposal, per this role's own `USE_WHEN` text).
- No test file exercising any of the above (parallel to
  `pricing-rulebook`'s own gate tests).
- Stale `HAND_OFF` record-path string (`coding.md` vs. actual
  `implementation.md`) that would make a naively-built gate a silent
  no-op.

## Constraints carried over unchanged

- Canon scripts (`role-directive.sh`, `stub-check.sh`, the three core
  gates, `warrant-hunter.md`) stay referenced only, never copied — this
  issue introduces no new canon dependency and touches none of those
  files' content.
- Role/write-scope boundaries unchanged: this plugin gates its own
  write surfaces (`docs/issue-<n>/proposals/*.md`,
  `docs/issue-<n>/reports/implementation.md`) only, same footing as
  `coding-progress-gate.sh` and `pricing`'s `methodology-gate.sh`.
