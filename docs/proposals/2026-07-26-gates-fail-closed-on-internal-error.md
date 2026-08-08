---
status: landed
title: Gate hook scripts fail closed on any internal error
---

# Gate hook scripts fail closed on any internal error

## Problem

Claude Code `PreToolUse` hooks BLOCK a guarded tool call only on exit code 2.
Every other non-zero exit is treated as NON-BLOCKING (fail-open). Each gate in
this rulebook runs a `python3` judge whose uncaught exception exits 1 — for
example `os.path.realpath()` on a `file_path` containing an embedded null byte
raises an uncaught `ValueError`, exiting 1. Exit 1 is fail-open, so an internal
crash silently let the guarded write/commit through.

## Change

Two layers are added to every gate script, changing ONLY the error path — never
the allow(0)/deny(2) verdict on well-formed input:

1. SHELL LAYER — after the `python3 <<'PY' … PY` judge runs, its exit code is
   captured (`_fc_rc=$?`) and anything that is not 0 (allow) and not 2 (deny)
   is mapped to a printed "fail-closed: internal error" message on stderr and
   `exit 2`. Missing `python3` already denies (exit 2).

2. PYTHON LAYER — the judge's main body is wrapped in
   `try: … except Exception as e: <stderr deny reason>; sys.exit(2)`. Because
   the existing `deny()`/`allow()`/`sys.exit()` paths raise `SystemExit` (a
   `BaseException`, not `Exception`), the legitimate exit 0 / exit 2 verdicts
   pass through unchanged; only genuine internal errors (e.g. the null-byte
   `ValueError` from `realpath`) are converted to exit 2.

## Gates hardened

warrant/hooks: build-scope-gate.sh, scope-gate.sh, handbook-trigger-gate.sh,
hunt-guard.sh, coding-progress-gate.sh, path-ownership-gate.sh.
doctrine/hooks: placement-gate.sh, record-fields-gate.sh.

## Tests

The `run-gate-tests.sh` harnesses gain a crash-payload case per gate — a null
byte in `tool_input.file_path` and/or malformed JSON — asserting exit 2 (DENY).
All pre-existing allow/deny cases still pass (warrant 45/45, doctrine 7/7,
procedure 10/0).
