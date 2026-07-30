# Proposal — proposal PRs must reference, never close, their issue

files: `coding/hooks/directive.sh`

## Request (paraphrased intent)

Two of nine phase-1 proposal PRs carried `Closes #n`; merging the
approved proposal closed the issue, and the following phase-2 session
saw a closed issue and silently exited — observed on
`ops-agent-rulebook#21` and this repo's own `coding-agent-rulebook#43`
(PR #44 merged with `Closes #43` in the body). State the rule: phase-1
proposal PRs reference their issue as plain `#n`, never with a closing
keyword; only the phase-2 delivery PR carries `Closes #n`; a phase-2
session finding its issue closed with no delivery landed reports the
anomaly instead of exiting silently.

## Constraints

- This repo carries the `coding` role's own directive only — the general
  two-phase contract (Approve gate, phase boundaries) is core's.
- No enforcement hook; expressed as steering text, consistent with every
  other phase rule already in `directive.sh`.

## What will be done

- Add an "ISSUE REFERENCE, phase-dependent" paragraph to the PROPOSAL
  section of `coding/hooks/directive.sh`, stating: phase-1 PRs use plain
  `#n`, never `Closes`/`Fixes`/`Resolves`; only the phase-2 delivery PR
  carries `Closes #n`; a phase-2 session that finds its issue closed with
  no delivery landed treats it as an anomaly to report.

## Out of scope

- Editing `docs/specs/handoff-protocol.md` or any core-owned protocol
  text.
- Any automated PR-body lint/gate.
- Retroactively reopening issue #43 (already reopened by hand per the
  issue body).

## How you'll know it worked

- `coding/hooks/directive.sh` prints the new paragraph on session start
  for the `coding` role (`bash coding/hooks/directive.sh` with
  `CLAUDE_ROLE=coding` set, manually inspected).
- Future phase-1 proposal PRs opened by this role reference their issue
  as plain `#n` with no closing keyword.
