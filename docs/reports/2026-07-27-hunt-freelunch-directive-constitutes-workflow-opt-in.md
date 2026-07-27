---
proposal: docs/proposals/2026-07-27-freelunch-directive-constitutes-workflow-opt-in.md
---

# Hunt record — freelunch-directive-constitutes-workflow-opt-in

## after-proposal — stance 2: assume this guard goes silent when its own input is malformed

Verdict: FINDING — the FREELUNCH_OFF kill-switch defaults to "off" (directive suppressed, exit 0, no output, no warning) for ANY value not exactly matching the case-sensitive whitelist `""|0|false|no|off`, so a natural typo/case variant (e.g. `False`, `OFF`, trailing/leading whitespace, `0x0`) silently disables the entire directive — including the proposal's new opt-in-for-Workflow-dispatch clause — with no error surfaced anywhere. This directly undermines the proposal's premise that "the directive itself constitutes the standing opt-in": if the directive text never reaches the session because of a stray env-var spelling, there is no opt-in clause present, and nothing tells the session or the user that this happened.
Kind: silent-failure
Seed: freelunch/hooks/freelunch.sh kill-switch case statement (~line 155), guarding the heredoc the proposal edits (LEAN FAN-OUT clause, ~line 170)

### Reproduce
cd /home/jwjung/tokenmaxxxer/coding-agent-rulebook
for v in "0" "False" "OFF" " " "0x0" "no " ""; do
  echo "=== FREELUNCH_OFF='$v' ==="
  FREELUNCH_OFF="$v" bash freelunch/hooks/freelunch.sh | head -1
done

### Observed
FREELUNCH_OFF='0'   -> directive printed (correct, "0" means not-off)
FREELUNCH_OFF='False' -> nothing printed (directive silently suppressed)
FREELUNCH_OFF='OFF'   -> nothing printed
FREELUNCH_OFF=' '     -> nothing printed
FREELUNCH_OFF='0x0'   -> nothing printed
FREELUNCH_OFF='no '   -> nothing printed (trailing space)
FREELUNCH_OFF=''      -> directive printed (correct)
Exit code is always 0; no stderr, no indication the hook chose to suppress itself.

### Expected
Either (a) the match should be case-insensitive / whitespace-trimmed so common spelling variants of "not off" still enable the directive, or (b) any value that isn't recognized as an explicit "off" spelling should fail loudly (stderr warning at minimum) rather than silently falling through to full suppression — especially now that this script is meant to carry the user's standing opt-in for background Workflow/Agent dispatch, so its silent absence has real behavioral consequences (harness gate no longer legibly satisfied) with zero signal to the session or user that it happened.

## before-landing — stance 4 (index 3): assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — freelunch.sh's FREELUNCH_OFF fix (normalize + fail-open-with-warning on unrecognized values) was not applied to its sibling observe.sh, which still silently treats any unrecognized FREELUNCH_OFF value as "off" (no log entry, no stderr warning), so a typo in the kill-switch value silently disables enforcement/telemetry while freelunch.sh (with the identical typo) correctly fails open and keeps printing the directive.
Kind: composition
Seed: commit 5c42a4b, freelunch/hooks/freelunch.sh FREELUNCH_OFF normalization vs freelunch/hooks/observe.sh's unmodified `case "${FREELUNCH_OFF:-}" in ""|0|false|no|off) ;; *) exit 0 ;; esac`

### Reproduce
```
cd coding-agent-rulebook
FREELUNCH_OFF=banana bash freelunch/hooks/freelunch.sh 2>&1 | tail -5
echo '{"tool_name":"Agent","tool_input":{"run_in_background":false}}' \
  | FREELUNCH_OFF=banana FREELUNCH_OBSERVE_LOG=/tmp/obs.jsonl bash freelunch/hooks/observe.sh
cat /tmp/obs.jsonl
```

### Observed
freelunch.sh: prints `freelunch: unrecognized FREELUNCH_OFF value 'banana' — treating as not-off, directive will print` on stderr and still emits the full directive (exit 0, directive present).
observe.sh: exits 0 with no stderr output and writes nothing to the observe log — the sync_agent_dispatch violation in the payload goes completely unrecorded, identical to explicitly setting FREELUNCH_OFF=1, with no warning that the value was unrecognized.

### Expected
Both hooks share the same kill-switch variable and the proposal's own rationale ("An unrecognized value is never silently treated as off... fail-open... never silent suppression") should apply uniformly; observe.sh should normalize/warn the same way instead of silently going dark on any value it doesn't recognize as an explicit off-synonym.
