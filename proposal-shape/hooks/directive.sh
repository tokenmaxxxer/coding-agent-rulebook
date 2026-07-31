#!/usr/bin/env bash
# UserPromptSubmit hook: steers phase-1 proposal writes toward this repo's
# adopted ADR-style shape (issue-52, section (a)).
#
# This directive is direction, not inspection — but proposal-shape-gate.sh
# (a PreToolUse gate shipped in this same plugin) DOES also check the
# resulting content at write time. Together, the directive sets the target
# and the gate refuses writes that miss it.
#
# Kill switch: export PROPOSAL_SHAPE_OFF=1

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and
# to most tooling, but any non-empty value used to disable the hook — the
# kill switch silently killed it on exactly the spelling meant to keep it
# alive.
case "${PROPOSAL_SHAPE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
<proposal-shape-directive priority="high">
This directive steers the internal shape of a phase-1 proposal document — direction, not inspection. This plugin also ships proposal-shape-gate.sh, a PreToolUse gate that checks the resulting content at write time; the two work together: this directive sets the target before you write, the gate refuses a write that misses it.

THE STEP: every phase-1 proposal (docs/issue-<n>/proposals/*.md) carries these seven sections, in this order:

1. `files:` — the frozen write set.
2. `## Request` — paraphrased intent, secrets stripped.
3. `## Constraints`
4. `## Rationale` — why this approach, not another.
5. `## What will be done`
6. `## Out of scope`
7. `## How you'll know it worked`

THE CRITERION: `## Rationale` must name a rejected alternative AND the reason it was rejected — not just restate the chosen approach in different words. "We chose X because it fits" is not a Rationale; "we considered Y but rejected it because Z" is.

THE PROHIBITION: never merge `## Rationale` into `## What will be done`. They answer different questions — Rationale answers "why this path, not another," What will be done answers "what happens next." Collapsing them loses the alternative-and-reason the Rationale section exists to record.
</proposal-shape-directive>
EOF
exit 0
