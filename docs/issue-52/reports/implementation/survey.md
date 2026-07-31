---
subject: issue-52
role: implementation
---

# Current-state survey — implementation domain norms (issue #52)

## Write surfaces this issue touches

- `coding/hooks/directive.sh` — the plugin currently instantiating the
  `implementation` role in this repo (plugin name `coding`; role name
  `implementation`, per `subject:`/`role:` frontmatter convention already
  used by issue-53/issue-56). Holds the *only* current statement of
  phase-1 proposal norms (inside `core_role_directive`'s `USE_WHEN` arg —
  RESEARCH / CURRENT-STATE SURVEY / PROPOSAL / ISSUE REFERENCE
  paragraphs) and phase-2 deliverable norms (`PRODUCES` arg — EXECUTION
  JUDGMENT bullets).
- `coding/hooks/hooks.json`, `coding/hooks/coding-progress-gate.sh`,
  `coding/hooks/hunt-guard.sh`, `coding/hooks/hunt-state.sh`,
  `coding/hooks/state.sh` — the plugin's gates. None currently encode a
  document-shape check (no section-presence gate on proposals or
  records); they gate process (loop_state, hunt cadence, Bash
  progress), not document content.
- `docs/issue-53/` and `docs/issue-56/` — the only two prior phase-1
  proposals authored under the current `subject:`/`role:` convention,
  used below as the de facto current template even though no norm
  document names it as one.

## What exists today (as of `main`, `446903b`)

1. **Proposal shape (phase 1).** `directive.sh`'s PROPOSAL paragraph
   requires: `files:` (frozen write set), `## Request`, `## Constraints`,
   `## What will be done`, `## Out of scope`, and "how you'll know it
   worked." No requirement for an explicit alternatives-considered
   section, no requirement for a rationale section distinct from "what
   will be done," no required frontmatter shape stated in the directive
   itself (though both existing proposals use `subject:`/`role:`
   frontmatter by convention, not by written rule).
2. **Deliverable shape (phase 2).** The PRODUCES bullets state: the
   scope-exceeded stop rule, honest-claims/no-mock confirmation,
   `## What did not work`, the doc-placement ladder (env var/config/dep/
   migration → handbook; library-or-format choice or changed
   signature/wire format → `docs/issue-<n>/decisions/`; benchmark/
   investigation numbers → `docs/issue-<n>/reports/`), hunt cadence, and
   `closed_checks:` entries in the record. No required record frontmatter
   schema is stated beyond what `core_role_directive`'s closing `RECORD:`
   line auto-emits (path + phase-gating only).
3. **No document-shape gate exists.** Unlike `coding-progress-gate.sh`
   (which blocks Bash on process state) there is no hook that checks a
   proposal or record file for required sections — conformance today is
   entirely directive-text discipline, unenforced mechanically.
4. **Two prior proposals, both informal single-author documents**, not
   built against any named methodology: issue-53's used an
   Options/numbered-item/"Open questions for the approver" shape;
   issue-56's used a Basis/Plan/Not-in-scope shape. Neither cites a
   rationale format; both are single-page mixed prose+list documents.

## Gaps this issue is meant to close

- No stated *methodology* behind the phase-1 proposal shape (why these
  sections, not others) — it reads as accreted convention, not a
  deliberate adoption.
- No stated *methodology* behind the phase-2 deliverable shape.
- No plugin-level gate enforcing either shape; a proposal or record
  missing a required section currently passes silently.
- No named required-field list for directive/record content that a
  future stub-check-style gate could check against.

## Constraint carried over unchanged

- warrant-hunter stays a core-canon reference (core issue #63), never a
  local copy — already true today (`coding/agents/warrant-hunter.md` was
  the copy; issue-53's phase 1, not yet executed, proposes deleting it in
  favor of the canon original). This proposal does not touch that file.
