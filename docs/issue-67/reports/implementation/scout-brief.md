---
subject: issue-67
role: implementation
---

# Scout brief — issue-67 (gate A+ final closeout)

Mode: batched-sequential, single session, no subagent fan-out — the
target field is this repo's own prior remediation pass (issue-64) plus
the core repo's landed precondition (issue #75), both already on disk
locally. Stages used: 2 (read issue-64's landed record + diff, read core
#75's landed commit). Within budget.

## Prior art: issue-64's gate A+ remediation (landed `e5f8e50`, PR #66)

Source: `docs/issue-64/reports/implementation.md`,
`docs/issue-64/proposals/2026-08-01-gate-a-plus-remediation.md`, `git show
e5f8e50 --stat`.

**Pattern already used, adopt again**:
- **Reference-not-copy for shared logic.** issue-64's core rationale
  ("Why reference `gate-lib.sh` rather than hand-fix each defect
  locally", proposal lines 71-82) was: a fix that is a general-purpose
  library function belongs in core and is sourced, never re-derived per
  gate. This applies directly to defect (a) here: if a real sha-existence
  check (`git cat-file -e`/`git rev-parse --verify`) is the fix, it
  should be added as a `gate-lib.py` helper if core already exposes one,
  or, if core has no such helper yet, implemented locally as a narrowly
  scoped addition to `coding-progress-gate.sh` only — not invented as a
  second general "verify a sha" utility duplicating what core might add
  later. Survey did not find an existing sha-verification helper in
  core's `gate-lib.py` (`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`),
  so the local-fix path is the only one available right now.
- **Per-plugin scoping, not a cross-cutting rewrite.** issue-64's
  Constraints (lines 54-60) kept each gate's fix inside its own plugin
  directory. Issue-67's four residual defects are all inside `coding/`
  (state.sh, coding-progress-gate.sh, hunt-guard.sh/hunt-state.sh/
  hooks.json) plus README.md — no other plugin (`proposal-shape/`,
  `record-shape/`, `survey-order/`) is implicated by the survey. Same
  scoping discipline applies: this closeout stays inside `coding/` +
  `README.md`, not a repo-wide sweep.
- **Named-but-deferred defects get closed explicitly, not silently
  dropped.** issue-64's proposal explicitly named the `coding/` →
  `implementation/` directory rename as "Out of scope... named as a
  follow-up" (lines 209-212) rather than pretending it wasn't a real gap.
  Issue-67's own defects — the two vocabulary/path items (c, d) and the
  hunt-reset wiring gap (b) — are exactly the kind of narrowly-scoped,
  previously-deferred residue this pattern exists to eventually close;
  this proposal follows the same discipline by closing them explicitly
  rather than opening yet another deferred-follow-up note.
- **Evidence step, not a claim.** issue-64's record cites a concrete
  `compliance-check.sh` exit-0 run and per-suite pass counts (record
  lines 112-129) rather than asserting "tests pass". The same standard
  applies to this closeout's own delivery record when phase 2 executes.

## Prior art: core issue #75 (landed `52bdc15`, precondition for this issue)

Source: `git log --oneline` in
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core` — `52bdc15
deliver(implementation): gate-lib source guard + gate_bash_write_targets
py parity (issue-75) (#77)`, preceded by `24eb5ed propose(implementation):
gate-lib source guard + gate_bash_write_targets py parity (issue-75)
(#76)`.

**What it establishes for matcher/coverage alignment and missing-core
guarding**: core #75's own title names "gate-lib source guard mandatory +
compliance-check detection + missing-core mandatory test +
gate_bash_write_targets.py port" — i.e. core's own test harness now
carries a mandatory missing-core case and a `compliance-check.sh`
detector pass for it. That precondition is landed; this repo's job is not
to re-derive a missing-core test (core already owns that mandatory case
in its own `run-gate-lib-tests.sh`/`compliance-check.sh`), but to make
sure this repo's own full-suite delivery record *runs*
`compliance-check.sh` against `coding/hooks/` and records the pass, per
issue-67 requirement 3 ("missing-core 케이스 포함 전 스위트 배송 상태
green + compliance-check 통과 record 기록"). Survey (§1) found no
missing-core test duplicated inside this repo — correct, per the
reference-not-copy convention; the gap is only that this repo's own
*record* of running the compliance detector needs to happen again at
ship time for this issue, same as issue-64 did.

## Adopt

- Reference-not-copy discipline for any core-owned check (missing-core,
  compliance detection) — do not duplicate core's own mandatory test
  inside this repo; run `compliance-check.sh` and record the result.
- Per-plugin write-set scoping (this closeout touches `coding/` +
  `README.md` only).
- Explicit named-and-closed treatment of the four residual defects,
  matching issue-64's own "name the gap, close it, don't silently drop
  it" pattern.

## Skip

- Do not invent a second sha-verification helper library — this is a
  one-file, in-place fix to `coding-progress-gate.sh`'s existing
  `entry_resolves()`/`SHA_RE` logic (see proposal Rationale for the
  rejected alternative of leaving the regex as-is with a tighter format).
- Do not attempt to independently verify on-the-record #182 from inside
  this repo — it is out-of-repo, and this repo has no mechanism to check
  it (survey §1); the proposal treats it as an unverified external
  precondition, not something this issue's write set can confirm.

## Gap line

Issue-64 closed the *substring→adjacency* structural upgrade to §15 and
the *kill-switch wiring* class of defects across all five gates entirely.
Issue-67's re-audit finds a narrower, second-order layer issue-64's own
write set did not reach: (1) §15's adjacency check still trusts an
unverified sha-*shaped* token rather than a real sha (issue-64 fixed
*where* the token must sit, not *whether* it is real); (2) the
`hunt-state.sh reset` subcommand issue-64 did not touch at all (its diff
for that file was kill-switch-only, `+3 -1`); (3)-(4) two stale-path
artifacts (`state.sh`'s dead `coding.md` check, `coding-progress-
gate.sh`'s comment) that issue-64's own record shows it fixed the *code*
for (§(a)) but not the adjacent comment or the sibling file. None of
these four were claimed fixed by issue-64 — they are genuinely residual,
not regressions.
