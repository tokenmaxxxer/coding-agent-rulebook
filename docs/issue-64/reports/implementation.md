---
subject: issue-64
role: implementation
code_under_review: 758e97c
loop_state: landed
---

# Record — gate A+ remediation (issue-64, phase 2)

Approved via issue comment `APPROVE issue-64/implementation` (single-account
mode, per role-handoff contract v3 s19). Phase-2 delivery against the
approved proposal `docs/issue-64/proposals/2026-08-01-gate-a-plus-remediation.md`.

## What was done

**(a) §15 semantic upgrade (`coding/hooks/coding-progress-gate.sh`).**
Replaced the file-global substring check (`"verify.md" in block`) with a
structural parse: `resolved_entries()` bounds the `resolved_findings`
section by its own heading/key line (ending at the next top-level
heading/key or EOF), then splits that section into per-finding sub-entries
at each `- ` list marker. `entry_resolves()` then requires the sha-shaped
token to sit on the same line, or the immediately following line, as the
mention of `verify.md` or the finding's own id — within that one
finding's own sub-entry, never the surrounding record. A gamed record
(matching 7-hex token and "verify.md" mention both present, but in
unrelated parts of the record) now denies; a real resolution (adjacent
within the finding's own entry) still allows. Covered by
`coding/hooks/tests/coding-progress-gate-tests.sh`'s
`resolved-adjacent-allows` / `resolved-gamed-not-adjacent-denies` cases.

Also fixed, in the same pass: the gate read `docs/issue-<n>/reports/
coding.md` for the implementation record, while every other part of this
repo (record-shape-gate.sh's `RECORD_RE`, contract v3, HAND_OFF text) uses
`docs/issue-<n>/reports/implementation.md`. The §15 check was silently
reading the wrong file. Corrected to `implementation.md` — this is not a
"resurrect the deleted file" move (that filename never existed under this
new name); it aligns the gate's own record lookup with the path convention
already in force everywhere else.

**(b) Kill-switch migration.** `coding/hooks/{state.sh,hunt-state.sh,
hunt-guard.sh,coding-progress-gate.sh}`, `proposal-shape/hooks/
proposal-shape-gate.sh`, `record-shape/hooks/record-shape-gate.sh`,
`survey-order/hooks/survey-order-gate.sh`: each now sources
`core/hooks/lib/gate-lib.sh` (referenced via `CLAUDE_PLUGIN_ROOT_CORE`,
never vendored) and calls `gate_kill_switch_active` instead of the
hand-rolled `case ... in ""|0|false|no|off) ;; *) exit 0 ;; esac` (which
disabled on ANY unrecognized value, including typos — the issue-72-
confirmed fail-open bug). `coding-progress-gate.sh` additionally gained the
`CODING_CYCLE_OFF` check it previously lacked entirely (defect 4):
`directive.sh` already documented this kill switch as controlling the
build-blocking gate; it now actually does.

While migrating `coding-progress-gate.sh`'s kill switch, also replaced its
own hand-rolled fail-closed trap (`__fc`/`trap __fc EXIT`) with
`gate_trap_fail_closed` from the same library, and its ad hoc
malformed-JSON handling (`json.loads(raw) if raw else {}`, which treated
an EMPTY payload as `{}` and proceeded rather than denying — confirmed via
the new `malformed-json-empty` test case, initially failing) with
`gate_parse_json_or_deny`.

**(c) `hunt-state.sh release` wiring (`coding/hooks/hooks.json`).** Added a
`SubagentStop` hook entry invoking `hunt-state.sh release`. Verified
functionally (not just by inspection): dispatched a simulated hunter lock,
confirmed a second dispatch is refused (single-flight), ran
`hunt-state.sh release`, confirmed a third dispatch succeeds — no
self-deadlock.

**(d) Edit/MultiEdit reconstruction migration.** `proposal-shape-gate.sh`,
`record-shape-gate.sh`, `survey-order-gate.sh` each replaced their
hand-rolled `.replace(old, new[, 1])` Edit/MultiEdit reconstruction (which
ignored `replace_all` — always first-occurrence-only) with
`gate_lib.gate_reconstruct_write`, loaded via `importlib` per
`gate-lib.py`'s own usage convention (`GATE_LIB_PY`, exported by
`gate-lib.sh` when sourced). `coding-progress-gate.sh` had no such
reconstruction to migrate (it never reconstructs Write/Edit content — its
own domain is Bash `git commit` commands).

**(e) `tests/run-gate-tests.sh` repair.** The six exit-127 cases targeted
two files consolidated away (`record-fields-gate.sh`, `trailer-gate.sh`).
`record-complete`/`record-empty`/`foreign-path` repointed at
`record-shape-gate.sh` against `docs/issue-7/reports/implementation.md`
(same allow/deny intent, new gate/path — record-field checking now lives
there). `commit-no-trailer`/`commit-with-trailer`/`commit-non-issue`
retired outright: `docs/specs/*.md` no longer states a `Subject:` trailer
requirement anywhere, and no gate in this repo enforces one — resurrecting
a check for a dropped requirement would invent behavior the current
contract does not ask for. `tests/run-gate-tests.sh` now runs 5/5 (down
from the original 8 cases; 3 tested a requirement that no longer exists).

Also repaired `tests/deny-only-check.sh`'s substance probe, found broken
during this pass: it hardcoded `docs/issue-999/reports/coding.md` and
scanned only `coding/hooks/` — stale from before the same record-field
consolidation. Repointed to scan the whole repo root for
`docs/issue-999/reports/implementation.md`, so it reaches whichever gate
currently owns the check (`record-shape-gate.sh`).

**(f) Mandatory test cases + full-suite green.** Added, per issue-64
point 3 (matching core's `run-gate-lib-tests.sh` six-group shape): Edit
`replace_all:true` over a multiply-occurring string, MultiEdit mixed
`replace_all`, malformed JSON (truncated/empty/non-object), kill-switch
unrecognized-value-stays-active, and absolute-path-denies-like-relative —
to `coding/hooks/tests/coding-progress-gate-tests.sh` (new file, plus the
§15 adjacency cases), `proposal-shape/hooks/tests/
proposal-shape-tests.sh`, `record-shape/hooks/tests/
record-shape-tests.sh`, `survey-order/hooks/tests/survey-order-tests.sh`.
The Bash-tool-write-reaching-a-Write-target mandatory group was not added
to the three shape gates: their `hooks.json` matcher is `Write|Edit|
MultiEdit` only (not in this issue's write set to extend), and
`coding-progress-gate.sh` is itself Bash-tool-triggered by design, so
neither has a meaningful home for that specific case.

Ran `core/hooks/tests/compliance-check.sh` (issue #72, referenced from
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core` via `CLAUDE_PLUGIN_ROOT_CORE`
for this local run) against the whole repo root: **exit 0, all four
`*-gate.sh` files ok** (`coding-progress-gate.sh`, `proposal-shape-gate.sh`,
`record-shape-gate.sh`, `survey-order-gate.sh`) — no hand-rolled
kill-switch or reconstruct pattern remains.

Full suite, all green:
- `tests/parse-check.sh` — 6/6 `bash -n`.
- `tests/run-gate-tests.sh` — 5/5.
- `tests/deny-only-check.sh` — ok (no `permissionDecision: allow`; substance
  probe refused by `record-shape-gate.sh`).
- `tests/methodology-plugins-tests.sh` — 23/23 (9 syntax + 14 behavior).
- `coding/hooks/tests/coding-progress-gate-tests.sh` — 10/10 (new).
- `proposal-shape/hooks/tests/proposal-shape-tests.sh` — 13/13.
- `record-shape/hooks/tests/record-shape-tests.sh` — 14/14.
- `survey-order/hooks/tests/survey-order-tests.sh` — 12/12.
- `core/hooks/tests/compliance-check.sh .` — 0 (4/4 gates ok).

**(g) README reconciliation.** Removed ghost file references
(`record-fields-gate.sh`, `trailer-gate.sh`, `handbook-trigger-gate.sh`
under `coding/hooks/`; `agents/warrant-hunter.md`, which does not exist
anywhere in this repo). Added the previously-undocumented
`proposal-shape`/`record-shape`/`survey-order` trio to the intro and
"What is here", all six real kill-switch env vars (`WARRANT_OFF`,
`WARRANT_HUNT_MAX`, `PROPOSAL_SHAPE_GATE_OFF`, `RECORD_SHAPE_GATE_OFF`,
`SURVEY_ORDER_GATE_OFF`, plus the pre-existing `CODING_CYCLE_OFF`), and
`tests/methodology-plugins-tests.sh` + the new/updated per-plugin test
invocations under "Run the checks". Also corrected a stale pre-v3 line
naming branch `issue-<n>/coding` / record `docs/issue-<n>/reports/
coding.md` — both now read `issue-<n>/implementation` /
`docs/issue-<n>/reports/implementation.md`, matching contract v3 and every
other reference in this repo.

**(h) Role-vocabulary note.** `coding/hooks/directive.sh`'s `HAND_OFF`
gained a short NAMING NOTE: the `coding` plugin directory and the
`implementation` role name are the same role (deliberate doubling, tracked
as a follow-up, not renamed here) — matches the proposal's Rationale and
"Out of scope".

## Closed checks

- `closed_checks`: `core/hooks/tests/compliance-check.sh` against
  `coding/hooks/`, `proposal-shape/hooks/`, `record-shape/hooks/`,
  `survey-order/hooks/` — exit 0, code_sha 758e97c (pre-remediation HEAD;
  re-run after this commit lands continues to pass against the same
  gate-lib.sh version).
- Functional hunt-lock probe (dispatch → single-flight refuse → release →
  re-dispatch succeeds) — closed, same code_sha.

## What did not work

- First draft of `tests/deny-only-check.sh`'s repair kept the original
  `coding/hooks`-only scan scope and only changed the record filename;
  that left the probe pointed at a directory with no gate that checks
  record content at all (coding-progress-gate.sh is Bash-command-triggered,
  not Write-triggered) — still failed. Widened the scan to the whole repo
  root so it reaches `record-shape-gate.sh`, which is where the check now
  actually lives.
- First `coding-progress-gate-tests.sh` draft passed `$VBLOCK` (verify
  `loop_state: reproduced`) as the verify-record fixture for the
  "resolved-adjacent-allows" (expected-allow) case — failed, since the
  gate correctly requires verify's own `loop_state: cleared` in addition to
  the resolved_findings adjacency match. Added a separate
  `$VBLOCK_CLEARED` fixture for that case.
- `tests/run-gate-tests.sh`'s trailer cases were initially left in place
  with `trailer-gate.sh` repointed to `coding-progress-gate.sh` (per a
  literal reading of the proposal's Constraints text, "record-fields +
  trailer checks now folded into it") — checking the actual file showed
  `coding-progress-gate.sh` has no trailer-checking logic at all, and no
  gate in this repo does. Retired the three cases instead of fabricating
  behavior to make them pass; documented why in the test file's own header
  comment.

## Rationale for deviations

The approved proposal's premise for (e) stated record-fields and trailer
checks were "now folded into" `coding-progress-gate.sh`. Direct inspection
of the file showed this was not true for the trailer check — no successor
exists anywhere in this repo, and `docs/specs/*.md` no longer states the
requirement. Rather than resurrect a trailer-enforcing case against a file
that has never checked it, the three trailer test cases were retired with
the reasoning recorded in `tests/run-gate-tests.sh`'s own header comment.
This is narrower than a scope-exceeded stop (no new write surface was
touched beyond the proposal's own `tests/*` line) but is a factual
deviation from what the proposal's text asserted about the current state,
so it is recorded here per the record-shape norm.

## Open findings

None. All items in "What will be done" (a)-(h) landed; full suite green;
`compliance-check.sh` exit 0 against all four gate directories.
