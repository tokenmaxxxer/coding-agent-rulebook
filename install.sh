#!/usr/bin/env bash
# Installs the freelunch plugin for Claude Code.
# Works with the claude CLI if present; otherwise writes the equivalent
# configuration directly so the VSCode extension (same ~/.claude config) picks it up.
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
MARKET="freelunch"
PLUGIN="freelunch"

if [ ! -f "$ROOT/.claude-plugin/marketplace.json" ]; then
  echo "ERROR: $ROOT/.claude-plugin/marketplace.json not found — run this script from its repo." >&2
  exit 1
fi

if command -v claude >/dev/null 2>&1; then
  echo "==> claude CLI found: installing via CLI"
  if claude plugin marketplace list 2>/dev/null | grep -q "$MARKET"; then
    echo "    marketplace '$MARKET' already registered"
  else
    claude plugin marketplace add "$ROOT" \
      || (cd "$(dirname "$ROOT")" && claude plugin marketplace add "./$(basename "$ROOT")")
  fi
  claude plugin install "$PLUGIN@$MARKET" --scope user
  echo "==> installed $PLUGIN@$MARKET (user scope)"
else
  echo "==> claude CLI not found: writing config for the VSCode extension"
  python3 - "$ROOT" "$MARKET" "$PLUGIN" <<'PY'
import json, os, shutil, sys

root, market, plugin = sys.argv[1], sys.argv[2], sys.argv[3]
key = f"{plugin}@{market}"
path = os.path.expanduser("~/.claude/settings.json")
os.makedirs(os.path.dirname(path), exist_ok=True)

settings = {}
if os.path.exists(path):
    with open(path) as f:
        try:
            settings = json.load(f)
        except ValueError:
            sys.exit(f"ERROR: {path} is not valid JSON — fix it and re-run.")
    shutil.copy2(path, path + ".bak")
    print(f"    backup written to {path}.bak")

settings.setdefault("extraKnownMarketplaces", {})[market] = {
    "source": {"source": "local", "path": root}
}

enabled = settings.get("enabledPlugins")
if isinstance(enabled, dict):
    enabled[key] = True
elif isinstance(enabled, list):
    if key not in enabled:
        enabled.append(key)
else:
    settings["enabledPlugins"] = [key]

tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
print(f"    updated {path}")
PY
  echo "==> done. Reload the VSCode window to activate the plugin."
fi

echo "==> verify inside a Claude Code session with: /plugins"
