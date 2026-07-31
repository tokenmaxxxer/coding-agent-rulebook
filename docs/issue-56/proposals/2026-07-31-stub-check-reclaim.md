---
subject: issue-56
role: implementation
---

# Proposal — reclaim `stub-check.sh` copy (issue-56, phase 2 plan)

## Basis

Survey: `docs/issue-56/reports/implementation/survey.md`. Executes core
issue #69's canon: `docs/handbooks/canon-scripts.md` (core) + the reclaim
procedure in `docs/issue-69/reports/implementation/reclaim-21-copies.md`
(core) + the reference-invocation shape in
`docs/handbooks/role-gates-tests.md` (core, "Canon invocation from a
rulebook").

## Plan (phase 2, on Approve)

1. Delete `coding/hooks/tests/stub-check.sh` (vendored copy).
2. No `hooks.json` change needed — confirmed `coding/hooks/hooks.json` has
   no `stub-check.sh` entry to remove (survey, "current state").
3. Run core's canon copy directly against this repo, from core's own
   install path, per the documented invocation shape:

   ```
   bash /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/tests/stub-check.sh coding
   ```

   (local sibling-checkout path; the marketplace-install form would be
   `"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" coding` —
   noting core's own docs flag this exact resolution as unverified against
   a real marketplace install, so the record states which form actually
   ran.)
4. Record the pass/fail output in `docs/issue-56/reports/implementation.md`
   (phase-2 record), same shape as issue-53's record used for its own
   `stub-check.sh` run.

## Not in scope

- No test-harness entry point exists in this repo to wire the reference
  invocation into permanently (survey gap) — creating one is not asked by
  issue #56's text (which asks only for deletion + one recorded pass) and
  is left for a future issue if wanted.
- No change to `docs/handbooks/canon-scripts.md` adoption in this repo —
  issue #56 doesn't ask for it; noted as a possible future follow-up only.
