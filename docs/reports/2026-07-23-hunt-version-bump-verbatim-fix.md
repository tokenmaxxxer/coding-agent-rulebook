---
proposal: docs/proposals/2026-07-23-version-bump-verbatim-fix.md
---

# Hunt record — version-bump-verbatim-fix

## after-proposal — stance 0: assume the gate just touched is bypassable — find the bypass.

Verdict: FINDING — nothing in the repo enforces that a plugin.json version bump actually reaches the live cache/pin; the exact failure mode the proposal is fixing (source corrected, cache never reinstalled) can recur silently and is currently reproducible on disk.
Kind: silent-failure
Seed: docs/proposals/2026-07-23-version-bump-verbatim-fix.md (bump warrant 0.4.0→0.4.1, dispatch 0.5.0→0.5.1 to force a cache rebuild)

### Reproduce
```
# 1. The source fix (commit c72a9f6, already merged) rewrote the directive text:
grep -n "verbatim\|paraphrase" /home/jwjung/claude-plugins/warrant/hooks/directive.sh

# 2. The live, currently-active cache that sessions actually load from:
grep -n "verbatim\|paraphrase" /home/jwjung/.claude/plugins/cache/tokenmaxxxer/warrant/0.4.0/hooks/directive.sh

# 3. Nothing in the repo checks that installed_plugins.json's pinned version/installPath
#    matches the source plugin.json version, or that a reinstall ran after a bump:
grep -rln "installed_plugins\|plugin\.json" /home/jwjung/claude-plugins --include="*.sh" --include="*.yml" --include="*.yaml"
find /home/jwjung/claude-plugins -iname "*.yml" -o -iname "*.yaml" | grep -i workflow
```

### Observed
- Step 1 shows the repo source already contains the corrected paraphrase wording (line 37: "the request's intent in one or two paraphrased sentences...").
- Step 2 shows the cache that a live session actually reads still contains the pre-fix wording (line 37: "the request quoted verbatim") — the fix has been sitting in git across several merges (c72a9f6 → 806feb1 → 1fa8bc7) without ever reaching a session, because the version field was never bumped for that commit.
- Step 3 returns nothing: there is no CI job, hook, or script anywhere in the repository that compares `installed_plugins.json`'s pinned `version`/`installPath` against each plugin's `.claude-plugin/plugin.json` version, and none that verifies a reinstall was actually run after a version bump.

The proposal's own "How I will know it worked" section is a manual, one-off grep the operator is expected to run by hand ("After reinstall, .../warrant/0.4.1/hooks/directive.sh contains..."); it is not wired into any gate, hook, or automated check. If the version bump lands (as text-only proposals like c72a9f6 already have) but the "operational step, outside the repo write set" reinstall is skipped or forgotten, the corrected directive again sits in source indefinitely while every live session keeps loading the stale pinned cache — silently, with no signal anywhere (git log, session output, or repo state) distinguishing "fixed and live" from "fixed in source only."

### Expected
A fix for "text changed but cache never picked it up" that itself has no automated verification that the cache picked it up is the same defect one layer up: it depends on a human remembering to run an unenforced manual step, exactly as happened with c72a9f6. Either the reinstall+pin-match should be checked by something in the repo (e.g., a SessionStart or CI check that installed_plugins.json version == plugin.json version for tokenmaxxxer plugins), or the proposal should not claim the version bump "forces" cache invalidation — it only makes a rebuild possible; nothing forces it to happen.

## before-landing — stance 1: assume this change and another plugin's rule cancel each other — find the pair.

Verdict: FINDING — the warrant/dispatch version bump violates the repo's own established version-sync convention: README.md and dispatch/README.md hardcode "Unbenchmarked as of vX.Y.Z" strings per plugin, and this bump (already applied in plugin.json) was not accompanied by the matching README update, exactly the sync step commit aad3b2f demonstrates is expected.
Kind: composition
Seed: warrant 0.4.0->0.4.1, dispatch 0.5.0->0.5.1 in .claude-plugin/plugin.json (docs/proposals/2026-07-23-version-bump-verbatim-fix.md)

### Reproduce
```
python3 -c "
import json
for p in ['warrant','dispatch']:
    d=json.load(open(f'{p}/.claude-plugin/plugin.json'))
    print(p, d['version'])
"
grep -n "Unbenchmarked as of" README.md dispatch/README.md

# Compare to the repo's own precedent: commit aad3b2f bumped freelunch/tokenmaxxxer-env
# and in the SAME commit synced dispatch/README.md's rule list to match, establishing
# that a version bump for a landed directive change is expected to be paired with a
# README sync:
git show aad3b2f --stat
```

### Observed
`warrant/.claude-plugin/plugin.json` reports version `0.4.1` and `dispatch/.claude-plugin/plugin.json` reports `0.5.1`, but `README.md` line 68 still reads "Unbenchmarked as of v0.4.0" for warrant, `README.md` line 69 still reads "Unbenchmarked as of v0.5.0" for dispatch, and `dispatch/README.md` line 7 still reads "Unbenchmarked as of v0.5.0". The two rules — "bump plugin.json to force cache invalidation for a landed wording fix" (this change) and "sync the README's version-stamped text whenever plugin.json bumps for a landed change" (the convention this same repo followed one commit earlier in aad3b2f, and follows again for the warrant/dispatch text pattern itself) — are each correct alone but cancel here: the bump lands without the sync, leaving the README's "Unbenchmarked as of" line silently pointing at a version number that no longer matches the shipped plugin, with nothing that flags the mismatch.

### Expected
Either the version-bump proposal should include the matching README.md/dispatch/README.md text update (as aad3b2f did), or there should be no version-stamped "Unbenchmarked as of vX.Y.Z" claim in README.md at all if nothing enforces keeping it in sync with plugin.json across every bump.
