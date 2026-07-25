---
status: landed
files:
  - docs/specs/handoff-protocol.md
---

## Intent

The handoff contract holds only within a single git repository. This rulebook is a plugin: it will be installed into and pointed at a real work repo, and today's sibling-directory layout under `tokenmaxxxer/` is only the development setup, not a structural fact any gate may rely on. Any gate logic that reaches outside its own repo — walking up parent directories, referencing the root `tokenmaxxxer` checkout, comparing against another repo's git history — is structurally wrong. That is what broke the SHA-pin checks added in the other five rulebooks (commits cfd2fc8/7096485/5ca4f59/9eec5ab/f07a6da). This repo never got its own build: `2026-07-26-role-protocol-section.md` sits `proposed`, recommending `docs/specs/handoff-protocol.md` plus a new `doctrine/hooks/staleness-gate.sh`. This proposal supersedes `2026-07-26-role-protocol-section.md` in full — it is not amended or marked withdrawn by this document, only superseded in intent — and commissions the role section without any pin or staleness comparison.

## Constraints

- No parent-directory walk, no reference to `tokenmaxxxer`, no comparison to another repo's git history or SHA, anywhere in the commissioned content.
- The section documents behavior only; it does not itself define a gate script in this round.
- Structure follows the same four-part shape used by the other five repos' role sections (contract location, absence behavior, no pin, scope note).

## What will be done

- `docs/specs/handoff-protocol.md`: write the coding role's "Handoff protocol" section, structured in four parts: (1) the authoritative contract is the work repo's own `docs/specs/role-handoff-contract.md`, resolved from the git root of the session's current working directory; (2) if absent, handoff-protocol actions should be refused with the message "this repo has no collaboration contract yet" — honest failure, never silent pass; (3) there is no SHA pin and no external original to compare against, so no pin concept applies; (4) this document describes only how the coding role behaves against whatever contract the work repo carries — it does not certify enforcement.

## Out of scope

- No `doctrine/hooks/staleness-gate.sh` or any other new gate script — there is nothing to compare against, so a staleness gate is void, not merely deferred.
- Building and wiring an actual enforcement gate for this rule in `doctrine` (or any other coding-rulebook plugin) is out of scope for this proposal — it is future work, to be commissioned separately once a specific gate owner is chosen.
- The other five rulebooks (qa, feasibility, product, ops, review).
- The root `tokenmaxxxer` repo itself.
- The `warrant` and `doctrine` plugins beyond the scope note above.

## How you'll know it worked

`docs/specs/handoff-protocol.md` exists, contains no reference to `tokenmaxxxer` or to a pinned SHA, and states the four-part structure above. `2026-07-26-role-protocol-section.md` is understood to be superseded by this proposal (its own `status` field remains outside this write set and is not edited here). No new hook file is added under `doctrine/hooks/`.
