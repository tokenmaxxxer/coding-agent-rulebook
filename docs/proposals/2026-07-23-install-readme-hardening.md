---
status: landed          # proposed -> approved -> landed
issue: 22
files:
  - install.sh
  - README.md
---

# Proposal: install.sh + README hardening (three hunt findings)

## The request (verbatim)

> 묶어서 가

("Go with them bundled" — fix the three follow-up findings as one unit.)

## Constraints that shape the build

1. Pre-approved by the user in this turn; the three findings are already
   reproduced and recorded under `docs/reports/`. This is a subtraction/guard
   change, not a redesign.
2. The plugin steering stack (freelunch/warrant/…) is not loaded this session,
   so the build runs inline rather than via a freelunch-worker, and no hunter is
   dispatched (agents unavailable). The git record (issue #22, this proposal,
   a PR that Closes it, merge on the standing approval) is kept regardless.

## What will be done

- **install.sh #1:** before the CLI marketplace/install operations, `cd` into a
  throwaway `mktemp -d` so `claude plugin marketplace add` cannot write into the
  invoking repo's tracked `.claude/settings.json`. The `write_settings` fallback
  already uses an absolute `$HOME` path and is unaffected.
- **install.sh #2:** check the fallback `write_settings` call; on failure print a
  clear error to stderr and `exit 1` instead of falling through to the "done"
  banner with exit 0.
- **README:** rewrite the "Writing the settings by hand" paragraph so the shown
  bundle-only JSON is the by-hand/fallback minimum, and state that install.sh's
  CLI path pins all ten plugins (nine deps + bundle) in `enabledPlugins`. Drop
  the false "converge on exactly these two keys" claim.

## Out of scope

- No change to which plugins install or to the explicit per-plugin install/update
  loops (the cascade measurement confirmed they are needed).
- No new install mechanism.

## How we will know it worked

- `bash -n install.sh` clean; running install.sh's CLI path from inside a
  marketplace-declaring repo leaves its `.claude/settings.json` untouched.
- The fallback exits non-zero and prints an error when `~/.claude/settings.json`
  is malformed JSON, instead of printing "done" / exit 0.
- README no longer claims the two paths converge on a single-entry
  `enabledPlugins`; the hand-write minimum and the CLI path are each described
  accurately.

## What did not work

(Appended during the build, at the moment each thing does not work.)
