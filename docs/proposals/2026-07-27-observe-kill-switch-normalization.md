---
status: approved
files:
  - freelunch/hooks/observe.sh
  - freelunch/.claude-plugin/plugin.json
---

# Normalize the FREELUNCH_OFF kill switch in observe.sh

## 1. Intent

A before-landing hunter (docs/reports/2026-07-27-hunt-freelunch-directive-constitutes-workflow-opt-in.md) reproduced the same kill-switch defect in `freelunch/hooks/observe.sh` that was just fixed in `freelunch/hooks/freelunch.sh` (landed in commit cee65fc merge): observe.sh matches `FREELUNCH_OFF` against a raw, unnormalized whitelist (`""|0|false|no|off`) at line 16, so any unrecognized value — including a typo like `FREELUNCH_OFF=banana` — falls through to the `*` branch and exits 0, silently disabling all telemetry logging with no warning. freelunch.sh's fixed version (lines 155–161) normalizes the value (lowercase, trim) and, on an unrecognized value, warns on stderr and fails open instead of silently suppressing. This is the same defect class, missed in the earlier proposal because observe.sh was outside its write set.

## 2. Constraints

- Mirror freelunch.sh's landed semantics exactly: one normalization behavior across the plugin, not a second bespoke variant.
- Do not introduce a new shared-sourcing structure between observe.sh and freelunch.sh solely for this fix; the two scripts do not currently source a common file.

## 3. What will be done

- Apply the identical normalize-then-match logic to `freelunch/hooks/observe.sh`, replacing line 16:
  - Lowercase + trim the raw `FREELUNCH_OFF` value.
  - `""|0|false|no|off` → not off, continue normal operation (log as usual).
  - `1|true|yes|on` → off, exit 0 (no log, no deny), matching current intent.
  - Any other value → unrecognized: print a warning to stderr and continue normal operation (fail open to logging, never silent suppression).
- Duplicate the small normalization block into observe.sh rather than extracting a shared helper, since freelunch.sh and observe.sh do not already source a common file and this proposal does not introduce new sourcing structure.
- Bump `freelunch/.claude-plugin/plugin.json` version (currently `0.2.20`) to reflect the patch.
- Scan of other plugins under `freelunch/hooks/` and sibling plugin directories (`warrant`, `dispatch`, `scout`, `no-mock`, `blueprint`, `no-footgun`, `terse`, `coding-agent-env`, `doctrine`) found no other script reading `FREELUNCH_OFF` or an equivalent unnormalized kill-switch env var; only `observe.sh` and the already-fixed `freelunch.sh` reference it.

## 4. Out of scope

- `freelunch/hooks/freelunch.sh` — already fixed, no changes needed.
- Other plugins — the scan found no instance of the same env-var kill-switch pattern outside the freelunch plugin.
- Introducing a shared helper/sourcing mechanism between the two scripts.

## 5. Success

- `FREELUNCH_OFF=banana bash freelunch/hooks/observe.sh <typical hook payload>` prints an "unrecognized FREELUNCH_OFF value" warning to stderr and still logs the row (does not silently suppress).
- Recognized on-values (`1`, `true`, `yes`, `on`, case-insensitive, with surrounding whitespace) still suppress logging as before (exit 0, no log).
- Recognized not-off values (`""`, `0`, `false`, `no`, `off`) continue normal logging behavior unchanged.
- Direct-execution outputs (the JSONL log rows) are recorded exactly as before for all not-off cases.
