# tokenmaxxxer / claude-plugins

A Claude Code plugin marketplace by Jung Jiwon & Lee Jongkwan. Every plugin here ships with the benchmark numbers that justify its rules — policies that lost their ablation get removed, not shipped.

## Plugins

| Plugin | What it does |
|---|---|
| [freelunch](freelunch/) ⚡ | Estimates a task's *width* (count of independently-producible units) before acting, then runs a lean solo pass for narrow tasks or a fan-out of concurrent background Sonnet agents for wide ones. Measured 1.50x geomean wall-clock speedup at tied quality and lower token cost. See [freelunch/README.md](freelunch/README.md). |

## Adding the marketplace

Inside any Claude Code CLI session:

```
/plugin marketplace add tokenmaxxxer/claude-plugins
/plugin install freelunch@tokenmaxxxer
```

Or from a shell:

```
claude plugin marketplace add tokenmaxxxer/claude-plugins
claude plugin install freelunch@tokenmaxxxer
```

Using only the VSCode extension (its chat has no `/plugin` commands)? Each plugin directory ships an `install.sh` that finds the CLI bundled inside the extension and installs through it — see the plugin's README for details.

## Repo layout

- `.claude-plugin/marketplace.json` — the marketplace manifest.
- `freelunch/` — the plugin itself (hooks, agents, workflows), plus its README and installer.
- `docs/`, `experiments/` — the freelunch benchmark suite, results, and paper.
