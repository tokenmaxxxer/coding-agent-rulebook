#!/usr/bin/env bash
# SessionStart hook: rebuilds work-unit state from the repository.
#
# The point of putting state on disk is that a new session can pick up an
# interrupted unit without being told. This reads the proposal files and git,
# and says where things stand. It writes nothing.
# Kill switch: export WARRANT_OFF=1

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and to
# most tooling, but any non-empty value used to disable the hook — the kill switch
# silently killed it on exactly the spelling meant to keep it alive.
case "${WARRANT_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$root" ] || exit 0
[ -d "$root/docs/proposals" ] || exit 0

branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)"

WARRANT_ROOT="$root" WARRANT_BRANCH="$branch" python3 <<'PY'
import os
import re
import subprocess
import sys

root = os.environ["WARRANT_ROOT"]
branch = os.environ.get("WARRANT_BRANCH", "")
proposals = os.path.join(root, "docs", "proposals")

STATUS = re.compile(r"^status:\s*([A-Za-z]+)\s*(?:#.*)?$", re.M)


def frontmatter(path):
    try:
        with open(path, encoding="utf-8-sig") as handle:
            text = handle.read(65536)
    except (OSError, UnicodeDecodeError):
        return None
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    return text[3:end] if end != -1 else None


open_units = []
for name in sorted(os.listdir(proposals)):
    if not name.endswith(".md") or name == "README.md":
        continue
    block = frontmatter(os.path.join(proposals, name))
    if block is None:
        continue
    found = STATUS.search(block)
    status = found.group(1).lower() if found else "proposed"
    if status in ("proposed", "approved"):
        open_units.append((status, "docs/proposals/" + name))

if not open_units:
    sys.exit(0)

lines = ["warrant: open work units in this repository —"]
for status, path in open_units:
    if status == "approved":
        try:
            shipped = subprocess.run(
                # -F: a proposal filename may contain regex metacharacters.
                ["git", "-C", root, "log", "--oneline", "-F", "--grep", "Proposal: " + path],
                capture_output=True, text=True, timeout=10,
            ).stdout.strip().splitlines()
        except (OSError, subprocess.SubprocessError):
            shipped = []
        lines.append(
            "  APPROVED, in progress: %s — %d commit(s) so far, branch %s. "
            "Read it before writing anything; the write set in its frontmatter is still frozen."
            % (path, len(shipped), branch or "?")
        )
    else:
        lines.append(
            "  AWAITING APPROVAL: %s — do not start this work until the user approves it." % path
        )

print("\n".join(lines))
PY

exit 0
