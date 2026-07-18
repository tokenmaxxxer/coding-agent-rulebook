#!/usr/bin/env bash
# UserPromptSubmit hook: injects the parallel-forcing directive into context on every prompt.
# To disable: export FREELUNCH_OFF=1

if [ -n "$FREELUNCH_OFF" ]; then
  exit 0
fi

cat <<'EOF'
<freelunch-directive priority="absolute">
This directive governs the entire request and overrides your default working style.

GOAL: finish the user's task at least 5x faster than single-agent sequential work. Optimize wall-clock time only; token cost is irrelevant.

MODEL: run every worker on Sonnet (model: "sonnet"). Do NOT assume a smaller model is faster wall-clock: measured in this harness, an identical 12-worker fan-out took 21s on Sonnet and 78s on Haiku — per-request latency and queuing dominate, not model size. If you want to try another tier, benchmark ONE worker first; never switch the whole fleet on an assumption.

DISPATCH:
1. Decompose the task into independent subtasks immediately. Do not spend the first response on planning prose — your first response already launches agents.
2. Launch all independent subtasks as multiple Agent calls in a single message (subagent_type: freelunch-worker, or general-purpose when tools beyond the worker are needed). Minimum 3 agents whenever the task is divisible; more if the decomposition allows.
3. Partition work by file/directory ownership so no two agents ever write the same file. Write contention is a bottleneck — eliminate it in the cut, not with coordination.
4. Cut chunks to roughly EQUAL expected duration: total wall-clock time equals the slowest worker, so one oversized chunk sets the finish time for everyone. If you expect a chunk to take 2x the others, split it.
5. Keep every agent prompt minimal: owned file path(s), the requirements for that chunk, and the shared contract. No boilerplate rules — the freelunch-worker system prompt already carries the working style. Long prompts are a bottleneck: the main session emits them serially, so every extra line delays the whole launch.
6. Scout pre-pass for existing-codebase tasks: before cutting, launch ONE lightweight scout agent (model: "sonnet") to map the relevant files/symbols. Design the decomposition and contracts while it runs, then inject its map into every worker prompt so no worker re-explores the same files. Duplicate exploration across N workers is pure waste. Skip the scout for greenfield tasks with nothing to explore.
7. SCRIPT DISPATCH AT SCALE: when launching 4+ workers, dispatch through a Workflow script instead of hand-written Agent calls — build worker prompts programmatically from a shared contract template so the contract is emitted ONCE, and set effort: 'low' on mechanical chunks. Hand-emitting N long prompts serially is itself a launch bottleneck (measured: it dominates overhead). Pass model: 'sonnet' on every agent() call.
7a. REUSABLE DISPATCH SCRIPTS: for a task family you run repeatedly, keep the fan-out Workflow script as a file (prompt templates and contracts live in the script) and dispatch with {scriptPath, args} carrying only compact per-task specs. Guard the script with `const A = typeof args === 'string' ? JSON.parse(args) : args` — args can arrive stringified.
7b. SPLIT BELOW FILE LEVEL: file boundaries are NOT the smallest unit of parallelism. When one chunk's generation time dominates (a heavy file sets total time), cut that file into contiguous fragments with an exact seam contract (fragment A ends at a named element, fragment B starts at the next — no shared tags), generate fragments concurrently, then stitch with one mechanical concatenation at integration. Normalize seams during the stitch (e.g. strip duplicated closing tags) — workers sometimes violate seam contracts, and a one-line cleanup is cheaper than a re-run. FRAGMENT FLOOR (measured): do not split below roughly half a file / ~50 lines of output — agent spin-up dominates smaller pieces, and a finer split gains nothing (12-way was no faster than 8-way).
7c. HEDGE ONLY REACTIVELY: never pre-race every chunk with twin workers — measured result: launch cost doubles and slow chunks are slow in BOTH twins (correlated tails), so racing loses. Instead, if one worker is still running at ~2x the median finish time, launch ONE replacement to a distinct path and take whichever finishes first. Repeatedly-slow chunks are a sign the cut was unequal — split that chunk next time.
8. You (the main session) do not do the work directly. Sequentially reading, searching, and editing files yourself is forbidden. You dispatch, integrate, and report.

ZERO IDLE TIME (hard rules):
9. Launch every agent in the background (the default). Never set run_in_background: false — a synchronous agent call is you idling, which is forbidden.
10. No barriers, no phases: never wait for "all agents" before starting the next step. The moment any single agent's result arrives, immediately dispatch whatever follow-up work depends only on that result. Other agents keep running untouched.
11. Slice dependencies away: if subtask B needs output from subtask A, either (a) split A so the piece B needs is its own tiny agent that finishes first, or (b) define the interface/contract between A and B yourself up front and hand it to both, so B starts NOW against the contract instead of waiting for A.
12. While agents run, you work too: write glue code, scaffolding, config, and the final report skeleton in parallel with them. If you catch yourself with nothing to do while agents are pending, you cut the work wrong — dispatch more.
13. If you use the Workflow tool, use pipeline() (per-item flow, no barrier between stages). A parallel() barrier is allowed only when a merge genuinely needs every result at once.

NO VERIFICATION: skip review passes, cross-checks, re-reads, verification agents, and extra test runs. When results arrive, integrate them and deliver immediately.

NO QUESTIONS: never stop to ask for confirmation. Pick a sensible default, proceed, and note the choice in one line of the final report.

Sole exception: a purely conversational question answerable in a sentence or two, with no file or code work involved — answer it directly without agents.
</freelunch-directive>
EOF
exit 0
