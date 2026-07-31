---
subject: issue-61
role: implementation
code_under_review: <pending: set to this branch's HEAD sha before PR>
loop_state: landed
---

# Record — implementation-domain methodology plugin set (phase 2)

## What was done

Reflected the approved proposal
(`docs/issue-61/proposals/2026-07-31-methodology-gate-design.md`) into
three new, independent, self-contained plugins plus the two small
coupled fixes the proposal scoped as (d)-(f):

1. **`proposal-shape/`** (new top-level plugin) — owns the phase-1
   ADR-style seven-section proposal shape adopted in issue-52.
   `plugin.json`, `hooks/hooks.json` (UserPromptSubmit → `directive.sh`,
   PreToolUse `Write|Edit|MultiEdit` → `proposal-shape-gate.sh`),
   `hooks/directive.sh` (kill switch `PROPOSAL_SHAPE_OFF`),
   `hooks/proposal-shape-gate.sh` (fail-closed, path-scoped to
   `docs/issue-[0-9]+/proposals/.*\.md$`, checks all seven headings
   present and in order, and that `## Rationale`'s body names a
   rejected alternative; kill switch `PROPOSAL_SHAPE_GATE_OFF`; named
   deny messages), `hooks/tests/proposal-shape-tests.sh` (6 cases,
   passing), `README.md`.
2. **`record-shape/`** (new top-level plugin) — owns the phase-2 record
   shape adopted in issue-52. `plugin.json`, `hooks/hooks.json`,
   `hooks/directive.sh` (kill switch `RECORD_SHAPE_OFF`, covers both
   the record-shape and deviation facets),
   `hooks/record-shape-gate.sh` (fail-closed, path-scoped to
   `docs/issue-[0-9]+/reports/implementation\.md$`, checks
   `code_under_review:`+`loop_state:` frontmatter and `## What did not
   work`, and conditionally requires `## Rationale for deviations` only
   when the record's own text signals a deviation; kill switch
   `RECORD_SHAPE_GATE_OFF`), `hooks/tests/record-shape-tests.sh` (7
   cases, passing), `README.md`.
3. **`survey-order/`** (new top-level plugin) — owns the
   research-before-proposal write ordering. `plugin.json`,
   `hooks/hooks.json`, `hooks/directive.sh` (kill switch
   `SURVEY_ORDER_OFF`), `hooks/survey-order-gate.sh` (fail-closed,
   path-scoped to the same proposal path pattern, denies a proposal
   write unless `docs/issue-<n>/reports/implementation/survey.md`
   already exists on disk for that issue or the proposal body states
   the scout-skip condition; kill switch `SURVEY_ORDER_GATE_OFF`),
   `hooks/tests/survey-order-tests.sh` (5 cases, passing), `README.md`.
4. **`.claude-plugin/marketplace.json`** — gained three entries
   (`proposal-shape`, `record-shape`, `survey-order`), each naming its
   owned methodology; the four existing entries (`coding`, `blueprint`,
   `no-mock`, `no-footgun`) are unchanged.
5. **`coding/hooks/directive.sh`** — only the stale `HAND_OFF` record
   path fixed, `docs/issue-<n>/reports/coding.md` →
   `docs/issue-<n>/reports/implementation.md` (survey finding 4; matches
   the path `record-shape`'s gate now targets).
6. **`tests/methodology-plugins-tests.sh`** (new repo-root harness) —
   invokes all three plugins' gates as real subprocesses against
   combined proposal/record fixtures, plus a `bash -n` syntax check on
   every hook script in the set. 23 cases, all passing.

Each new plugin is genuinely independent (own `plugin.json`, own
`hooks/`, own `hooks/tests/`) and installable/removable on its own,
matching how `no-mock`/`no-footgun` already sit beside `coding`.

## Why

The approver's FEEDBACK on the first attempt (PR #62) rejected a
single `methodology-gate.sh` folded into `coding` and required a
plugin set instead — the plugin inventory/composition design already
approved in the proposal is executed here as-is. Three plugins, not
one, because `proposal-shape`'s content check and `survey-order`'s
ordering check are genuinely different methodologies even though both
gate the same file (issue-52's own "one plugin, one methodology"
split), and `record-shape` needs no ordering component. No fourth
plugin was added for review/test discipline, matching the proposal's
"Out of scope" — no prior maturation round ratified that norm for this
role.

## Upstream basis

- Issue: #61.
- Approved proposal: `docs/issue-61/proposals/2026-07-31-methodology-gate-design.md`.
- Approval: issue-61 comment `APPROVE issue-61/implementation` (single-account mode).
- Survey / scout brief: `docs/issue-61/reports/implementation/survey.md`,
  `docs/issue-61/reports/implementation/scout-brief.md`.
- Exemplar referenced (canon-reference discipline, not copied):
  `pricing-rulebook/pricing/hooks/methodology-gate.sh`'s fail-closed
  PreToolUse structure; `coding-progress-gate.sh`'s sibling-file-as-
  state-signal pattern for `survey-order`'s ordering check.

## closed_checks

None run this cycle — no warrant-hunter probe was dispatched; this is
new gate/directive/test authorship with its own test suite exercised
directly (23 combined-harness cases + 18 per-plugin cases, all
passing), not a hunt-derived closure.

## What did not work

- The repo-root combined harness (`tests/methodology-plugins-tests.sh`)
  initially reported `exit-141` (SIGPIPE) on all three kill-switch
  cases: piping the JSON payload directly into a gate whose kill-switch
  branch exits before consuming stdin causes the writer (`printf`) to
  receive SIGPIPE, and `pipefail` propagated that into the recorded
  exit code instead of the gate's actual 0. Fixed by writing the
  payload to a temp file and redirecting stdin from the file instead of
  piping, matching `record-shape-tests.sh`'s own pattern.

## Open findings

(none)

## Doc placement outcomes

- No env var, config key, dependency, or migration introduced —
  handbook placement not applicable.
- No library/format choice or changed public signature/wire format
  beyond what the approved proposal itself already specified — no
  additional `docs/issue-61/decisions/` entry needed.
- No benchmark or investigation numbers produced this cycle.

## Rationale for deviations

(none — phase-2 execution followed the approved proposal's plugin
inventory, composition, and file list exactly; the SIGPIPE fix above
is a test-harness correction, not a deviation from the proposal's
scope)

## How you'll know it worked

- `proposal-shape/hooks/tests/proposal-shape-tests.sh`: 6 passed, 0
  failed.
- `record-shape/hooks/tests/record-shape-tests.sh`: 7 passed, 0 failed.
- `survey-order/hooks/tests/survey-order-tests.sh`: 5 passed, 0 failed.
- `tests/methodology-plugins-tests.sh`: 23 passed, 0 failed (includes
  the `bash -n` syntax check on all nine plugin hook scripts).
- `.claude-plugin/marketplace.json` is valid JSON and lists all three
  new plugins alongside the four existing ones.
- This record itself, once `code_under_review:` is set to this
  branch's HEAD sha, satisfies `record-shape`'s own gate (dogfooding,
  same as issue-52's close-out): frontmatter carries both required
  keys, `## What did not work` is present, and `## Rationale for
  deviations` is present-but-empty since no deviation occurred.
