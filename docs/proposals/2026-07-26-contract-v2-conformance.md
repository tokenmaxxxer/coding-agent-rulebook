---
status: landed
files:
  - docs/specs/handoff-protocol.md
  - warrant/hooks/scope-gate.sh
  - doctrine/hooks/placement-gate.sh
---

# Bring coding's handoff section and gates up to contract v2 (blackboard/event model)

## Request

`docs/specs/role-handoff-contract.md` (root `tokenmaxxxer` repo, landed at
commit `b240ec4`, `status: final`) replaced the v1 one-shot parcel-handoff
model (ACCEPTS/refuse at a single moment) with a v2 shared-blackboard model:
roles read/write/wake from a common board instead of accepting or refusing
a handoff parcel. Per the contract's own scope line ("Landing this contract
in each rulebook is separate, one proposal per repo"), this proposal
commissions that landing for the coding role only: rewriting coding's home
section for the v1 handoff text, and the two gates that currently touch
handoff-adjacent enforcement, to match the v2 shape. This is a proposal
only — it does not implement any of the rewrites itself.

## Constraints that change what gets built

- Coding's v1 handoff section already lives at
  `docs/specs/handoff-protocol.md` (not `README.md` — this placement was
  itself decided by the prior proposal
  `docs/proposals/2026-07-26-role-protocol-section.md`, which put it under
  `docs/specs/` as a normative doc a code change can invalidate, distinct
  from `README.md`'s human-facing bundle intro). The current file's
  sections are `## 1. Where the contract lives`, `## 2. Absence behavior`,
  `## 3. Accepts`, `## 4. Produces`, `## 5. Stops`, and a `## Scope note`
  disclaiming that the document "does not build, wire, or certify any
  enforcement gate for these rules."
- The current `## 3. Accepts` section reads (verbatim):

  > When a contract is present, coding accepts:
  > - `hypothesis` (product's spec to build against)
  > - `feasibility-record` (feasibility's verdict on a hypothesis)
  > - `finding` (review's per-item record — a `verdict: Absent|Incorrect|Surface`
  >   finding is coding's route back into a fix)
  >
  > Coding must refuse `qa-state`, `review-record` (as a whole record — only
  > its inline `finding` blocks are accepted), and `ops-state`.

  This is the v1 ACCEPTS/refuse-whole-kind model the contract's §4 replaces.
  It is also already stale against the current contract's kind table: v1's
  `qa-state`/`ops-state` kinds do not exist in v2 (§2's table has
  `qa-record` and `ops-record` instead), and v1 never granted coding a wake
  on a feasibility `verdict: go` or on qa's defect verdicts at all — v2 §3
  adds both.
- Neither `warrant/hooks/scope-gate.sh` nor `doctrine/hooks/placement-gate.sh`
  currently contains any `kind:`-parsing logic or any read-refusal logic at
  all — confirmed by grepping both files for `kind` (no match in either) and
  by `handoff-protocol.md`'s own `## Scope note`, which states the document
  "does not build, wire, or certify any enforcement gate for these rules."
  The only frontmatter-parsing regex in either gate is
  `scope-gate.sh`'s `STATUS = re.compile(r"^status:\s*([A-Za-z]+)\s*(?:#.*)?$", re.M)`
  (line 41), which parses a proposal's `status:` field, not any record's
  `kind:` field, and already tolerates a trailing comment
  (`status: approved  # go` parses as `approved`). There is therefore no
  existing kind-parsing regex in this repo to find and fix in the sense the
  contract's §2 hunt anecdote describes (`kind: x  # note` silently
  bypassed) — that failure mode has not yet been introduced into this
  repo's gates, and this proposal's gate work must not introduce it either
  when it adds the first kind-aware check (see "What will be done" below).
- `scope-gate.sh` already has, and keeps, an unrelated allow-all-of-`docs/`
  carve-out at lines 279-280 (`if relative.split("/")[0] == "docs" or
  "/docs/" in "/" + relative: allow()`) — this is the "warrant's
  `scope-gate.sh` allows any write under `docs/` unconditionally, regardless
  of an approved proposal's `files:` write set" tension the contract's §11
  names verbatim as "carried over, unenforced." The contract explicitly
  states "this proposal does not add the gate" at the contract level; this
  coding-repo proposal is the "each rulebook's own responsibility" instance
  the contract defers to, but even here the recommendation is a narrow
  addition (see below), not a rewrite of that carve-out — widening it further
  risks conflicting with `doctrine`'s own claim on `docs/` placement.
- `placement-gate.sh` enforces bucket placement only (`decisions/`,
  `handbooks/`, `reports/`, `specs/`, `proposals/`, `_assets/`); it has no
  concept of "role" or "kind" at all today. `docs/reports/records/<subject>/coding.md`
  and `docs/proposals/<date>-build-<slug>.md` both already land inside
  buckets the gate recognizes (`reports/` and `proposals/` respectively), so
  no bucket-list change is needed — only the new ownership/kind check
  described below.

## What will be done

1. **Rewrite `docs/specs/handoff-protocol.md` §3 "Accepts" into a v2
   "Wakes-on" section**, replacing the ACCEPTS/refuse-list model with
   contract §3's coding row verbatim:
   - coding wakes on: a feasibility `verdict: go`; a `qa-record` defect
     carrying a human is-this-a-defect verdict; a `finding` with
     `addressed_to: coding`.
   - Delete the "Coding must refuse `qa-state`, `review-record` …, `ops-state`"
     refuse-list sentence entirely — v2 has no refuse-at-handoff concept; a
     role may always READ any record (contract §4).

2. **Add a "Read / Depends-on / Never-overwrite" section** replacing the
   old accept/refuse framing, transcribing contract §4's coding-specific
   rows:
   - READ: broad, unconditional — coding may read every other role's
     record on the board for context; reading is never a violation.
   - DEPENDS-ON (narrow): coding's conclusions may be built only on
     `hypothesis`, `feasibility-record`, and `finding` blocks addressed to
     it — not on `qa-record`, `review-record`, `product-record`, or
     `ops-record` content directly (those may be read but not cited as the
     basis for a coding decision).
   - NEVER-OVERWRITE: coding writes only
     `docs/proposals/<date>-build-<slug>.md` (`kind: build-proposal`) and
     `docs/reports/records/<subject>/coding.md` (`kind: coding-record`),
     per contract §11's ownership table. Carry forward contract §11's
     rule: finding an existing record already present at a path owned by
     another role means refuse-and-report, not overwrite-or-merge.

3. **Add a "Blackboard record spec" section**, transcribing contract §2's
   two coding rows and §7's authority rule:
   - `build-proposal`: `loop_state` vocabulary `proposed, approved,
     landed`; required fields `files:` (write-set freeze list),
     `## Request`, `## Constraints`, `## What will be done`,
     `## Out of scope`.
   - `coding-record`: same `loop_state` vocabulary as `build-proposal`,
     plus `finding-response` sub-entries (see item 4 below); required
     fields: pointer to the active `build-proposal`, commit shas landed.
   - State §7's authority rule explicitly: `loop_state` is the one part of
     coding's internal state a downstream role's WAKES-ON check may depend
     on; a transition coding completes internally but does not reflect
     onto the board's `loop_state` has not, for contract purposes,
     completed.

4. **Add a "Finding back-edge" section**, transcribing contract §5 scoped
   to coding as an addressed role:
   - coding is the addressed role for qa's defect findings (a `qa-record`
     defect carrying a human is-this-a-defect verdict) and for any role's
     `finding` with `addressed_to: coding`.
   - Closing out a finding requires a `finding-response` entry in
     `coding.md` with: the finding reference (record path + finding
     identifier), the action taken or the decline reason, and — when code
     changed — proof of fix (commit sha or targeted re-run result). An
     entry missing any of the three parts does not close the finding
     (contract §5, "an entry missing any of these three parts does not
     close the finding").
   - State the qa↔coding cycle-termination rule from contract §6
     verbatim in substance: a `finding` from qa produces a
     `finding-response` from coding; coding's fix produces a commit, which
     wakes qa again; the cycle terminates only when qa's resulting wake
     produces either `loop_state: verified-fixed` with no new finding, or
     a genuinely new finding (not a restatement of an already-filed,
     unresolved one).

5. **Add a "Loop termination" section**, transcribing contract §6's general
   rule as it applies to coding: a wake is consumed only by writing the
   resulting record entry (a `loop_state` change, a new `finding-response`,
   or equivalent); leaving the board byte-identical to what woke coding
   means the wake was not consumed and fires no further wake.

6. **Rewrite `docs/specs/handoff-protocol.md` §5 "Stops"** to drop item 2
   ("handed an artifact whose declared `kind` is not in coding's accepts
   list") — v2 has no accepts-list refusal, since READ is unconditional and
   DEPENDS-ON is a citation discipline, not a read gate. Keep item 1 (no
   `docs/specs/role-handoff-contract.md` in the work repo → "this repo has
   no collaboration contract yet") and item 3 (existing record at another
   role's owned path → refuse and report), both of which contract v2
   carries forward unchanged (§11, §4's "READ/DEPENDS-ON add semantics on
   top of an unchanged ownership rule").

7. **`warrant/hooks/scope-gate.sh`**: no read-refusal logic exists to
   delete (confirmed above — the gate has never parsed `kind:` and has no
   read-side check at all; it only gates writes). The one addition this
   proposal commissions is a DEPENDS-ON-adjacent, mechanically-detectable
   check consistent with contract §14's own limit ("mechanical checks are
   not substantive checks" — §11's ownership table "is a table, not a
   gate" unless a rulebook's own hook adds one): when a `build-proposal`'s
   frontmatter is being parsed for the existing `STATUS` regex, add a
   parallel `KIND` regex using the same comment-tolerant shape already
   proven at line 41, e.g.:
   `KIND = re.compile(r"^kind:\s*(\S+)\s*(?:#.*)?$", re.M)`
   — matching `kind: build-proposal  # re-scoped` correctly, per contract
   §2's rule ("`kind` parsing by any gate must tolerate a trailing comment
   on the line … a regex anchored to end-of-line with no comment tolerance
   is a gate defect, not a contract violation by the record's author") and
   §14's caution that `kind` is self-declared and unverified — this check
   only confirms the declared value, it does not validate content against
   it. Use this to refuse a coding-authored proposal file whose `kind` is
   present but not `build-proposal` (a mechanically detectable NEVER-OVERWRITE
   violation: coding's write landing under `docs/proposals/` with the wrong
   declared kind is a strong signal of writing into product's `hypothesis`
   lane, both of which share the `docs/proposals/` directory per contract
   §11's "`docs/proposals/` stays shared between product and coding,
   disambiguated by filename tag" rule). Do not touch the existing
   `docs/`-carve-out at lines 279-280 — that tension is explicitly named as
   "carried over, unenforced" by contract §11 and out of scope for a narrow
   kind-check addition.

8. **`doctrine/hooks/placement-gate.sh`**: add the repo-has-no-contract
   refusal path coding's §5 item 1 requires (currently this check exists
   only in prose in `handoff-protocol.md`, not in any hook — confirmed by
   grepping `placement-gate.sh` for "contract", no match). Concretely: when
   a write targets `docs/proposals/<date>-build-<slug>.md` or
   `docs/reports/records/<subject>/coding.md` (coding's two owned paths per
   contract §11) and `docs/specs/role-handoff-contract.md` does not exist
   in the work repo, refuse with the message
   `"this repo has no collaboration contract yet"` — the exact string
   `handoff-protocol.md` §2 already commits to, now enforced instead of
   only stated. This is the one item explicitly carried from the "repo-local
   round" — `handoff-protocol.md` §2's "Absence behavior" section already
   states this refusal in prose; wiring it into `placement-gate.sh` (the
   only gate in this repo that inspects `docs/` paths pre-write) closes the
   gap between the documented rule and its enforcement, consistent with the
   contract's own framing in §11 ("enforcing it is each role's own
   rulebook's responsibility (a `placement-gate.sh`-style check), same as
   v1").

## Write set

- `docs/specs/handoff-protocol.md` — rewrite §3 into WAKES-ON, add
  READ/DEPENDS-ON/NEVER-OVERWRITE, blackboard record spec, finding
  back-edge, and loop-termination sections; trim §5 "Stops" to drop the
  accepts-list refusal item.
- `warrant/hooks/scope-gate.sh` — add a comment-tolerant `KIND` regex
  paralleling the existing `STATUS` regex, and a mechanical
  wrong-declared-kind refusal scoped to coding's own proposal writes under
  `docs/proposals/`.
- `doctrine/hooks/placement-gate.sh` — add a refusal, for writes to
  coding's two owned paths, when `docs/specs/role-handoff-contract.md` is
  absent from the work repo, using the exact message string
  `"this repo has no collaboration contract yet"`.

## Out of scope

- No build, no code changes, no commit — this document is a proposal only,
  per the task brief and per this repo's own `warrant` protocol (a proposal
  freezes intent; a separate approved build executes it).
- Changing `docs/specs/role-handoff-contract.md` itself — it is the landed
  source in the root `tokenmaxxxer` repo, not something coding edits (same
  boundary the prior `2026-07-26-role-protocol-section.md` proposal
  states).
- The other five role rulebooks (qa, feasibility, product, ops, review) and
  their own contract-v2 landings — each gets its own proposal per the
  contract's own scope line.
- Widening `scope-gate.sh`'s existing `docs/`-carve-out (lines 279-280) —
  named "carried over, unenforced" by the contract and left alone here.
- Building an automated WAKES-ON watcher — contract §3 states explicitly
  that no such watcher exists yet and a human reads the board and matches
  it against the table; this proposal does not invent one.
- Any change to `doctrine/hooks/hooks.json` registration wiring beyond what
  is already required to keep `placement-gate.sh` running — no new hook
  file is introduced by this proposal (unlike the separate, unrelated
  `staleness-gate.sh` commissioned by `2026-07-26-role-protocol-section.md`
  for the SHA-pin question, which this proposal does not touch).

## How you will know it worked

`docs/specs/handoff-protocol.md` contains no "Accepts"/refuse-list section
and no reference to `qa-state` or `ops-state`; it contains WAKES-ON,
READ/DEPENDS-ON/NEVER-OVERWRITE, blackboard record spec, finding
back-edge, and loop-termination sections that a reader can map 1:1 onto
contract §§2-7's coding-specific rows without opening the root contract.
`warrant/hooks/scope-gate.sh` parses `kind:` with the same comment-tolerant
shape as its existing `status:` regex and refuses a coding-owned proposal
write carrying a wrong declared kind. `doctrine/hooks/placement-gate.sh`
refuses a write to either of coding's owned paths when the work repo has
no `docs/specs/role-handoff-contract.md`, using the exact absence-behavior
message already documented in `handoff-protocol.md` §2.
