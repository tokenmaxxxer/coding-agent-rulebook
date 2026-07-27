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

## before-landing — stance 4: write-set-cannot-carry-the-work

Verdict: FINDING — the log-write-failure warning that observe.sh's own comment says exists "to report once per session rather than letting the record go quiet" is unconditionally swallowed, because the entire python invocation is piped through `2>/dev/null` at the call site (line 122), so the warning never reaches stderr/the user; a sync_agent_dispatch violation is silently un-enforced and unlogged with zero visible signal.
Kind: silent-failure
Seed: freelunch/hooks/observe.sh line 16 FREELUNCH_OFF normalization diff; hunted the write path of the same file (log write / warning emission) for a write-set that cannot actually carry the record it claims to.

### Reproduce
```
cd /home/jwjung/tokenmaxxxer/coding-agent-rulebook
tmpd=$(mktemp -d)
touch "$tmpd/blocker"
export FREELUNCH_OBSERVE_LOG="$tmpd/blocker/sub/log.jsonl"
echo '{"session_id":"s1","tool_name":"Agent","tool_input":{"run_in_background":false}}' \
  | bash freelunch/hooks/observe.sh 2>err.txt 1>out.txt
cat err.txt   # expected the "observation log ... is not writable ... dispatches are going unrecorded" warning
cat out.txt
echo $?
rm -rf "$tmpd" err.txt out.txt
```

### Observed
`err.txt` and `out.txt` are both empty, exit code 0. The `os.makedirs`/`open(log_path, "a")` call fails (parent path is blocked by a file), the except branch's `print(..., file=sys.stderr)` runs inside the python heredoc, but the shell wraps the whole `python3 -c '...' "$LOG"` invocation with `2>/dev/null`, discarding that stderr before it ever leaves the process. The dispatch violation (`sync_agent_dispatch`) is neither logged nor enforced (enforcement also depends on the same write path having succeeded to compute violations — here violations were computed but the row was never persisted), and no operator-visible signal is produced at all: the tool call proceeds exactly as if freelunch weren't installed.

### Expected
When the observation log cannot be written, the warning designed for exactly this case ("An empty observation log otherwise reads as 'no dispatches happened' ... Report once per session rather than letting the record go quiet") should actually reach stderr, not be discarded by the wrapping shell redirect.
