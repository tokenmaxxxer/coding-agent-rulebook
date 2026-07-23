---
proposal: docs/proposals/2026-07-23-release-version-bump.md
---

# Hunt record — release-version-bump

## after-proposal — stance 0: assume the gate just touched is bypassable — find the bypass

Verdict: FINDING — install.sh's own printed manual-update instruction bypasses the dependency-propagation fix its install path uses
Kind: silent-failure
Seed: proposal bumps freelunch and tokenmaxxxer-env plugin.json versions and instructs deploy is "merge to main... users update via marketplace auto-update or `/plugin update`"; followed the version/marketplace wiring into install.sh.

### Reproduce
grep -n "update tokenmaxxxer-env\|Updating the bundle alone\|for plugin in freelunch" /home/jwjung/claude-plugins/install.sh

Output:
```
126:  for plugin in freelunch terse blueprint no-mock scout no-footgun doctrine warrant dispatch; do
133:  # Updating the bundle alone would not move its unpinned dependencies, so update
135:  for plugin in freelunch terse blueprint no-mock scout no-footgun doctrine warrant dispatch; do
165:      claude plugin update tokenmaxxxer-env@tokenmaxxxer
```

Read install.sh lines 120-171: the install/first-run path (lines 126, 135) deliberately loops `claude plugin update <plugin>@tokenmaxxxer` over every individual plugin name (freelunch, terse, blueprint, ...) precisely because, per the script's own comment at line 133, "Updating the bundle alone would not move its unpinned dependencies." Yet the final "done" banner (line 165), which is the only instruction given to a user who declined interactive auto-update, tells them to refresh with just `claude plugin update tokenmaxxxer-env@tokenmaxxxer` — the exact single-bundle-only command the script's own comment says does not propagate new plugin versions.

### Observed
A user without auto-update enabled who follows the script's own recommended refresh command will not receive the version bump this proposal makes to `freelunch/.claude-plugin/plugin.json` (0.2.18 -> 0.2.19), because that command only updates the `tokenmaxxxer-env` bundle manifest, not its dependency `freelunch`, per the script's own documented reasoning two lines away.

### Expected
The "done" banner's manual-refresh instruction should loop over every plugin (same list used at install time), not just the bundle — otherwise the deploy mechanism this proposal depends on ("users update via marketplace" / "`/plugin update`") silently fails for exactly the plugin whose version this proposal bumps.
