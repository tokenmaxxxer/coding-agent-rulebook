#!/usr/bin/env bash
# SessionStart: coding's role directive — how this role fills each stage of
# the core lifecycle. core's directive carries the protocol; this carries
# the role. Kill switch: export CODING_CYCLE_OFF=1
trap 'rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then exit 2; fi' EXIT
set -uo pipefail

case "${CODING_CYCLE_OFF:-}" in ""|0|false|no|off) ;; *) trap - EXIT; exit 0 ;; esac
[ "${CLAUDE_ROLE:-}" = "coding" ] || { trap - EXIT; exit 0; }

cat <<'DIRECTIVE'
[coding] Role directive (on top of core's protocol):

YOU DECIDE: how the approved scope becomes working code — and nothing
beyond it. Generation is your job; verification belongs to qa, review,
verify, and the human's PR review. No self-review loops, no re-reading
finished units: deliver and let the verification layer verify.

RESEARCH (phase 1, scout protocol): the field for a build is the
codebase and its ecosystem — the affected modules, the libraries the
project already uses, the decisions already recorded under
docs/decisions/, and (for product-shaped surfaces) the category's
best-in-class per scout.

CURRENT-STATE SURVEY (phase 1): what will change — the write set,
projected honestly: implementation files, the test files that cover
them, .env.example when a new variable appears, the dependency manifest
when a dependency appears, migrations when the schema moves. A new dep
or env var is a DECISION and belongs in the proposal, not a mid-build
surprise. Freeze shared contracts (schema, interface, naming — blueprint
skill) before any fan-out.

PROPOSAL (phase 1): the build proposal — files: (the frozen write set),
## Request (paraphrased intent, secrets stripped), ## Constraints,
## What will be done, ## Out of scope, and how you'll know it worked.

ISSUE REFERENCE, phase-dependent: the phase-1 proposal PR references its
issue as plain #n in the body — never Closes/Fixes/Resolves #n. Merging
a phase-1 PR must not auto-close the issue; only the phase-2 delivery PR
carries Closes #n. If a phase-2 session finds its issue already closed
with no delivery landed, that is an anomaly to report, not a completed
task — do not silently exit.

EXECUTION JUDGMENT (phase 2, quality bar):
- SCOPE-EXCEEDED RULE: when the work needs a file outside the frozen
  write set, finish what the proposal covers, STOP, and report — never
  widen mid-build, never pause to ask mid-build. The remainder is the
  next proposal.
- HONEST CLAIMS (no-mock): say "runs"/"works" only about what you
  actually ran. Confirming your own claim IS part of generation: build
  it, run it, run the tests you wrote, once — and fix what breaks before
  the PR. That single confirmation run is not a verification pass; the
  re-reading and review loops freelunch bans are.  Production-runnable
  by default; a placeholder is labeled MOCK: at the site and listed in
  the final message with what would make it real.
- ## What did not work: append to your record AT THE MOMENT of failure —
  when you wrote something then undid/replaced it, or something you
  expected to hold did not (one line: expected vs actual). Workers'
  internal retries excluded.
- Document placement (doctrine ladder): env var/config key/new dep/
  migration/setup step -> the component's handbook, same turn; a
  library-or-format choice over a named alternative, or a changed public
  signature/wire format -> docs/issue-<n>/decisions/; benchmark or
  investigation numbers -> docs/issue-<n>/reports/. Session recaps
  belong in the reply, never in docs/.
- A blocking finding addressed to you (verify's record) blocks further
  build commits until your record carries the resolved_findings entry
  and the finder re-clears — the coding-progress gate enforces it.
- Hunt cadence: dispatch the warrant-hunter at end of phase 1 and before
  phase-2 completion; stances rotate — never chosen; record a section
  even when nothing is found.
- HUNT RESULTS ARE VERIFY'S INPUT, not your certificate: write each
  concluded probe into your record as a closed_checks: entry (check name
  + code_sha equal to the record's code_under_review:). verify may
  cite-and-skip what you closed (contract s16) or re-derive it — the
  authority stays with verify, and a blocking finding is never blunted
  by your own closed checks. A hunt that only lives in prose saves
  verify nothing.

RECORD REQUIREMENT (do not skip this): your record lives at
docs/issue-<n>/reports/coding.md and only there — research files,
surveys, and proposals are not the record. Write it as your FIRST act of
phase 2, and update its loop_state at every transition. Ending phase 2
without your record committed on the branch means the record was never
written. (Measured: a phase-1-only issue left the record empty.)

DIRECTIVE

trap - EXIT
exit 0
