---
subject: issue-61
role: implementation
---

# Proposal — implementation-domain methodology gate (phase 1 design)

Phase 1 only. No execution in this PR. Survey:
`docs/issue-61/reports/implementation/survey.md`. Scout brief:
`docs/issue-61/reports/implementation/scout-brief.md`.

files: `coding/hooks/directive.sh`, `coding/hooks/hooks.json`,
`coding/hooks/methodology-gate.sh` (new),
`coding/hooks/tests/order-state.md` (new, doc only — see (b).2),
`tests/methodology-gate-tests.sh` (new).

## Request

Issue #52's adopted phase-1/phase-2 norms (ADR-style `## Rationale`,
named-not-narrated completion criteria) landed as directive text only —
issue-52 itself explicitly declined a gate as out of proportion to one
added section. Issue #61 asks for the next step: bring this role's own
methodology up to the `coding-progress-gate.sh` hook-machine bar —
directive text deepened per facet (steps, judgment criteria,
prohibitions, not one-line summaries), a mechanical gate that verifies
the required elements of every phase-1 proposal and phase-2 record,
state-tracked order enforcement where the methodology has one, gate
tests, and an agents/checklist artifact if a repeated procedure is
implied. Canon scripts stay referenced, never copied.

## Constraints

- Phase 1 only — this PR ends at proposal; no code lands until Approve.
- Canon reference discipline (core issue-69's `canon-scripts.md`): no
  copy of any `core/hooks/**` file; the new gate is this repo's own
  artifact, same footing as `coding-progress-gate.sh`.
- Role/write-scope boundaries unchanged: the gate governs only this
  role's own write surfaces.
- Do not touch `record-fields-gate.sh`/`trailer-gate.sh`/
  `handbook-trigger-gate.sh` equivalents — those are core canon now
  (issue-53), out of this issue's scope.

## Rationale

**Why a gate now, reversing issue-52's own "no gate" call**: issue-52
weighed *one* additive section against gate-authoring cost and correctly
declined. Issue #61's ask is categorically larger — the full seven-
section phase-1 shape and the full phase-2 record shape, matched against
a proven exemplar already in this codebase family
(`pricing-rulebook/pricing/hooks/methodology-gate.sh`, scout-brief
"Must-bes"). The exemplar shows this is not "one section, not worth a
gate" territory anymore; it is the same shape of problem
`coding-progress-gate.sh` already solves for process state, applied to
document content — a natural sibling gate, not a novel design.

**Alternative considered and rejected — checklist/agent instead of a
gate**: a `docs/handbooks/` checklist or a repeated-review agent (like
`warrant-hunter`) could substitute for a mechanical gate. Rejected:
issue-52's own survey already found the failure mode is *silent* section
omission at write time, not a lack of periodic review — a checklist
read only at proposal-authoring time (voluntarily) does not change the
incentive that let two prior proposals (issue-53, issue-56) each use a
different informal shape. A PreToolUse gate, fail-closed like every
other gate in this repo, closes that gap at the point of writing instead
of relying on a later read. An agent/checklist is still proposed below
((d).4) but as a *complement* for the one genuinely repeated procedure
this norm implies (survey-before-proposal order), not as a replacement
for the section-presence check.

**Alternative considered and rejected — a single blanket
"proposal/record incomplete" gate message**: rejected in favor of named
element-by-element deny messages, per the exemplar's "element
specificity" performance axis (scout-brief) — a blanket message forces
the author to re-diff against the norm text to find what's missing;
named misses are directly actionable, matching `coding-progress-gate.sh`
and the pricing exemplar's own convention.

**Alternative considered and rejected — new JSON/state file for
order tracking**: rejected per scout-brief's "skip" line — file-existence-
as-state-signal (does `docs/issue-<n>/reports/implementation/survey.md`
exist before a proposal write) is the same pattern
`coding-progress-gate.sh` already uses to read another record file as
its state signal; a new state schema would be unprecedented surface area
for a check this simple.

## What will be done

**(a) Directive deepening — phase 1 (`USE_WHEN`).** Restructure the
PROPOSAL paragraph from a single run-on sentence into per-facet
guidance, each facet stating steps, a judgment criterion, and a
prohibition:
- *Research facet*: step — read the codebase/ecosystem/decisions per
  scout-directive; criterion — an alternative is only "considered" if it
  could plausibly have been chosen (not a straw man); prohibition — no
  proposal may name zero alternatives in `## Rationale`.
- *Survey facet*: step — write the current-state survey before drafting
  the proposal body; criterion — the write set must be the actually-
  projected set (files that will change), not a placeholder; prohibition
  — a proposal write must not precede its own survey file on disk (this
  becomes the gate's order check, (b).2 below).
- *Proposal-shape facet*: step — the seven sections in order (`files:`,
  `## Request`, `## Constraints`, `## Rationale`, `## What will be
  done`, `## Out of scope`, `## How you'll know it worked`); criterion —
  `## Rationale` must name the rejected alternative AND the reason, not
  just the chosen approach restated; prohibition — no merging `##
  Rationale` into `## What will be done` (the two answer different
  questions: why vs. what).
- *Issue-reference facet*: unchanged (plain `#n`, never
  Closes/Fixes in phase 1).

**(a) Directive deepening — phase 2 (`PRODUCES`).** Same per-facet
restructure for EXECUTION JUDGMENT:
- *Deviation facet*: step — the moment a scope-exceeded stop or a
  proposal-stated-alternative swap happens, note it; criterion — a
  deviation is any point where phase-2 execution diverges from what
  `## What will be done` said, not only a scope-exceeded stop;
  prohibition — `## Rationale for deviations` must not be added
  speculatively to a record with no actual divergence (keeps the
  section conditional, per issue-52's own design).
- *Record-shape facet*: step — `code_under_review:`+`loop_state:`
  frontmatter, `## What did not work` (present even when empty),
  placement-ladder cross-references as a completed-items list;
  criterion — "present even when empty" means the heading exists with
  explicit "None." content, not an omitted heading; prohibition — no
  narrating placement-ladder outcomes only in prose without the
  cross-reference list issue-52 (b).5 already requires.
- Also corrects the stale `HAND_OFF` record-path string from
  `docs/issue-<n>/reports/coding.md` to
  `docs/issue-<n>/reports/implementation.md` (survey finding 4) — the
  gate in (b) targets the real path; the directive text must say the
  same path or the gate and the directive silently disagree.

**(b) Methodology gate — `coding/hooks/methodology-gate.sh`.**
PreToolUse, `Write|Edit|MultiEdit` matcher, modeled directly on
`pricing/hooks/methodology-gate.sh`'s structure (fail-closed trap-at-top,
path-scoped to this role's own write surfaces, content resolved for
Write/Edit/MultiEdit alike, kill switch `IMPLEMENTATION_METHODOLOGY_GATE_OFF`):

1. **Path scope**: `docs/issue-[0-9]+/proposals/.*\.md$` and
   `docs/issue-[0-9]+/reports/implementation\.md$` only; every other
   write exits 0 immediately (exemplar's "path-scoped, not global"
   must-be).
2. **Proposal checks** (on any write resolving inside the proposals
   path): the seven required headings present, in order
   (`files:`/`## Request`/`## Constraints`/`## Rationale`/`## What will
   be done`/`## Out of scope`/`## How you'll know it worked`); `##
   Rationale` section body non-trivial (contains language indicating a
   rejected alternative — mirrors the pricing exemplar's
   presence-of-named-language check, not a word-count heuristic).
   **Order check**: deny if `docs/issue-<n>/reports/implementation/
   survey.md` does not exist on disk for the same `<n>` (survey-before-
   proposal, scout-brief "Adopt" #2) — unless the proposal body itself
   states the scout/skip-record condition (mirrors scout-directive's own
   mandatory skip-record escape hatch, so a legitimately-skipped survey
   is not falsely blocked).
3. **Record checks** (on any write resolving to
   `reports/implementation.md`): `code_under_review:` and `loop_state:`
   present in frontmatter; `## What did not work` heading present;
   **conditional check** — if the record's own text elsewhere signals a
   deviation (scope-exceeded language, or an explicit "diverged from the
   proposal" statement), `## Rationale for deviations` must also be
   present; if no deviation language appears, the section's absence is
   not an error (mirrors issue-52 (b).4's conditionality and the
   exemplar's conjoint-family conditional check).
4. Deny messages name the specific missing element(s), never a blanket
   "incomplete."

**(c) Gate tests — `tests/methodology-gate-tests.sh`** (new file,
sibling to `tests/run-gate-tests.sh` rather than an addition to it —
survey finding 5: that file already exercises three deleted hooks and
needs its own separate fix, out of this issue's write set). Cases,
modeled on `tests/run-gate-tests.sh`'s `run()`/`report()` harness
(temp git repo, JSON tool-call payload piped to the gate, exit-code
classified allow/deny/other):
- allow: complete 7-section proposal, survey.md present.
- deny: proposal missing `## Rationale`.
- deny: proposal complete but survey.md absent and no skip-record
  language.
- allow: proposal complete, survey.md absent, but proposal body states
  the scout-skip condition explicitly.
- allow: complete record, no deviation language, no
  `## Rationale for deviations` section.
- deny: record contains deviation language but no
  `## Rationale for deviations` section.
- deny: record missing `## What did not work`.
- allow: foreign path (e.g. `docs/issue-7/reports/qa.md`) passes through
  untouched.
- allow: kill switch set, otherwise-denying content passes through.

**(d) Agents/checklist.** No new adversarial-hunt-style agent — this
norm has exactly one repeated procedure (survey-before-proposal
ordering), and (b).2's order check already enforces it mechanically;
adding an agent on top would duplicate what the gate already does
deterministically (scout-brief's own "skip: separate state-tracking"
reasoning applies equally here — a gate is enforcement, an agent would
be commentary on the same fact). No checklist file is added either: the
seven-section/record-shape checklist now *is* the gate's own check list,
named once in `methodology-gate.sh`'s comments (matching the pricing
exemplar's convention of stating the checked elements in the script's
own header comment) rather than duplicated into a separate
`docs/handbooks/` file that could drift from the gate's actual logic.

## Out of scope

- Any change to core-canon files (`role-directive.sh`, `stub-check.sh`,
  the three retired local gates, `warrant-hunter.md`) — referenced only,
  untouched.
- Fixing `tests/run-gate-tests.sh`'s stale references to the three
  deleted hooks — a real gap (survey finding 5) but not this issue's
  write set; noted for a future issue.
- Renaming the `coding` plugin directory to `implementation` — the
  role/plugin name mismatch predates this issue and is not part of the
  methodology-gate ask.
- Any change to `coding-progress-gate.sh`, `hunt-guard.sh`,
  `hunt-state.sh`, `state.sh` — untouched, not this norm's concern.

## How you'll know it worked

- This proposal PR is open against `main`, referencing `#61` (plain, not
  Closes/Fixes), with survey + scout-brief + this file committed under
  `docs/issue-61/`.
- On Approve, phase 2 lands (d) items (a)-(c) above:
  `coding/hooks/directive.sh` deepened per facet with the corrected
  record path, `coding/hooks/methodology-gate.sh` wired into
  `coding/hooks/hooks.json`'s `PreToolUse` block alongside the existing
  `coding-progress-gate.sh`/`hunt-guard.sh` entries, and
  `tests/methodology-gate-tests.sh` passing every case in (c) as a real
  subprocess run (`bash -n` syntax check + the harness's own allow/deny
  classification), demonstrating the phase-2 record for this same issue
  satisfies its own gate (dogfooding, same as issue-52's close-out).
