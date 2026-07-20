#!/usr/bin/env bash
# observe.sh — PreToolUse telemetry (+ optional enforcement) for freelunch
# rule compliance. Reads the tool-call JSON from stdin, appends one JSONL line
# per Agent/Task/Workflow dispatch to $FREELUNCH_OBSERVE_LOG (default
# ~/.claude/freelunch-observe.jsonl), flagging syntactically checkable
# freelunch-NEVER violations:
#   sync_agent_dispatch — Agent/Task called with run_in_background: false
# Default mode is observe-only (always allows). With FREELUNCH_ENFORCE=1 a
# flagged call is DENIED with a corrective reason; the logged row records
# "enforced": true. Denial converts the dispatch, it never loses work: a
# background dispatch + completion notification is semantically equivalent
# to waiting synchronously. Kill switch: FREELUNCH_OFF=1 (no log, no deny).

[ -n "${FREELUNCH_OFF:-}" ] && exit 0
LOG="${FREELUNCH_OBSERVE_LOG:-$HOME/.claude/freelunch-observe.jsonl}"

# Capture the hook payload BEFORE anything else touches stdin.
PAYLOAD="$(cat 2>/dev/null || true)"

OBSERVE_PAYLOAD="$PAYLOAD" FREELUNCH_ENFORCE="${FREELUNCH_ENFORCE:-}" python3 -c '
import json, sys, time, os

log_path = sys.argv[1]
enforce = os.environ.get("FREELUNCH_ENFORCE") == "1"
try:
    payload = json.loads(os.environ.get("OBSERVE_PAYLOAD", ""))
except Exception:
    sys.exit(0)

tool = payload.get("tool_name", "")
if tool not in ("Agent", "Task", "Workflow"):
    sys.exit(0)

inp = payload.get("tool_input") or {}
row = {
    "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "session": payload.get("session_id", ""),
    "tool": tool,
    "violations": [],
}
if tool in ("Agent", "Task"):
    bg = inp.get("run_in_background")
    row["background"] = bg
    row["model"] = inp.get("model", "")
    row["prompt_chars"] = len(inp.get("prompt", "") or "")
    if bg is False:
        row["violations"].append("sync_agent_dispatch")
else:  # Workflow
    row["script_chars"] = len(inp.get("script", "") or "")
    row["named"] = inp.get("name", "")

row["enforced"] = bool(enforce and row["violations"])

try:
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    with open(log_path, "a") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")
except Exception:
    pass

if row["enforced"]:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                "freelunch: synchronous Agent dispatch (run_in_background: false) is "
                "blocked — a synchronous call is the orchestrator idling. Re-issue the "
                "SAME Agent call with run_in_background: true; you will be notified on "
                "completion, which is semantically equivalent to waiting. Do not drop "
                "or shrink the task in response to this denial."
            ),
        }
    }))
' "$LOG" 2>/dev/null
exit 0
