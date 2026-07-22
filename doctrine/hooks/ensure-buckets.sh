#!/usr/bin/env bash
# SessionStart hook: makes sure the six doctrine buckets exist under docs/.
#
# Measured reason this exists: in a repository with no docs/ tree, the directive
# alone did not get documents written — four headless runs on a task that
# introduced an environment variable produced no document at all. The same task
# in a repository whose buckets were already present, with one prior decision
# record visible, produced the decision record unprompted. An empty repository
# reads as "this project does not keep documentation"; the buckets are what
# makes the practice visible.
#
# This is the one place in the stack that writes to the user's repository, so it
# is deliberately the smallest write that can work:
#   - mkdir -p for missing buckets; an existing bucket is a no-op, contents and
#     mtime untouched
#   - a one-line README.md per bucket, written ONLY when absent
#   - nothing outside docs/, nothing removed, nothing overwritten, no network
# It skips entirely when the working directory is not a git repository, when
# docs/ exists as a file, or when docs/ is a symlink (the write would land
# outside the repository).
# Kill switch: export DOCTRINE_OFF=1

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and to
# most tooling, but any non-empty value used to disable the hook — the kill switch
# silently killed it on exactly the spelling meant to keep it alive.
case "${DOCTRINE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

root="${CLAUDE_PROJECT_DIR:-$PWD}"
root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$root" ] || exit 0

docs="$root/docs"
# A symlinked or non-directory docs/ is someone else's arrangement — leave it.
[ -L "$docs" ] && exit 0
[ -e "$docs" ] && [ ! -d "$docs" ] && exit 0

created=""
failed=""
while IFS='|' read -r bucket blurb; do
  [ -n "$bucket" ] || continue
  target="$docs/$bucket"
  [ -L "$target" ] && continue
  if [ -e "$target" ] && [ ! -d "$target" ]; then
    continue
  fi
  if [ ! -d "$target" ]; then
    if ! mkdir -p "$target" 2>/dev/null; then
      failed="$failed $bucket"
      continue
    fi
    created="$created $bucket"
  fi
  if [ ! -e "$target/README.md" ]; then
    printf '# %s\n\n%s\n' "$bucket" "$blurb" > "$target/README.md" 2>/dev/null || true
  fi
done <<'BUCKETS'
decisions|Why a hard-to-reverse choice was made. Fixed at the moment of the decision.
handbooks|Current state. Edited from now on to stay true.
reports|An observation, measurement, or investigation fixed to a point in time. Research goes in reports/research/.
specs|Design and specification. Updated in the same PR as the code.
proposals|Not adopted yet — proposals, drafts, RFCs.
_assets|Images and attachments. The underscore marks it as not a document class.
BUCKETS

if [ -n "$failed" ]; then
  echo "doctrine: could not create docs/ buckets —$failed (permissions?). Documents have nowhere to land."
fi

if [ -n "$created" ]; then
  echo "doctrine: created docs/ buckets —$created. Documentation goes in one of the six, chosen by lifetime."
fi

exit 0
