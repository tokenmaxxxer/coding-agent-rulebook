# tokenmaxxxer / coding-agent-rulebook

The `coding` role on contract v3. A coding session is spawned with two
plugin sets installed: this marketplace's plugins (`coding`, the steering
trio `blueprint`, `no-mock`, `no-footgun`, and the methodology trio
`proposal-shape`, `record-shape`, `survey-order`), and the
[tokenmaxxxer-core](https://github.com/tokenmaxxxer/tokenmaxxxer-core)
plugins (`core`, `terse`, `freelunch`, `scout`). Core owns the interaction
protocol — issue in, two-phase PR out (research/survey/proposal → human
review Approve → execution), branch `issue-<n>/implementation`, record at
`docs/issue-<n>/reports/implementation.md`. (The plugin directory is still
named `coding` — a deliberate, tracked naming doubling with the
`implementation` role name used everywhere else; see
`coding/hooks/directive.sh`.)

The stack's thesis is unchanged: **the generation layer generates;
verification lives elsewhere** — with qa, review, verify, and the human's
PR review. terse, freelunch, and scout were promoted to the core
marketplace (they are role-agnostic); dispatch retired (contract v3 IS
dispatch, mechanized); warrant's proposal-freeze/approval machinery
retired (core's approval-gate owns the human gate); doctrine's placement
gates retired (core's board-gate R1 owns layout). The full position paper
remains at [docs/reports/generation-is-all-you-need.md](docs/reports/generation-is-all-you-need.md).

## What is here

    coding/hooks/directive.sh           SessionStart — the four facets:
                                        codebase/ecosystem research, write-set
                                        survey (a new dep or env var is a
                                        decision), build-proposal fields,
                                        judgment (scope-exceeded stop rule,
                                        honest claims, "What did not work",
                                        placement ladder, hunt cadence)
    coding/hooks/state.sh               SessionStart — rebuilds open-unit
                                        context from the issue branch + PR
                                        review state
    coding/hooks/coding-progress-gate.sh  s15: a blocking verify finding
                                        blocks build commits until a
                                        resolved_findings entry (sha
                                        adjacent to the finding's own id or
                                        verify.md mention) + finder re-clear;
                                        also honors CODING_CYCLE_OFF
    coding/hooks/hunt-guard.sh + hunt-state.sh
                                        the rotating adversarial hunter
                                        (one at a time, stances rotate,
                                        session cap WARRANT_HUNT_MAX)
    blueprint/ no-mock/ no-footgun/     steering plugins, unchanged
    proposal-shape/                     phase-1 proposal shape gate (own
                                        directive + PreToolUse gate on
                                        docs/issue-<n>/proposals/*.md)
    record-shape/                       phase-2 record shape gate (own
                                        directive + PreToolUse gate on
                                        docs/issue-<n>/reports/implementation.md)
    survey-order/                       research-before-proposal ordering
                                        gate (own directive + PreToolUse gate)
    tests/                              repo-level checks (never installed)

## Record vocabulary

`loop_state`: `proposed, approved, landed` (+ `findings-resolved` per s15;
terminal: `landed`). Signals: commit shas landed, `resolved_findings:`
naming the finder path and finder-record sha, `## What did not work`.

## Install

    claude plugin marketplace add tokenmaxxxer/coding-agent-rulebook
    claude plugin install coding@tokenmaxxxer-coding

Kill switches: `CODING_CYCLE_OFF=1` (coding's directive/state), `WARRANT_OFF=1`
(the rotating hunter), `WARRANT_HUNT_MAX` (session dispatch cap, default 3),
`PROPOSAL_SHAPE_OFF=1` + `PROPOSAL_SHAPE_GATE_OFF=1` (proposal-shape's
directive and gate respectively), `RECORD_SHAPE_OFF=1` +
`RECORD_SHAPE_GATE_OFF=1` (record-shape's directive and gate), and
`SURVEY_ORDER_OFF=1` + `SURVEY_ORDER_GATE_OFF=1` (survey-order's directive
and gate).

## Run the checks

All five gates (`coding-progress-gate.sh`, `proposal-shape-gate.sh`,
`record-shape-gate.sh`, `survey-order-gate.sh`, plus `hunt-guard.sh`/
`hunt-state.sh`/`state.sh`) source core's gate-house standard
(`core/hooks/lib/gate-lib.sh`/`gate-lib.py`, issue #72) — reference only,
never vendored (`docs/handbooks/canon-scripts.md`). Set
`CLAUDE_PLUGIN_ROOT_CORE` to your `tokenmaxxxer-core` checkout's `core/`
directory before running these locally; a real plugin-marketplace install
resolves it automatically.

    /bin/bash tests/parse-check.sh
    /bin/bash tests/run-gate-tests.sh
    /bin/bash tests/deny-only-check.sh
    /bin/bash tests/methodology-plugins-tests.sh
    /bin/bash coding/hooks/tests/coding-progress-gate-tests.sh
    /bin/bash proposal-shape/hooks/tests/proposal-shape-tests.sh
    /bin/bash record-shape/hooks/tests/record-shape-tests.sh
    /bin/bash survey-order/hooks/tests/survey-order-tests.sh
    "$CLAUDE_PLUGIN_ROOT_CORE/hooks/tests/compliance-check.sh" .
