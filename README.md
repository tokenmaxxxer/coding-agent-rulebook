# tokenmaxxxer / coding-agent-rulebook

The `coding` role on contract v3. A coding session is spawned with two
plugin sets installed: this marketplace's plugins (`coding`, plus the
steering trio `blueprint`, `no-mock`, `no-footgun`), and the
[tokenmaxxxer-core](https://github.com/tokenmaxxxer/tokenmaxxxer-core)
plugins (`core`, `terse`, `freelunch`, `scout`). Core owns the interaction
protocol — issue in, two-phase PR out (research/survey/proposal → human
review Approve → execution), branch `issue-<n>/coding`, record at
`docs/issue-<n>/reports/coding.md`.

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
    coding/hooks/record-fields-gate.sh  s20 minimum content on the record
    coding/hooks/coding-progress-gate.sh  s15: a blocking verify finding
                                        blocks build commits until
                                        resolved_findings + finder re-clear
    coding/hooks/trailer-gate.sh        commits staging docs/issue-<n>/** carry
                                        `Subject: issue-<n>`
    coding/hooks/handbook-trigger-gate.sh  s21 same-turn handbook sync
    coding/hooks/hunt-guard.sh + hunt-state.sh + agents/warrant-hunter.md
                                        the rotating adversarial hunter
                                        (one at a time, stances rotate)
    blueprint/ no-mock/ no-footgun/     steering plugins, unchanged
    tests/                              repo-level checks (never installed)

## Record vocabulary

`loop_state`: `proposed, approved, landed` (+ `findings-resolved` per s15;
terminal: `landed`). Signals: commit shas landed, `resolved_findings:`
naming the finder path and finder-record sha, `## What did not work`.

## Install

    claude plugin marketplace add tokenmaxxxer/coding-agent-rulebook
    claude plugin install coding@tokenmaxxxer-coding

Kill switch: `CODING_CYCLE_OFF=1`.

## Run the checks

    /bin/bash tests/parse-check.sh
    /bin/bash tests/run-gate-tests.sh
    /bin/bash tests/deny-only-check.sh
