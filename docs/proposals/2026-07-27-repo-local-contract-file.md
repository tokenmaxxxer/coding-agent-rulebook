---
status: approved
files:
  - docs/specs/role-handoff-contract.md
  - docs/proposals/2026-07-27-repo-local-contract-file.md
---

## Intent

`doctrine/hooks/placement-gate.sh` (line 134) checks for `docs/specs/role-handoff-contract.md` at the repo root and, finding it absent, refuses every gated call with "this repo has no collaboration contract yet" (line 136). This repo does carry the v2 contract shape, but under a different filename: `docs/specs/handoff-protocol.md`, which itself documents (per `2026-07-26-repo-local-contract.md`) that the authoritative contract a work repo must carry is named `docs/specs/role-handoff-contract.md`. This repo never produced its own file under that exact name — it only produced the section describing the rule. Rule 0 (contract-presence) therefore fails on this repo's own gates, and the subject-scoped ownership test cases that depend on Rule 0 passing cannot run green. This proposal commissions the missing file, sourced from this repo's existing `docs/specs/handoff-protocol.md`, so the gate finds what it is already looking for.

## Constraints

- Content is sourced from this repo's own `docs/specs/handoff-protocol.md` — no cross-repo copying, no reference to sibling rulebooks' contract files, no reference to the root `tokenmaxxxer` checkout.
- No SHA pin and no staleness comparison, consistent with `2026-07-26-repo-local-contract.md`'s prior finding that no external original exists to pin against.
- `doctrine/hooks/placement-gate.sh` is not touched by this proposal: its check (line 134) already looks for the correct path; the gap is the missing file, not the gate logic.
- No new hook scripts are introduced.

## What will be done

- Create `docs/specs/role-handoff-contract.md` containing the v2 handoff contract content, carried over from this repo's `docs/specs/handoff-protocol.md` under the filename the gate resolves against.
- Confirm (read-only, not a write in this round) whether `warrant/hooks/scope-gate.sh` or any gate-test runner hardcodes a different contract path or asserts contract-absent as expected behavior; this repo currently has no `run-gate-tests.sh`, so no test-expectation file is touched in this pass. If a future scan finds such an assumption, it is out of scope here and would need its own proposal.

## Out of scope

- Editing `doctrine/hooks/placement-gate.sh` or `warrant/hooks/scope-gate.sh` logic — their path resolution is already correct.
- Writing a new gate-test runner script; none exists in this repo today.
- Any other repo under `tokenmaxxxer/`, merging branches, or remote push.
- Re-authoring the contract's content from scratch — it is carried over from `docs/specs/handoff-protocol.md`, not redesigned.

## How you'll know it worked

`docs/specs/role-handoff-contract.md` exists at the repo root path `doctrine/hooks/placement-gate.sh` checks (line 134). Gate calls that previously refused with "this repo has no collaboration contract yet" no longer hit that refusal branch via Rule 0, and the subject-scoped ownership test cases that were blocked solely by contract-absence can execute and pass.

## What did not work

- Looked for an existing `run-gate-tests.sh` or any test-runner script to update per the "confirm gate-test runner expectations" step of the execution instructions. None exists anywhere in this repo (`find` over the tree turned up no `*test*` file at all, only hook scripts under `*/hooks/`). This matches the proposal's own prior finding — there is no test-expectation file to touch, so this step is a documented no-op rather than a completed edit.
- Verification was instead done by invoking `doctrine/hooks/placement-gate.sh` directly with synthetic PreToolUse JSON payloads (a `docs/proposals/*-build-*.md` path and a `docs/reports/records/<subject>/coding.md` path) before and after creating the contract file, since no formal harness exists to run.
