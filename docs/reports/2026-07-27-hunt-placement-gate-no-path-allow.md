---
proposal: docs/proposals/2026-07-27-placement-gate-no-path-allow.md
---

# Hunt record — placement-gate-no-path-allow

## after-proposal — stance 1: assume this change and another plugin's rule cancel each other — find the pair

Verdict: FINDING — the proposal reintroduces an enumerated PreToolUse matcher (`Write|Edit|NotebookEdit`) on `doctrine/hooks/hooks.json`'s placement-gate entry that this same repository already tried and explicitly reverted in commit b0f7a661 ("Both gates enumerated tool names in their matcher; a renamed or added tool would skip them entirely. Now `.*`, with the script deciding."), and it omits `MultiEdit`, which the sibling gate `record-fields-gate.sh` (registered on the SAME `PreToolUse` event in the SAME `doctrine/hooks.json`, targeting writes into the very same `docs/` tree) explicitly documents and handles as a live write tool (`tool in ("Write", "Edit", "MultiEdit")`, doctrine/hooks/record-fields-gate.sh:106). The two gates now disagree about which tools can write into docs/: record-fields-gate treats MultiEdit as in-scope, placement-gate's matcher (post-proposal) does not, so a `MultiEdit` call that writes a misplaced document under `docs/not-a-bucket/...` will invoke record-fields-gate.sh (still matcher `.*`) but never invoke placement-gate.sh at all — the bucket-placement check the proposal itself says "must still stay denied" (Constraints section) silently stops applying to exactly the tool the codebase's own sibling gate treats as a first-class write path into the same directory tree. This is the identical defect class the repo's own commit b0f7a661 named and fixed by moving both `doctrine` and `warrant`'s matchers from enumerated tool lists back to `.*`; this proposal walks it back for `doctrine/hooks/hooks.json` without addressing that MultiEdit is missing, and without revisiting warrant's parallel history of the same mistake.

Kind: composition
Seed: doctrine/hooks/hooks.json:24-32 matcher `.*` -> `Write|Edit|NotebookEdit`; doctrine/hooks/placement-gate.sh:96-98; doctrine/hooks/record-fields-gate.sh (sibling PreToolUse gate on same event, same hooks.json, same docs/ target tree)

### Reproduce
```
cd /home/jwjung/tokenmaxxxer/coding-agent-rulebook
git log --all -S"Both gates enumerated" --oneline
git show b0f7a661 -- doctrine/hooks/hooks.json warrant/hooks/hooks.json
grep -n '"matcher"' doctrine/hooks/hooks.json
grep -n 'tool in (' doctrine/hooks/record-fields-gate.sh
```

### Observed
```
$ git show b0f7a661 -- doctrine/hooks/hooks.json
-        "matcher": "Write|Edit|NotebookEdit",
+        "matcher": ".*",
```
commit message: "Both gates enumerated tool names in their matcher; a renamed or added tool would skip them entirely. Now `.*`, with the script deciding."

Current (post-proposal) state reverts exactly this line:
```
$ grep -n '"matcher"' doctrine/hooks/hooks.json
25:        "matcher": "Write|Edit|NotebookEdit",
34:        "matcher": ".*",
```
and record-fields-gate.sh, on the unchanged `.*` matcher two lines below, explicitly enumerates `MultiEdit` as an in-scope write tool for the same docs/ tree:
```
106:    if tool in ("Write", "Edit", "MultiEdit"):
```
`MultiEdit` appears nowhere in placement-gate's new matcher.

### Expected
Either the matcher stays `.*` (as the prior fix mandated, with the script itself deciding scope — which is exactly what step 1 of this same proposal already does by having the script `allow()` on a missing path), or, if a matcher is enumerated at all, it must include every tool the codebase's own sibling docs/-writing gate (record-fields-gate.sh) already recognizes, including `MultiEdit`. As written, the proposal makes the two gates that share the same `PreToolUse`/same-hooks.json/same-target-tree disagree about which tools they cover, silently exempting `MultiEdit` writes from placement-gate's bucket enforcement while step 1's Constraints section claims that enforcement "is unaffected and stays denied."
