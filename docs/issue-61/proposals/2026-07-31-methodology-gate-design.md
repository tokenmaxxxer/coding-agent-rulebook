---
subject: issue-61
role: implementation
---

# Proposal — implementation-domain methodology plugin set (phase 1 design)

**Revision (approver FEEDBACK on PR #62):** the prior version of this
proposal put all enforcement into one `methodology-gate.sh` bolted onto
the existing `coding` plugin. The approver's required correction: this
is not a single-gate/directive deepening — it must be a **plugin set**,
matching how `no-mock`/`no-footgun`/`blueprint` already sit alongside
`coding` in this repo's own `.claude-plugin/marketplace.json`. Each
adopted methodology becomes its own **independent, self-contained
plugin** (own `plugin.json`, own `hooks/`, its own gate/directive/tests,
`freelunch`-level completeness), and the phase-1/phase-2 norms are
*compositions* of those plugins, not one monolithic check. The plugin
inventory below, with each plugin's owned methodology and how phase-1
and phase-2 norms compose them, is now the core of this design — see
"Plugin inventory" and "Composition" below.

Phase 1 only. No execution in this PR. Survey:
`docs/issue-61/reports/implementation/survey.md`. Scout brief:
`docs/issue-61/reports/implementation/scout-brief.md`.

files: `.claude-plugin/marketplace.json` (register 3 new plugins),
`proposal-shape/.claude-plugin/plugin.json` (new),
`proposal-shape/hooks/{directive.sh,hooks.json,proposal-shape-gate.sh}` (new),
`proposal-shape/hooks/tests/` (new),
`record-shape/.claude-plugin/plugin.json` (new),
`record-shape/hooks/{directive.sh,hooks.json,record-shape-gate.sh}` (new),
`record-shape/hooks/tests/` (new),
`survey-order/.claude-plugin/plugin.json` (new),
`survey-order/hooks/{directive.sh,hooks.json,survey-order-gate.sh}` (new),
`survey-order/hooks/tests/` (new),
`coding/hooks/directive.sh` (fix stale `HAND_OFF` path only — see (e)),
`tests/methodology-plugins-tests.sh` (new, repo-root harness invoking
all three plugins' gates).

## Request

Issue #52's adopted phase-1/phase-2 norms (ADR-style `## Rationale`,
named-not-narrated completion criteria) landed as directive text only —
issue-52 itself explicitly declined a gate as out of proportion to one
added section. Issue #61 asks for the next step, and the approver's
FEEDBACK on the first attempt (PR #62) fixed the *shape* of that next
step: not one directive/gate deepened in place, but the methodologies
already adopted for this role split into **independent plugins**, each
owning exactly one methodology, each self-contained
(directive+gate+tests, `marketplace.json`-registered), with phase-1 and
phase-2 norms defined as which plugins compose to produce them. Canon
scripts stay referenced, never copied.

## Constraints

- Phase 1 only — this PR ends at proposal; no code lands until Approve.
- Canon reference discipline (core issue-69's `canon-scripts.md`): no
  copy of any `core/hooks/**` file; each new plugin's gate is this
  repo's own artifact, same footing as `coding-progress-gate.sh`.
- Role/write-scope boundaries unchanged: every new plugin's gate governs
  only this role's own write surfaces (`docs/issue-<n>/proposals/*.md`,
  `docs/issue-<n>/reports/implementation.md`); no plugin gates another
  role's output.
- Do not touch `record-fields-gate.sh`/`trailer-gate.sh`/
  `handbook-trigger-gate.sh` equivalents — those are core canon now
  (issue-53), out of this issue's scope.
- Each new plugin is genuinely independent and self-contained: its own
  `.claude-plugin/plugin.json`, its own `hooks/` tree, its own tests —
  installable/removable on its own, same as `no-mock`/`no-footgun` are
  today, not a sub-folder of `coding`.
- No plugin may duplicate another plugin's check; where two norms would
  otherwise overlap (e.g. both phase-1 and phase-2 caring about
  frontmatter), ownership is split by document type, not by norm name
  (see "Plugin inventory").

## Plugin inventory

Per the approver's FEEDBACK, each adopted methodology below is its own
independent plugin — not a facet of one gate. Every plugin: own
`plugin.json`, own `hooks/{directive.sh,hooks.json,<name>-gate.sh}`, own
`hooks/tests/`, registered in `.claude-plugin/marketplace.json`.

| Plugin | Methodology owned | Components | Composes into |
|---|---|---|---|
| `proposal-shape` | The ADR-style phase-1 proposal shape (issue-52's adopted norm): seven required sections in order, `## Rationale` naming a rejected alternative and reason. | `directive.sh` (USE_WHEN facet: proposal-shape steps/criterion/prohibition), `proposal-shape-gate.sh` (PreToolUse `Write\|Edit\|MultiEdit`, path-scoped to `docs/issue-<n>/proposals/*.md`, section-presence + order + non-trivial-Rationale check, named per-element deny messages, kill switch `PROPOSAL_SHAPE_GATE_OFF`), `hooks/tests/proposal-shape-tests.sh`. | **Phase-1 norm** (with `survey-order`). |
| `record-shape` | The phase-2 record shape (issue-52's adopted norm): `code_under_review:`+`loop_state:` frontmatter, `## What did not work` present even when empty, conditional `## Rationale for deviations` only when deviation language appears elsewhere in the record. | `directive.sh` (PRODUCES facet: record-shape steps/criterion/prohibition, plus the corrected `HAND_OFF` record path), `record-shape-gate.sh` (PreToolUse, path-scoped to `docs/issue-<n>/reports/implementation.md`, frontmatter + heading + conditional-deviation check, kill switch `RECORD_SHAPE_GATE_OFF`), `hooks/tests/record-shape-tests.sh`. | **Phase-2 norm** (standalone — no phase-1 dependency). |
| `survey-order` | The research-before-proposal ordering (this role's own `USE_WHEN` research/survey facets, plus the scout-directive's skip-record escape hatch): a proposal write must be preceded by `docs/issue-<n>/reports/implementation/survey.md` on disk for the same `<n>`, unless the proposal body itself states the scout-skip condition. | `directive.sh` (research/survey facet: steps/criterion/prohibition), `survey-order-gate.sh` (PreToolUse, path-scoped to `docs/issue-<n>/proposals/*.md`, file-existence-as-state-signal order check — no new state schema, reusing `coding-progress-gate.sh`'s own pattern of reading another record file as its signal), `hooks/tests/survey-order-tests.sh`. | **Phase-1 norm** (with `proposal-shape`; this is the state-tracked-order piece the issue separately calls out). |

`coding/hooks/directive.sh` keeps the role's overall `YOU_DECIDE`
framing (unchanged) and gets only the stale `HAND_OFF` path string fixed
(`docs/issue-<n>/reports/coding.md` → `.../implementation.md`) — the
per-facet directive *content* itself now lives in the three plugins
above, since it is methodology-specific, not role-framing.

## Composition

- **Phase-1 norm = `proposal-shape` ∘ `survey-order`.** Together they
  cover everything issue-52 adopted for proposals plus this role's own
  research-order expectation: `survey-order` runs first in write-time
  sequence (blocks the proposal write itself if the survey is missing
  and unexplained), `proposal-shape` then checks the written proposal's
  internal shape. Neither plugin depends on the other's code — both are
  independently installable — but a phase-1 write that must satisfy
  "the issue-61 phase-1 norm" is defined as passing both gates, since
  each targets a disjoint slice (order-of-writing vs. shape-of-content)
  of the same document.
- **Phase-2 norm = `record-shape`** alone — issue-52's phase-2 adoption
  had no ordering component (a record is a single end-of-work write,
  not preceded by another required artifact this repo tracks), so one
  plugin covers it fully. If a future issue adds a phase-2 ordering
  requirement, it becomes a fourth independent plugin, not a change to
  `record-shape`'s scope.
- No plugin imports another's code; composition is *purely* "both gates
  fire on the relevant write, both must exit 0" — matching how
  `no-mock`/`no-footgun`/`blueprint` already coexist with `coding` today
  with no cross-plugin coupling in `marketplace.json`.

## Rationale

**Why a plugin set, not one gate on `coding`**: the first draft of this
proposal (PR #62) put a single `methodology-gate.sh` inside the existing
`coding` plugin, deepening its directive text in place. The approver's
FEEDBACK rejected that shape directly: this repo's own convention for an
adopted methodology is an independent, freelunch/scout-grade plugin
(`no-mock`, `no-footgun`, `blueprint` all sit beside `coding` in
`marketplace.json`, none folded into it), and issue #61 explicitly asks
for that per-methodology granularity, not a deepened-in-place directive.
Splitting into `proposal-shape`/`record-shape`/`survey-order` also
resolves a coupling problem the single-gate design had: the prior
`methodology-gate.sh` mixed "does the proposal have the right sections"
with "was the proposal written in the right order" in the same script
and the same kill switch, so a repo maintainer could not disable one
concern without disabling the other; three plugins with three
independent kill switches let each be turned off or replaced on its own.

**Why exactly three plugins, not one per section-check**: `proposal-
shape` and `record-shape` are not split further (e.g. one plugin per
required heading) because issue-52 adopted them as single indivisible
norms — "the phase-1 shape" and "the phase-2 shape" are each one
methodology with multiple required elements, not multiple methodologies.
`survey-order` is split out separately because it is a genuinely
different methodology (an *ordering* constraint on writes, sourced from
the scout-directive and this role's own research facet) from
`proposal-shape`'s *content* constraint, even though both gate the same
file — the "one plugin, one methodology" rule from the FEEDBACK is
satisfied by splitting on methodology identity, not on file path.

**Why a mechanical gate at all, reversing issue-52's own "no gate"
call**: issue-52 weighed *one* additive section against gate-authoring
cost and correctly declined. Issue #61's ask is categorically larger —
the full seven-section phase-1 shape and the full phase-2 record shape,
matched against a proven exemplar already in this codebase family
(`pricing-rulebook/pricing/hooks/methodology-gate.sh`, scout-brief
"Must-bes"). The exemplar shows this is not "one section, not worth a
gate" territory anymore; it is the same shape of problem
`coding-progress-gate.sh` already solves for process state, applied to
document content.

**Alternative considered and rejected — checklist/agent instead of
gates**: a `docs/handbooks/` checklist or a repeated-review agent (like
`warrant-hunter`) could substitute for mechanical gates. Rejected:
issue-52's own survey already found the failure mode is *silent* section
omission at write time, not a lack of periodic review — a checklist
read only at proposal-authoring time (voluntarily) does not change the
incentive that let two prior proposals (issue-53, issue-56) each use a
different informal shape. Three PreToolUse gates, fail-closed like every
other gate in this repo, close that gap at the point of writing instead
of relying on a later read. No agent/checklist plugin is added (see
"Agents/checklist" below) — the order-enforcement piece that would have
motivated one is now `survey-order`'s own mechanical check.

**Alternative considered and rejected — a single blanket
"proposal/record incomplete" gate message**: rejected in favor of named
element-by-element deny messages per plugin, per the exemplar's "element
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
for a check this simple, and `survey-order` reuses it rather than
inventing one.

## What will be done

**(a) `proposal-shape` plugin** (new, top-level directory alongside
`coding`/`no-mock`/`no-footgun`/`blueprint`):
- `proposal-shape/.claude-plugin/plugin.json` — name, version, one-line
  description naming the exact norm (seven-section ADR shape).
- `proposal-shape/hooks/directive.sh` — the PROPOSAL-shape facet only:
  step (write the seven sections in order), criterion (`## Rationale`
  names the rejected alternative AND the reason, not just the chosen
  approach restated), prohibition (no merging `## Rationale` into `##
  What will be done` — the two answer different questions).
- `proposal-shape/hooks/proposal-shape-gate.sh` — PreToolUse,
  `Write|Edit|MultiEdit` matcher, modeled on
  `pricing/hooks/methodology-gate.sh`'s structure (fail-closed
  trap-at-top, content resolved for Write/Edit/MultiEdit alike, kill
  switch `PROPOSAL_SHAPE_GATE_OFF`): path-scoped to
  `docs/issue-[0-9]+/proposals/.*\.md$` (every other write exits 0
  immediately); checks the seven required headings present in order
  (`files:`/`## Request`/`## Constraints`/`## Rationale`/`## What will
  be done`/`## Out of scope`/`## How you'll know it worked`); checks
  `## Rationale`'s body is non-trivial (contains language indicating a
  rejected alternative, presence-check not word-count); deny messages
  name the specific missing/misordered element(s).
- `proposal-shape/hooks/tests/proposal-shape-tests.sh`.

**(b) `record-shape` plugin** (new, same top-level footing):
- `record-shape/.claude-plugin/plugin.json`.
- `record-shape/hooks/directive.sh` — the PRODUCES record-shape facet:
  step (`code_under_review:`+`loop_state:` frontmatter, `## What did
  not work` present even when empty, placement-ladder cross-references
  as a completed-items list), criterion ("present even when empty"
  means the heading exists with explicit "None." content, not an
  omitted heading), prohibition (no narrating placement-ladder outcomes
  only in prose without the cross-reference list issue-52 (b).5
  already requires). Also carries the deviation facet: step (note a
  deviation the moment a scope-exceeded stop or alternative-swap
  happens), criterion (any divergence from `## What will be done`
  counts, not only a scope-exceeded stop), prohibition (`## Rationale
  for deviations` must not be added speculatively with no actual
  divergence).
- `record-shape/hooks/record-shape-gate.sh` — PreToolUse, path-scoped
  to `docs/issue-[0-9]+/reports/implementation\.md$`; checks
  `code_under_review:`+`loop_state:` present in frontmatter and `## What
  did not work` heading present; conditional check — if the record's
  own text elsewhere signals a deviation (scope-exceeded language, or an
  explicit "diverged from the proposal" statement), `## Rationale for
  deviations` must also be present, otherwise its absence is not an
  error; kill switch `RECORD_SHAPE_GATE_OFF`; named deny messages.
- `record-shape/hooks/tests/record-shape-tests.sh`.

**(c) `survey-order` plugin** (new, same top-level footing):
- `survey-order/.claude-plugin/plugin.json`.
- `survey-order/hooks/directive.sh` — the research/survey facet: step
  (read the codebase/ecosystem/decisions per scout-directive, write the
  current-state survey before drafting the proposal body), criterion
  (the write set must be the actually-projected set, not a placeholder;
  an alternative is only "considered" if it could plausibly have been
  chosen), prohibition (a proposal write must not precede its own survey
  file on disk, and no proposal may name zero alternatives).
- `survey-order/hooks/survey-order-gate.sh` — PreToolUse, path-scoped to
  `docs/issue-[0-9]+/proposals/.*\.md$`; deny if
  `docs/issue-<n>/reports/implementation/survey.md` does not exist on
  disk for the same `<n>`, unless the proposal body itself states the
  scout/skip-record condition (mirrors scout-directive's own mandatory
  skip-record escape hatch); kill switch `SURVEY_ORDER_GATE_OFF`.
- `survey-order/hooks/tests/survey-order-tests.sh`.

**(d) Marketplace registration.** `.claude-plugin/marketplace.json`
gains three entries (`proposal-shape`, `record-shape`, `survey-order`),
each with `source`/`description` naming its owned methodology, alongside
the existing `coding`/`blueprint`/`no-mock`/`no-footgun` entries — no
change to the four existing entries' content.

**(e) `coding/hooks/directive.sh` path fix only.** Corrects the stale
`HAND_OFF` record-path string from `docs/issue-<n>/reports/coding.md` to
`docs/issue-<n>/reports/implementation.md` (survey finding 4) — the
`record-shape` gate in (b) targets the real path; the role directive
must say the same path or the gate and the directive silently disagree.
This is the only change to `coding/hooks/directive.sh`; the per-facet
methodology text itself moves to the three new plugins, not added here.

**(f) Repo-root harness — `tests/methodology-plugins-tests.sh`** (new
file, sibling to `tests/run-gate-tests.sh` rather than an addition to it
— survey finding 5: that file already exercises three deleted hooks and
needs its own separate fix, out of this issue's write set). Invokes all
three plugins' gates (each plugin also ships its own `hooks/tests/`, per
(a)-(c) above, for standalone/removable testing; this repo-root file
additionally exercises them together against realistic combined
proposal/record fixtures). Cases, modeled on
`tests/run-gate-tests.sh`'s `run()`/`report()` harness (temp git repo,
JSON tool-call payload piped to the gate, exit-code classified
allow/deny/other):
- allow: complete 7-section proposal, survey.md present (both
  `proposal-shape` and `survey-order` allow).
- deny: proposal missing `## Rationale` (`proposal-shape` denies).
- deny: proposal complete but survey.md absent and no skip-record
  language (`survey-order` denies).
- allow: proposal complete, survey.md absent, but proposal body states
  the scout-skip condition explicitly (`survey-order` allows).
- allow: complete record, no deviation language, no
  `## Rationale for deviations` section (`record-shape` allows).
- deny: record contains deviation language but no
  `## Rationale for deviations` section (`record-shape` denies).
- deny: record missing `## What did not work` (`record-shape` denies).
- allow: foreign path (e.g. `docs/issue-7/reports/qa.md`) passes through
  untouched, for all three gates.
- allow: each plugin's own kill switch set, otherwise-denying content
  passes through, tested independently per plugin.

**(g) Agents/checklist.** No new adversarial-hunt-style agent — the one
repeated procedure this norm set implies (survey-before-proposal
ordering) is `survey-order`'s own mechanical check, not a periodic
review; adding an agent on top would duplicate what the gate already
does deterministically (scout-brief's own "skip: separate
state-tracking" reasoning applies equally here). No checklist file is
added either: each plugin's own required-elements list is named once in
its gate script's header comment (matching the pricing exemplar's
convention), not duplicated into a separate `docs/handbooks/` file that
could drift from the gates' actual logic.

## Out of scope

- Any change to core-canon files (`role-directive.sh`, `stub-check.sh`,
  the three retired local gates, `warrant-hunter.md`) — referenced only,
  untouched.
- Fixing `tests/run-gate-tests.sh`'s stale references to the three
  deleted hooks — a real gap (survey finding 5) but not this issue's
  write set; noted for a future issue.
- Renaming the `coding` plugin directory to `implementation` — the
  role/plugin name mismatch predates this issue and is not part of this
  ask.
- Any change to `coding-progress-gate.sh`, `hunt-guard.sh`,
  `hunt-state.sh`, `state.sh` — untouched, not this norm's concern.
- Merging `proposal-shape`/`record-shape`/`survey-order` back into
  `coding` or into each other — the FEEDBACK's plugin-set requirement is
  the point of this revision, not a transitional step toward
  consolidation.

## How you'll know it worked

- This proposal PR (existing branch/PR, not a new one) is open against
  `main`, referencing `#61` (plain, not Closes/Fixes), with survey +
  scout-brief + this revised file committed under `docs/issue-61/`, and
  the "Plugin inventory"/"Composition" sections present and naming all
  three plugins, their owned methodologies, components, and composition
  into the phase-1/phase-2 norms (the approver's explicit proposal
  requirement).
- On Approve, phase 2 lands (d)-(f) items (a)-(f) above: three new
  top-level plugin directories (`proposal-shape`, `record-shape`,
  `survey-order`), each with its own `plugin.json`, `hooks/`, and
  `hooks/tests/`; `.claude-plugin/marketplace.json` listing all three;
  `coding/hooks/directive.sh` with only the corrected `HAND_OFF` path;
  `tests/methodology-plugins-tests.sh` passing every case in (f) as a
  real subprocess run (`bash -n` syntax check + the harness's own
  allow/deny classification per plugin), demonstrating the phase-2
  record for this same issue satisfies `record-shape`'s own gate
  (dogfooding, same as issue-52's close-out).

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
