---
status: approved
files:
  - freelunch/hooks/freelunch.sh
  - freelunch/.claude-plugin/plugin.json
---

# Proposal: freelunch directive must state it IS the user's standing opt-in for subagent/Workflow dispatch

## Intent

A session following this rulebook in another repo computed width 5 →
FAN-OUT correctly, then refused to dispatch because the Claude Code harness
gates the `Workflow` tool behind explicit user opt-in, and the session
generalized that gate into "subagent execution is forbidden without a user
request" — falling back to inline solo work, violating freelunch's own
DELEGATED rule. The user confirmed the rulebook's intent is that
delegation/parallelism is mandatory once the mechanical threshold is met; a
harness-level gate meant to stop an agent from silently going multi-agent on
its own initiative should never be triggered by a session that is already
executing a user-installed hook directive telling it to do exactly that.

## Constraints

- The harness's `Workflow` opt-in gate itself is out of our control; the fix
  is directive wording only, not a harness change.
- The harness's stated opt-in conditions include "the user invoked a skill
  or slash command whose instructions tell you to call Workflow" — a
  user-installed `UserPromptSubmit` hook directive that the user has
  configured to run on every prompt is the same class of standing
  instruction and should satisfy the same gate.
- Must not weaken the mechanical LEAN FAN-OUT / LEAN SOLO threshold rule or
  any other existing enforcement in `freelunch.sh`.

## What will be done

1. Add to the freelunch directive prose in `freelunch/hooks/freelunch.sh`,
   near the LEAN FAN-OUT block and its "4+ workers → dispatch via a Workflow
   script" clause, an explicit statement that this directive IS the user's
   standing opt-in for background subagent dispatch and for `Workflow`
   execution at 4+ workers: a harness-level opt-in gate is satisfied by this
   directive's presence in the session and is never grounds for falling back
   to inline solo work.
2. Add a degradation order for environments where `Workflow` is genuinely
   unavailable (not merely gated): (a) single-batch `Agent`-tool dispatch of
   all workers in one message, then (b) one delegated worker via the `Agent`
   tool. Inline solo remains forbidden whenever any dispatch mechanism
   (`Workflow` or `Agent`) works; it is reserved only for the case where no
   dispatch mechanism is available at all.
3. Patch-bump `freelunch/.claude-plugin/plugin.json` version.
4. Normalize the `FREELUNCH_OFF` kill-switch match (hunter finding): the
   case-sensitive whitelist `""|0|false|no|off` currently means any
   unrecognized spelling (`False`, `OFF`, stray whitespace, `0x0`, ...)
   silently disables the entire directive — including this proposal's new
   opt-in clause — with no error surfaced anywhere. Lowercase and trim the
   value before matching so common case/whitespace variants of the
   recognized spellings resolve correctly, and treat any value that still
   doesn't match a recognized on/off spelling as fail-open: print a one-line
   stderr warning naming the unrecognized value and then emit the directive
   normally rather than silently suppressing it.

## Out of scope

- `warrant`/`hunt-guard` or any other plugin's wording.
- Other plugins' directive prose.
- Harness behavior or the `Workflow` gate's implementation itself.

## How we know it worked

- The freelunch directive text contains the explicit opt-in clause tying
  this directive's presence to satisfaction of the harness `Workflow` gate,
  and contains the degradation order (batch `Agent` dispatch → one delegated
  worker → inline only if neither works).
- A session reading the directive at width >= 4 cannot derive "subagents are
  forbidden without an explicit user request" from the harness's `Workflow`
  opt-in gate — the directive itself is legible as that opt-in.
