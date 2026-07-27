---
proposal: docs/proposals/2026-07-27-scope-gate-malformed-skip-and-deny-codes.md
---

# Hunt record — scope-gate-malformed-skip-and-deny-codes

## before-landing — stance 2: assume this guard goes silent when its own input is malformed — make it go silent

Verdict: NO FINDING
Seed: warrant/hooks/scope-gate.sh diff (base c9c0fdb..87894c1..78f59a7 / merge commit 010ec8b) — malformed/unknown proposal status now warns and falls through to stand_down() (nested_units reach preserved); multiple-approved and nested-units violations exit 2 directly; new `elif malformed:` branch (exactly one approved, sibling malformed) warns and continues to write-set enforcement.

Tried and could not break: constructed a repo with one `status: approved` proposal (write set `src`) plus a sibling proposal with `status: banana` (malformed), and issued a Write outside the write set:

    root=$(mktemp -d); mkdir -p "$root/docs/proposals" "$root/src" "$root/other"
    printf -- '---\nstatus: approved\nfiles:\n  - src\n---\n# p\n' > "$root/docs/proposals/approved.md"
    printf -- '---\nstatus: banana\n---\n# bad\n' > "$root/docs/proposals/bad.md"
    payload='{"tool_name":"Write","tool_input":{"file_path":"'"$root"'/other/escape.py","content":"x=1"}}'
    CLAUDE_PROJECT_DIR="$root" bash warrant/hooks/scope-gate.sh <<<"$payload"

Observed: rc=2, denies with the write-set message plus the malformed-skip warning — enforcement is not silenced by the sibling malformed proposal.

Also re-ran the full suite (`bash warrant/hooks/run-gate-tests.sh`): 60/60 pass, including the new cases 52-54 covering malformed+nested (still denies, no bypass) and malformed-only (still allows-with-warning, unchanged from prior behavior). Checked the `nested_units()` reach check: it is invoked only from `stand_down()`, which is reached whenever `len(approved) != 1` (the only case where "nothing is enforced" is actually true); when exactly one approved unit exists, root-level enforcement is active regardless of nested/malformed siblings, so skipping the reach check there is consistent with its stated purpose, not a new gap introduced by this diff. Could not construct an input that reaches allow() (exit 0) while a write should have been denied by an in-scope rule; the diff removes the malformed-triggers-allow() early-exit that was the actual bug this proposal fixes, and does not introduce a new one within its own scope.
