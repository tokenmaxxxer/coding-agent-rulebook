#!/usr/bin/env bash
# Tests for the procedure-enforcing gates added by
# docs/proposals/2026-07-26-implement-procedure-hooks-all-rulebooks.md.
# Each gate gets one crafted VIOLATION (must be refused, non-zero exit) and
# one COMPLIANT case (must pass, exit 0).
#
#   path-ownership-gate.sh   (§11)  Write/Edit
#   record-fields-gate.sh    (§20)  Write/Edit
#   build-scope-gate.sh      (§19)  git commit
#   coding-progress-gate.sh  (§15)  git commit
#   handbook-trigger-gate.sh (§21)  git commit
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
WARRANT="$HOOK_DIR"
DOCTRINE="$(cd "$HOOK_DIR/../../doctrine/hooks" && pwd -P)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0

jpay() { python3 -c 'import json,sys; print(json.dumps({"tool_name":sys.argv[1],"tool_input":json.loads(sys.argv[2])}))' "$1" "$2"; }

run() { # <gate> <root> <payload>
  CLAUDE_PROJECT_DIR="$2" bash "$1" <<<"$3" >/dev/null 2>&1
}
expect_deny() { # name gate root payload
  if run "$2" "$3" "$4"; then echo "FAIL: $1 — expected DENY, got allow"; fail=$((fail+1));
  else echo "PASS(deny): $1"; pass=$((pass+1)); fi
}
expect_allow() { # name gate root payload
  if run "$2" "$3" "$4"; then echo "PASS(allow): $1"; pass=$((pass+1));
  else echo "FAIL: $1 — expected ALLOW, got deny"; fail=$((fail+1)); fi
}

newrepo() { # echoes a fresh git-repo fixture root
  local d; d="$(mktemp -d -p "$WORK")"
  mkdir -p "$d/docs/specs"
  printf 'stub\n' > "$d/docs/specs/role-handoff-contract.md"
  git -C "$d" init -q
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  printf 'x\n' > "$d/README.md"
  git -C "$d" add README.md >/dev/null 2>&1
  git -C "$d" commit -qm init >/dev/null 2>&1
  echo "$d"
}

# ---------------- path-ownership-gate (§11) ----------------
R="$(newrepo)"; mkdir -p "$R/docs/reports/records/subjA"
expect_deny "path-ownership: write another role's record" "$WARRANT/path-ownership-gate.sh" "$R" \
  "$(jpay Write "$(python3 -c 'import json,sys;print(json.dumps({"file_path":sys.argv[1],"content":"x"}))' "$R/docs/reports/records/subjA/verify.md")")"
expect_allow "path-ownership: write own coding record" "$WARRANT/path-ownership-gate.sh" "$R" \
  "$(jpay Write "$(python3 -c 'import json,sys;print(json.dumps({"file_path":sys.argv[1],"content":"x"}))' "$R/docs/reports/records/subjA/coding.md")")"

# ---------------- record-fields-gate (§20) ----------------
R="$(newrepo)"; mkdir -p "$R/docs/reports/records/subjB"
BAD='---
loop_state: coding-active
---
just a stub'
GOOD='---
loop_state: cleared
---
## What was done
Implemented the parser.
## Why
Rationale: the spec required streaming.
## Upstream basis
based on commit deadbeef1234 / docs/reports/records/subjB/product.md
## Open findings
none'
mk() { python3 -c 'import json,sys;print(json.dumps({"file_path":sys.argv[1],"content":sys.argv[2]}))' "$1" "$2"; }
expect_deny "record-fields: missing required sections" "$DOCTRINE/record-fields-gate.sh" "$R" \
  "$(jpay Write "$(mk "$R/docs/reports/records/subjB/coding.md" "$BAD")")"
expect_allow "record-fields: complete terminal record" "$DOCTRINE/record-fields-gate.sh" "$R" \
  "$(jpay Write "$(mk "$R/docs/reports/records/subjB/coding.md" "$GOOD")")"

# ---------------- build-scope-gate (§19) ----------------
mkbuild() { # <root> <frontstate>
  local d="$1" st="$2"
  mkdir -p "$d/src" "$d/docs/reports/records/subjC"
  printf 'code\n' > "$d/src/main.py"
  printf -- '---\nloop_state: %s\n---\nfront record\n' "$st" > "$d/docs/reports/records/subjC/product.md"
  printf -- '---\nloop_state: coding-active\n---\n## What was done\nx\n## Why\ny\n## Upstream basis\ndeadbeef\n## Open findings\nnone\n## Next steps\nz\n## Resolution path\nw\n' > "$d/docs/reports/records/subjC/coding.md"
  git -C "$d" add src/main.py docs/reports/records/subjC/coding.md >/dev/null 2>&1
}
R="$(newrepo)"; mkbuild "$R" scope-proposed
expect_deny "build-scope: first build without scope-approved front" "$WARRANT/build-scope-gate.sh" "$R" \
  "$(jpay Bash '{"command":"git commit -m first-build"}')"
R="$(newrepo)"; mkbuild "$R" scope-approved
expect_allow "build-scope: first build with scope-approved front" "$WARRANT/build-scope-gate.sh" "$R" \
  "$(jpay Bash '{"command":"git commit -m first-build"}')"

# ---------------- coding-progress-gate (§15) ----------------
mkverify() { # <root> <resolved?>
  local d="$1" resolved="$2"
  mkdir -p "$d/docs/reports/records/subjD"
  if [ "$resolved" = yes ]; then vstate=cleared; else vstate=findings-open; fi
  printf -- '---\nloop_state: %s\n---\nfinding F1\n  severity: blocking\n  addressed_to: coding\n  id: F1\n---\n' "$vstate" \
    > "$d/docs/reports/records/subjD/verify.md"
  if [ "$resolved" = yes ]; then
    printf -- '---\nloop_state: coding-active\n---\nresolved_findings:\n  - finder: docs/reports/records/subjD/verify.md sha: cafebabe1234 id: F1\n' \
      > "$d/docs/reports/records/subjD/coding.md"
  else
    printf -- '---\nloop_state: coding-active\n---\nno resolutions yet\n' \
      > "$d/docs/reports/records/subjD/coding.md"
  fi
  git -C "$d" add docs/reports/records/subjD/coding.md >/dev/null 2>&1
}
R="$(newrepo)"; mkverify "$R" no
expect_deny "coding-progress: unresolved blocking finding" "$WARRANT/coding-progress-gate.sh" "$R" \
  "$(jpay Bash '{"command":"git commit -m land\n\nSubject: subjD"}')"
R="$(newrepo)"; mkverify "$R" yes
expect_allow "coding-progress: blocking finding resolved+cleared" "$WARRANT/coding-progress-gate.sh" "$R" \
  "$(jpay Bash '{"command":"git commit -m land\n\nSubject: subjD"}')"

# ---------------- handbook-trigger-gate (§21) ----------------
R="$(newrepo)"; printf '{}\n' > "$R/package.json"; git -C "$R" add package.json >/dev/null 2>&1
expect_deny "handbook-trigger: manifest change without handbook" "$WARRANT/handbook-trigger-gate.sh" "$R" \
  "$(jpay Bash '{"command":"git commit -m deps"}')"
R="$(newrepo)"; mkdir -p "$R/docs/handbooks"; printf '{}\n' > "$R/package.json"; printf 'hb\n' > "$R/docs/handbooks/core.md"
git -C "$R" add package.json docs/handbooks/core.md >/dev/null 2>&1
expect_allow "handbook-trigger: manifest change with handbook update" "$WARRANT/handbook-trigger-gate.sh" "$R" \
  "$(jpay Bash '{"command":"git commit -m deps"}')"

echo "-----"; echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
