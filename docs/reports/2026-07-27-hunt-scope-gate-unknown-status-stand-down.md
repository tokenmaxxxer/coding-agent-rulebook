---
proposal: docs/proposals/2026-07-27-scope-gate-unknown-status-stand-down.md
---

# Hunt record — scope-gate-unknown-status-stand-down

## after-proposal — stance 0: assume the gate just touched is bypassable — find the bypass

Verdict: FINDING — proposal fixes only the "malformed/unrecognized status" stand-down branch's `sys.exit(1)`, but the structurally identical "multiple proposals marked approved" branch (and the `nested_units()` branch inside `stand_down()`) still `sys.exit(1)`, which `__fc` still remaps to `exit 2` (deny), reproducing the same session self-lock the proposal is meant to eliminate, just via a different trigger.
Kind: design-error
Seed: docs/proposals/2026-07-27-scope-gate-unknown-status-stand-down.md; warrant/hooks/scope-gate.sh stand-down branches around the "cannot be read" message (fixed by the proposal) and the "are all marked approved" message / nested_units() (not touched by the proposal), both currently `sys.exit(1)`.

### Reproduce
```
mkdir -p /tmp/repro/docs/proposals /tmp/repro/docs/specs && cd /tmp/repro
git init -q
touch docs/specs/role-handoff-contract.md
cat > docs/proposals/a.md <<'MD'
---
status: approved
files:
  - foo.txt
---
# A
MD
cat > docs/proposals/b.md <<'MD'
---
status: approved
files:
  - bar.txt
---
# B
MD
git add -A && git commit -qm init
export CLAUDE_PROJECT_DIR=/tmp/repro
echo '{"tool_name":"Read","tool_input":{"file_path":"/tmp/repro/docs/proposals/a.md"}}' \
  | bash /home/jwjung/tokenmaxxxer/coding-agent-rulebook/warrant/hooks/scope-gate.sh
echo "exit=$?"
```

### Observed
```
warrant: docs/proposals/a.md, docs/proposals/b.md are all marked approved. One unit is enforceable at a time, so the write set and trailer rules are OFF until exactly one is approved — set the finished ones to `landed`.
scope-gate.sh: fail-closed: internal error (judge exited 1)
exit=2
```
A plain `Read` tool call is denied, and the `__fc` trap makes the deny apply for the rest of the session — the exact self-lock scenario described in the proposal's Intent, still reachable after the proposal's change ships, via a second approved proposal instead of a malformed status.

### Expected
Per the proposal's own reasoning (Constraints: "Reads and other analysis-only tool calls are already outside warrant's intended enforcement surface"), this stand-down-with-warning branch should also exit `0` (allow, with the warning still printed to stderr), not `1`. The proposal's write set (`warrant/hooks/scope-gate.sh`, `warrant/hooks/run-gate-tests.sh`, `warrant/.claude-plugin/plugin.json`) does not mention updating this second branch or `nested_units()`, so as scoped the fix is incomplete and the self-lock survives under a different, equally plausible trigger.

## before-landing — stance 1: assume this change and another plugin's rule cancel each other — find the pair

Verdict: FINDING — a malformed-status proposal in docs/proposals/ silently short-circuits the nested_units() enforcement-reach check, flipping the gate's verdict from deny to allow-all.
Kind: composition
Seed: commit c9c0fdb on branch scope-gate-unknown-status-stand-down (warrant/hooks/scope-gate.sh) — malformed proposal handling now calls `allow()` (exit 0) instead of `sys.exit(1)`.

### Reproduce
```
mkdir -p repro/docs/proposals repro/packages/foo/docs/proposals && cd repro && git init -q
cat > docs/proposals/malformed.md <<'MD'
---
status: bogus-status-value
files:
  - foo.txt
---
body
MD
cat > packages/foo/docs/proposals/other.md <<'MD'
---
status: proposed
---
body
MD
git add -A && git commit -q -m init
export CLAUDE_PROJECT_DIR="$PWD"

# (a) with the malformed proposal present:
echo '{"tool_name":"Write","tool_input":{"file_path":"anything-not-in-write-set.txt"}}' \
  | bash <repo>/warrant/hooks/scope-gate.sh; echo "exit=$?"

# (b) remove docs/proposals/malformed.md, rerun the same payload
rm docs/proposals/malformed.md
echo '{"tool_name":"Write","tool_input":{"file_path":"anything-not-in-write-set.txt"}}' \
  | bash <repo>/warrant/hooks/scope-gate.sh; echo "exit=$?"
```

### Observed
(a) with malformed.md present: gate prints the "standing down (allowing)" message for the malformed
file and exits 0 — the nested `packages/foo/docs/proposals` unit is never mentioned at all, the
nested_units() check inside stand_down() is never reached (the malformed branch returns via allow()
before stand_down() is called).

(b) with malformed.md removed, same nested unit, same tool_input: gate prints the nested-units
warning and fails closed with exit 2 (deny), via the fail-closed trap wrapping the judge's
`sys.exit(1)`.

### Expected
The malformed-status branch and the nested-units-reach branch are two independent "the gate can't
fully judge this" conditions; the presence or absence of a garbage `status:` value in an unrelated
proposal file should not determine whether an out-of-reach nested proposal unit gets flagged.
Adding one unparseable/unknown-status proposal.md to docs/proposals/ is now a way to make the gate
go fully permissive even when there's a real reach problem (a nested unit) it would otherwise have
denied against.
