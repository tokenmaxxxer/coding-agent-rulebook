---
subject: issue-61
role: implementation
---

# Scout brief — methodology-gate exemplars (issue #61)

Non-product deliverable (plugin hook machinery). Scout target per
scout-directive: "the best of comparable systems," read here as the
other rulebooks in this same marketplace family that already built a
document-shape enforcement gate, plus the standing canon constraint on
where such a script may live. Mode: **batched-sequential fallback**, one
session, direct file reads against sibling repo checkouts already
present on disk — no parallel subagent/tool-call dispatch was used.
Reason: this is an internal cross-repo architecture comparison (not a
web-reachable product category), the candidate set is small (one other
rulebook with this exact pattern, one core canon doc), and judge point 1
saturated immediately — the pricing exemplar and the canon constraint
are the whole field; a second round would not change any build decision.
2 stages used (sweep + one deepening read of the exemplar file in full),
well under the 5-stage/3-min budget.

## Must-bes (from the one exemplar that exists)

- **Fail-closed trap-at-top** (`__fc`/`trap __fc EXIT` before any
  `set`/`source`): any abnormal exit maps to 2 (deny), never a silent
  allow. Present in both `coding-progress-gate.sh` (this repo) and
  `pricing/hooks/methodology-gate.sh` independently — convergent, not
  copied.
- **Path-scoped, not global**: the gate resolves the target path against
  a discovered project root and exits 0 immediately for anything outside
  its named write surfaces (`docs/issue-<n>/proposals/*.md`,
  `docs/issue-<n>/reports/<role>.md`). A gate that fires on unrelated
  writes is the one failure mode both this repo's existing gates and the
  pricing exemplar structurally avoid.
- **Resolves the actual post-write text, not just the tool name**: for
  `Write` use `content`; for `Edit`/`MultiEdit`, apply `old_string`→
  `new_string` against currently-read file content and deny (rather than
  guess) when the edit can't be resolved against current content. Grepping
  only `tool_input` without this step would miss edits that remove a
  required section from an already-compliant file.
- **Kill switch env var**, checked first, mirroring every other gate in
  both repos (`CODING_CYCLE_OFF`, `PRICING_METHODOLOGY_GATE_OFF`).

## Performance axes the exemplar competes on

1. **Element specificity** — pricing's gate checks six named elements
   (method-named, family-named-conditionally, inputs-needed,
   gate-check-result, labeled-numbers, residual-list) with per-element
   deny messages, not one blanket "proposal incomplete."
2. **Conditional requirements expressed as code, not prose** — e.g.
   pricing's "family named only when conjoint-family language appears"
   mirrors this issue's own conditional (`## Rationale for deviations`
   required only when a deviation is claimed) — the same
   presence-implies-requirement pattern applies directly.
3. **Fail-closed on the unparseable**, not just the non-compliant —
   empty stdin, non-JSON payload, non-dict `tool_input`, unresolvable
   edit all deny with a distinct message rather than falling through to
   an implicit allow.

## Adopt / skip

- **Adopt**: the exact structural shape above (trap-at-top, path-scope
  gate, content-resolution, per-element deny messages, kill switch) —
  this is what "implementation-rulebook 훅 머신 수준" in the issue text
  is pointing at, and it is already proven in this same marketplace
  family, not a fresh design.
- **Adopt**: state-tracked order enforcement via file presence, not a
  separate state file — checking `docs/issue-<n>/reports/implementation/
  survey.md` exists on disk before allowing a `docs/issue-<n>/
  proposals/*.md` write is the same pattern `coding-progress-gate.sh`
  already uses (reads another record file to gate a write), applied to
  survey-before-proposal instead of finding-before-commit.
- **Skip**: pricing's domain-specific element list (method names,
  conjoint family, PSM/CBC vocabulary) — not transferable; this role's
  required elements are the seven proposal sections and the record's
  frontmatter+two-section shape named in issue-52's adopted norm, not a
  pricing-methodology vocabulary.
- **Skip**: building a wholly separate state-tracking file/schema for
  the survey→proposal order constraint — the exemplar and this repo's
  own existing gate both show file-existence-as-state-signal is
  sufficient; a new JSON/state file would be new surface area with no
  precedent pulling toward it.

## Gap line

Current implementation-rulebook state already meets: fail-closed gate
conventions (via `coding-progress-gate.sh`), the deepened directive text
naming the required sections (via issue-52 phase 2), the canon-reference
discipline (via issue-53). Missing, matched against the exemplar: any
gate at all checking document *content* shape, and any state-tracked
order enforcement of survey-before-proposal.

## Sources

- `pricing-rulebook/pricing/hooks/methodology-gate.sh` (sibling checkout
  at `/home/jwjung/.tokenmaxxxer/work/pricing-rulebook-issue-1-pricing/pricing/hooks/methodology-gate.sh`)
- `tokenmaxxxer-core/docs/handbooks/canon-scripts.md` (sibling checkout
  at `/home/jwjung/.tokenmaxxxer/work/tokenmaxxxer-core-issue-69-implementation/docs/handbooks/canon-scripts.md`)
- This repo's own `coding/hooks/coding-progress-gate.sh` and
  `coding/hooks/directive.sh` (current-state survey, above)
