---
status: final
---

# Handoff protocol

Coding's role section under the shared role-handoff contract. This document
describes only how the coding role behaves against whatever
`docs/specs/role-handoff-contract.md` the work repo carries — it does not
itself define or certify enforcement of that contract.

## 1. Where the contract lives

The authoritative contract is the work repo's own
`docs/specs/role-handoff-contract.md`, resolved from the git root of the
session's current working directory. Coding does not walk up parent
directories, does not reference any sibling checkout, and does not compare
against another repo's copy of this file — the contract holds only within
the single repository coding is working in.

## 2. Absence behavior

If the work repo has no `docs/specs/role-handoff-contract.md`, coding
refuses handoff-protocol actions with the message "this repo has no
collaboration contract yet." This is an honest failure, never a silent
pass: coding does not fall back to some other repo's contract and does not
proceed as if a contract were in force.

## 3. Accepts

When a contract is present, coding accepts:

- `hypothesis` (product's spec to build against)
- `feasibility-record` (feasibility's verdict on a hypothesis)
- `finding` (review's per-item record — a `verdict: Absent|Incorrect|Surface`
  finding is coding's route back into a fix)

Coding must refuse `qa-state`, `review-record` (as a whole record — only its
inline `finding` blocks are accepted), and `ops-state`.

There is no SHA pin and no external original to compare a handed-over
artifact against — coding's own repo is the only source of truth it reads,
so no pin concept applies here.

## 4. Produces

- `build-proposal` at `docs/proposals/<date>-build-<slug>.md`
- per-subject record at `docs/reports/records/<subject>/coding.md`

## 5. Stops

Coding stops and refuses to proceed when:

1. The work repo has no `docs/specs/role-handoff-contract.md` ("this repo
   has no collaboration contract yet" — section 2).
2. It is handed an artifact whose declared `kind` is not in coding's
   accepts list (section 3).
3. It finds an existing record already present at a path owned by a
   different role; it reports the conflict rather than overwriting it.

## Scope note

This document states only how coding behaves against a contract the work
repo already carries. It does not build, wire, or certify any enforcement
gate for these rules, and it does not amend the contract itself.
