---
proposal: docs/proposals/2026-07-27-observe-kill-switch-normalization.md
---

# Hunt record — observe-kill-switch-normalization

## after-proposal — stance 4 (index 3): assume the rule as written cannot hold — find the state nothing maintains

Verdict: NO FINDING
Seed: freelunch.sh:155-161 normalize-then-match FREELUNCH_OFF logic mirrored into observe.sh:16, plus freelunch/.claude-plugin/plugin.json version bump.

Investigation: the change is already landed (commit 3d6a5cb, plugin.json at 0.2.21, proposal status: approved). Verified observe.sh's normalization block against the proposal's success criteria directly:
- `FREELUNCH_OFF=banana` (unrecognized): warns on stderr (`unrecognized FREELUNCH_OFF value 'banana' — treating as not-off, logging will continue`), still logs the row, exit 0 — fail-open as specified.
- Recognized on-values (`1`, ` True `, `YES`, `on`), case/whitespace-insensitive: exit 0, no log row written.
- Recognized not-off values (`0`, `False`, ` `, `""`), including a literal tab-padded `\tfalse\t`: log row written normally.
- The duplicated block's warning message was correctly adapted per-script ("logging will continue" in observe.sh vs "directive will print" in freelunch.sh), not a stale verbatim copy — no message-text drift found.
No dependency on unmaintained state (session-scoped assumptions, missing files, stale env vars) found in the normalization path itself; the pre-existing `python3 ... 2>/dev/null` stderr suppression and the `.unwritable` marker's non-session-scoped lifetime are out of scope for this proposal and were not touched by it.
