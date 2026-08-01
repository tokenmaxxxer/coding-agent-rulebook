---
subject: issue-67
role: implementation
---

# Survey — issue-67 (gate A+ final closeout: re-audit residual defects)

## 0. What "gate A+" is and what issue-64 already fixed

`docs/issue-64/proposals/2026-08-01-gate-a-plus-remediation.md` (landed
`e5f8e50`, PR #66) is the prior remediation pass against a re-audit that
graded this repo's gates C. Its `docs/issue-64/reports/implementation.md`
records (a)-(h) landed: §15 upgraded from a file-global substring match to
a structural per-finding adjacency parse; all five gates migrated to
`gate_kill_switch_active`/`gate_trap_fail_closed`/`gate_reconstruct_write`
from core's `gate-lib.sh`/`gate-lib.py` (issue #72); `hunt-state.sh
release` wired into `coding/hooks/hooks.json`'s `SubagentStop`; six
mandatory test-case groups added per gate; `tests/run-gate-tests.sh` and
`tests/deny-only-check.sh` repaired; README reconciled (ghost
`record-fields-gate.sh`/`trailer-gate.sh`/`handbook-trigger-gate.sh`/
`agents/warrant-hunter.md` references removed, kill-switch env vars
documented). Full suite green, `compliance-check.sh` exit 0, recorded at
that time.

Issue #67 is a *second* re-audit (2026-08-01, same day) that found four
residual defects issue-64 did not close, plus two structural checks
(matcher/coverage alignment, README/manifest zero-stale-name). This survey
verifies each claim against the current tree with file:line citations.

## 1. Common preconditions (verified on the core repo, not in this repo)

This repo (`coding-agent-rulebook` / implementation-rulebook) does not
contain a `core/` directory or an `on-the-record` plugin — both are
external, referenced only via `CLAUDE_PLUGIN_ROOT_CORE`
(`README.md:84-86`; e.g. `coding/hooks/coding-progress-gate.sh:27`).
Checked the referenced checkout at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`:

- **core #75** (gate-lib source guard mandatory + compliance-check
  detection + missing-core mandatory test + `gate_bash_write_targets.py`
  port): landed. `git log --oneline` there shows `52bdc15
  deliver(implementation): gate-lib source guard + gate_bash_write_targets
  py parity (issue-75) (#77)`, preceded by `24eb5ed
  propose(implementation): gate-lib source guard + gate_bash_write_targets
  py parity (issue-75) (#76)`. Precondition satisfied.
- **on-the-record #182** (`CLAUDE_PLUGIN_ROOT_CORE` injection in
  `spawn.py`): `spawn.py` does not exist anywhere in this repo (`find . -
  iname spawn.py` — no hits) and no `on-the-record` plugin directory
  exists in this repo either. This is out-of-repo work; I could not
  independently verify #182's landing state from inside this checkout
  (no `on-the-record` remote clone available here). Flagging this as
  **unverified from this repo** — the issue-67 requirements should be
  read as depending on it being true externally, not something this
  proposal can confirm or fix.

Grep confirms `CLAUDE_PLUGIN_ROOT_CORE` is used consistently as the core
reference point throughout this repo's gates: `coding/hooks/state.sh:6`,
`coding/hooks/coding-progress-gate.sh:27`, `coding/hooks/hunt-guard.sh:10`,
`coding/hooks/hunt-state.sh:21`, `coding/hooks/directive.sh:6`,
`tests/run-gate-tests.sh:25,27`,
`coding/hooks/tests/coding-progress-gate-tests.sh:12,14`. No test file in
this repo exercises a "CLAUDE_PLUGIN_ROOT_CORE unset and no local `core/`
fallback resolves" (missing-core) case — grep for `missing-core` across
`coding/hooks/*.sh`, `coding/hooks/tests/*.sh`, `tests/*.sh`, `README.md`
returns no hits. Whatever "missing-core mandatory test" core #75 added
lives in the core repo's own `run-gate-lib-tests.sh`/`compliance-check.sh`
(confirmed present there), not duplicated here — consistent with this
repo's own "reference, never vendor" rule
(`docs/handbooks/canon-scripts.md` referenced at `README.md:83`, itself
a ghost reference — see §7 below).

## 2. §15 sha verification — no real sha check (defect a)

`coding/hooks/coding-progress-gate.sh:151`:

```python
SHA_RE = re.compile(r'\b[0-9a-f]{7,40}\b')
```

This regex matches any 7-to-40-character lowercase-hex token — it never
runs `git cat-file -e <sha>` or `git rev-parse --verify <sha>` against the
target repo to confirm the token names a commit that actually exists.
`entry_resolves()` (lines 189-204) only checks that a `SHA_RE`-shaped
token sits on the same or next line as a `verify.md` mention or the
finding's own id — adjacency, not existence. issue-64's own fix (record
§(a), `docs/issue-64/reports/implementation.md:16-38`) explicitly
describes this as a *structural/adjacency* upgrade ("the sha-shaped token
to sit on the same line... as the mention of `verify.md`") — it never
claimed to verify the sha is real, and the code matches that: adjacency
only, format check only.

Confirmed via the existing test fixture itself:
`coding/hooks/tests/coding-progress-gate-tests.sh:55-58` — the
`resolved-adjacent-allows` case's `GOOD_RESOLVED` fixture uses
`finder: docs/issue-7/reports/verify.md sha abc1234`, a fabricated,
never-committed 7-hex string, and the gate allows it (`progress allow
resolved-adjacent-allows ...`). No test in this file constructs a real
commit and a fabricated same-length hex string to assert the fabricated
one is denied — there is no such case, because the code has no logic to
distinguish them. **Confirmed live, not already fixed.**

## 3. Hunt reset not wired — lifetime cap instead of session cap (defect b)

`coding/hooks/hunt-state.sh:9` documents two subcommands:
```
#   release  (SubagentStop)  a subagent finished — drop the lock
#   reset    (SessionStart)  new session — drop the lock and zero the count
```
and implements both (lines 33-40, `release` at 34-36, `reset` at 37-39,
`reset` clears `.warrant-hunt.count` in addition to the lock).

`coding/hooks/hooks.json:3-10` — the `SessionStart` block only registers:
```json
{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/directive.sh" },
{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/state.sh" }
```
No `hunt-state.sh reset` (or `hunt-state.sh` with any argument) entry
exists in `SessionStart`. Only `SubagentStop` invokes `hunt-state.sh`, and
only with `release` (`hooks.json:25-31`, matches issue-64's record §(c) —
that landed pass wired `release`, not `reset`).

Effect confirmed by reading `hunt-guard.sh:135-146`: `.warrant-hunt.count`
is read once per dispatch attempt and compared against
`WARRANT_HUNT_MAX` (default 3), and is only ever incremented (line
148-152), never decremented anywhere except `hunt-state.sh reset`, which
is never called. Because `.warrant-hunt.count` lives at the git root
(`hunt-guard.sh:110-112`, `posixpath.join(root, ".warrant-hunt.count")`)
and is never cleared automatically, the "session cap" described in the
comment (`hunt-guard.sh:17`: "session cap — WARRANT_HUNT_MAX dispatches
... then no more") is in practice a repository-lifetime cap: once 3
hunters have ever been dispatched against this checkout, no session,
ever, can dispatch a fourth without a human manually running
`rm .warrant-hunt.count` (the exact remedy hunt-guard.sh's own deny
message at lines 143-145 names). **Confirmed live, not already fixed** —
issue-64 wired `release` only; `reset` was implemented in `hunt-state.sh`
from the start (its own header comment predates issue-64, describing the
exact bug this leaves: "WARRANT_HUNT_MAX was a repository-lifetime cap
wearing the name 'session cap'" — `hunt-state.sh:1-7`) but was never
plugged into `hooks.json`.

## 4. `state.sh` dead code with old vocabulary (defect c)

`coding/hooks/state.sh:27-28`:
```bash
rec="$root/docs/${issue}/reports/coding.md"
[ -f "$rec" ] && echo "[coding] Own record exists: docs/${issue}/reports/coding.md — read it before continuing."
```

Current record-path convention, confirmed in three independent places:
- `README.md:10-11`: "record at `docs/issue-<n>/reports/implementation.md`".
- `coding/hooks/coding-progress-gate.sh:90-91` (code, not comment):
  `re.match(r'^docs/(issue-[0-9]+)/reports/implementation\.md$', f)`.
- `docs/issue-64/reports/implementation.md:31-38`, issue-64's own record:
  "the gate read `docs/issue-<n>/reports/coding.md` for the implementation
  record ... Corrected to `implementation.md`" — describing exactly this
  fix, but applied only to `coding-progress-gate.sh`, not `state.sh`.

`state.sh`'s own `rec=` line was never touched by issue-64 (issue-64's
diff stat for `coding/hooks/state.sh` was `+3 -1` lines — the kill-switch
migration only, per `git show e5f8e50 --stat`). Because
`docs/<issue>/reports/coding.md` is never written by anything in this
repo (record-shape-gate.sh and every convention target
`implementation.md`), this `[ -f "$rec" ]` check is permanently false —
dead code checking a path under a retired name. Not blocking (this hook
is informational, `SessionStart`, never denies), but it is the literal
"dead code with old vocabulary" the issue names. **Confirmed live, not
already fixed.**

## 5. `coding-progress-gate.sh` comment references the old path (defect d)

`coding/hooks/coding-progress-gate.sh:13-17` (top-of-file comment block):
```
# Before a coding commit lands for a subject, read the subject's verify record
# docs/issue-<n>/reports/verify.md (same target repo coding is
# building) and scan for inline `finding` blocks with severity: blocking and
# addressed_to: coding. Each such finding counts as STILL BLOCKING unless
# coding's own record docs/issue-<n>/reports/coding.md carries a
```
Line 17 says `docs/issue-<n>/reports/coding.md`. The executable code three
lines below the comment (line 91,
`re.match(r'^docs/(issue-[0-9]+)/reports/implementation\.md$', f)`) and
the README/issue-64 record cited in §4 above both confirm the real,
current path is `implementation.md`. issue-64's remediation fixed the
*code* (per its record §(a), quoted in §4) but left this comment
un-updated — a self-contradicting file: comment says `coding.md`, code
requires `implementation.md`. **Confirmed live, not already fixed.**

## 6. hooks.json matcher vs. code tool-coverage (issue requirement 2)

`coding/hooks/hooks.json:18-23`:
```json
{
  "matcher": "Agent|Task",
  "hooks": [
    { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/hunt-guard.sh" }
  ]
}
```
`coding/hooks/hunt-guard.sh:93`:
```python
if tool not in ("Agent", "Task", "Workflow"):
    allow()
```
The code branches on three tool names (`Agent`, `Task`, `Workflow`); the
`hooks.json` matcher only advertises/dispatches two (`Agent|Task`). A
`Workflow` tool call, in a production install, would never reach
`hunt-guard.sh` at all (PreToolUse matchers gate which hook commands even
run) — the `Workflow` branch in the Python is unreachable in production
regardless of what it says. Grep for `Workflow` across
`coding/hooks/tests/` and `tests/` (only file found:
`coding/hooks/hunt-guard.sh` itself, lines 21/23/93) confirms no test
exercises a `tool_name: Workflow` payload either — the branch is neither
reachable in production nor covered by a test, so it cannot even be
argued the test suite is asserting dead-but-intentional code. This is the
literal "advertised/tested branches must be reachable in production" gap
issue-67 requirement 2 names. Whether the fix is to add `Workflow` to the
matcher or drop it from the code's tuple is a proposal-stage decision
(see the proposal document), not resolved by this survey.

## 7. README / manifest ghost files and stale names (issue requirement 4)

Checked every file/path README.md references against the filesystem:

| README reference | Location | Exists? |
|---|---|---|
| `coding/hooks/directive.sh` | README.md:27 | yes |
| `coding/hooks/state.sh` | README.md:34 | yes |
| `coding/hooks/coding-progress-gate.sh` | README.md:37 | yes |
| `coding/hooks/hunt-guard.sh` + `hunt-state.sh` | README.md:43 | yes |
| `blueprint/ no-mock/ no-footgun/` | README.md:47 | yes |
| `proposal-shape/` | README.md:48 | yes |
| `record-shape/` | README.md:51 | yes |
| `survey-order/` | README.md:54 | yes |
| `tests/` | README.md:56 | yes |
| `core/hooks/lib/gate-lib.sh`/`gate-lib.py` | README.md:81-82 | external (by design) |
| `docs/handbooks/canon-scripts.md` | README.md:83 | **NO — missing** |

`docs/handbooks/canon-scripts.md` is cited by name at `README.md:83`
("... source core's gate-house standard ... reference only, never
vendored (`docs/handbooks/canon-scripts.md`)") but `find docs/handbooks
-type f` returns only `docs/handbooks/gate-tests.md` and
`docs/handbooks/README.md` — no `canon-scripts.md` anywhere in the repo.
This is a ghost-file reference README.md itself carries, un-caught by
issue-64's own README reconciliation pass (which removed
`record-fields-gate.sh`/`trailer-gate.sh`/`handbook-trigger-gate.sh`/
`agents/warrant-hunter.md` per its record §(g),
`docs/issue-64/reports/implementation.md:131-134`, but evidently missed
this one). **New finding, not previously flagged.**

`agents/warrant-hunter.md` (referenced in
`coding/hooks/hunt-guard.sh:21,114` as the tool-list source that forecloses
nesting) still does not exist anywhere in this repo (`find . -iname
'*warrant-hunter*'` — only hits inside `hunt-guard.sh` itself). issue-64's
record already flagged this exact non-existence and removed it from
README (record §(g)) but the *code comment* in `hunt-guard.sh` referring
to `warrant-hunter.md`'s frontmatter as a live enforcement mechanism
remains — this is a known, previously-acknowledged gap (the agent
definition presumably lives in whatever deployment wires
`warrant-hunter`, not this rulebook repo), not a new defect, but it is
adjacent to the "ghost file" concern issue-67 raises and worth naming for
completeness.

No "43-role taxonomy" document exists inside this repo (`grep -rl "43.role
taxonomy\|43-role" docs` — no hits under `docs/`; the only "43" hits are
`blueprint/README.md` and `docs/issue-64/proposals/...` where "43" refers
to something else entirely, not a role count). The 43-role taxonomy is
presumably defined in the core repo (its own scout-brief
`docs/issue-64/reports/implementation/scout-brief.md:94-96` references
"one of the 43 downstream rulebooks `gate-house-standard.md`'s migration
checklist explicitly targets" — 43 *rulebooks*, not 43 *roles*, in that
context). No stale *role* name (e.g. an old name for `implementation`,
`qa`, `review`, `verify`) was found anywhere in README.md, `plugin.json`,
or `marketplace.json` — the only naming duplication is the deliberate,
already-tracked `coding`-directory-vs-`implementation`-role doubling
(README.md:11-14, `directive.sh`'s NAMING NOTE per issue-64 record §(h)).
I could not independently verify requirement 4's "per the 43-role
taxonomy" clause against a taxonomy document, because no such document is
present in this repo; flagging this as **unverifiable from this repo
alone** rather than asserting compliance.

## 8. Summary table

| Issue claim | Status | Evidence |
|---|---|---|
| (a) §15 no real sha verification | **confirmed live** | §2 above |
| (b) hunt reset not wired (lifetime cap) | **confirmed live** | §3 above |
| (c) state.sh dead code, old vocabulary | **confirmed live** | §4 above |
| (d) coding-progress-gate comment, old path | **confirmed live** | §5 above |
| hooks.json matcher vs. code coverage | **confirmed gap** (`Workflow`) | §6 above |
| README/manifest ghost files | **confirmed** (`canon-scripts.md`) | §7 above |
| README/manifest stale role names | not found (only pre-existing tracked doubling) | §7 above |
| core #75 precondition | **landed** (external repo) | §1 above |
| on-the-record #182 precondition | **unverified from this repo** | §1 above |
