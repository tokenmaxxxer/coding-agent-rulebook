---
subject: issue-64
role: implementation
---

# Current-state survey — gate A+ remediation (issue-64)

## 1. §15 gate cavity (file-global scope, any 7hex passes)

`coding/hooks/coding-progress-gate.sh:156` checks a resolved_findings block
with `names_verify = ("verify.md" in block) or (...)` — a plain substring
test against the whole matched block text, not a section/heading- or
adjacency-scoped check. Any block that merely *mentions* the word
`verify.md` anywhere, or contains any 7-hex-looking token anywhere in the
block, satisfies the check regardless of whether that token is actually the
sha that resolved the named finding. This is the audit's "§15 gate cavity"
finding: semantic intent (this finding was resolved by this specific commit)
is checked by keyword co-occurrence, not by structure.

## 2. hunt lock self-deadlock (no SubagentStop wiring)

`coding/hooks/hunt-state.sh` declares three verbs: `acquire` (PreToolUse),
`release` (SubagentStop), `reset` (SessionStart). `coding/hooks/hooks.json`
registers `hunt-guard.sh` only under `PreToolUse` (`Agent|Task` matcher) and
`directive.sh`+`state.sh` under `SessionStart`. **No `SubagentStop` hook
entry exists anywhere in `coding/hooks/hooks.json`** — `hunt-state.sh
release` is never invoked. Once `hunt-guard.sh` acquires
`.warrant-hunt.lock` for a dispatched hunter subagent, nothing ever calls
`release`; every subsequent `Agent|Task` call self-deadlocks against the
still-held lock until a new session's `SessionStart` reset fires. Root
cause: the release half of the lock lifecycle was designed
(`hunt-state.sh`'s comments describe it) but never wired into
`hooks.json`.

## 3. Root test suite: 5/8 exit-127

`bash tests/run-gate-tests.sh` — measured now:
```
FAIL   record-complete       want=allow got=exit-127
FAIL   record-empty          want=deny  got=exit-127
FAIL   foreign-path          want=allow got=exit-127
FAIL   commit-no-trailer     want=deny  got=exit-127
FAIL   commit-with-trailer   want=allow got=exit-127
FAIL   commit-non-issue      want=allow got=exit-127
ok     blocking-finding-unresolved  deny
ok     no-verify-findings          allow
== 2 passed, 6 failed ==
```
`tests/run-gate-tests.sh` invokes `$HOOKS/record-fields-gate.sh` and
`$HOOKS/trailer-gate.sh` against `coding/hooks/` — neither file exists in
`coding/hooks/` any more (`ls coding/hooks/` shows only
`coding-progress-gate.sh`, `directive.sh`, `hunt-guard.sh`, `hunt-state.sh`,
`state.sh`). Those two gates were consolidated into
`coding-progress-gate.sh` at some point after `tests/run-gate-tests.sh` was
written; the test file was never updated, so every case that shells out to
the old filenames gets bash's not-found exit 127, not a real pass/fail
signal. Issue #61's own proposal (`docs/issue-61/proposals/2026-07-31-
methodology-gate-design.md`, "Out of scope") already flagged this exact gap
("Fixing tests/run-gate-tests.sh's stale references to the three deleted
hooks — a real gap ... but not this issue's write set") and deferred it —
issue-64 is that deferred fix's landing point.

## 4. `CODING_CYCLE_OFF` unimplemented

`coding/hooks/state.sh` (SessionStart, non-blocking) reads
`CODING_CYCLE_OFF` and exits early if set — but `state.sh` only writes
session-start bookkeeping, it is not a PreToolUse gate. The actual blocking
gate, `coding-progress-gate.sh`, has **no `CODING_CYCLE_OFF` (or any
`*_OFF`) kill-switch check at all** (`grep -n "_OFF\|kill_switch" coding/
hooks/coding-progress-gate.sh` returns only the fail-closed trap comment,
no case statement). `coding/hooks/directive.sh` documents "Kill switch:
export CODING_CYCLE_OFF=1" as if it disables the cycle gate; it does not —
the documented kill switch has no effect on the gate it is described as
controlling.

## 5. Role-vocabulary doubling

The plugin directory is `coding/`, but the role name used everywhere else
in this repo (branch names `issue-<n>/implementation`, record path
`docs/issue-<n>/reports/implementation.md`, this session's own role
identity) is `implementation`. `docs/issue-61/proposals/...` explicitly
called out and declined to fix this ("Renaming the `coding` plugin
directory to `implementation` — the role/plugin name mismatch predates this
issue and is not part of this ask"). Two names for one role persist through
directive text, gate error messages, and directory structure, which is a
standing source of drift (e.g. `directive.sh`'s stale `HAND_OFF` path,
already fixed once in issue-61, was exactly this kind of naming
mismatch).

## 6. core gate-house standard (issue-72, landed) — reference material

`core/hooks/lib/gate-lib.sh` + `gate-lib.py` (cached copies read at
`/tmp/claude-1000/core-ref/`; `docs/handbooks/gate-house-standard.md`
confirms landed) supply, canon, sourceable (never copy —
`docs/handbooks/canon-scripts.md`'s reference-not-copy rule, reinforced by
`core/hooks/tests/canon-manifest.txt` + `stub-check.sh`):
- `gate_trap_fail_closed` — canonical fail-closed EXIT trap.
- `gate_kill_switch_active <value>` — fixed convention: only a recognized
  on-spelling (`1`/`true`/`yes`/`on`, case-insensitive) disables; empty, a
  recognized off-spelling, or any unrecognized value all stay active. This
  is the fail-closed-by-default kill-switch semantic issue #64 point 1
  requires everywhere in this repo — `coding`'s own `state.sh`/
  `hunt-state.sh`/`hunt-guard.sh` all still use the old inverted
  `case ""|0|false|no|off) ;; *) exit 0 ;; esac` idiom (unrecognized value
  = disable), the exact bug class `gate-lib.sh`'s header comment names as
  fixed.
- `gate_deny <name> <msg>` / `gate_allow` — stderr-only deny(2)/allow(0).
- `gate_parse_json_or_deny` (Python) — malformed-JSON deny (truncated,
  empty, non-object).
- `gate_normalize_path` (Python) — absolute/relative/`./`-prefixed path
  normalization to a root-relative tail.
- `gate_reconstruct_write` (Python) — full Write/Edit/MultiEdit/
  NotebookEdit reconstruction honoring per-edit `replace_all`.
- `gate_bash_write_targets` (bash) — token-scan a Bash command string for
  path-shaped candidates (already used by this repo's own
  `board-gate.sh`-style gates, per this survey's own experience triggering
  it in §7 below).
- `core/hooks/tests/run-gate-lib-tests.sh` names six mandatory case
  groups: `Edit replace_all:true` over a multiply-occurring string,
  `MultiEdit` mixed `replace_all`, malformed JSON (truncated/empty/
  non-object), kill-switch unrecognized value stays active, absolute +
  `./`-prefixed path parity, Bash-tool write reaching a Write-tool target.
  Issue-64 point 3's "mandatory test cases" list is exactly this set, plus
  this repo's own kill-switch/path cases.
- `core/hooks/tests/compliance-check.sh [hooks-dir]` flags a gate reading
  a `*_OFF` var without calling `gate_kill_switch_active`, and a gate doing
  hand-rolled `.replace(old, new[, 1])` instead of `gate_reconstruct_write`.
  Not yet run against this repo's own `coding/hooks/` — every one of this
  repo's gates (`coding-progress-gate.sh`, `proposal-shape-gate.sh`,
  `record-shape-gate.sh`, `survey-order-gate.sh`) currently hand-rolls its
  own kill-switch case statement and would be flagged.

## 7. Existing sibling plugins (proposal-shape/record-shape/survey-order)

Landed via issue-61 (`docs/issue-61/proposals/2026-07-31-methodology-gate-
design.md`, merged per `git log` — commit `fb24296`). Each is a small,
independent, freelunch-scale plugin: `plugin.json` + `hooks/{directive.sh,
hooks.json,<name>-gate.sh}` + `hooks/tests/`. None of them yet source
`gate-lib.sh`; each still hand-rolls its own kill-switch case and its own
ad hoc content checks. They are the template this issue's remediation
should match in shape (one plugin per concern, own tests, marketplace-
registered), but they are themselves in-scope for the same core-gate-lib
migration issue-64 asks for, to the extent they touch the semantic
weaknesses point 2 calls out (they are substring/keyword checks over
section text, not section/adjacency/structure checks — same class of
problem as §15, just less severe since their content is authored by this
same role rather than adversarially by a different role).

## 8. README drift

Not yet enumerated file-by-file (issue point 4, "README를 실물과
정합화") — deferred to the proposal's own file-diff pass, since it requires
diffing README's plugin/path list against the actual `.claude-plugin/
marketplace.json` + each plugin's real hooks tree, which is mechanical
verification work appropriate to the proposal draft itself rather than a
separate survey pass.

## Write surfaces this issue will plausibly touch

- `coding/hooks/{coding-progress-gate.sh,hunt-guard.sh,hunt-state.sh,
  state.sh,hooks.json,directive.sh}` — kill-switch migration, §15 semantic
  fix, SubagentStop wiring, CODING_CYCLE_OFF wiring.
- `proposal-shape/hooks/*`, `record-shape/hooks/*`, `survey-order/hooks/*`
  — kill-switch migration to `gate_kill_switch_active`, path-normalization
  and reconstruct migration to `gate_normalize_path`/
  `gate_reconstruct_write` where each currently hand-rolls the equivalent.
- `tests/run-gate-tests.sh` — repair the 6 exit-127 cases (repoint at
  `coding-progress-gate.sh`'s consolidated behavior, or retire the file if
  its cases are now redundant with `coding-progress-gate.sh`'s own
  `hooks/tests/`).
- `tests/*` — new mandatory Edit/MultiEdit/replace_all/malformed-JSON/
  kill-switch/absolute-path cases, one harness reused across the affected
  gates (matches `run-gate-lib-tests.sh`'s six-case shape).
- `README.md` — plugin/path inventory reconciliation.
- Possibly `coding/` → renamed to reduce vocabulary doubling, or a
  narrower fix (directive text only) — open design question for the
  proposal's Rationale, since a directory rename is a larger blast radius
  than this issue's other fixes and issue-61 explicitly punted it.
