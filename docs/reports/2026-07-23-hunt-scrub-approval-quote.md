---
proposal: docs/proposals/2026-07-23-scrub-approval-quote.md
---

# Hunt record — scrub-approval-quote

## after-proposal — stance 2: assume this guard goes silent when its own input is malformed — make it go silent

Verdict: NO FINDING
Seed: proposal rewords the "post a PR comment quoting the approval" instruction in dispatch/hooks/directive.sh to pass through the same scrub as the rest of the file.

Checked whether any actual code (not just LLM-directed prose) implements the "scrub"/"strip credential, secret, token, PII" logic anywhere the proposal's change would run through, since a silent-failure-on-malformed-input finding requires an executable parser to break. `grep -rl "scrub\|strip any credential\|nothing stripped"` across the repo turns up only two files, dispatch/hooks/directive.sh and warrant/hooks/directive.sh, and in both cases the text is inside a `cat <<'EOF' ... EOF` heredoc emitted verbatim as an `<...-directive>` prompt block for the agent to follow — there is no shell function, sed/grep filter, or any other runtime mechanism that actually performs scrubbing or parses the "approval" text. The only real input-parsing logic in dispatch/hooks/directive.sh is the unrelated `DISPATCH_OFF` case statement, which the proposal does not touch and whose write set is limited to this one file. Downstream consumers of the emitted directive (hooks.json entries wiring UserPromptSubmit) just pipe stdout into the prompt; nothing programmatically parses the `<dispatch-directive>` XML-like tags either, so there's no parser to feed malformed content into. No executable guard exists here that could go silent on malformed input as a result of this change; no reproduction is possible.
