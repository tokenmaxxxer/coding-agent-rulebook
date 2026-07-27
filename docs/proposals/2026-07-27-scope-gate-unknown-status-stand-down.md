---
status: landed
files:
  - warrant/hooks/scope-gate.sh
  - warrant/hooks/run-gate-tests.sh
  - warrant/.claude-plugin/plugin.json
  - docs/proposals/2026-07-27-scope-gate-unknown-status-stand-down.md
---

# Proposal: scope-gate must warn, not self-lock, on an unknown or malformed proposal status

## Intent

A malformed or unknown proposal `status:` (observed: a proposal file whose
status value is outside `proposed`/`approved`/`landed`, and/or a frontmatter
block missing its closing `---`) drives `warrant/hooks/scope-gate.sh` into its
stand-down branch, which currently exits `1`. The fail-closed trap `__fc`
installed at the top of the script (landed in 503feed/806fa2a/3a2c5cd) treats
any exit code other than `0` (allow) or `2` (deny) as an internal error and
converts it to `exit 2` — a deny. Because this is a `PreToolUse` gate, that
deny applies to every tool call, including `Read` and `Bash`, in every
subsequent turn of the session. The result is a self-lock: the very proposal
file that is broken can no longer be inspected or repaired from inside the
session that hit the problem, because the tools needed to read and fix it are
now themselves denied. The user hit this live in another repo using this
gate and asked for it to be fixed here at the source.

## Constraints

- Fail-closed on genuine internal errors (script crashes, exceptions) is a
  landed decision (3a2c5cd/503feed/806fa2a) and must remain in force. This
  proposal narrows what counts as "genuine internal error," it does not touch
  the `__fc` trap mechanism itself.
- Reads and other analysis-only tool calls are already outside warrant's
  intended enforcement surface by design; the gate should not be the reason a
  session cannot even read a file.
- Do not weaken enforcement for proposals that are well-formed: an
  unrecognized-but-parseable status or missing fence must degrade to a
  warning, not to silent approval of writes.

## What will be done

1. Extend the recognized status vocabulary in `warrant/hooks/scope-gate.sh`
   (`KNOWN_STATES`) to include `withdrawn` and `rejected`, both treated as
   inactive units — ignored by the write-set/approval logic the same way
   `landed` already is.
2. Change the "cannot be read / unknown status" stand-down branch (currently
   `sys.exit(1)` after the "cannot be read — the frontmatter has no closing
   `---`, or its status is not one of proposed/approved/landed" message) to
   exit `0` instead of `1`, after printing the same warning to stderr naming
   the offending proposal file. Exit `0` is a legitimate "allow, gate stands
   down" verdict already recognized by the `__fc` trap, so this stops the
   trap from reclassifying a parseable-but-unrecognized proposal, or a
   frontmatter with no closing fence, as an internal error. Fail-closed
   (`exit 2` via `__fc`) remains reserved for actual script crashes and
   unhandled exceptions.
3. Add regression tests (in `warrant/hooks/run-gate-tests.sh` or an adjacent
   test file following its existing style) covering: (a) a proposal with an
   unrecognized `status:` value, (b) a proposal frontmatter with no closing
   `---`, (c) `status: withdrawn` and `status: rejected` are accepted and
   treated as inactive, and (d) confirm a subsequent `Read`/`Bash` call in
   the same session is not denied after cases (a) and (b).
4. Bump the patch version in `warrant/.claude-plugin/plugin.json`
   (`0.4.1` -> `0.4.2`).
5. No separate status-vocabulary doc was found outside `scope-gate.sh` itself
   during a repo-wide check; if implementation turns up one, update it in the
   same set.

## Out of scope

- Other gate scripts' status vocabularies (e.g. `doctrine/hooks/placement-gate.sh`).
- The fail-closed trap (`__fc`) mechanism itself, and the decision that
  internal errors must fail closed.
- `muster` and any other plugin not named above.

## How we know it worked

- New regression tests pass.
- A repo containing a proposal with `status: withdrawn` (or `rejected`) is
  parsed and ignored correctly, same as `landed`.
- A repo containing a proposal whose frontmatter has no closing `---`, or
  whose status is some other unrecognized value, no longer blocks `Read` or
  `Bash` for the rest of the session — reproducing the observed transcript
  scenario (stand-down exit reclassified by `__fc` into a global deny) as a
  test and showing it now exits `0` with a stderr warning instead.
