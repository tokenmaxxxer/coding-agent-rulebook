# Coding record — issue #49

loop_state: landed

## What was done

Phase 1 (PR #50) already carried the actual two-line wording change to
`coding/hooks/directive.sh`'s RECORD REQUIREMENT section — the
enforcement clause and its measured-evidence citation were raised to the
strong form used by `feasibility`/`verify`/`reflect`/`ux-design`. PR #50
was approved and merged to main. This phase-2 session verified the
merged wording against the reference byte-for-byte and writes the record
phase 1 could not yet write (record is phase-2 output per contract
v3 s19).

## Why

Issue #49: coding's RECORD REQUIREMENT enforcement clause read weaker
("means the obligation is unmet" / "left no record committed") than the
equivalent clause already standardized across the other rulebooks
("means the record was never written" / "left the record empty"). The
weaker phrasing under-states that a missing record is treated as never
having been written at all, not merely an open obligation.

## Upstream basis

- Issue #49 (this issue), naming the exact reference:
  `ux-design-rulebook`'s `ux-design/hooks/directive.sh` RECORD FORMAT
  section, post issue-12 state.
- `docs/issue-49/reports/coding/survey.md` (phase-1 current-state
  survey) — identified the two differing clauses and confirmed no other
  clause in the section differs.
- `docs/issue-49/proposals/2026-07-30-record-discipline-strong-form.md`
  (phase-1 proposal) — froze the exact target wording.
- PR #50 (merged 2026-07-30T03:48:20Z), commit 88438ce onward — carried
  the two-line diff to `coding/hooks/directive.sh`.

## Verification

Diffed `coding/hooks/directive.sh` on `main` (post-merge) against the
proposal's target wording and against `ux-design/hooks/directive.sh`'s
RECORD FORMAT section:

- Enforcement clause: "Ending phase 2 without your record committed on
  the branch means the record was never written." — matches.
- Evidence citation: "(Measured: a phase-1-only issue left the record
  empty.)" — matches.
- All other RECORD REQUIREMENT clauses (file path, first-act timing,
  loop_state-update rule) and role-specific record fields — unchanged,
  as scoped.

## closed_checks

- check: byte-for-byte diff of coding's RECORD REQUIREMENT clauses
  against ux-design's RECORD FORMAT reference wording
  code_sha: origin/main HEAD at time of this record (coding/hooks/directive.sh)
  result: match, no residual gap

## What did not work

(none — the wording swap landed cleanly in phase 1 and required no
rework in phase 2)

## Hunt

Stance: skeptic-of-completeness. No warrant-hunter dispatch made in this
phase-2 session: the write set is a two-line wording swap already merged
and byte-diffed against the reference above; no code path, composition
seam, or silent-failure surface was introduced for a hunt to probe.
Nothing found because nothing new was built.

## Open findings

None open. No blocking finding addressed to coding is outstanding for
this issue.

## Out of scope

- Issue #49 itself was left OPEN with no `Closes #49` anywhere on the
  branch (PR #50 correctly referenced it as `#49`, not `Closes #49`,
  per phase-1 convention). This record's PR carries `Closes #49` to
  close it now that phase 2 has verified and recorded delivery.
