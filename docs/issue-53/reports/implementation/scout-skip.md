---
subject: issue-53
role: implementation
---

# Scout skip record

Scouting skipped. Reason: the spec (issue #53, plus core issue #63/#66's
own implementation records, read from the sibling `tokenmaxxxer-core`
checkout) names the exact files to delete, the exact stub shape
(`core_role_directive` call form, checked mechanically by
`core/hooks/tests/stub-check.sh`), and the exact escape hatch
(`RECORD_FIELDS_TERMINAL_STATES`) already. This is the per-rulebook
mechanical follow-up those two core issues explicitly deferred, not a
product-shaped decision needing best-in-class exemplars.

One design decision remains open inside that fixed shape — how to fold
`coding`'s much larger role directive (six sections) into
`core_role_directive`'s four-argument signature — but that is a mapping
choice against an already-fixed contract, not a field to scout
comparable systems for. It is raised as an open question for the
approver in the proposal instead.
