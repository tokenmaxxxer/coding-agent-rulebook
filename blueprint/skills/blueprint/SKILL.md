---
name: blueprint
description: >-
  Situational code-architecture selection backed by a queryable database and a
  deterministic CLI. Use whenever you are about to produce non-trivial code
  spanning multiple modules or files and need to decide structure — "how should
  I structure this", "what pattern should I use", "design the architecture",
  "이 코드 어떻게 구조화할까", "아키텍처 잡아줘" — or before fanning work out
  to parallel workers and needing the contract to freeze. Do NOT use for a
  single-file script, a one-line fix, or purely algorithmic work: run the
  classify step anyway if unsure — it vetoes structure for those cases.
---

# blueprint — the course is set by the situation

Structure is a function of what the code IS and what CHANGES about it. This
skill routes the task to one of seven archetypes (Parnas 1972 → DDD 2003
lineage) and returns the structure, gates, and anti-patterns from a curated
database. Do not paste the CSVs into context; query them.

## Workflow

1. **Classify.** First pick the surface — backend (default), ui, infra, ml,
   agent, game, or distributed. Backend then answers three questions
   (external callers? / logic: crud, rich, or transform? / async across
   processes?); the other surfaces route directly with at most one modifier
   (`--scale` for ui, `--multi` for agent, `--serving` for ml):

   ```
   python3 <skill-dir>/scripts/prep.py classify --surface backend --external no --logic crud --asynchronous no
   python3 <skill-dir>/scripts/prep.py classify --surface agent --multi yes
   ```

   Pass `--single-file` when the task is one file, one concern, no callers —
   the tool will veto structure entirely. Honor the veto: write the code flat
   and move on.

2. **Recommend.** Fetch the full course for the routed archetype:

   ```
   python3 <skill-dir>/scripts/prep.py recommend <archetype> --team <N>
   ```

   Output contains: the one rule, the module layout, the gate that must hold,
   the anti-patterns to avoid, and the FAN-OUT PREP block.

3. **Freeze the contract, then build to the gate.** The FAN-OUT PREP block
   names the unit of width and exactly what to freeze (API signatures,
   schemas, event names, interfaces). Count the units: 5 or fewer, build solo
   in this session; more than 5, freeze the contract first and dispatch one
   worker per unit. The frozen contract is the entire shared context a worker
   needs. The GATE and PRINCIPLES lines are constraints you write code UNDER
   — know them before the first line, satisfy them as you go. There is no
   post-build check step: never re-read finished units against the gate, and
   never add a review pass. A mixed system gets classified per component,
   each component built to its own archetype's gate.

## Rules of engagement

- One archetype simpler beats one archetype fancier: when torn, take the
  simpler one; the RECLASSIFY line in the output tells you the exact trigger
  for upgrading later.
- Every layer must name the change it contains. Use
  `prep.py search <keywords>` to pull disciplines and anti-patterns on demand.
- The recommendation is emitted once and is deterministic. Do not iterate on
  it, second-guess it, or re-run classify hoping for a different answer —
  if the situation changed, the inputs changed; rerun with the new inputs.
