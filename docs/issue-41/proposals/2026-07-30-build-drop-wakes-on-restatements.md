---
kind: build-proposal
loop_state: proposed
---

files: docs/specs/handoff-protocol.md

## Request

Wake-routing ownership migration step 3: this repo's rulebook must state
nothing about which role a record state summons — that canon now lives at
on-the-record's `docs/specs/wake-routing.md`. Audit every WAKES-ON/wake
mention in this repo's rulebook files (excluding `docs/issue-*/`), keep
statements about coding's own record states/format, and strip or repoint
to the host doc anything naming which role a state summons, including
coding's own trigger list if restated.

## Constraints

- Repo-wide grep for `wakes|wake-on|WAKES-ON` outside `docs/issue-*/`
  only; historical `docs/proposals/` and `docs/reports/` records are not
  live rulebook statements and stay untouched.
- Preserve record-format material (loop_state vocabulary, required
  fields, produces paths, stops, read/depends-on/never-overwrite) — only
  the routing (which role summons which) is removed or repointed.

## What will be done

- `docs/specs/handoff-protocol.md` section 3 ("Wakes-on"): drop the
  bulleted trigger list naming other roles' states, repoint to
  on-the-record's `docs/specs/wake-routing.md`.
- Section 7 ("Finding back-edge"): drop the qa<->coding cycle-termination
  wording naming which role a fix commit wakes, repoint to the same host
  doc; keep the finding-response closure requirements (coding's own
  record format).

## Out of scope

- `coding/hooks/directive.sh` — its WAKES-ON mention only states where
  WAKES-ON reads from for coding's own record, names no other role, and
  is out of scope for this change.
- `docs/proposals/2026-07-26-contract-v2-conformance.md` and other
  `docs/reports/`/`docs/proposals/` history — frozen records of past
  decisions, not live rulebook text.

## How you'll know it worked

`grep -rliE 'wakes|wake-on|WAKES-ON' --include=*.md --include=*.sh .`
outside `docs/issue-*/` still lists `docs/specs/handoff-protocol.md` (for
its remaining record-format prose) and the historical proposal, but the
file no longer names any role's routing trigger — verified by re-reading
sections 3 and 7 for role names tied to wake conditions.
