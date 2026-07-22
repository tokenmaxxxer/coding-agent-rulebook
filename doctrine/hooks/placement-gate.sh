#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|NotebookEdit): refuses markdown writes that would
# land anywhere other than a doctrine bucket.
#
# The rule is an allow-list, not a docs/-only check. A document scattered at the
# repository root is the failure this plugin exists to prevent, so everything is
# refused except: a bucket under any docs/ directory, README.md at any level,
# the root files an ecosystem fixes by name (LICENSE, CHANGELOG, ...), anything
# inside a dot-directory or a vendored/generated tree, and whatever the repo
# adds via DOCTRINE_ALLOW.
#
# This inspects the TOOL INPUT — a path string, before the write happens. It is
# not a pass over generated content, and it makes no judgment about the
# document: which bucket a document belongs in is left to the directive, since
# a path cannot tell you that. The only claim made here is mechanical: this
# path is not an allowed location.
#
# Fails open. A missing python3, unreadable payload, or unexpected schema lets
# the write through rather than blocking a session on the gate itself.
#
# Kill switch:  export DOCTRINE_OFF=1
# Escape hatch: export DOCTRINE_ALLOW="content,blog,_posts/drafts"
#               comma-separated; each entry matches a whole path segment or a
#               path prefix relative to the project root.

if [ -n "$DOCTRINE_OFF" ]; then
  exit 0
fi

command -v python3 >/dev/null 2>&1 || exit 0

payload="$(cat)"

DOCTRINE_PAYLOAD="$payload" python3 <<'PY'
import json
import os
import posixpath
import sys

BUCKETS = ("decisions", "handbooks", "reports", "specs", "proposals", "_assets")
DOC_SUFFIXES = (".md", ".mdx")
# Names an ecosystem expects at the repository root, by convention or tooling.
ROOT_FILES = (
    "README.md", "LICENSE.md", "CHANGELOG.md", "CONTRIBUTING.md",
    "CODE_OF_CONDUCT.md", "SECURITY.md", "AGENTS.md", "CLAUDE.md",
)
# Vendored, generated, or otherwise not-ours trees.
SKIP_DIRS = (
    "node_modules", "vendor", "dist", "build", "target", "out",
    "venv", ".venv", "site-packages", "coverage",
)


def allow():
    sys.exit(0)


try:
    event = json.loads(os.environ.get("DOCTRINE_PAYLOAD", ""))
except ValueError:
    allow()

if not isinstance(event, dict):
    allow()

tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    allow()

path = tool_input.get("file_path") or tool_input.get("notebook_path")
if not isinstance(path, str) or not path:
    allow()

normalized = path.replace("\\", "/")

root = (os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()).replace("\\", "/")
absolute = posixpath.normpath(
    normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
)
root = posixpath.normpath(root)

# Outside the project entirely (scratch dirs, /tmp) — not this gate's business.
if absolute != root and not absolute.startswith(root + "/"):
    allow()

relative = absolute[len(root) + 1:]
segments = [s for s in relative.split("/") if s not in ("", ".")]
if not segments:
    allow()

directories, name = segments[:-1], segments[-1]

# Dot-directories and vendored trees are none of the doctrine's business — except
# under docs/, where the exemption exists to avoid fighting doc-site tooling that
# is already there. Scaffolding a NEW one is the model inventing structure under
# docs/, so under docs/ the directory has to exist already.
scaffolding = None
for i, directory in enumerate(directories):
    if directory not in SKIP_DIRS and not directory.startswith("."):
        continue
    if "docs" not in directories[:i]:
        allow()
    branch = posixpath.join(root, *directories[:i + 1])
    if os.path.isdir(branch):
        allow()
    scaffolding = "/".join(directories[:i + 1])
    break

for extra in (os.environ.get("DOCTRINE_ALLOW") or "").split(","):
    extra = extra.strip().strip("/")
    if extra and (extra in directories or relative == extra or relative.startswith(extra + "/")):
        allow()

# Inside a docs/ tree the doctrine governs every file, whatever its extension:
# images and attachments belong in _assets/, not loose under docs/. Outside it,
# only documents are governed — source and config are none of this gate's business.
in_docs = False
for i, directory in enumerate(directories):
    if directory != "docs":
        continue
    in_docs = True
    if i + 1 < len(directories) and directories[i + 1] in BUCKETS:
        allow()

if in_docs:
    # The doctrine file a team writes for itself sits at the top of docs/.
    if directories[-1] == "docs" and name == "README.md":
        allow()
else:
    if not name.lower().endswith(DOC_SUFFIXES):
        allow()
    # README.md is the one filename that means "this directory, explained".
    if name == "README.md":
        allow()
    if not directories and name in ROOT_FILES:
        allow()

buckets = ", ".join(b + "/" for b in BUCKETS)
if scaffolding:
    reason = (
        "`%s` would create `%s`, a new directory under docs/ that is not one of the six "
        "buckets. Existing doc-site tooling is left alone, but new structure under docs/ "
        "is not invented here." % (relative, scaffolding)
    )
elif in_docs:
    reason = (
        "`%s` is under docs/ but not in one of the six buckets. Every file under docs/ "
        "belongs to a bucket — images and attachments go in _assets/." % relative
    )
else:
    reason = (
        "`%s` puts a document outside docs/. Documents do not live next to the code "
        "or at the repository root." % relative
    )

print(
    "doctrine: refused — %s\n"
    "Every document lives in exactly one of: %s — all under docs/.\n"
    "Classify by lifetime, not topic: undecided -> proposals/; invalidated by a code change -> specs/; "
    "kept current from now on -> handbooks/; why a hard-to-reverse choice was made -> decisions/; "
    "an observation fixed to a point in time -> reports/ (research under reports/research/).\n"
    "Create the bucket if it does not exist yet, then write there. Allowed outside the buckets: "
    "README.md at any level, root LICENSE/CHANGELOG/CONTRIBUTING/CODE_OF_CONDUCT/SECURITY/AGENTS/CLAUDE, "
    "and paths listed in DOCTRINE_ALLOW."
    % (reason, buckets),
    file=sys.stderr,
)
sys.exit(2)
PY

exit $?
