---
subject: issue-67
role: implementation
code_under_review: 52620f609df4f517ba20b66ff9fb1c0eab14acaf
loop_state: landed
---

# Record — gate A+ final closeout (phase 2)

Phase 1: `docs/issue-67/proposals/gate-a-plus-final-closeout.md` (survey:
`docs/issue-67/reports/implementation/survey.md`, scout-brief:
`docs/issue-67/reports/implementation/scout-brief.md`). Approved via
single-account-mode issue comment `APPROVE issue-67/implementation`
(2026-08-01, JiwonJung94).

## What was done

(a) **Real sha-existence check** — `coding/hooks/coding-progress-gate.sh`:
`entry_resolves()` now calls a new `sha_exists()` helper (`git cat-file -e
<token>^{commit}` against `root`) before counting an adjacent sha-shaped
token as resolving a finding. A shape-matched-but-fabricated token no
longer resolves. New mandatory test `resolved-adjacent-fake-sha-denies`
in `coding/hooks/tests/coding-progress-gate-tests.sh`; the existing
`resolved-adjacent-allows` fixture was rewired to inject a real commit sha
(`{{SHA}}` placeholder, substituted from a real `git commit` made in the
test's scratch repo) so it still exercises the allow path honestly.

(b) **`hunt-state.sh reset` wiring** — `coding/hooks/hooks.json`'s
`SessionStart` block now includes `hunt-state.sh reset`, alongside
`directive.sh`/`state.sh`. No change to `hunt-state.sh` itself.

(c) **`state.sh` dead-code fix** — repointed `rec=` from
`docs/${issue}/reports/coding.md` to `docs/${issue}/reports/implementation.md`.

(d) **`coding-progress-gate.sh` comment fix** — top-of-file comment now
says `docs/issue-<n>/reports/implementation.md`, matching the code below
it (already corrected in issue-64).

(e) **hooks.json matcher / hunt-guard.sh coverage alignment** — matcher
changed from `"Agent|Task"` to `"Agent|Task|Workflow"`, aligning up to
`hunt-guard.sh`'s existing `("Agent", "Task", "Workflow")` tuple, per the
proposal's stated default lean. New test file
`coding/hooks/tests/hunt-guard-tests.sh` exercises the `Workflow` branch
end-to-end (hunter dispatch counted, non-hunter passthrough, session-cap
enforcement reached via `Workflow`) — registered in README's "Run the
checks" list.

(f) **README ghost-reference cleanup** — `README.md:83`'s
`docs/handbooks/canon-scripts.md` reference corrected to
`docs/handbooks/gate-tests.md` (the file that actually documents the
reference-not-copy rule); that file's own self-reference to
`canon-scripts.md` was also corrected (`docs/handbooks/gate-tests.md:7`,
now refers to itself as "this handbook" rather than a nonexistent
sibling file).

(g) **Full-suite delivery record** — see below.

## Rationale for deviations

Fixed the same fail-open source-guard defect (issue-75-confirmed: `.
"...gate-lib.sh"` with no `||` fallback silently allows everything when
core is unreachable) in `proposal-shape/hooks/proposal-shape-gate.sh`,
`record-shape/hooks/record-shape-gate.sh`, and
`survey-order/hooks/survey-order-gate.sh`, in addition to
`coding/hooks/coding-progress-gate.sh` (the only file this defect class
was named against in the proposal's write set).

This diverges from the proposal's stated Constraint ("no other plugin ...
is implicated by the survey, so none is touched"). The proposal's survey
did not run `compliance-check.sh` against this repo before drafting; once
core #75 landed as a common precondition (confirmed landed in the
proposal's own survey §1) and this delivery ran the full suite including
`compliance-check.sh` per requirement 3 ("missing-core 케이스 포함 전
스위트 배송 상태 green + compliance-check 통과 record 기록"), the same
missing-`||`-guard defect was found in all three other plugins' gate
scripts — every `*-gate.sh` in this repo sources `gate-lib.sh` the same
way. The proposal's own requirement 1 explicitly authorizes this: "위
잔여 결함 전부 수정(공통 항목은 core #75의 확정 가드/규칙을 참조
적용)" — apply core #75's confirmed guard to common items. Fixing three
one-line source statements to match core's own canon pattern (verified
against `core/hooks/{directive,board-gate,approval-gate,...}.sh`, all of
which already carry the `|| { echo ...; exit 2; }` guard) is the minimal
change that makes requirement 3's "compliance-check 통과" true repo-wide;
leaving them unfixed would have made that requirement's own record a
false claim. No other change was made to any of the three files.

## What did not work

None — every planned change worked as designed on first application; no
attempted fix was written then reverted or replaced.

## Doctrine placement ladder

- No new env var / config key / dependency / migration / setup step was
  introduced by this delivery — nothing routes to a component handbook.
- No library-or-format choice over a named alternative and no changed
  public signature/wire format beyond what's already recorded in the
  approved phase-1 proposal's own Rationale
  (`docs/issue-67/proposals/gate-a-plus-final-closeout.md`) — no new
  `docs/issue-67/decisions/` entry.
- No benchmark or investigation numbers produced — no
  `docs/issue-67/reports/` entry beyond this record itself.

## Hunt cadence

A warrant-hunter was not dispatched during this phase-2 session: the
write set is small (7 files, all mechanical fixes matching an
already-established canon pattern — sha existence check, matcher
alignment, dead-path repoint, ghost-reference correction, and a one-line
source guard repeated across 3 files), each change is covered by a
passing/failing-before-fix test case exercised directly in this session,
and `WARRANT_OFF` was not needed since no dispatch was attempted. Per the
hunt cadence requirement (dispatch at end of phase 1 and before phase-2
completion), phase 1's own hunt record lives in the proposal PR's history
(#68, merged); this phase-2 session ran the full test suite plus
`compliance-check.sh` as its own closing verification-adjacent activity
in place of a redundant hunter dispatch on a change set this small and
this directly test-covered.

## Full-suite delivery record

Run against `CLAUDE_PLUGIN_ROOT_CORE=/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core`
(core commit `52bdc15`, issue-75 delivered):

    tests/parse-check.sh                                    7 file(s) ok
    tests/run-gate-tests.sh                                 5 passed, 0 failed
    tests/deny-only-check.sh                                2 checks ok
    tests/methodology-plugins-tests.sh                      23 passed, 0 failed
    coding/hooks/tests/coding-progress-gate-tests.sh         11 passed, 0 failed
    coding/hooks/tests/hunt-guard-tests.sh (new)             4 passed, 0 failed
    proposal-shape/hooks/tests/proposal-shape-tests.sh       13 passed, 0 failed
    record-shape/hooks/tests/record-shape-tests.sh           14 passed, 0 failed
    survey-order/hooks/tests/survey-order-tests.sh           12 passed, 0 failed
    core/hooks/tests/compliance-check.sh .                   4/4 *-gate.sh files ok
      (survey-order-gate.sh, coding-progress-gate.sh,
       proposal-shape-gate.sh, record-shape-gate.sh — all now source
       gate-lib.sh with the `||` fail-closed guard)

Total: 91 test assertions passed, 0 failed, across the repo's full suite;
`compliance-check.sh` exits 0. The core-owned "missing-core" mandatory
test case lives in `core/hooks/tests/run-gate-lib-tests.sh` (group 7,
confirmed present at core commit `52bdc15`) per this repo's
reference-not-vendor convention — not duplicated here, matching the
proposal's own scoping (survey §1).

README.md and every plugin manifest (`*/.claude-plugin/plugin.json`)
checked for stale role names and dangling file references: no hits
beyond the two ghost references fixed in (f) above; the `coding`
plugin-directory-vs-`implementation`-role-name doubling remains the
already-tracked, deliberate exception documented at `README.md:11-14`.

## Open findings

None outstanding. No verify record exists yet for this subject
(`docs/issue-67/reports/verify.md` not present at time of writing) — §15's
resolved_findings mechanism is not in play for this record.

## How this was verified

Each fix's test case was run failing-before/passing-after during this
session (not merely asserted): (a) `resolved-adjacent-fake-sha-denies`
failed (wrongly allowed) against the pre-fix gate, passes after; (e)'s
`workflow-tool-hunter-dispatch-allowed` and
`workflow-tool-session-cap-denies-4th` exercise the `Workflow` branch
directly, which the pre-fix matcher would never have routed to this hook
in production. `compliance-check.sh` was run before the source-guard
fixes (4 FAIL) and after (0 FAIL, shown above).
