---
subject: issue-52
role: implementation
---

# Proposal — implementation-domain proposal & deliverable norms

Phase 1 only. No execution in this PR. Survey:
`docs/issue-52/reports/implementation/survey.md`. Scout brief:
`docs/issue-52/reports/implementation/scout-brief.md`.

## (a) Phase-1 proposal norm

**Methodology adopted: ADR's Context → Decision → Consequences skeleton**,
grafted onto this role's existing Request/Constraints/What-will-be-
done/Out-of-scope shape rather than replacing it.

Required sections for every phase-1 proposal, in order:

1. `files:` — the frozen write set (unchanged from current practice).
2. `## Request` — paraphrased intent, secrets stripped (unchanged).
3. `## Constraints` (unchanged).
4. `## Rationale` **(new)** — why this approach, not another: at minimum
   one alternative considered and rejected, and the reason. This is the
   section the survey found missing from current practice and the one
   must-be every scouted angle (RFC, SRS, ADR) converged on independently.
5. `## What will be done` (unchanged).
6. `## Out of scope` (unchanged).
7. `## How you'll know it worked` (unchanged).

One-document-one-decision scoping stays as-is (already this role's
practice — issue-53 and issue-56's proposals each cover one issue's one
decision).

## (b) Phase-2 deliverable norm

**Methodology adopted: explicit, named, recoverable completion
criteria** (the Definition-of-Done literature's structural lesson — not
its specific test/review content, which already belongs to qa/review/
verify under this role's existing scope boundary).

Required components for every phase-2 record
(`docs/issue-<n>/reports/implementation.md`), restated as a named list
rather than left to directive prose alone:

1. `code_under_review:` (sha) and `loop_state:` — unchanged, already
   required by the record-fields convention.
2. `closed_checks:` — hunt-derived probes closed this cycle, each tied
   to the `code_under_review:` sha (unchanged).
3. `## What did not work` — present even when empty, one line per
   instance: expected vs. actual (unchanged).
4. **`## Rationale for deviations` (new)** — required only when phase-2
   execution diverged from the approved phase-1 proposal (e.g. scope-
   exceeded stop triggered, an alternative from the proposal's Rationale
   section was swapped mid-build for a stated reason). Absent when no
   deviation occurred — this is not a mandatory section on every record,
   only a mandatory *response* to a divergence, matching the Rationale
   section's role in phase 1.
5. Doc-placement ladder outcomes (env var/config/dep/migration →
   handbook; library-or-format choice or changed signature/wire format →
   `docs/issue-<n>/decisions/`; benchmark/investigation numbers →
   `docs/issue-<n>/reports/`) — unchanged, now explicitly cross-
   referenced from the record as a completed-items list, not just
   narrated.

## (c) Rationale for these adoptions

- ADR's Context/Decision/Consequences shape is the only pattern scouted
  that (i) independent SRS and RFC conventions reinforce rather than
  contradict, and (ii) is small enough to avoid the one documented
  failure mode in this space: Google's own early backend RFC template
  grew to ~14 required-section pages and was later judged by its own
  authors/reviewers as mostly superfluous. A one-section addition
  (`## Rationale`) keeps this role's proposal shape closer to ADR's
  one-page discipline than to that bloated extreme.
- The DoD literature's own strongest empirical signal is that
  externally-imposed checklists correlate with *worse* team performance
  than team-authored ones — which argues against importing a generic
  agile DoD wholesale. What transfers is the structural point (criteria
  must be explicit and recoverable, not just narrated), applied only to
  the completion criteria this role actually owns (build/record
  discipline), leaving verification-specific criteria (test coverage,
  review sign-off) where they already sit: qa/review/verify's job, per
  this role's existing `YOU_DECIDE` scope statement.
- Both new/restated items are additive to current `directive.sh` text,
  not replacements — every existing bullet in USE_WHEN/PRODUCES survives
  unchanged; this proposal narrows the gap the survey found (missing
  rationale, missing named-not-narrated criteria) without discarding
  anything already working (issue-53's and issue-56's proposals both
  already satisfy items 1-3 and 5-7 of (a) as written).

## (d) Plugin reflection plan (phase 2, on Approve)

1. `coding/hooks/directive.sh` — extend the `USE_WHEN` PROPOSAL paragraph
   with the `## Rationale` section requirement (item (a).4) and the
   `PRODUCES` section with the `## Rationale for deviations` conditional
   requirement (item (b).4). Both stay inside `core_role_directive`'s
   existing `$'...'`-quoted single-physical-line variable convention
   (issue-53's transition plan, not yet executed, will restructure this
   file into `you_decide/use_when/produces/hand_off` args regardless —
   this proposal's text is written to slot into either the current
   six-section file or issue-53's four-arg stub without rework, since it
   only adds sentences to existing USE_WHEN/PRODUCES content).
2. **Gate**: no new blocking gate is proposed. A mechanical section-
   presence check on proposal/record Markdown is out of proportion to a
   single added section and would duplicate the human approver's own
   read; conformance stays directive-text discipline, as it already is
   for every other item in USE_WHEN/PRODUCES today (survey finding:
   no existing gate checks document shape, only process state).
3. **Record-fields**: no new *required* field on every record — item
   (b).4 is conditional (only on divergence), so it is not added to
   `RECORD_FIELDS_TERMINAL_STATES` or any always-required list; it is
   directive guidance the approver/verify can check for when a deviation
   is claimed.
4. Order dependency: per issue #53's own proposal, its core-canon
   transition must land before this repo's `directive.sh` changes if
   both are approved — this proposal's phase-2 write, if issue #53 has
   already landed by then, targets the new stub's `use_when`/`produces`
   arguments instead of the current six-section file; if issue #53 has
   not landed, it targets the current file directly. Either target
   carries the same two sentence-level additions.

## Out of scope

- warrant-hunter / core-canon reference mechanics — untouched, per this
  issue's own constraint (core issue #63 stays the source of truth).
- Any change to `record-fields-gate.sh`/`trailer-gate.sh`/
  `handbook-trigger-gate.sh` — those are issue-53's subject, not this
  issue's.
- Full IEEE 29148 SRS apparatus and generic agile DoD import — scouted
  and explicitly rejected (see scout brief, "Adopt/skip").

## How you'll know it worked

- This proposal PR is open against `main`, referencing `#52` (plain,
  not Closes/Fixes), with survey + scout-brief + this file committed
  under `docs/issue-52/`.
- On Approve, phase 2 lands items (d).1-4 above and the phase-2 record
  at `docs/issue-52/reports/implementation.md` demonstrates its own
  `## Rationale` /completion-criteria sections satisfying the norms this
  proposal just adopted (dogfooding the new norm on its own delivery).
