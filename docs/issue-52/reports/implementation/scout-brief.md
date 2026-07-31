---
subject: issue-52
role: implementation
---

# Scout brief — implementation-domain proposal/deliverable norms

Mode: parallel WebSearch, 4 angles, 1 sweep stage, 0 deepening stages
(saturated at judge point 1 — see below). Wall-clock well under budget.

## Angles run

1. RFC / engineering design-doc templates (Google-lineage, Pragmatic
   Engineer survey of industry practice).
2. IEEE/ISO/IEC 29148 Software Requirements Specification structure.
3. Definition of Done — agile deliverable-completeness checklists.
4. Architecture Decision Record (ADR) template and rationale practice
   (Nygard format, adr.github.io, AWS/Microsoft/TechTarget guidance).

## Category must-bes (converge across angles)

- **Problem/context stated before the decision** (RFC "Context/Problem
  Statement"; SRS "Introduction" + "Overview"; ADR "Context").
- **The decision or proposed change stated explicitly, separate from its
  justification** (RFC "Proposed solution"; ADR "Decision"; SRS
  "Specific Requirements").
- **Rationale/consequences as its own section, including alternatives
  considered and trade-offs** — the single most consistent must-be across
  all four angles (ADR "Consequences," explicitly recommended to include
  pros/cons and confidence level; RFC "Consequences/trade-offs";
  DoD frames completeness itself as a negotiated, team-owned criterion
  set, i.e. the *why* of each criterion should be recoverable, not just
  the checklist).
- **One document, one decision** — ADR best practice explicitly warns
  against bundling multiple decisions into one record; SRS scopes to one
  system/product overview per document.
- **A deliverable is "done" against an explicit, previously-agreed
  criteria list**, not a private judgment call — the Definition-of-Done
  literature's central point, and the one place non-team-authored /
  externally-imposed DoDs are flagged as correlating with *lower*
  performance than team-authored ones.

## Performance axes the field competes on

1. **Length discipline vs. completeness** — Google's own backend RFC
   template is cited as a cautionary example: ballooned to ~14 pages of
   required sections, later criticized by its own authors/reviewers as
   mostly superfluous, with too much implementation detail crowding out
   the actual decision. ADR guidance is the opposite pole: "should fit on
   one page; longer usually means multiple decisions bundled."
2. **Enforced structure vs. team-owned structure** — DoD literature's
   strongest empirical signal: checklists a team writes for itself
   correlate with high performance; ones imposed from outside correlate
   with worse outcomes, even though the criteria may look identical on
   paper.

## Adopt / skip

- **Adopt**: ADR's Context → Decision → Consequences (rationale +
  alternatives + trade-offs) skeleton as the backbone for the *rationale*
  half of both phase-1 proposal norms and phase-2 deliverable norms —
  it's the one shape independently reinforced by RFC and SRS practice
  too, and it's short enough not to hit the Google-RFC bloat failure
  mode.
- **Adopt**: one-document-one-decision scoping — keep each phase-1
  proposal scoped to the issue's decision, not a bundle.
- **Skip**: full IEEE 29148 SRS apparatus (traceability matrices,
  verification-method-per-requirement tables) — built for large
  contractual systems engineering, disproportionate to a single-issue,
  single-role proposal; would recreate the Google-RFC bloat failure mode
  this survey specifically flags.
- **Skip**: importing a generic agile DoD checklist wholesale — this
  role's phase-2 boundary already excludes verification/testing
  judgment (owned by qa/review/verify per `directive.sh`'s YOU_DECIDE);
  a DoD checklist's core content (test coverage, review sign-off) is
  already someone else's job here, so only the *structural* DoD lesson
  (agreed-upon, explicit, recoverable criteria — not the specific
  criteria) transfers.

## Gap line (survey vs. field)

- Current proposal shape already has an implicit RFC skeleton (Request /
  Constraints / What will be done / Out of scope) but is **missing** the
  one must-be every angle converged on: a named rationale/alternatives/
  trade-offs section distinct from "what will be done."
- Current deliverable shape already has DoD-style completeness bullets
  (scope rule, honest-claims, doc placement, hunt cadence) but has **no
  named required-fields list** a gate could check mechanically — the
  DoD literature's point that criteria must be explicit and recoverable,
  not just narrated in directive prose, is not met today.
- Neither shape currently requires an explicit "alternatives considered"
  or "confidence/risk" statement anywhere — present in ADR guidance, and
  a candidate section this issue's proposal will recommend adding to
  both phase-1 and phase-2 norms.

## Segment fit

This role writes single-issue, single-branch proposals and delivery
records read by one human approver — closest fit is ADR's scale (one
decision, one page, explicit rationale), not SRS's contractual scale or
Google's early bloated RFC scale.

## Sources

- https://newsletter.pragmaticengineer.com/p/rfcs-and-design-docs
- https://blog.pragmaticengineer.com/rfcs-and-design-docs/
- https://newsletter.pragmaticengineer.com/p/software-engineering-rfc-and-design
- https://www.reqview.com/doc/iso-iec-ieee-29148-templates/
- https://www.well-architected-guide.com/documents/iso-iec-ieee-29148-template/
- https://plane.so/blog/definition-of-done-dod-checklist-examples-for-agile-teams
- https://www.programstrategyhq.com/post/dor-and-dod-checklists
- https://adr.github.io/
- https://www.techtarget.com/searchapparchitecture/tip/4-best-practices-for-creating-architecture-decision-records
- https://aws.amazon.com/blogs/architecture/master-architecture-decision-records-adrs-best-practices-for-effective-decision-making/
