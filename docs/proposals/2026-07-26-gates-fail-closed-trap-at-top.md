---
status: approved
title: PreToolUse gate scripts fail closed with a trap-at-top
---

# PreToolUse gate scripts fail closed with a trap-at-top

## Problem

Claude Code `PreToolUse` hooks BLOCK a guarded tool call only on exit code 2.
Every other exit code — including a script that aborts BEFORE its verdict logic
ever runs — is treated as NON-BLOCKING (fail-OPEN). The prior fail-closed work
(`2026-07-26-gates-fail-closed-on-internal-error.md`) hardened the `python3`
judge and remapped its exit code, but that protection only takes effect once
the shell reaches the judge. Anything that kills the gate earlier — a failed
`source`, a `set -euo pipefail` abort, an unbound variable, a stray non-2
`exit` — still terminates with a non-2 code and fails open.

## Change

To EACH PreToolUse tool-gating gate script, as the FIRST executable statement
immediately after the shebang and ABOVE any `set`/`source`/other code, install
a fail-closed EXIT trap:

```
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
```

The trap inspects the terminal exit code and, if it is neither 0 (allow) nor 2
(deny), re-exits 2 (DENY). Legitimate `exit 0` / `exit 2` verdicts on
well-formed input pass through unchanged; only abnormal/other exits are forced
to 2. This composes with — does not replace — the already-landed python
try/except and shell exit-code remap.

Gates covered:

- warrant/hooks/scope-gate.sh
- warrant/hooks/hunt-guard.sh
- warrant/hooks/path-ownership-gate.sh
- warrant/hooks/build-scope-gate.sh
- warrant/hooks/coding-progress-gate.sh
- warrant/hooks/handbook-trigger-gate.sh
- doctrine/hooks/placement-gate.sh
- doctrine/hooks/record-fields-gate.sh

Never-blocking hooks (capture-verdict.sh, scope-approval-token.sh,
directive.sh, inject-transition-rules.sh, hunt-state.sh, ensure-buckets.sh,
state.sh) are left untouched. No gate here sources a `_gate-common.sh`, and no
gate installs its own EXIT trap, so there is no existing EXIT trap to merge
with or be overwritten by.

## Tests

Each harness (`warrant/hooks/run-gate-tests.sh`,
`doctrine/hooks/run-gate-tests.sh`) gains a pre-logic-abort case per gate: a
temp copy of the real gate is produced with a self-contained abort snippet
(`set -u; : "${__FC_TEST_UNBOUND_VAR__}"`) spliced in immediately after
`trap __fc EXIT` — above every set/source/verdict statement — and the copy is
asserted to still exit 2 (DENY). All pre-existing allow/deny cases continue to
pass (warrant 51/51, doctrine 9/9).
