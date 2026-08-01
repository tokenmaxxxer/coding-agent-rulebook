---
subject: issue-64
role: implementation
---

# Scout brief — issue-64 (gate A+ remediation)

Mode: batched-sequential (single session, `Read`/`Bash` in sequence over
cached local copies — no parallel subagent/tool fan-out was run; the
target field here is this codebase family's own prior art, already
materialized as files on disk under `/tmp/claude-1000/core-ref/` and
`/tmp/claude-1000/core-check/`, so a web sweep was not the applicable
angle). Stages used: 2 (read core canon + compliance detector, read
issue-61's own prior design for this repo). Within budget (5 stages /
3min).

## Exemplar: core issue-72's gate-house standard

`core/hooks/lib/gate-lib.sh`/`gate-lib.py` + `core/hooks/tests/
run-gate-lib-tests.sh` + `core/hooks/tests/compliance-check.sh` — the
canon fix for exactly issue-64's defect classes (kill-switch fail-open,
replace_all-ignoring reconstruction), already landed and referenced-not-
copied by every downstream rulebook per `docs/handbooks/canon-scripts.md`.

**Must-bes** (what a compliant gate must do, per the exemplar):
- Fail-closed trap installed as the literal first statement
  (`gate_trap_fail_closed`), before `set -uo pipefail`.
- Kill switch narrows the *disabling* set to recognized on-spellings only
  (`gate_kill_switch_active`); every other value, including garbage,
  stays active.
- Any Edit/MultiEdit reconstruction honors `replace_all` per-edit
  (`gate_reconstruct_write`), never a raw `.replace(old, new[, 1])`.
- Path matching normalizes absolute/relative/`./`-prefixed forms to a
  root-relative tail (`gate_normalize_path`) before pattern-matching scope.
- Deny messages go to stderr with a named reason (`gate_deny`).
[Sources: `/tmp/claude-1000/core-ref/gate-lib.sh`,
`/tmp/claude-1000/core-ref/gate-house-standard.md`]

**Performance axes competitors compete on** (per the standard's own test
harness, `run-gate-lib-tests.sh`):
1. Coverage of the six mandatory case groups (replace_all-true multi-
   occurrence, MultiEdit mixed replace_all, malformed JSON, kill-switch
   unrecognized-value-stays-active, absolute+`./`-prefixed path parity,
   Bash-tool write reaching a Write-tool target) — a suite that skips any
   one of the six fails the harness itself, not just a case.
2. A compliance detector runnable non-interactively
   (`compliance-check.sh`) that flags a hand-rolled kill switch or
   hand-rolled reconstruction by grep signature alone, so drift is
   catchable without re-reading every gate by hand.
[Source: `/tmp/claude-1000/core-check/core/hooks/tests/
compliance-check.sh`]

**Adopt**: source `gate-lib.sh`/load `gate-lib.py` in every gate this
issue touches, per the usage lines in `gate-lib.sh`'s own header comment;
run `compliance-check.sh` against `coding/hooks/` (and the three
proposal-shape/record-shape/survey-order gates) as the proposal's own
evidence step, per `gate-house-standard.md`'s migration checklist step 1.

**Skip**: do not invent a second compliance detector or a second six-case
harness — `compliance-check.sh` and `run-gate-lib-tests.sh` already exist
as canon and are referenced, not re-derived (canon-scripts.md's
reference-not-copy rule applies to the detector/harness themselves, not
just `gate-lib.sh`).

## Prior art within this same repo: issue-61's plugin-set design

`docs/issue-61/proposals/2026-07-31-methodology-gate-design.md` (landed,
`fb24296`) is the most recent precedent for *how this repo's own approver
wants a gate-design proposal shaped*: one independent, freelunch-scale
plugin per methodology (own `plugin.json`/`hooks/`/`hooks/tests/`,
marketplace-registered), not one gate deepened in place. Its "Out of
scope" section explicitly named two of issue-64's defects as deferred
gaps for a later issue: the `tests/run-gate-tests.sh` stale-reference
exit-127s (survey §3), and the `coding`/`implementation` naming mismatch
(survey §5).

**Adopt**: match the same plugin-set granularity precedent already
validated by this repo's own approver — this proposal is a remediation
of existing gates rather than new-methodology plugins, so it does not
need new plugins, but any structural fix should stay scoped per-plugin
(fix `coding-progress-gate.sh`'s issues in `coding/`, fix
`proposal-shape-gate.sh`'s in `proposal-shape/`, etc.) rather than a
cross-cutting rewrite, matching how issue-61 kept each plugin
independently touchable.

**Gap line**: this repo currently meets none of the exemplar's must-bes —
every gate hand-rolls its own kill-switch case statement and its own
path/reconstruct logic; none source `gate-lib.sh`. The gap is total, not
partial — issue-64's remediation is a full first migration, not a
top-up.

## Segment fit

This repo (`implementation-rulebook`) is one of the 43 downstream
rulebooks `gate-house-standard.md`'s migration checklist explicitly
targets — the exemplar was built for exactly this migration, not an
adjacent product being cloned for inspiration. The bar (six mandatory
test cases, compliance-check clean) is the standard's own stated
acceptance criterion for a rulebook's A+ remediation issue, not an
external aspiration.
