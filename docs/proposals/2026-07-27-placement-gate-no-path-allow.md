---
status: approved
files:
  - doctrine/hooks/placement-gate.sh
  - doctrine/hooks/hooks.json
  - doctrine/hooks/run-gate-tests.sh
  - doctrine/.claude-plugin/plugin.json
  - docs/proposals/2026-07-27-placement-gate-no-path-allow.md
---

# Proposal: placement-gate must allow, not refuse, a tool call with no file path

## Intent

`doctrine/hooks/placement-gate.sh` is a write-placement gate: it inspects
`tool_input.file_path`/`notebook_path` before a write and refuses paths that
land under `docs/` outside the six doctrine buckets. Its intake currently
treats "no usable `file_path`/`notebook_path` in `tool_input`" as a reason to
`deny(...)` (exit 2) — see the branch at
`doctrine/hooks/placement-gate.sh:96-98`, which emits "doctrine: refused — no
usable file_path/notebook_path in tool_input; the gate cannot judge a write it
cannot identify" and exits 2. Combined with the fail-closed trap `__fc`
(landed in 7b07d32/503feed/806fa2a/3a2c5cd, `placement-gate.sh:2`) that
converts any non-0/non-2 exit into a deny, and with `hooks.json` registering
this `PreToolUse` hook against matcher `.*` (`doctrine/hooks/hooks.json:24-32`
— every tool, not just `Write|Edit|NotebookEdit`), the practical effect
observed live in another repo is that a read-only `Bash` call (`git log`) and
an `Agent` dispatch — neither of which has a `file_path` in `tool_input` —
are both refused by a gate whose entire stated scope is document placement.
A gate that only knows how to judge writes must treat "no file path" as "not
a write, not my business, allow" — not as an unparseable payload to refuse.

## Constraints

- Fail-closed for genuine internal errors (crashes, exceptions, missing
  python3) is a landed decision (3a2c5cd/503feed/806fa2a) and stays in force;
  this proposal narrows what counts as "an error," it does not touch the
  `__fc` trap mechanism.
- The gate must still refuse writes it genuinely cannot place: a `Write`,
  `Edit`, or `NotebookEdit` call that DOES carry a `file_path`/`notebook_path`
  landing under `docs/` outside the six buckets is unaffected and stays
  denied.
- Malformed JSON or a non-dict `tool_input` (payloads the gate cannot parse
  at all, as opposed to a well-formed payload that simply has no path) keep
  their existing fail-closed `deny(...)` behavior — this proposal only
  changes the specific "parsed fine, but no path field present" branch.

## What will be done

1. In `doctrine/hooks/placement-gate.sh`, change the branch at line 96-98
   (`path = tool_input.get("file_path") or tool_input.get("notebook_path")`
   / `if not isinstance(path, str) or not path: deny(...)`) to call
   `allow()` instead of `deny(...)`. A missing path means the tool call is
   not a file write this gate has jurisdiction over, so the correct verdict
   is "gate stands down," not "refused." Keep it silent (no stderr) on this
   path so a `Bash`/`Agent`/etc. call does not print a spurious "doctrine:
   refused" line before immediately being allowed anyway — reserve stderr
   output for actual denials.
2. In `doctrine/hooks/hooks.json`, narrow the `PreToolUse` matcher for
   `placement-gate.sh` from `.*` to `Write|Edit|NotebookEdit` as defense in
   depth, so the hook is not invoked at all for tools that can never carry a
   `file_path`/`notebook_path`. This is a second, independent fix to the same
   symptom: step 1 makes the gate correct even if invoked broadly; this step
   also stops the unnecessary invocation and matches the hook's documented
   scope (`hooks.json` comment / plugin.json description already say this is
   a write-placement gate).
3. Add regression tests to `doctrine/hooks/run-gate-tests.sh` covering: (a) a
   `Bash` tool call with a `command` field and no `file_path` → allow
   (exit 0); (b) an `Agent`/`Task` dispatch tool call with no `file_path` →
   allow (exit 0); (c) confirm a `Write` call with `file_path` landing under
   `docs/` outside the six buckets is still denied (exit 2) — the existing
   coverage for this must not regress; (d) confirm a `Write` call with no
   `file_path` at all (malformed tool call) now allows rather than denies,
   documenting the intentional behavior change from the old test (if one
   exists) that asserted the opposite.
4. Bump the patch version in `doctrine/.claude-plugin/plugin.json`
   (`0.4.3` -> `0.4.4`).
5. `warrant/hooks/hunt-guard.sh` was checked for the same "no identifiable
   input → refuse" intake pattern and does not have one: it is a
   single-flight/session-cap concurrency gate for background hunters, not a
   path-placement gate, and has no `file_path`/`notebook_path` branch at all
   (confirmed by grep across the file). It is therefore not included in this
   proposal's write set.

## Out of scope

- `warrant/hooks/scope-gate.sh` unknown-status stand-down, already fixed in
  `docs/proposals/2026-07-27-scope-gate-unknown-status-stand-down.md`.
- The other sibling `PreToolUse` gates registered under matcher `.*` in
  `warrant/hooks/hooks.json` (`hunt-guard.sh`, `path-ownership-gate.sh`,
  `build-scope-gate.sh`, `coding-progress-gate.sh`,
  `handbook-trigger-gate.sh`) and in `doctrine/hooks/hooks.json`
  (`record-fields-gate.sh`) — each would need its own no-path-intake audit
  and is not covered here.
- The `__fc` fail-closed trap mechanism itself, and the decision that
  internal errors must fail closed.
- Any plugin other than `doctrine` (and the ruled-out check of
  `warrant/hooks/hunt-guard.sh`).

## How we know it worked

- New regression tests in `doctrine/hooks/run-gate-tests.sh` pass.
- A session in a repo with the `doctrine` plugin installed can run `git log`
  via `Bash` and dispatch an `Agent` without a placement-gate refusal,
  reproducing and resolving the observed transcript scenario.
- A `Write`/`Edit`/`NotebookEdit` call with a `file_path` landing under
  `docs/` outside the six buckets is still refused — misplaced document
  writes remain caught.
