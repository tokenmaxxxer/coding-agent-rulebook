---
status: proposed        # proposed -> approved -> landed
issue: 18
files:
  - install.sh
---

# Proposal: `install.sh` — keep only the user-scope install

## The request (verbatim)

> 그냥 install.sh 에서는 유저 단위로 설치하는거만 남기라고

("Just leave only the user-scope install in install.sh.")

## Constraints that shape the build

Settled in the conversation that produced this proposal; decisions, not open questions.

1. The `--project` mechanism's SessionStart bootstrap hook cannot load plugins in
   a web session: the docs state SessionStart hooks run **after** Claude Code
   launches, and hook disk writes are not captured in the cached environment
   snapshot, so a fresh remote container installs too late and nothing carries
   forward. `--project` is therefore removed, not repaired.
2. The **user-scope CLI install** is the part worth keeping — register the
   marketplace and install the stack into `~/.claude` for the current account.
3. The existing CLI-less fallback (write `~/.claude/settings.json` directly when
   no `claude` binary is found) is user-scope too and stays.
4. Behaviour of the kept path is unchanged; this is a subtraction, not a redesign.

## What will be done

Reduce `install.sh` to a single user-scope path:

- Drop the `--project` / `--user` scope selector, `TOKENMAXXXER_SCOPE`, and the
  usage text describing project scope; the script performs the user-scope install
  unconditionally (a `--help` stays).
- Delete `write_bootstrap_hook()` and the entire project branch (the
  `.claude/settings.json` writer for a repo, the marketplace-source-for-project
  logic, and the SessionStart-hook heredoc).
- Keep `find_cli()`, the marketplace add/update, the explicit per-plugin install
  loop plus the bundle, and the `write_settings` fallback to
  `~/.claude/settings.json` when no CLI is present.

## Out of scope (separate follow-ups)

- README `--project` references (2 spots). `README.md` is also in the frozen
  write set of the still-open `2026-07-22-dispatch` unit, so it is not touched
  here; the stale references become the next proposal.
- The repo's own dogfood `.claude/settings.json` SessionStart-hook registration
  and `.claude/hooks/install-stack.sh` — orphaned once `--project` is gone, but
  removing them is a distinct decision (stop dogfooding the hook), taken next.
- No change to any plugin, or to what gets installed.

## How we will know it worked

- `install.sh` with no arguments installs the stack at user scope; `install.sh
  --help` still prints usage.
- No `--project`, `write_bootstrap_hook`, or hook heredoc remains (`grep -n
  project install.sh` returns nothing meaningful).
- `bash -n install.sh` is clean.

## What did not work

(Appended during the build, at the moment each thing does not work.)
