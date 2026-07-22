#!/usr/bin/env bash
# UserPromptSubmit hook: injects the work-unit protocol.
#
# One gate, at the front. Everything after it runs without interruption — which
# is why the proposal has to carry the decisions that would otherwise become
# mid-build questions. freelunch forbids pausing MID-task; a pre-task gate is a
# different thing and the two compose unchanged.
#
# State lives on disk, not in the conversation: the proposal file's status field
# and the git branch survive session death, so state.sh can rebuild the picture
# at session start.
# Kill switch: export WARRANT_OFF=1

if [ -n "$WARRANT_OFF" ]; then
  exit 0
fi

cat <<'EOF'
<warrant-directive priority="high">
STANDING REQUEST FROM THE USER: work in this repository moves through one approval gate at the front. I am asking for the proposal before the code, every time — not as ceremony, as the thing I approve.

SURFACE GATE: applies when a turn would create, modify, or delete repository files as work. Conversation, questions, reading, and analysis are outside it — answer those directly. Once inside, this directive is the protocol until the work lands.

THE UNIT IS A PROPOSAL. One request, one proposal, one branch, one landing. It lives at `docs/proposals/YYYY-MM-DD-<slug>.md` with frontmatter:
```
---
status: proposed        # proposed -> approved -> landed
files:                  # the write set; nothing outside it gets edited
  - path/one.py
  - path/two.py
---
```
and a body of five short sections: the request quoted verbatim; the constraints stated so far that change what gets built; what will be done; what is deliberately out of scope; how you will know it worked. Keep it to what a reader needs — a typo fix is six lines, a subsystem is a page.

THE WRITE SET ANTICIPATES WHAT THE WORK WILL NEED. List every path the change will touch, not just the obvious one: the test file that covers it, `.env.example` when a new variable appears, the dependency manifest when something is added, the migration, the fixture. These are the parts I most want to see before approving — a new dependency or a new environment variable is a decision, and it belongs in the proposal rather than arriving unannounced during the build. Documents under `docs/` are the exception: those are the record the work produces, and they are always writable.

WRITE IT, THEN STOP. Create the proposal, say it is ready, and end the turn. Do not begin the work in the same turn. The proposal file itself is the only write this turn makes.

ON APPROVAL: set `status: approved`, create a branch, and build without stopping. The write set is frozen — every edit lands in a listed path. Choices that come up inside the scope are settled by the proposal's stated constraints and defaults and recorded in `decisions/`; they are never bounced back as questions.

SCOPE EXCEEDED: when the work turns out to need a file outside the write set, finish what the proposal covers, stop, and report what was found. Do not widen the set, do not ask mid-build. The remainder becomes the next proposal.

EVERY COMMIT CARRIES ITS WARRANT: the message ends with a trailer naming the proposal.
```
Proposal: docs/proposals/2026-07-22-<slug>.md
```
`git log --grep` then answers "what shipped for this proposal" without anyone maintaining an index.

ON LANDING: set `status: landed`. The durable parts of the proposal have homes of their own — system design goes to `docs/specs/`, the reason behind a hard-to-reverse choice to `docs/decisions/`, measurements to `docs/reports/`. `specs/` describes the system, so it changes only when the system's design changed; most proposals touch it not at all.

COMPOSITION: freelunch decides how the approved work is executed (solo or fan-out) — the write set is its ownership map. doctrine decides where documents land. This directive decides only what may begin and when.

NEVER:
- starting work in the turn that writes the proposal, or editing a path outside the frozen write set.
- pausing mid-build to ask a question the proposal should have settled.
- committing work without the `Proposal:` trailer.
- a second gate: after approval there is exactly one more exchange, the one where the work is reported.
</warrant-directive>
EOF
exit 0
