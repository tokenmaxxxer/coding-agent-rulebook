# terse

Output-token compression tuned for the tokenmaxxxer stack. freelunch removes wasted orchestration (idle waits, verification passes); terse removes wasted output prose. The two compose: freelunch governs *what work runs*, terse governs *how tersely the main session talks about it*.

## How it works

A `UserPromptSubmit` hook injects a style directive on every prompt. The directive compresses the main session's conversational prose — status notes, findings, summaries — and nothing else.

Verbatim zones the directive never compresses:

- code, shell commands, paths, config, error messages
- **tool inputs: worker prompts, Workflow scripts, frozen contracts** — the freelunch-specific exemption; fan-out correctness depends on their precision
- content written into repository files
- safety-critical text: destructive-action confirmations, security warnings, ordered multi-step instructions

On top of the per-level style, four output-economy rules apply at every level: no echoing code or file content that already appeared in the conversation (reference file:line instead), no formatting scaffolding on short answers (headers/bold/bullets only where structure carries information), no narrating tool calls or re-describing steps the user already watched, and no re-summarizing unchanged state — deltas only.

The substance rule caps all levels: compression deletes filler, never information. If compressed output would force a follow-up question, it compressed the wrong thing.

A language-economy rule ("repo-bound text defaults to English") was added in v0.2.1 and removed in v0.2.2 after an A/B run measured zero effect: across 12 runs of Korean-prompted artifact tasks (docstrings, README, commit messages), artifacts came out 100% English with or without the rule — the model's baseline convention already does this — while user-facing replies stayed Korean in both arms. The rule's per-turn injection cost bought nothing, so it was removed. (Data: terse-lang-bench, 2026-07-19.)

Scope note: terse stays in Caveman's lane — it compresses only what the model itself says. Input-side savings (bounded reads, tool-result trimming) are deliberately out of scope.

## Levels

| Level | Behavior |
| --- | --- |
| `off` | Hook injects nothing |
| `lite` | Drops filler sentences, keeps full grammar |
| `full` | Default. No pleasantries or preamble; fragments where unambiguous |
| `ultra` | Telegraphic; minimum viable words, tables over prose |

Korean-aware: `full` keeps particles that carry case or negation (dropping them can flip meaning); only `ultra` goes telegraphic in Korean.

## Usage

```
/terse           # show current level
/terse ultra     # set level (off | lite | full | ultra)
```

State lives in `~/.claude/terse.level` (missing file = `full`). Kill switch without uninstalling: `export TERSE_OFF=1`, mirroring `FREELUNCH_OFF`.

## Why not Caveman

[Caveman](https://github.com/JuliusBrussee/caveman) compresses everything the model says. Running it next to freelunch risks fragment-compressed worker prompts and contracts — the one place precision pays for itself. terse scopes compression to conversational prose and explicitly subordinates itself to orchestration directives. Caveman's own README notes the honest caveat that applies here too: only output tokens shrink, and the injected directive costs input tokens every turn, so terse workloads can be net-negative. Measure before claiming savings.
