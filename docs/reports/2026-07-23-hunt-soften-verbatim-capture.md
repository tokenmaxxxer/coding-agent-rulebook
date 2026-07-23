---
proposal: docs/proposals/2026-07-23-soften-verbatim-capture.md
---

# Hunt record — soften-verbatim-capture

## after-proposal — stance 0: assume the gate just touched is bypassable — find the bypass

Verdict: FINDING — the proposal's own carve-out clause is a sanctioned bypass of the scrub guard it adds in the same breath.

Kind: composition

Seed: docs/proposals/2026-07-23-soften-verbatim-capture.md — the warrant rewording constraint: "replace 'the request quoted verbatim' with 'the request's intent in one or two paraphrased sentences; quote only a short phrase when exact wording changes what gets built.'" plus, as a separate sentence, "Add a sensitive-info guard line ... strip credentials, secrets, tokens, personal data, and internal URLs before writing the record."

### Reproduce
Apply the proposed instruction text literally (as an agent writing a proposal body would) to a sample request that contains a secret whose exact value is load-bearing for what gets built:

Input request: "Use the API key sk-live-abc123xyz to configure the Stripe webhook; the retry count must be exactly 3."

Follow the two clauses in the order the proposal states them:
1. Paraphrase clause: "quote only a short phrase when exact wording changes what gets built" — the API key's exact string IS what gets built (auth to a specific endpoint), so this clause explicitly licenses quoting `sk-live-abc123xyz` verbatim in the proposal body.
2. Scrub clause: "strip credentials, secrets, tokens ... before writing the record" — this is a separate, later sentence with no stated precedence over clause 1, and no instruction that it overrides the "quote a short phrase" permission.

Resulting proposal body (produced by literally following both instructions in sequence):

"## Request (intent)
User wants the Stripe webhook configured using API key `sk-live-abc123xyz` (exact wording preserved since the key's value determines what gets built); retry count 3."

### Observed
The written record contains the live credential, because the "quote a short phrase for exact wording" carve-out is textually a green light to quote precisely the kind of string (a key/token) the scrub guard exists to strip — and nothing in the proposed wording tells the agent which instruction wins when they conflict on the same span of text. Two individually-sensible rules (allow a verbatim short phrase; strip secrets) compose into "write the secret verbatim, labeled as a permitted short phrase."

### Expected
The scrub guard should either (a) be stated as taking precedence over the short-phrase quoting exception, or (b) the short-phrase exception should itself exclude anything matching the categories the scrub line names (credentials, secrets, tokens, personal data, internal URLs), so a case like an API key that is simultaneously "exact wording that changes what gets built" and "a secret" cannot be quoted into the record.

## before-landing — stance 1: assume this change and another plugin's rule cancel each other — find the pair

Verdict: FINDING — dispatch's own unmodified "quote the approval" merge rule re-permits verbatim capture two lines below the scrub rule the proposal just added, in the same file.
Kind: composition
Seed: warrant/hooks/directive.sh:37 and dispatch/hooks/directive.sh:27 softened verbatim capture into paraphrase-plus-mandatory-scrub for the ISSUE record. The proposal's write set is limited to those two lines; it left dispatch/hooks/directive.sh's MERGE ONLY ON EXPLICIT APPROVAL paragraph (a few lines below the edited one, same file) untouched.

### Reproduce
```
git show soften-verbatim-capture:dispatch/hooks/directive.sh | sed -n '26,32p'
```

### Observed
```
- A REQUIREMENT the user gives -> record it as an ISSUE before starting (open one, or append to the open one it belongs to). The issue records the request's intent in paraphrase — not a verbatim paste of the user's message — after stripping any credential, secret, token, personal data, or internal URL; nothing stripped is ever quoted back, even when its exact wording seems load-bearing.
...
MERGE ONLY ON EXPLICIT APPROVAL, AND RECORD IT. ... Before merging, post a PR comment quoting the approval. Do not merge while a question you asked the user is still unanswered.
```
The ISSUE line now carries a hard rule — "nothing stripped is ever quoted back, even when its exact wording seems load-bearing" — but five lines later, in the same directive block, the approval-recording rule still says "post a PR comment quoting the approval," with no scrub step at all. An agent following the directive literally quotes the user's raw approval turn (which can carry anything the user typed in that message, including a pasted credential or token used to authorize the merge, e.g. "yes, ship it — CI token is ghp_xxx if you need it") straight into a public PR comment, the exact leak the new scrub line exists to prevent for the issue text. The permission in the second rule cancels the refusal just established in the first, inside one file, one directive block.

### Expected
The scrub guard added by this change should either apply directive-wide (any record written under dispatch's mirror-to-git rule gets the strip-then-paraphrase treatment) or the approval-quoting line should itself be re-worded to scrub before quoting — otherwise the directive contradicts itself: one paragraph says sensitive material is never quoted back, the next mandates quoting the user's message verbatim.
