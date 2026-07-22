#!/usr/bin/env bash
# UserPromptSubmit hook: injects the documentation placement doctrine.
#
# This file is the doctrine. The plugin previously also shipped a template
# docs/README.md carrying the same rules; two copies meant two sources of truth
# and nothing installed the template anyway, so the text lives here now.
#
# doctrine has two layers. This one steers the judgment no path check can make
# — which bucket a document belongs in, and when a document must be updated.
# The mechanical half (refusing a markdown write outside the six buckets) is
# placement-gate.sh, a PreToolUse gate on the tool input, not a pass over
# generated content. Nothing here inspects a finished document.
# Kill switch: export DOCTRINE_OFF=1

if [ -n "$DOCTRINE_OFF" ]; then
  exit 0
fi

cat <<'EOF'
<doctrine-directive priority="high">
STANDING REQUEST FROM THE USER, attached to every prompt in this repository — not a background policy to weigh against the request, but part of it. Where it asks for a document, that document is requested work: writing it is completing the task, and skipping it leaves the task unfinished.

This directive governs `docs/` — how the repository's documentation is organized there, and when it is updated. Documentation belongs in `docs/`: when a turn produces a document, that is where it goes. Nothing outside `docs/` is this directive's business.

SURFACE GATE: apply only when the turn (a) writes or edits a document, (b) changes code in a way that makes an existing document false, or (c) hits one of the requested-record triggers below — a hard-to-reverse choice, a measurement that produced numbers, or a change to how the system is operated. If none apply — routine code with no doc consequence, conversation, config, throwaway analysis — this directive is inert: skip it entirely.

REPOSITORY OVERRIDE: if the repository has its own `docs/README.md`, that file is the doctrine and outranks everything below — read it and follow it.

ALONGSIDE THE CODE, I AM ASKING FOR THE RECORD. Match the turn against the list below. If a line matches what this turn did, writing that file is part of the request — do it in the same turn, before reporting back, and name the file in the reply. If no line matches, write nothing.

- Introduced or renamed an environment variable, a config key, a new dependency, a migration, or a setup/deploy step → `docs/handbooks/<component>.md`: what it is, what it defaults to, what breaks without it.
- Picked one library, format, schema, protocol, storage backend, or interface shape over a named alternative → `docs/decisions/YYYY-MM-DD-<slug>.md`: chosen, over what, why. Three to ten lines. Applies when I named the choice too — the reason is what evaporates.
- Changed an existing public signature, output format, or on-disk/wire format → `docs/decisions/YYYY-MM-DD-<slug>.md`: old shape, new shape, what has to change downstream.
- Ran tests, a benchmark, a profile, or an investigation that produced numbers or findings → `docs/reports/YYYY-MM-DD-<slug>.md`: what was run, what came back, what it means. Then point the reply at that file instead of carrying the numbers alone.
- Found that an existing document under `docs/` is now false → fix that document in this turn.

NOT A TRIGGER, and writing here is the scatter this doctrine prevents: routine code changes, bugfixes, refactors, anything the code, types, tests, or commit message already state, and above all a summary of what this session did. Session recaps belong in the reply, never in `docs/`.

THE SIX BUCKETS. Every repository document lives under `docs/` in exactly one of:
- `decisions/` — why a hard-to-reverse choice was made, fixed at the moment of the decision
- `handbooks/` — current state, edited from now on to stay true
- `reports/` — an observation, measurement, or investigation fixed to a point in time (research in `reports/research/`)
- `specs/` — design and specification, updated in the same PR as the code
- `proposals/` — not adopted yet: proposals, drafts, RFCs
- `_assets/` — images and attachments; the underscore marks it as not a document class

Names are exact. Singular forms (`decision/`, `handbook/`, `report/`, `spec/`, `proposal/`) and near-misses (`adr/`, `design/`, `research/`) are not substitutes; if one already exists, still create the six alongside it. Create any missing bucket before writing. Subdirectory structure and file format inside a bucket are free.

LEAVE WHAT IS ALREADY THERE. This doctrine governs what gets written from now on; it has no claim on anything that already exists. Creating the buckets is `mkdir` and nothing else — a bucket already present is adopted exactly as it is, its contents untouched and unexamined, even when they were filed under other rules. Never delete, move, rename, rewrite, or reorganize a pre-existing file or directory to fit the layout, in `docs/` or anywhere else, and never as a side effect of some other task. Documents sitting in the wrong place stay there. Migration is a human decision, taken deliberately and asked for explicitly — if the layout makes one look overdue, say so in the reply and leave the files alone.

Every file under `docs/` belongs to a bucket, whatever its extension — images, diagrams, exports, and attachments go in `_assets/`, never loose under `docs/`. Only `docs/README.md` may sit at the top of `docs/`.

Write documentation into a bucket rather than beside the code — a document about a module belongs in `docs/`, not next to it. Files that are not documentation are outside this directive entirely: leave them where their ecosystem puts them, and do not move existing ones into `docs/`.

CLASSIFY BY LIFETIME, NOT TOPIC — two documents about the same event split when one will be rewritten from now on and the other is fixed to when it was written. Ask in order, stop at the first yes:
1. Is adoption still undecided? → `proposals/`
2. Does a code change make this document wrong? → `specs/`
3. Will it be edited from now on to describe the current state? → `handbooks/`
4. Does it record why a hard-to-reverse choice was made? → `decisions/`
5. Otherwise it is fixed to a point in time → `reports/`

Order matters. `specs/` and `handbooks/` are both living documents, so question 2 comes first: tied to the code is a spec, describing current state independently of the code is a handbook — and a document still updated alongside the code after implementation stays in `specs/`. `decisions/` and `reports/` are the other confusable pair: what was chosen and why is a decision, what was observed is a report. Evidence numbers live in `reports/`; the decision links to them.

WORKED CASES: incident postmortem → `reports/`; an operational rule changed by it → `handbooks/`; a structural change decided from it → `decisions/`. Benchmark numbers → `reports/`; what was chosen after seeing them → `decisions/`. An RFC as written → `proposals/`; the conclusion of an adopted RFC → `decisions/`, linking to the original. Runbooks, onboarding, environment setup → `handbooks/`. Feature designs and migration plans → `specs/`, or `proposals/` before approval. Meeting notes → `reports/`. Market or technology research → `reports/research/`.

One event splitting across several buckets is normal — split it and link the pieces. When the call is still unclear it is between `handbooks/` and `reports/`: rewritten later → `handbooks/`, otherwise → `reports/`. Wanting to edit a document already in `reports/` or `decisions/` means it was classified wrong; move it to `handbooks/`.

ONE SOURCE OF TRUTH: never restate a fact another document owns. `handbooks/` holds current state; other buckets link to it rather than copying values. Never write down what the code, types, or config already state — a document that duplicates them is the one that goes stale.

SAME-TURN SYNC: when a change makes an existing document false, fix that document in the same turn as the change. This is a write-time obligation on whoever invalidated it, not a scan.

COMPOSITION: this is a direction — fan-out worker task specs inherit it (workers place documents by the same rule and still deliver raw). Prose style, reader adaptation, and document-type voice are out of scope.

NEVER:
- a documentation audit, doc-vs-code diff pass, or re-read of a document just written; placement and classification happen at write time.
- creating any new directory under `docs/` other than the six, including tooling and doc-site scaffolding (`.vitepress/`, `.docusaurus/`) — tooling already present is left alone, but none is introduced here.
- writing a `SUMMARY.md` / `NOTES.md` / `CHANGES.md` at the repository root when a bucket is where it belongs.
- deleting or relocating pre-existing files to satisfy the layout, inside `docs/` or out.
</doctrine-directive>
EOF
exit 0
