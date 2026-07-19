#!/usr/bin/env python3
"""blueprint prep CLI — deterministic archetype selection over the CSV databases.

Three modes:
  classify   route the task to an archetype from three yes/no answers
  recommend  print the full course for an archetype: structure, gate,
             fan-out prep (width unit + contract to freeze), anti-patterns
  search     keyword lookup across all three databases

Stdlib only. The CSVs are the source of truth; this script never invents
content — it selects and formats rows. Token contract: the model runs this
on demand instead of holding the databases in context.
"""
import argparse
import csv
import os
import sys

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")


def load(name):
    with open(os.path.join(DATA_DIR, name), newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def classify(args):
    if args.single_file:
        print("VETO: single file, single concern, no callers -> no-structure")
        print("Reason: ceremony where it doesn't earn its keep — just write it")
        print("correctly and note 'this is a script; flat is fine'.")
        return
    if args.surface == "ui":
        if args.external in ("yes", "plugin"):
            pick = "design-system"
        elif args.scale == "large":
            pick = "feature-module"
        else:
            pick = "ui-state-flow"
    elif args.surface == "infra":
        pick = "declarative-infra"
    elif args.surface == "ml":
        pick = "ml-train-serve" if args.serving == "yes" else "pipeline"
    elif args.surface == "agent":
        pick = "orchestrator-worker" if args.multi == "yes" else "agent-loop"
    elif args.surface == "game":
        pick = "ecs"
    elif args.surface == "distributed":
        pick = "distributed-service"
    elif args.external == "plugin":
        pick = "plugin-system"
    elif args.external == "yes":
        pick = "library"
    elif args.logic == "rich":
        pick = "domain-rich"
    elif args.logic == "transform":
        pick = "pipeline"
    elif args.asynchronous == "yes":
        pick = "event-driven"
    elif args.logic == "crud":
        pick = "data-centric"
    else:
        pick = "script"
    routes = {r["then"]: r for r in load("rules.csv") if r["type"] == "route"}
    reason = routes.get(pick, {}).get("reason", "")
    print(f"ARCHETYPE: {pick}")
    print(f"Routing reason: {reason}")
    if pick == "data-centric":
        print("Tiebreak note: if torn with domain-rich, stay data-centric — "
              "upgrading is cheaper than downgrading.")
    print(f"\nNext: prep.py recommend {pick} [--team N]")


def recommend(args):
    rows = {r["name"]: r for r in load("archetypes.csv")}
    if args.archetype not in rows:
        sys.exit(f"unknown archetype '{args.archetype}'; one of: {', '.join(rows)}")
    a = rows[args.archetype]
    print(f"=== {a['name'].upper()} — {a['defining_feature']} ===")
    print(f"\nONE RULE: {a['one_rule']}")
    print("\nMODULES:")
    for m in a["modules"].split("|"):
        print(f"  - {m}")
    print(f"\nGATE (constraints to build to — known before writing, not checked after): {a['gate']}")

    print("\nFAN-OUT PREP (freeze before dispatching workers):")
    print(f"  unit of width : {a['width_unit']}")
    print(f"  contract      : {a['contract_freeze']}")
    print("  threshold     : count the units — <=5 build solo, >5 fan out")
    if a["upgrade_note"]:
        print(f"\nRECLASSIFY: {a['upgrade_note']}")

    anti = [r for r in load("antipatterns.csv") if r["archetype"] in (a["name"], "any")]
    print("\nANTI-PATTERNS:")
    for r in anti:
        print(f"  - {r['name']}: {r['smell']} -> {r['instead']}")

    if args.team == 1:
        print("\nCONWAY: one owner — collapse elaborate module boundaries; "
              "they'd protect nothing.")

    print("\nPRINCIPLES (hold these while writing — never a post-build check pass):")
    print("  coupling   : each module hides exactly one nameable design decision")
    print("  cohesion   : each module describable without the word 'and'")
    print("  abstraction: no raw SQL/file/HTTP alongside domain logic in one function")


def tokenize(s):
    return [w for w in "".join(c.lower() if c.isalnum() else " " for c in s).split() if len(w) > 2]


def search(args):
    query = tokenize(" ".join(args.terms))
    scored = []
    sources = [("archetypes", load("archetypes.csv")), ("rules", load("rules.csv")),
               ("antipatterns", load("antipatterns.csv"))]
    for src, rows in sources:
        for row in rows:
            text = tokenize(" ".join(row.values()))
            score = sum(text.count(q) for q in query)
            if score:
                scored.append((score, src, row))
    scored.sort(key=lambda t: -t[0])
    if not scored:
        print("no matches")
        return
    for score, src, row in scored[: args.limit]:
        head = row.get("name") or row.get("then") or ""
        body = row.get("one_rule") or row.get("reason") or row.get("instead") or ""
        print(f"[{src}] {head} (score {score}): {body}")


def main():
    p = argparse.ArgumentParser(prog="prep.py")
    sub = p.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("classify", help="route the task to an archetype")
    c.add_argument("--single-file", action="store_true",
                   help="single file, single concern, no callers")
    c.add_argument("--surface", default="backend",
                   choices=["backend", "ui", "infra", "ml", "agent", "game", "distributed"],
                   help="what is being built; backend uses the three-question flow")
    c.add_argument("--external", choices=["no", "yes", "plugin"], default="no",
                   help="called by external code? plugin = caller is an extension; with --surface ui, yes = reusable component library")
    c.add_argument("--logic", choices=["none", "crud", "rich", "transform"], default="none",
                   help="business logic: crud=validation only, rich=rules exist without a DB, transform=data movement is the point")
    c.add_argument("--asynchronous", choices=["no", "yes"], default="no",
                   help="async messages across process boundaries?")
    c.add_argument("--scale", choices=["small", "large"], default="small",
                   help="ui only: large = many features needing vertical partitioning")
    c.add_argument("--multi", choices=["no", "yes"], default="no",
                   help="agent only: runtime decomposition across multiple agent roles?")
    c.add_argument("--serving", choices=["no", "yes"], default="yes",
                   help="ml only: is there an online serving path?")
    c.set_defaults(fn=classify)

    r = sub.add_parser("recommend", help="full course for an archetype")
    r.add_argument("archetype")
    r.add_argument("--team", type=int, default=0, help="number of maintainers")
    r.set_defaults(fn=recommend)

    s = sub.add_parser("search", help="keyword lookup across the databases")
    s.add_argument("terms", nargs="+")
    s.add_argument("--limit", type=int, default=5)
    s.set_defaults(fn=search)

    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
