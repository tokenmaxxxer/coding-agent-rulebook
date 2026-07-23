---
status: landed
files:
  - .claude-plugin/marketplace.json
  - install.sh
  - README.md
  - freelunch/README.md
  - no-footgun/README.md
---

# Rename marketplace: tokenmaxxxer → tokenmaxxxer-coding

Issue: #32

## Request
Rename this repo's marketplace from `tokenmaxxxer` to `tokenmaxxxer-coding`, adopting a per-repo naming scheme (`tokenmaxxxer-coding`, later `tokenmaxxxer-qa`, …) so multiple repos never collide on the marketplace namespace key.

## Constraints that change what gets built
- `tokenmaxxxer` appears in TWO roles and only ONE changes:
  - **Marketplace identifier (CHANGE)** — the marketplace name and the `@tokenmaxxxer` install suffix: `marketplace.json` `name`; install.sh `MARKET=`; every `<plugin>@tokenmaxxxer` install reference; the `extraKnownMarketplaces` key `"tokenmaxxxer"` in README's settings example; prose that names the market instance ("the `tokenmaxxxer` marketplace", "/plugin → marketplaces → tokenmaxxxer").
  - **Brand / project name (KEEP)** — "tokenmaxxxer stack", "tokenmaxxxer environment", the repo title `tokenmaxxxer / coding-agent-rulebook`, and the GitHub org path `tokenmaxxxer/coding-agent-rulebook` (URLs and `marketplace add tokenmaxxxer/coding-agent-rulebook`). These stay `tokenmaxxxer`.
- Therefore NO global `sed s/tokenmaxxxer/tokenmaxxxer-coding/g` — it would corrupt org URLs and rebrand prose. Every occurrence is judged by role. In particular freelunch/README.md line 84 mixes both on one line (`marketplace add tokenmaxxxer/coding-agent-rulebook && … install freelunch@tokenmaxxxer`): the org path stays, the suffix changes.
- Blast radius (stated, not fixable here): install becomes `X@tokenmaxxxer-coding`; every existing user's `~/.claude` marketplace entry and `enabledPlugins` keys (all under `@tokenmaxxxer`) go stale and must be re-added/re-installed. Per-user state is out of the repo's reach (same boundary as #24/#30).
- The install.sh superseded-prune set (`tokenmaxxxer-env@{market}`) is now doubly moot: after the market rename the whole `@tokenmaxxxer` namespace is superseded, which a repo-side prune keyed on the new `{market}` cannot reconcile. Not widened here — flagged as a known limit.

## What will be done (occurrence by occurrence, identifier-role only)
- `.claude-plugin/marketplace.json`: `"name": "tokenmaxxxer"` → `"tokenmaxxxer-coding"`. (The `description` prose "tokenmaxxxer steering stack" is brand — keep.)
- install.sh: `MARKET="tokenmaxxxer"` → `"tokenmaxxxer-coding"`; the `claude plugin update coding-agent-env@tokenmaxxxer` line; the `/plugin -> marketplaces -> tokenmaxxxer` recommendation line. (Keep "the tokenmaxxxer stack" header/help prose.)
- README.md: the `install <name>@tokenmaxxxer` example, `coding-agent-env@tokenmaxxxer`, `terse@tokenmaxxxer` examples, the `extraKnownMarketplaces` `"tokenmaxxxer": {` key, and the two prose references naming the marketplace ("registers the `tokenmaxxxer` marketplace", "marketplaces → tokenmaxxxer"). (Keep the title line and any "tokenmaxxxer stack" brand prose.)
- freelunch/README.md: `freelunch@tokenmaxxxer` suffix on lines 81 and 84 → `-coding`; the org path on line 84 and the "[`tokenmaxxxer` marketplace]" link text on line 5 (this names the market instance → change to `tokenmaxxxer-coding`, but the `../README.md` link target stays).
- no-footgun/README.md: `no-footgun@tokenmaxxxer` → `-coding`.

## What is deliberately out of scope
- The GitHub org name and all `tokenmaxxxer/coding-agent-rulebook` paths.
- Brand prose ("tokenmaxxxer stack/environment").
- Per-user `~/.claude` migration; the install.sh prune-set generalization (separate concern).
- Other plugin READMEs that mention only the brand "tokenmaxxxer stack" (terse, blueprint, coding-agent-env descriptions) — no identifier there, nothing to change.

## How I will know it worked
- `grep -rn "@tokenmaxxxer\b" --exclude-dir=.git .` returns nothing (every install suffix is now `@tokenmaxxxer-coding`).
- `marketplace.json` `name` is `tokenmaxxxer-coding`; install.sh `MARKET="tokenmaxxxer-coding"`.
- `grep -rn "tokenmaxxxer/coding-agent-rulebook"` is unchanged (org paths intact); "tokenmaxxxer stack" brand prose still present.
