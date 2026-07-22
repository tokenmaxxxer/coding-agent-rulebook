# warrant

One approval gate at the front of the work, and none after it. The failure this
targets: an agent that starts editing before anyone agreed what it was building,
then widens as it goes, so what lands is nobody's decision — least of all in a
form a later session can reconstruct.

A request becomes a **proposal**: what was asked (quoted), the constraints
gathered so far, what will be done, what is deliberately out of scope, how you
will know it worked, and the **write set** — the paths the work may touch.
Approving it freezes that set. From there the build runs uninterrupted.

## The shape

```
docs/proposals/2026-07-22-store-sqlite.md
---
status: approved          # proposed -> approved -> landed
files:
  - src/store.py
---
```

The state lives in the repository, not in the conversation: `status` says where
the unit is, the branch and its commits say how far it got. A session that dies
mid-unit loses nothing — the next one reads the same two things.

Every commit for the unit carries its warrant:

```
Proposal: docs/proposals/2026-07-22-store-sqlite.md
```

so `git log --grep "Proposal: <path>"` answers "what shipped for this" with no
index to maintain. Trailers survive rebase and cherry-pick, and `git merge
--squash` keeps them in the prepared message.

## Three layers of the protocol

**`UserPromptSubmit` directive** — the protocol. Write the proposal and end the
turn; on approval build without stopping; when the work turns out to need a path
outside the write set, finish what the proposal covers and report rather than
widening or asking mid-build.

**`PreToolUse` gate** — the mechanical half, armed only while exactly one
proposal is `approved`. An edit outside the frozen write set is refused. A
commit without the trailer is refused. And because approval covers the work, the
shell is granted by default while a unit is in flight — `pytest`, `npm install`,
whatever the build needs — with two classes withheld: landing steps (`push`,
`merge`, `rebase`, `reset --hard`, branch deletion) because landing is the
user's call, and destructive ones (`rm -r`, `sudo`, piping into a shell) because
those should never ride in on a build approval. Withheld is not refused: the
normal permission prompt decides.

**`SessionStart` state** — reads the proposals and git, and reports open units:
awaiting approval, or approved with N commits so far.

## Hunters

Right after the proposal is written, and again right before the work lands, one
background agent goes out and the turn carries on without it. It gets a single
stance and the diff of that transition, and it returns at most one finding —
with a command that reproduces it and the wrong output that command produces —
or nothing. It never blocks the conversation and never gates the work.

Only three things count as a finding: a guard that stopped working without
saying so, two rules that are each right alone and wrong together, and a rule
that cannot hold as written. No reproduction, no finding; a plausible concern
the human has to triage costs more than it saves.

The diff is a seed, not a fence. A defect written once tends to get pasted five
times, so the hunter follows its pattern across the repository with grep. That
reach is what makes the anchoring rules load-bearing: it runs things before
reading them, never opens `docs/decisions/`, `docs/specs/`, or
`docs/handbooks/` (they argue for the design a real finding has to contradict),
holds its stance even when the code makes the stance look wrong, and takes that
stance from the dispatch count rather than picking whichever seems apt — the
apt-seeming one is whatever the code just suggested.

Runaway agents are bounded by machinery, not by asking:

- the agent type omits `Agent`/`Task`/`Workflow`, so nesting is impossible by
  definition rather than by instruction
- `hunt-guard.sh` (`PreToolUse`) enforces one hunter at a time and a session cap
  (`WARRANT_HUNT_MAX`, default 3)
- `hunt-state.sh` drops the lock on `SubagentStop` and clears both files at
  `SessionStart`

Killing a hunter that hangs is **not** possible from a shell hook. The lock
carries its start time so a stale one is at least visible and can be stopped
deliberately. Release is also approximate: `SubagentStop` does not say which
subagent stopped, so an unrelated worker finishing can drop a live hunter's
lock. That makes single-flight the common case rather than a guarantee; it never
becomes unbounded, because what actually bounds cost is the session cap.

This is developer self-check, not QA. It claims no coverage, accumulates
nothing, returns no pass verdict, and gates nothing.

## The record a stranger can read

Two things a finished unit leaves behind that the code cannot show.

**What did not work.** The proposal grows a section during the build, appended
at the moment something fails rather than saved for landing — by landing the
failure has left the model's context and what gets written is a summary of the
success. Two conditions fire it: something was written and then undone, or
something expected to hold did not. One line each. Not a transcript, not every
attempt, and not a worker's internal dead ends, which stay with the worker. What
belongs there is only what the next person would otherwise try again.

**Hunt records.** Both dispatches append a section to one file per unit,
`docs/reports/<date>-hunt-<proposal-slug>.md`, carrying the stance, the verdict,
and the seed — including the runs that found nothing, because a probe nobody
recorded reads exactly like a probe nobody ran. Its frontmatter names the
proposal, which attaches the record to its unit the same way the commit trailer
does. The hunter appends blindly (`test -f`, then a shell redirect) rather than
reading the earlier sections, which would aim it at the previous stances'
leftovers.

Together with the proposal itself and `git log --grep`, that is the onboarding
surface: what was asked, what the plan was, which commits implemented it, what
was probed, and what already fell over.

## Composing with the rest of the stack

freelunch decides *how* the approved work executes — the write set is its
fan-out ownership map. doctrine decides *where* documents land, and owns the
`docs/proposals/` bucket this plugin writes into. warrant decides only what may
begin, and when.

The pre-task gate does not contradict freelunch's ban on mid-task pausing: that
rule forbids stopping in the middle, and this one only ever asks before the
start. After approval there is exactly one more exchange — the one where the
work is reported.

## What is verified, and what is not

The gate is deterministic and tested against a decision table: paths in and out
of the write set, traversal (`tests/../src/x.py`), empty and over-broad write
sets, `git -C . commit` and `git  commit` spellings of the trailer rule,
`status: Approved` and trailing comments, malformed frontmatter, and monorepo
proposal directories the gate does not reach. Six silent failures were found
that way and closed; the rule that came out of it is that a gate may fail open
on things outside itself (no `python3`, an unreadable payload) but never on
input it can see and cannot parse — an unreadable warrant is how a gate quietly
stops existing.

The protocol half is prompt text and was exercised across multi-turn sessions:
propose-and-stop, approve-and-build, resume in a brand-new session, and stop at
the write set with a report instead of widening. It is not guaranteed the way
the gate is.

The hunt guard's limits are tested the same way as the gate: concurrent
dispatch refused, cap reached and refused, nested dispatch refused, ordinary
workers unaffected, and — after these were themselves found by trial hunters —
the lock released between a unit's two intended dispatches, the count cleared at
session start, and a directory that is not a git repository still bounded rather
than silently unlimited.

Hunter yield is measured on four runs, which is not enough to generalise: three
under the current contract returned three reproduced findings, all in code
written minutes earlier, which is the easiest target there is. An earlier run
under a diff-scoped contract found a kill switch that `X_OFF=0` silently
disabled across thirteen hooks, on a surface no diff had touched — that one is
why the diff became a seed instead of a fence.

Neither record has been produced by a real session yet. Those rules are written
and unmeasured.

## Kill switch

```sh
export WARRANT_OFF=1
```

Disables every hook in the plugin — protocol, gates, state, and hunters. Any
other value, including `0`, `false`, `no`, and `off`, leaves them running.
