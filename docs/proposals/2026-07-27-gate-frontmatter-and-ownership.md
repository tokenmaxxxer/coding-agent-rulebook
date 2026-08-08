---
status: landed
files:
  - warrant/hooks/scope-gate.sh
  - doctrine/hooks/placement-gate.sh
  - docs/specs/handoff-protocol.md
  - docs/proposals/2026-07-27-gate-frontmatter-and-ownership.md
---

# Proposal: fix scope-gate's frontmatter detection so it actually engages

## Intent

Under contract-v2 the blackboard lives at `docs/reports/records/<subject>/<role>.md`;
each role's gate must enforce §11 subject-scoped path-ownership (a role writes
only its own `<role>.md`), and must parse the repo's ACTUAL proposal/record
format, not a format the repo never uses. Today, `warrant/hooks/scope-gate.sh`
requires literal `---` YAML frontmatter delimiters in proposals, but proposals
in this repo do not consistently produce a parseable block for the gate — the
gate stands down (`exit 1`) instead of enforcing the write-set / proposal
discipline for the coding role. This was surfaced live in the full-gate relay
(`docs/reports/2026-07-27-full-gate-relay-simulation.md`, relay-sim-v2). This
proposal restores real enforcement: scope-gate must engage against proposals
in the format this repo actually writes, and placement-gate's owned-path
handling must continue to target the subject-scoped record path correctly.

## Constraints

- The frozen shared contract (contract-v2) is verbatim and non-negotiable:
  blackboard lives at `docs/reports/records/<subject>/<role>.md`; each role's
  gate enforces §11 subject-scoped path-ownership (a role writes only its own
  `<role>.md`); each gate must parse the repo's actual proposal/record format.
- Fix only the detection/parsing layer. Do not change what counts as
  "approved," the write-set semantics, or the ownership model itself.
- Match the comment-tolerant, YAML-ish `status:`/`files:` parsing style the
  other gates in this repo already use for proposals/records — do not invent
  a new format or a new frontmatter convention.
- No behavior change for repos/formats outside this one; this is a rulebook
  repo local to itself (its own git repo), and this proposal does not touch
  the other five rulebook repos or relay-sim-v2.
- Never push, never open a PR, from this local-only repo as part of this
  proposal's own preparation.

## What will be done

1. In `warrant/hooks/scope-gate.sh`, adjust the `frontmatter()` detection so
   it recognizes this repo's actual proposal frontmatter form — the same
   YAML-ish `status:` / `files:` block already parsed comment-tolerantly by
   the other gates — instead of only accepting a strict, literal leading
   `---` fence with a matching closing `---`. The goal is that a real
   proposal already in the repo's own format causes the gate to engage
   (evaluate `status`/`files` and enforce the write-set) rather than
   silently treating the file as malformed or standing the gate down.
2. Re-check the malformed/approved classification logic downstream of the
   fixed detection so a correctly-recognized block still flows into the
   existing `STATUS`/`KNOWN_STATES` checks unchanged.
3. In `doctrine/hooks/placement-gate.sh`, confirm (and adjust if needed) that
   the owned-path handling for `is_coding_record` targets the subject-scoped
   record path `docs/reports/records/<subject>/coding.md` specifically —
   i.e., that ownership is checked per-subject/per-role, not just against the
   `records/` directory generally — consistent with §11.
4. Update `docs/specs/handoff-protocol.md` only if this work changes a
   documented format detail (e.g., the description of what counts as valid
   proposal frontmatter); otherwise leave it untouched.

## Out of scope

- The other five rulebook repos.
- relay-sim-v2 and any changes to the relay simulation itself.
- Changing the write-set semantics, the ownership model, or the definition of
  "approved."
- Any actual code changes — this document is a proposal only; the fix
  described above is not started here.

## How we know it worked

- With a real proposal present in the repo's actual format (the same
  `status:`/`files:` frontmatter form already used by proposals in
  `docs/proposals/`), `warrant/hooks/scope-gate.sh` engages: it parses the
  block, evaluates `status`, and enforces the frozen write-set — it does not
  `exit 1` / stand down for a well-formed proposal in this repo's own format.
- A foreign-role write to another role's subject-scoped record path (e.g. a
  non-coding role attempting to write
  `docs/reports/records/<subject>/coding.md`, or vice versa) is refused by
  `doctrine/hooks/placement-gate.sh`.
- Re-running (or re-simulating) the scenario from
  `docs/reports/2026-07-27-full-gate-relay-simulation.md` no longer shows
  scope-gate standing down when a real, correctly-formatted proposal is
  present.

## What did not work

- `docs/reports/2026-07-27-full-gate-relay-simulation.md`, cited above as the
  scenario that surfaced the stand-down live, does not exist in this repo
  (checked at implementation time). It could not be re-run or re-simulated
  to confirm the fix against the original failure; the fix was instead
  validated directly by parsing every real proposal in `docs/proposals/`
  and by exercising the hooks end-to-end (see below).
- The original `frontmatter()` (strict `text.startswith("---")` +
  `text.find("\n---", 3)`) was tested against every proposal currently in
  `docs/proposals/` before changing anything, and it parsed all of them
  correctly — every proposal in this repo already uses a literal `---`-
  fenced block. No on-disk proposal reproduces a stand-down caused by
  frontmatter detection specifically. The detection was still widened to be
  comment-tolerant on the fence line itself (trailing whitespace/comment,
  CRLF) per the proposal's instruction, since the narrower, stricter form was
  the named target of the fix, but this could not be validated against a
  real repro of the cited failure.
- End-to-end engage/refuse behavior could not be exercised in this repo's
  actual working tree as-is: `docs/proposals/2026-07-26-contract-v2-
  conformance.md` is already `status: approved`, and its files: list is
  frozen (out of this proposal's write set — it is not touched here), so
  flipping this proposal to `approved` produces two simultaneously-approved
  proposals. scope-gate correctly refuses to pick one (`len(approved) != 1`)
  and stands down with the "all marked approved" message — a different,
  already-correct code path, not the frontmatter bug this proposal targets.
  Verified instead in an isolated copy of the repo
  (outside this git tree) with `2026-07-26-contract-v2-conformance.md`
  patched to `status: landed` only in that copy: with exactly one proposal
  approved, scope-gate engaged, allowed writes inside the frozen set,
  refused a write outside it (`exit 2`), refused a commit missing the
  `Proposal:` trailer (`exit 2`), and allowed one carrying it (`exit 0`).
  Nothing in the real repo's git tree was changed for this test.
- `doctrine/hooks/placement-gate.sh`'s `is_coding_record` check was
  confirmed to already target the subject-scoped path correctly (`len(
  directories) == 4`, `docs/reports/records/<subject>/coding.md`) — no code
  change was needed or made there. Testing also showed the gate does not
  itself refuse a foreign role writing another role's file under the same
  subject (e.g. `docs/reports/records/<subject>/qa.md` from a coding
  session) — that path falls through to the ordinary `reports/` bucket
  allow, exit 0. Refusing cross-role writes at that granularity is a
  broader ownership-enforcement change that this proposal's own scope
  excludes ("do not change ... the ownership model itself"), so the "foreign
  write is refused" line in *How we know it worked* is not fully met by
  `placement-gate.sh` as scoped here; only the owned-path *targeting* was in
  scope, and that was confirmed correct.
