---
subject: issue-64
role: implementation
---

# Proposal — gate A+ remediation (phase 1 design)

Phase 1 only. No execution in this PR. Survey:
`docs/issue-64/reports/implementation/survey.md`. Scout brief:
`docs/issue-64/reports/implementation/scout-brief.md`.

files: `coding/hooks/coding-progress-gate.sh` (kill-switch migration, §15
semantic upgrade, `CODING_CYCLE_OFF` wiring), `coding/hooks/hunt-guard.sh`
(kill-switch migration), `coding/hooks/hunt-state.sh` (kill-switch
migration), `coding/hooks/state.sh` (kill-switch migration),
`coding/hooks/hooks.json` (add `SubagentStop` entry for
`hunt-state.sh release`), `coding/hooks/directive.sh` (role-vocabulary
note, `CODING_CYCLE_OFF` doc correction), `proposal-shape/hooks/
proposal-shape-gate.sh`, `record-shape/hooks/record-shape-gate.sh`,
`survey-order/hooks/survey-order-gate.sh` (kill-switch migration on all
three), `tests/run-gate-tests.sh` (repair the 6 exit-127 cases against
consolidated `coding-progress-gate.sh` behavior), `tests/*` (new mandatory
Edit/MultiEdit/replace_all/malformed-JSON/kill-switch/absolute-path
cases), `README.md` (reconcile plugin/path inventory with actual tree).

## Request

Issue #64's 2026-08-01 audit graded this repo's gates C and lists five
concrete defects: (1) `coding-progress-gate.sh`'s §15 check is a file-
global substring match any 7-hex token can satisfy; (2) `hunt-guard.sh`'s
lock has no `SubagentStop` release wiring, so it self-deadlocks; (3)
`tests/run-gate-tests.sh` is 5/8 (measured now: 6/8) exit-127 because it
targets two deleted hook files; (4) `CODING_CYCLE_OFF` is documented as a
kill switch but the gate it is supposed to disable never reads it; (5) the
role is called `coding` in the plugin tree but `implementation` everywhere
else. The issue asks for all-axis A+: fail-closed everywhere (trap-at-top,
malformed-JSON deny, unrecognized-kill-switch-value = active), full
Edit/MultiEdit/replace_all reconstruction, deny reasons on stderr, semantic
checks upgraded from substring to section/adjacency/structure, mandatory
test cases for all of the above, a green full suite at ship time, and
README reconciled with the real tree — built by referencing core's
already-landed gate-house standard (`core/hooks/lib/gate-lib.sh` +
`docs/handbooks/gate-house-standard.md`, issue #72), never
re-implementing it.

## Constraints

- Phase 1 only — this PR ends at proposal; no code lands until Approve.
- Reference core's `gate-lib.sh`/`gate-lib.py`, never re-derive an
  equivalent fail-closed trap, kill-switch case statement, or
  Edit/MultiEdit reconstruction in this repo's own gates
  (`docs/handbooks/canon-scripts.md`'s reference-not-copy rule; issue #64
  itself names this precondition — core issue #72 landed first).
- Every gate this issue touches keeps governing only this role's own
  write surfaces; no gate gains authority over another role's output.
- No new plugin is added — this issue remediates the five existing gates
  (`coding`, `proposal-shape`, `record-shape`, `survey-order` — the fourth
  and fifth are `coding-progress-gate.sh` peers already landed by
  issue-61) in place, matching the granularity issue-61's approver already
  validated (one plugin, one concern, independently fixable).
- The mandatory test cases issue #64 point 3 asks for match core's own
  `run-gate-lib-tests.sh` six-case shape exactly, plus this repo's
  existing kill-switch/absolute-path cases — no separate, repo-invented
  test taxonomy.
- `tests/run-gate-tests.sh`'s repair targets the *current* consolidated
  `coding-progress-gate.sh` behavior (record-fields + trailer checks now
  folded into it), not a resurrection of the two deleted files.

## Rationale

**Why reference `gate-lib.sh` rather than hand-fix each defect locally**:
defects 1 (path/semantic scope), and the kill-switch half of defect 4, are
each already-solved, already-tested problems in core's own canon
(`gate_kill_switch_active`, `gate_reconstruct_write`,
`gate_normalize_path`) — issue #64 itself states the precondition
("core issue #72가 랜딩된 뒤 그 라이브러리를 참조해 구현, 자체 재구현
금지"). Re-deriving a second kill-switch case statement or a second
Edit/MultiEdit reconstructor in this repo would recreate exactly the bug
class the audit already found (this repo's five gates today all hand-roll
both, and none has the replace_all bug caught yet only because no
adversarial write has exercised it — the audit graded process gaps, not
yet a confirmed live incident, for that specific one).

**Alternative considered and rejected — hand-patch each gate's existing
case statement to flip the on/off-spelling logic in place, without
sourcing `gate-lib.sh`**: this would fix the *known* kill-switch bug
today but leaves every gate maintaining its own copy of the same fix,
diverging again the next time the on-spelling set changes (exactly how
this repo arrived at five independent, subtly-different case statements
in the first place, per the survey). Rejected in favor of sourcing the
one canonical function, so a future fix to the semantic (e.g. adding a
new on-spelling) lands once in core and propagates on next reference.

**Alternative considered and rejected — leave the §15 check as
substring-but-narrower (e.g. require the sha to be inside a specific
labeled sub-line rather than anywhere in the block)**: narrowing the
substring window reduces the false-positive surface but does not remove
the underlying weakness the audit calls out — a check that still asks
"does this text appear somewhere nearby" rather than "does this named
finding's own resolution field parse to a commit reference" stays
gameable by any 7-hex token placed inside the narrower window. Rejected in
favor of an actual structural parse (see "What will be done" (a)): extract
each finding's own bounded sub-block by heading/marker, then require the
sha token to appear specifically within that finding's own resolution
line, not merely within the enclosing block.

**Alternative considered and rejected — wire `hunt-state.sh release` via a
periodic timeout instead of `SubagentStop`**: a timeout-based release
(e.g. lock considered stale after N minutes) was considered because
`SubagentStop` "does not say WHICH subagent stopped" (survey §2,
`hunt-state.sh`'s own comment) — an unrelated subagent finishing could
drop a live hunter's lock either way. Rejected: `hunt-state.sh`'s own
design comment already accepts this imprecision as the deliberate
trade-off ("release is approximate on purpose"); the missing piece is not
a better release signal, it is that *no* release signal is wired at all
right now — a self-deadlock is strictly worse than an occasionally-early
release. Wiring the already-designed `SubagentStop` hook fixes the actual
defect (never releases) without inventing a second, undesigned mechanism
(timeout state, its own new failure mode) on top.

**Alternative considered and rejected — rename `coding/` to
`implementation/` in this issue**: would fully resolve defect 5, but
issue-61's proposal already weighed and declined exactly this rename as
out of its own scope, and a directory rename here touches every
`hooks.json`/`marketplace.json` reference plus any external tooling
keyed to the `coding` plugin name — a materially larger blast radius than
this issue's other four defects, which are all in-place fixes to
existing files. Rejected in favor of the narrower fix: correct the
directive text and any doc that actively asserts the wrong name (already
partly done in issue-61 for `HAND_OFF`), and note the plugin-directory
rename as a named follow-up rather than silently expanding this issue's
scope.

## What will be done

**(a) §15 semantic upgrade (`coding-progress-gate.sh`).** Replace the
block-wide substring check (`"verify.md" in block`) with a structural
parse: split each `resolved_findings`-shaped block into its own
per-finding sub-section by its own heading/marker (not the whole
surrounding block); within a given finding's own sub-section, require
`verify.md` to appear specifically adjacent to (same line or the
immediately following line as) the sha-shaped token, not merely present
anywhere in the finding's text. A token or filename mention elsewhere in
the finding's free-text body no longer satisfies the check.

**(b) Kill-switch migration (all 5 gates).** `coding/hooks/{state.sh,
hunt-state.sh,hunt-guard.sh,coding-progress-gate.sh}`,
`proposal-shape/hooks/proposal-shape-gate.sh`, `record-shape/hooks/
record-shape-gate.sh`, `survey-order/hooks/survey-order-gate.sh`: replace
each hand-rolled `case ... in ""|0|false|no|off) ;; *) exit 0 ;; esac`
with `. ".../core/hooks/lib/gate-lib.sh"` + `gate_kill_switch_active
"${X_OFF:-}"`, per `gate-lib.sh`'s own usage comment. `coding-progress-
gate.sh` additionally gains the `CODING_CYCLE_OFF` check it currently
lacks entirely (defect 4) using the same call, so the switch
`directive.sh` already documents actually takes effect on the blocking
gate, not only on the non-blocking `state.sh` SessionStart hook.

**(c) `hunt-state.sh release` wiring (`coding/hooks/hooks.json`).** Add a
`SubagentStop` hook entry invoking `hunt-state.sh release`, matching the
verb `hunt-state.sh` already implements but `hooks.json` never registers
(defect 2). No change to `hunt-state.sh`'s own release logic — the
approximate-release trade-off is accepted as already-designed (see
Rationale).

**(d) Edit/MultiEdit/path-normalize migration where applicable.** For any
of the five gates found (during phase 2 implementation) to hand-roll its
own `.replace(old, new[, 1])` reconstruction or its own absolute/relative
path-matching instead of `gate_reconstruct_write`/`gate_normalize_path`,
migrate to the `gate-lib.py` call per the same reference-not-copy
discipline. (Survey did not exhaustively audit every gate's Python payload
line-by-line; `compliance-check.sh`, run at ship time per (f), is the
authoritative detector for this — phase 2 fixes whatever it flags.)

**(e) `tests/run-gate-tests.sh` repair.** Repoint the six exit-127 cases
(`record-complete`, `record-empty`, `foreign-path`, `commit-no-trailer`,
`commit-with-trailer`, `commit-non-issue`) at `coding-progress-gate.sh`'s
current consolidated behavior instead of the two deleted hook files,
preserving each case's original allow/deny intent.

**(f) Mandatory test cases + full-suite green.** Add, across the affected
gates' own `hooks/tests/` and/or `tests/run-gate-tests.sh`: `Edit` with
`replace_all:true` against a multiply-occurring string; `MultiEdit` with
mixed `replace_all` true/false edits; malformed JSON (truncated, empty,
non-object); kill-switch set to an unrecognized value asserting the gate
stays **active**; absolute `file_path` plus a `./`-prefixed variant
matching the same scope as an existing relative-path fixture; a
Bash-tool file write reaching the same target a Write-tool call would
hit — the same six groups `run-gate-lib-tests.sh` names as mandatory. Run
`core/hooks/tests/compliance-check.sh` against `coding/hooks/`,
`proposal-shape/hooks/`, `record-shape/hooks/`, `survey-order/hooks/` as
the ship-time evidence step; the full suite (`tests/run-gate-tests.sh` +
each plugin's own `hooks/tests/` + `tests/methodology-plugins-tests.sh`)
must be green before phase 2 closes.

**(g) README reconciliation.** Diff `README.md`'s stated plugin/path
inventory against `.claude-plugin/marketplace.json` and each plugin's
actual `hooks/` tree; remove any file/path README names that do not exist
on disk, add any real plugin/kill-switch not currently documented.

**(h) Role-vocabulary note, not a rename.** `coding/hooks/directive.sh`
gains a one-line note that the plugin directory name (`coding`) and the
role name used everywhere else (`implementation`) are the same role,
cross-referencing this proposal's Rationale; the plugin-directory rename
itself is named as an explicit follow-up (see "Out of scope"), not
silently done here.

## Out of scope

- Renaming the `coding/` plugin directory to `implementation/` — larger
  blast radius than this issue's other fixes (touches `hooks.json`,
  `marketplace.json`, and any external references to the `coding` plugin
  name); named as a follow-up, not done here (see Rationale).
- Any change to `core/hooks/**` itself — referenced only, never edited by
  a downstream rulebook.
- Adding a new plugin for a methodology not yet adopted by this repo (out
  of issue-64's remediation scope — it fixes existing gates, it does not
  adopt new norms; same boundary issue-61's own "Out of scope" drew for
  its fourth-plugin question).
- Changing `hunt-state.sh`'s release-approximation trade-off (it drops
  the lock on *any* `SubagentStop`, not necessarily the hunter's own) —
  accepted as already-designed; this issue only wires the missing hook
  registration, it does not redesign the lock's precision.
- A timeout/staleness-based lock-recovery mechanism as an alternative to
  `SubagentStop` wiring — considered and rejected (see Rationale).

## How you'll know it worked

- This proposal PR is open against `main`, referencing `#64` (plain, not
  Closes/Fixes), with survey + scout-brief + this proposal committed
  under `docs/issue-64/`.
- On Approve, phase 2 lands (a)-(h): `coding-progress-gate.sh`'s §15 check
  is structural (a same-finding adjacency/section test replaces the
  block-wide substring test, confirmed by the new mandatory test cases in
  (f)); `hunt-guard.sh`'s lock is released via a real `SubagentStop`
  wiring (confirmed by a test that dispatches, stops, and re-dispatches
  without deadlock); `tests/run-gate-tests.sh` runs 8/8 (or its
  replacement count) with no exit-127; `CODING_CYCLE_OFF=1` measurably
  disables `coding-progress-gate.sh`'s blocking behavior in a test case;
  all five gates source `gate-lib.sh`/`gate-lib.py` per (b)/(d), confirmed
  by `core/hooks/tests/compliance-check.sh` exiting 0 against
  `coding/hooks/`, `proposal-shape/hooks/`, `record-shape/hooks/`,
  `survey-order/hooks/`; the full test suite (root + all four plugins'
  `hooks/tests/`) is green; `README.md` names only files that exist on
  disk and every plugin/kill-switch that does.
