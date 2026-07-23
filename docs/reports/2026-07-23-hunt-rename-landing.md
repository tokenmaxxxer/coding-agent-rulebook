---
proposal: docs/proposals/2026-07-23-rename-coding-agent-rulebook.md, docs/proposals/2026-07-23-rename-bundle-coding-agent-env.md
---

# Hunt record — rename-landing

## before-landing — stance 0: assume the gate just touched is bypassable — find the bypass

Verdict: FINDING — install.sh's settings-only fallback leaves the pre-rename `tokenmaxxxer-env@tokenmaxxxer` key dangling in `enabledPlugins` after a rename re-install, and still prints the unconditional "done" success banner.
Kind: silent-failure
Seed: docs/proposals/2026-07-23-rename-bundle-coding-agent-env.md (bundle rename tokenmaxxxer-env -> coding-agent-env) + install.sh / .claude-plugin/marketplace.json on main after PR #28 + #29 merged (5bddd5a / 7a75d60)

Both renames are internally coherent on `main`: marketplace.json's plugin names/sources all resolve to existing dirs, `coding-agent-env/.claude-plugin/plugin.json`'s dependencies all match marketplace entries, install.sh's `BUNDLE`/`GITHUB_REPO` match the new names, and `grep -rIn "tokenmaxxxer-env|claude-plugins" --exclude-dir=.git --exclude-dir=docs .` returns nothing. The bypass is not in that static coherence — it's in the CLI-less install path's *migration* behavior for a user who installed before the rename.

### Reproduce
```
cd /tmp && rm -rf renametest && mkdir renametest && cd renametest
mkdir -p fakehome/.claude
cat > fakehome/.claude/settings.json <<'JSON'
{
  "extraKnownMarketplaces": {
    "tokenmaxxxer": {
      "source": { "source": "github", "repo": "tokenmaxxxer/claude-plugins" }
    }
  },
  "enabledPlugins": {
    "tokenmaxxxer-env@tokenmaxxxer": true,
    "freelunch@tokenmaxxxer": true
  }
}
JSON
HOME="$(pwd)/fakehome" TOKENMAXXXER_SETTINGS_ONLY=1 bash /home/jwjung/claude-plugins/install.sh
cat fakehome/.claude/settings.json
```

### Observed
install.sh prints `==> done (user scope). ...` (unconditional success banner, same one printed on a clean install) and the resulting settings.json is:
```json
{
  "extraKnownMarketplaces": {
    "tokenmaxxxer": { "source": { "source": "github", "repo": "tokenmaxxxer/coding-agent-rulebook" } }
  },
  "enabledPlugins": {
    "tokenmaxxxer-env@tokenmaxxxer": true,
    "freelunch@tokenmaxxxer": true,
    "coding-agent-env@tokenmaxxxer": true
  }
}
```
The stale `"tokenmaxxxer-env@tokenmaxxxer": true` key survives the "upgrade" untouched — `write_settings` only ever adds `enabled[key] = True`, it never removes any key. `tokenmaxxxer-env` no longer exists as a plugin name anywhere in marketplace.json (renamed to `coding-agent-env`), so this enabledPlugins entry now names a plugin that cannot resolve, yet the script reports success with no mention of it.

### Expected
Either install.sh should detect and drop/migrate the pre-rename `tokenmaxxxer-env@tokenmaxxxer` key (or at minimum warn "removing stale entry for renamed bundle tokenmaxxxer-env"), or the success banner should not claim unconditional "done" while a dangling reference to a plugin absent from the current marketplace sits in the same file it just wrote. As written, a user who installed before the bundle rename and re-runs the documented installer gets a settings.json that looks correct (new key present, "done" printed) but silently carries a broken plugin reference the tool itself just had every opportunity to see and clean up.
