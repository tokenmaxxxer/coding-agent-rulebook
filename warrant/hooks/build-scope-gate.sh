#!/usr/bin/env bash
# PreToolUse gate (Bash matching `git commit`) — contract §19, coding side.
#
# Front-record scope-approved check before a subject's FIRST build commit.
# On a `git commit` whose staged set lands coding's build path (src/...) for a
# subject, read that subject's FRONT record
# (docs/reports/records/<subject>/{product,feasibility}.md, whichever exists)
# and require its loop_state to be `scope-approved`. If the front record is
# missing/unreadable/malformed, or its loop_state is anything other than
# scope-approved => refuse. First-build-only: a commit landing after a prior
# build commit already exists for this subject is never refused here.
#
# HARD BOUNDARY: this gate only verifies a human-owned scope approval was
# RECORDED (loop_state: scope-approved, set via the product/feasibility repos'
# human-actor transition). It never performs the approval.
#
# Additive sibling to scope-gate.sh; never edits it. FAIL-CLOSED on every
# malformed/missing-input branch (modeled on ops-cycle/state-gate.sh).
set -uo pipefail

deny() { echo "warrant: refused — $*" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || deny "build-scope-gate.sh requires python3, which is not on PATH; denying rather than guessing."
command -v git >/dev/null 2>&1 || deny "build-scope-gate.sh requires git, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"

# Root: this gate fires on a Bash commit, so it has no file target — resolve
# from a validated CLAUDE_PROJECT_DIR, else the git top-level of cwd.
_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; failing closed (§19 build-scope cannot be judged)."

BS_PAYLOAD="$payload" BS_ROOT="$root" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, subprocess, sys

    def deny(m):
        sys.stderr.write("warrant: refused — " + m + "\n"); sys.exit(2)

    raw = os.environ.get("BS_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; failing closed on §19.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on §19.")

    if ev.get("tool_name") != "Bash":
        sys.exit(0)
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a commit it cannot parse (§19).")
    cmd = ti.get("command")
    if not isinstance(cmd, str) or not cmd.strip():
        sys.exit(0)
    if not re.search(r'\bgit\b[^\n]*\bcommit\b', cmd):
        sys.exit(0)  # not a commit — not this gate's business

    root = posixpath.normpath(os.environ["BS_ROOT"].replace("\\", "/"))

    def git(*args):
        try:
            return subprocess.run(["git", "-C", root, *args],
                                  capture_output=True, text=True, timeout=30)
        except Exception:
            return None

    # --- staged file set ---
    r = git("diff", "--cached", "--name-only")
    if r is None or r.returncode != 0:
        deny("could not read the staged file set (`git diff --cached`); failing closed on §19.")
    staged = [ln.strip() for ln in r.stdout.splitlines() if ln.strip()]

    BUILD_RE = re.compile(r'^src/')
    build_files = [f for f in staged if BUILD_RE.match(f)]
    if not build_files:
        sys.exit(0)  # not a build commit — not this gate's business

    # --- derive subject(s): from a staged coding record path, else a Subject: trailer ---
    subjects = set()
    for f in staged:
        m = re.match(r'^docs/reports/records/([^/]+)/coding\.md$', f)
        if m:
            subjects.add(m.group(1))
    for m in re.finditer(r'(?im)^\s*subject:\s*([A-Za-z0-9._-]+)\s*$', cmd):
        subjects.add(m.group(1))

    if not subjects:
        # build files staged but no subject attributable => cannot verify approval
        deny(
            "this commit stages build files under src/ but no subject can be attributed to it "
            "(no staged docs/reports/records/<subject>/coding.md and no `Subject:` trailer). §19 "
            "requires the first build of a subject to have a scope-approved front record; the "
            "gate fails closed rather than let an unattributable first build through."
        )

    def loop_state_of(path_abs):
        try:
            with open(path_abs, encoding="utf-8-sig") as fh:
                text = fh.read(1 << 20)
        except OSError:
            return None, "unreadable"
        if not text.startswith("---"):
            return None, "no-frontmatter"
        end = text.find("\n---", 3)
        if end == -1:
            return None, "no-frontmatter-close"
        m = re.search(r'^\s*loop_state:\s*([A-Za-z0-9_-]+)\s*$', text[3:end], re.M)
        if not m:
            return None, "no-loop_state"
        return m.group(1).strip().lower(), None

    def prior_build_exists(subject):
        # a prior commit whose message names this subject AND that touched src/
        log = git("log", "--all", "--format=%H", "--", "src")
        if log is None or log.returncode != 0:
            return None  # indeterminate
        for h in [x.strip() for x in log.stdout.splitlines() if x.strip()]:
            body = git("log", "-1", "--format=%B", h)
            if body is None:
                continue
            b = body.stdout
            if re.search(r'(?im)^\s*subject:\s*' + re.escape(subject) + r'\s*$', b) or subject in b:
                return True
        return False

    for subject in sorted(subjects):
        pb = prior_build_exists(subject)
        if pb is None:
            deny("could not determine whether a prior build commit exists for subject '%s'; failing closed on §19." % subject)
        if pb:
            continue  # not the first build — §19 does not gate re-wakes/fixes

        front = None
        for role in ("product", "feasibility"):
            cand = posixpath.join(root, "docs/reports/records", subject, role + ".md")
            if os.path.isfile(cand):
                front = cand
                break
        if front is None:
            deny(
                "subject '%s' has no scope-approved front record "
                "(docs/reports/records/%s/{product,feasibility}.md is missing). Per contract §19, "
                "coding may not commit a subject's first build until the human has approved its "
                "scope statement." % (subject, subject)
            )
        state, err = loop_state_of(front)
        if err is not None:
            deny(
                "subject '%s' front record %s is unreadable/malformed (%s); failing closed on §19."
                % (subject, front[len(root):].lstrip("/"), err)
            )
        if state != "scope-approved":
            deny(
                "subject '%s' front record shows loop_state: %s, not scope-approved. Per contract "
                "§19, coding may not commit a subject's first build until the human has approved "
                "its scope statement." % (subject, state)
            )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("build-scope-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "build-scope-gate.sh: fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"