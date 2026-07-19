# blueprint

Situational code-architecture selection for the tokenmaxxxer stack. Once the
situation is classified, the blueprint is set — one of sixteen archetypes, each
with its structure, gate, and anti-patterns, served from a queryable database
instead of prompt text.

The original seven (Script, Library, Data-Centric, Domain-Rich, Event-Driven,
Pipeline, Plugin System) come from the code-architecture decision framework.
Nine more were added from a 7-angle external research sweep (frontend, mobile,
agent/LLM, game/realtime, IaC, ML systems, canonical catalogs): ui-state-flow,
feature-module, design-system, distributed-service, agent-loop,
orchestrator-worker, declarative-infra, ml-train-serve, ecs. Merges made during
synthesis: web/mobile unidirectional-state candidates collapsed into
ui-state-flow; vertical-slicing candidates (feature-sliced design, mobile
feature modules) collapsed into feature-module; Terraform stacks + GitOps
collapsed into declarative-infra. CQRS and the actor model were deliberately
kept as discipline rows, not archetypes — the sources themselves warn CQRS
should never be an app-wide default, and actors are event-driven with
per-entity state ownership. All nine additions had consensus-grade sourcing
except feature-sliced design (emerging), which is folded under feature-module
rather than standing alone.

## Shape

The structure borrows what made ui-ux-pro-max work — curated data + a
deterministic CLI the model queries on demand — and swaps the domain:

```
skills/blueprint/
  SKILL.md              # trigger + 4-step workflow
  data/archetypes.csv   # 7 archetypes: one rule, modules, gate, fan-out prep
  data/rules.csv        # routing questions, vetoes, tiebreaks, disciplines
  data/antipatterns.csv # per-archetype and universal smells with replacements
  scripts/prep.py       # classify | recommend | search (stdlib only)
```

Knowledge lives in the CSVs; the script only selects and formats. The model
never carries the database in context — it runs `prep.py` when it needs a row.

## What differentiates it from the prompt-pack competitors

Existing architecture skills (keez97/claude-architecture-skills, the mcpmarket
pattern packs) are instruction text: the whole methodology rides along as
prompt tokens and the model free-forms the application. blueprint is:

- **Deterministic where determinism is cheap.** Routing, tiebreaks, and the
  proportionality veto are code, not judgment. Same inputs, same architecture.
- **Anti-over-engineering by construction.** The first classify question can
  return "no structure — write it flat," and the rule-of-three / name-the-change
  disciplines are vetoes in the database, not vibes.
- **Fan-out native.** Every archetype row carries a FAN-OUT PREP block: the
  unit of width and the exact contract to freeze (API signatures, schemas,
  event names, stage boundaries) before dispatching parallel workers. The
  output plugs straight into freelunch's width estimate and worker contracts.
- **No verification anywhere.** The recommendation is emitted once, and the
  gate is a set of constraints the code is written UNDER — known before the
  first line, never applied as a post-build check, re-read, or critique pass.

## Usage

```
python3 skills/blueprint/scripts/prep.py classify --external no --logic rich --asynchronous no
python3 skills/blueprint/scripts/prep.py recommend domain-rich --team 2
python3 skills/blueprint/scripts/prep.py search idempotency handler
```

## Lineage

The archetype taxonomy, gates, and disciplines condense the code-architecture
decision framework (Parnas 1972 information hiding, Yourdon & Constantine
coupling/cohesion, GoF 1994, Beck YAGNI, Conway's Law, Evans 2003 DDD). The
taxonomy is MECE by construction, not experimentally validated — its value is
routing to the right body of rules, same as the source methodology.
