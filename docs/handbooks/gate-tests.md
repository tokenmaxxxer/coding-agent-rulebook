# Running this repo's gate tests

All five of this repo's `*-gate.sh` scripts (`coding-progress-gate.sh`,
`proposal-shape-gate.sh`, `record-shape-gate.sh`, `survey-order-gate.sh`,
plus `hunt-guard.sh`/`hunt-state.sh`/`state.sh`) source core's gate-house
standard (`core/hooks/lib/gate-lib.sh` + `gate-lib.py`, issue #72) —
referenced, never vendored, per this handbook's reference-not-copy rule.

To run any of this repo's test scripts locally (not through an installed
plugin marketplace, where `CLAUDE_PLUGIN_ROOT_CORE` is resolved
automatically), set it to your `tokenmaxxxer-core` checkout's `core/`
directory first:

    export CLAUDE_PLUGIN_ROOT_CORE=/path/to/tokenmaxxxer-core/core

Then run (see README.md "Run the checks" for the full list):

    bash tests/parse-check.sh
    bash tests/run-gate-tests.sh
    bash tests/deny-only-check.sh
    bash tests/methodology-plugins-tests.sh
    bash coding/hooks/tests/coding-progress-gate-tests.sh
    bash proposal-shape/hooks/tests/proposal-shape-tests.sh
    bash record-shape/hooks/tests/record-shape-tests.sh
    bash survey-order/hooks/tests/survey-order-tests.sh
    "$CLAUDE_PLUGIN_ROOT_CORE/hooks/tests/compliance-check.sh" .

`compliance-check.sh` is the ship-time evidence step: it flags any
`*-gate.sh` that reads a `*_OFF` kill-switch without calling
`gate_kill_switch_active`, or that reconstructs Edit/MultiEdit content by
hand instead of `gate_reconstruct_write`. Run it against the whole repo
root before every phase-2 delivery that touches a gate script.

`tests/run-gate-tests.sh`'s `record-complete`/`record-empty`/`foreign-path`
cases exercise `record-shape/hooks/record-shape-gate.sh` (record-field
checking moved there when `coding`'s own record-fields/trailer gates were
consolidated; issue-64). It carries no trailer-check case — this repo's
current contract (`docs/specs/*.md`) does not require a `Subject:` commit
trailer, and no gate here enforces one.
