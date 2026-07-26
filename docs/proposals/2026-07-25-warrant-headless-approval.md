---
date: 2026-07-25
status: withdrawn
files:
  - warrant/hooks/scope-gate.sh
---

# Getting warrant's approval through a headless run — withdrawn

**Withdrawn 2026-07-26. The observation below stands; the conclusion drawn
from it was wrong.**

## What was observed (still true)

An empty repository holding only `calc.py`, with the coding role brought up
headless through `muster`:

```
$ python3 spawn.py coding "add subtract(a, b) to calc.py" -C <empty repo>
[coding] 9 plugins

docs/proposals/2026-07-25-add-subtract-to-calc.md written with status: proposed
  write set: calc.py, test_calc.py
Approve and I will flip it to status: approved, cut a branch, and implement.

$ git status --short
?? docs/
```

The rulebook worked: six `docs/` buckets appeared, so doctrine ran, and warrant
wrote a proposal naming its write set. Code changes: zero. Re-running says one
is already written and reuses it, so the behaviour is idempotent. Work stops at
exactly one transition: `proposed → approved`.

## Why it was withdrawn

The proposal called that stop a blocker and asked to pass it with a single-use
approval token, copying `review-cycle`. Two things make that wrong.

**The pattern it copied no longer exists.** `review-cycle/hooks/state-gate.sh`
states plainly that it "no longer consults approval tokens or any other
side-channel". The proposal cited a mechanism that had already been removed.

**The contract puts this stop in the human's seat on purpose.**
`docs/specs/role-handoff-contract.md` v2 (`status: final`) §8 names four
judgment points reserved for a human, and **approving scope changes** is one of
them. warrant halting a headless run at `proposed → approved` is that contract
being honoured, not a defect to route around.

So the right reading of the reproduction is the opposite of the one this
proposal drew: the coding role is *supposed* to stop there, and an unattended
path through it is not something to design.

## What this does not settle

Whether an adjudicating agent in a separate context could ever hold that seat is
a live question, but it is a change to §8 of the contract — the handoff
contract's own concern, decided there, not worked around in a single rulebook's
hook.
