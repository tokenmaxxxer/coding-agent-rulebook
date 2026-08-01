---
subject: issue-67
role: implementation
---

# Proposal — gate A+ final closeout (phase 1 design)

Phase 1 only. No execution in this PR. Survey:
`docs/issue-67/reports/implementation/survey.md`. Scout brief:
`docs/issue-67/reports/implementation/scout-brief.md`.

files: `coding/hooks/coding-progress-gate.sh` (real sha-existence check
added to `entry_resolves()`/`SHA_RE` path; top-of-file comment path
correction), `coding/hooks/state.sh` (drop the dead `coding.md` record
check, replace with the current `implementation.md` path or remove the
check if it is judged not worth keeping), `coding/hooks/hunt-guard.sh`
(matcher/coverage alignment — resolve the `Agent|Task` vs.
`Agent|Task|Workflow` mismatch), `coding/hooks/hooks.json` (add
`hunt-state.sh reset` to the `SessionStart` block; matcher change if the
proposal's chosen alignment direction adds `Workflow`),
`coding/hooks/tests/coding-progress-gate-tests.sh` (new mandatory case:
fabricated-but-correctly-shaped sha denies; hunt-reset regression
coverage lives in a hunt-guard/hunt-state test file if one needs to be
added), `README.md` (remove the `docs/handbooks/canon-scripts.md` ghost
reference).

## Request

Issue #67 is a second 2026-08-01 re-audit (grade B) of the same gates
issue-64 (#64/#66) already remediated once. It finds four residual
defects issue-64's write set did not reach: (a) `coding-progress-
gate.sh`'s §15 check still accepts any correctly-shaped 7-to-40-hex token
as a "sha" without confirming it names a real commit; (b) `hunt-
state.sh`'s `reset` subcommand (drop lock + zero the dispatch count) is
implemented but never invoked from `hooks.json`'s `SessionStart` block,
so `WARRANT_HUNT_MAX` behaves as a per-repository lifetime cap rather
than a per-session cap; (c) `state.sh` still checks for a record at the
retired `docs/<issue>/reports/coding.md` path, a permanently-false dead
check; (d) `coding-progress-gate.sh`'s own top-of-file comment still
names that same retired `coding.md` path even though the code beneath it
was already corrected to `implementation.md` in issue-64. The issue also
asks for hooks.json-matcher/code-coverage alignment (every branch a gate
script checks in code must be reachable via the matcher actually
registered in production), a green full-suite delivery record including
a `compliance-check.sh` pass, and confirmation that README/manifest carry
no stale role names or references to files that do not exist.

## Constraints

- Phase 1 only — this PR ends at proposal; no code lands until Approve.
- Stay inside `coding/` + `README.md`; no other plugin
  (`proposal-shape/`, `record-shape/`, `survey-order/`, `blueprint/`,
  `no-mock/`, `no-footgun/`) is implicated by the survey, so none is
  touched (matches issue-64's own per-plugin scoping discipline).
- Any sha-existence check added to `coding-progress-gate.sh` must stay a
  local, narrowly-scoped addition — core's `gate-lib.py` was checked
  (survey §1, scout-brief) and has no existing sha-verification helper to
  reference instead; inventing a new cross-repo library function for a
  single call site would be scope creep this issue does not ask for.
- The `hunt-state.sh reset` fix wires an *already-implemented*
  subcommand into `hooks.json` — no change to `hunt-state.sh`'s own
  release/reset logic, matching issue-64's precedent of accepting
  `hunt-state.sh`'s existing design and only fixing the missing wiring
  (issue-64 record §(c) did exactly this for `release`; this proposal
  does the analogous thing for `reset`).
- On-the-record #182 (`CLAUDE_PLUGIN_ROOT_CORE` injection in `spawn.py`)
  is an external, unverifiable-from-this-repo precondition (survey §1);
  this proposal does not attempt to confirm or touch it.
- Every fix in this closeout must be independently testable and covered
  by a new or updated test case before phase 2 is considered done — no
  "fixed but unverified" items, per issue #67's own "full suite delivery
  status green" requirement.

## Rationale

**Why fix the sha check locally instead of deferring to a future core
library helper**: core's `gate-lib.py` (checked directly in the
referenced core checkout) has no existing "verify this token names a real
git object" helper to reference — the reference-not-copy discipline
issue-64 established only applies to logic core *already* owns. Waiting
for core to add such a helper before fixing a currently-gameable check in
this repo's own blocking gate would leave defect (a) live indefinitely on
someone else's roadmap. Rejected alternative: **tighten the regex
further** (e.g. require exactly 7 or exactly 40 hex characters, or
require it prefixed with `sha `) instead of adding an actual `git
cat-file -e <sha>`/`git rev-parse --verify <sha>^{commit}` existence
check. A tighter regex narrows the false-positive surface but does not
close the underlying gap the audit names — any adversarial record author
can still fabricate a correctly-shaped token without ever running `git
commit`. An actual existence check against the target repo is the only
fix that makes the field mean what it claims to mean (survey §2's own
test evidence — `GOOD_RESOLVED`'s `sha abc1234` is fabricated and never
committed, yet passes today).

**Why wire `hunt-state.sh reset` into `SessionStart` rather than redesign
the cap to reset on some other signal (e.g. time-based, per-branch)**:
`hunt-state.sh`'s own header comment (quoted in survey §3) already names
this exact bug and already implements the fix as a `reset` subcommand —
the code has existed since before issue-64 landed and was simply never
plugged into `hooks.json`'s `SessionStart` block (issue-64's diff for
`hunt-state.sh` was kill-switch-migration only). Rejected alternative:
**redesign the cap as a rolling time window** (e.g. "3 dispatches per 24
hours") instead of wiring the existing session-boundary `reset`. A
time-based redesign invents a new mechanism, a new failure mode, and a
new thing to test, to solve a problem the existing `reset` subcommand
already solves correctly — wiring what is already built and already
named "SessionStart" in its own docstring is the narrower, lower-risk
fix, and matches the "wire the already-designed hook, don't invent a
second mechanism" precedent issue-64 itself set for the `release` half of
the same file (proposal rationale, `docs/issue-64/proposals/
2026-08-01-gate-a-plus-remediation.md:107-119`).

**Why fix `state.sh`'s dead `coding.md` check to `implementation.md`
rather than delete the check entirely**: considered deleting the
`[ -f "$rec" ]` block outright, since it is presentation-only
(`SessionStart`, informational, never blocks) and one could argue a
broken informational nicety is lower priority than removing it. Rejected
in favor of repointing it to the correct path: the check's *intent* —
telling a resuming session "your own record already exists, read it
before continuing" — is still useful and is exactly the kind of context
`state.sh`'s own header comment says the file exists to rebuild ("the v3
analogue of warrant's proposal-frontmatter scan... Informing only").
Deleting it would silently drop a still-wanted feature instead of fixing
its one-line path bug; repointing it to `implementation.md` (the same
correction issue-64 already made to `coding-progress-gate.sh`'s code)
restores the intended behavior with a smaller diff than removal +
justification would require.

**Why resolve the hooks.json matcher/`Workflow` mismatch by aligning the
matcher to the code, rather than trimming the code's tuple down to match
the matcher**: two directions close this gap — add `Workflow` to
`hooks.json`'s `"Agent|Task"` matcher, or delete the `"Workflow"` branch
from `hunt-guard.sh`'s Python tuple. This proposal defers the final
direction to phase 2 (survey §6 notes it as a proposal-stage decision),
but records here that the default lean is toward *aligning the matcher
up* rather than *trimming the code down*: `hunt-guard.sh`'s own comment
block (lines 19-29) already reasons carefully about which agent-dispatch
tool names can reach this gate and why nesting is foreclosed upstream —
that reasoning treats `Workflow` as a first-class dispatch surface
alongside `Agent`/`Task`, not a leftover. Removing it from the code would
require re-deriving that same reasoning to confirm `Workflow` truly can
never carry a hunter dispatch, which the survey did not establish either
way. Phase 2 will confirm against whatever `Workflow` tool semantics this
Claude Code version actually exposes before finalizing which side moves.

## What will be done

**(a) Real sha-existence check in `coding-progress-gate.sh`.** Replace or
supplement the format-only `SHA_RE` match in `entry_resolves()`
(`coding/hooks/coding-progress-gate.sh:151,189-204`) with an actual
existence check against the target repo — e.g. `git cat-file -e
<token>^{commit}` (or `git rev-parse --verify --quiet
<token>^{commit}`) run against `root` (the already-resolved project
root), only for tokens that already pass the current shape/adjacency
test. A shape-matched-but-nonexistent token no longer resolves a
finding. New mandatory test case:
`resolved-adjacent-fake-sha-denies` — same fixture shape as the existing
`resolved-adjacent-allows` case, but with a fabricated hex string that
matches no real commit in the test repo, asserting `deny`.

**(b) `hunt-state.sh reset` wiring (`coding/hooks/hooks.json`).** Add a
`hunt-state.sh reset` command entry to the existing `SessionStart` block
(alongside `directive.sh`/`state.sh`), matching the subcommand
`hunt-state.sh` already implements and documents but `hooks.json` never
invokes. No change to `hunt-state.sh`'s own reset logic.

**(c) `state.sh` dead-code fix.** Repoint
`coding/hooks/state.sh:27-28`'s `rec=` path from
`docs/${issue}/reports/coding.md` to `docs/${issue}/reports/
implementation.md`, matching the path convention already in force
everywhere else in this repo (README.md, `coding-progress-gate.sh`'s
code, record-shape-gate.sh's target).

**(d) `coding-progress-gate.sh` comment fix.** Correct the top-of-file
comment (`coding/hooks/coding-progress-gate.sh:13-17`) to say
`docs/issue-<n>/reports/implementation.md`, matching the code three lines
below it.

**(e) hooks.json matcher / code-coverage alignment for `hunt-guard.sh`.**
Resolve the `"Agent|Task"` matcher vs. `("Agent", "Task", "Workflow")`
code tuple mismatch (`coding/hooks/hooks.json:18-23` vs.
`coding/hooks/hunt-guard.sh:93`) in one direction, confirmed during phase
2 against actual `Workflow`-tool dispatch semantics (see Rationale for
the default lean). Whichever direction is chosen, add a test case that
exercises the now-aligned branch end-to-end (payload with `tool_name:
Workflow`, `agent_type: warrant-hunter`) so the branch is provably
reachable, not merely present in source.

**(f) README ghost-reference cleanup.** Remove or correct the
`docs/handbooks/canon-scripts.md` reference at `README.md:83` — either
point it at the file that actually documents the reference-not-copy rule
today (`docs/handbooks/gate-tests.md`, if that is where the content now
lives — confirmed during phase 2), or drop the specific filename from the
sentence if no single file documents the rule.

**(g) Full-suite delivery record.** Re-run the complete suite listed in
`README.md`'s "Run the checks" section (`tests/parse-check.sh`,
`tests/run-gate-tests.sh`, `tests/deny-only-check.sh`,
`tests/methodology-plugins-tests.sh`,
`coding/hooks/tests/coding-progress-gate-tests.sh`, the three
proposal-shape/record-shape/survey-order suites) plus
`compliance-check.sh` against `coding/hooks/` (referencing
`CLAUDE_PLUGIN_ROOT_CORE`), and record the pass/fail counts in the
phase-2 implementation record — matching the evidence standard issue-64's
own record set (concrete counts, not a bare "tests pass" claim).

## Out of scope

- **Phase 2 execution is explicitly out of scope for this document.**
  This proposal is a phase-1 design only; no code, test, or README change
  described above is made by this PR. Everything under "What will be
  done" is deferred to a subsequent phase-2 PR contingent on an Approve.
- Verifying or acting on on-the-record #182 — external, unverifiable from
  this repo (survey §1); this issue's write set has no path to it.
- Inventing a new cross-repo sha-verification library function in core's
  `gate-lib.py` — the fix here is local to `coding-progress-gate.sh` (see
  Rationale).
- Redesigning `hunt-state.sh`'s cap semantics (e.g. a rolling time
  window) — wiring the already-implemented `reset` subcommand is the full
  fix (see Rationale).
- Renaming the `coding/` plugin directory to `implementation/` — already
  named as an explicit, larger-blast-radius follow-up by issue-64's own
  proposal; not reopened here, and the survey found no *new* stale role
  name beyond that already-tracked, deliberate doubling.
- Any change to `core/hooks/**` itself — referenced only, never edited by
  a downstream rulebook.
- Touching `proposal-shape/`, `record-shape/`, `survey-order/`,
  `blueprint/`, `no-mock/`, or `no-footgun/` — the survey found no
  residual defect in any of them; issue-67's findings are all inside
  `coding/` + `README.md`.

## How you'll know it worked

- This proposal PR is open against `main`, referencing `#67` (plain, not
  Closes/Fixes), with survey + scout-brief + this proposal committed
  under `docs/issue-67/`.
- On Approve, phase 2 lands (a)-(g): a fabricated-but-correctly-shaped
  sha token in a `resolved_findings` entry is denied by
  `coding-progress-gate.sh` (new mandatory test case, confirmed failing
  before the fix and passing after); a fourth hunter dispatch succeeds in
  a fresh session after three were used in a prior session (functional
  test exercising `hunt-state.sh reset` via a simulated `SessionStart`);
  `state.sh`'s own-record check fires against a real
  `docs/<issue>/reports/implementation.md` fixture, not a `coding.md`
  one; `coding-progress-gate.sh`'s top-of-file comment and its code agree
  on the record path; the `hunt-guard.sh` `Workflow` branch is reachable
  end-to-end via `hooks.json`'s matcher (or is removed from the code, if
  phase 2's confirmation goes that direction) and is covered by a test
  either way; `README.md` names only files that exist on disk; the full
  suite (root + all four plugins' `hooks/tests/`) is green and
  `compliance-check.sh` exits 0 against `coding/hooks/`, both recorded
  with concrete pass counts in the phase-2 implementation record.
