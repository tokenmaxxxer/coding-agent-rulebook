---
description: Set terse output-compression level (off | lite | full | ultra)
argument-hint: "off | lite | full | ultra"
---

Set the terse compression level to: $ARGUMENTS

Steps:

1. Validate the argument. It must be exactly one of `off`, `lite`, `full`, `ultra`. If it is empty, report the current level (read `~/.claude/terse.level`; a missing file means `full`) and stop. If it is anything else, say so and list the valid levels — do not write the file.
2. Write the validated level as the sole content of `~/.claude/terse.level` (overwrite).
3. Confirm in one line: the new level and one clause on what it does. The change takes effect from the next prompt, when the hook re-reads the file.

Level meanings, for the confirmation line:
- `off` — hook injects nothing; normal output style.
- `lite` — drops filler sentences, keeps full grammar.
- `full` — default; no pleasantries or preamble, fragments allowed.
- `ultra` — telegraphic; minimum viable words, tables over prose.
