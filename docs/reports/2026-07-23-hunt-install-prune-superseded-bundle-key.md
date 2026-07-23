
## after-proposal — stance 1: assume this change and another plugin's rule cancel each other — find the pair

Verdict: NO FINDING
Seed: docs/proposals/2026-07-23-install-prune-superseded-bundle-key.md — install.sh write_settings() pruning SUPERSEDED={tokenmaxxxer-env@<market>} from enabledPlugins before adding coding-agent-env@<market>

Checked:
- `grep -rln tokenmaxxxer-env` across the repo (excluding docs/reports): only hits are the three proposal docs themselves (rename-bundle, release-version-bump, this one). No plugin.json, hooks.json, marketplace.json, or script references the old name as a live dependency or key.
- coding-agent-env/.claude-plugin/plugin.json `dependencies` list names the nine steering plugins by their current names only; no `tokenmaxxxer-env` entry to re-resolve.
- marketplace.json plugins list has no `tokenmaxxxer-env` entry (it was renamed to `coding-agent-env` in commit 2d26992, not duplicated).
- No install-stack hook remains in the repo (removed per commit b66955b); nothing besides install.sh itself reads or writes enabledPlugins.
- The CLI path and the write_settings fallback are mutually exclusive branches of the same `if [ -n "$CLI" ]` in one invocation — they cannot run against the same settings.json in the same execution to fight over enabledPlugins. Proposal explicitly scopes the prune to the fallback branch only, leaving CLI-path bookkeeping (which never wrote the old key format under the new bundle name) untouched.

No other rule, hook, or plugin declaration in this repository still reads, writes, or depends on `tokenmaxxxer-env@<market>` as a key. Pruning it has nothing live to cancel against.

## before-landing — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — the `superseded` prune set in install.sh's write_settings() is a hardcoded single old plugin name with no mechanism tying it to future renames, so the rule "installer keeps enabledPlugins free of dead keys from past renames" silently stops holding the very next time any plugin is renamed.
Kind: design-error
Seed: install.sh write_settings() gains `superseded = {f"tokenmaxxxer-env@{market}"}`; coding-agent-env bundle bumps 0.6.1->0.6.2. Note repo history already shows one prior rename (commit 2d26992, tokenmaxxxer-env -> coding-agent-env) that this hardcoded set is reacting to after the fact.

### Reproduce
```
cd /home/jwjung/claude-plugins
python3 - "test-market" "coding-agent-env" '{"source":"github","repo":"x/y"}' /tmp/settings-sim.json <<'PY'
import json, sys
market, bundle, source_json, path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
key = f"{bundle}@{market}"
# simulate a settings.json left from a hypothetical *next* rename
# (e.g. coding-agent-env-old -> coding-agent-env)
settings = {"enabledPlugins": {f"coding-agent-env-old@{market}": True}}
superseded = {f"tokenmaxxxer-env@{market}"}  # exactly as hardcoded in install.sh line 80
enabled = settings["enabledPlugins"]
for stale in list(enabled):
    if stale in superseded and stale != key:
        del enabled[stale]
        print(f"    removed superseded plugin key {stale}")
enabled[key] = True
settings["enabledPlugins"] = enabled
print(json.dumps(settings, indent=2))
PY
```

### Observed
```
{
  "enabledPlugins": {
    "coding-agent-env-old@test-market": true,
    "coding-agent-env@test-market": true
  }
}
```
The stale key `coding-agent-env-old@test-market` survives untouched — the prune logic runs but matches nothing, so it produces no removal message and no error, exactly the "guard that stops working without saying so" pattern. This is not hypothetical: the repo already underwent exactly this kind of rename once (commit 2d26992, tokenmaxxxer-env -> coding-agent-env), which is what motivated the current hardcoded entry — proving the pattern recurs and the fix does not generalize to the next occurrence.

### Expected
Either the prune set should be derived from something that is actually maintained across renames (e.g. a small history/alias file updated as part of the rename procedure), or the installer should not claim to keep enabledPlugins free of dead keys from past renames in general — only from this one specific past rename.
