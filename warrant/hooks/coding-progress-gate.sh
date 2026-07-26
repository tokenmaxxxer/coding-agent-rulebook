#!/usr/bin/env bash
# PreToolUse gate (Bash matching `git commit`) — contract §15 (verify's
# blocking-finding predicate, implemented HERE in coding's rulebook because
# coding is the role being refused progress).
#
# Before a coding commit lands for a subject, read the subject's verify record
# docs/reports/records/<subject>/verify.md (same target repo coding is
# building) and scan for inline `finding` blocks with severity: blocking and
# addressed_to: coding. Each such finding counts as STILL BLOCKING unless
# coding's own record docs/reports/records/<subject>/coding.md carries a
# `resolved_findings` entry naming that finder's path + finder-record sha AND
# the finder's record loop_state is `cleared`. An unresolved blocking finding
# => refuse the commit.
#
# Additive sibling to scope-gate.sh; never edits it. FAIL-CLOSED on every
# malformed/missing-input branch (modeled on ops-cycle/state-gate.sh): if
# verify.md is present but unreadable/unparseable, refuse rather than pass.
set -uo pipefail

deny() { echo "warrant: refused — $*" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || deny "coding-progress-gate.sh requires python3, which is not on PATH; denying rather than guessing."
command -v git >/dev/null 2>&1 || deny "coding-progress-gate.sh requires git, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; failing closed (§15 progress cannot be judged)."

CP_PAYLOAD="$payload" CP_ROOT="$root" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, subprocess, sys

    def deny(m):
        sys.stderr.write("warrant: refused — " + m + "\n"); sys.exit(2)

    raw = os.environ.get("CP_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; failing closed on §15.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on §15.")

    if ev.get("tool_name") != "Bash":
        sys.exit(0)
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a commit it cannot parse (§15).")
    cmd = ti.get("command")
    if not isinstance(cmd, str) or not cmd.strip():
        sys.exit(0)
    if not re.search(r'\bgit\b[^\n]*\bcommit\b', cmd):
        sys.exit(0)

    root = posixpath.normpath(os.environ["CP_ROOT"].replace("\\", "/"))

    def git(*args):
        try:
            return subprocess.run(["git", "-C", root, *args],
                                  capture_output=True, text=True, timeout=30)
        except Exception:
            return None

    r = git("diff", "--cached", "--name-only")
    if r is None or r.returncode != 0:
        deny("could not read the staged file set (`git diff --cached`); failing closed on §15.")
    staged = [ln.strip() for ln in r.stdout.splitlines() if ln.strip()]

    # derive subject(s) from staged coding record, staged build files' subject via
    # trailer, or a Subject: trailer in the commit message.
    subjects = set()
    for f in staged:
        m = re.match(r'^docs/reports/records/([^/]+)/coding\.md$', f)
        if m:
            subjects.add(m.group(1))
    for m in re.finditer(r'(?im)^\s*subject:\s*([A-Za-z0-9._-]+)\s*$', cmd):
        subjects.add(m.group(1))
    if not subjects:
        sys.exit(0)  # no subject attributable — not this gate's business

    def read(path_abs):
        try:
            with open(path_abs, encoding="utf-8-sig") as fh:
                return fh.read(1 << 20)
        except OSError:
            return None

    # Parse inline finding blocks. A finding block is delimited by a `finding`
    # marker line; fields severity/addressed_to/id/from live on their own lines
    # until the next `finding` marker or a `---` fence.
    FINDING_SPLIT = re.compile(r'(?im)^\s*(?:-\s*)?finding\b.*$')

    def parse_findings(text):
        parts = FINDING_SPLIT.split(text)
        # parts[0] is preamble before the first finding marker
        blocks = parts[1:]
        out = []
        for b in blocks:
            seg = re.split(r'(?m)^\s*---\s*$', b, 1)[0]
            sev = re.search(r'(?im)^\s*severity:\s*([A-Za-z0-9_-]+)', seg)
            adr = re.search(r'(?im)^\s*addressed_to:\s*([A-Za-z0-9_-]+)', seg)
            fid = re.search(r'(?im)^\s*(?:id|finding_id):\s*([A-Za-z0-9._-]+)', seg)
            out.append({
                "severity": (sev.group(1).lower() if sev else None),
                "addressed_to": (adr.group(1).lower() if adr else None),
                "id": (fid.group(1) if fid else None),
            })
        return out

    for subject in sorted(subjects):
        vpath = posixpath.join(root, "docs/reports/records", subject, "verify.md")
        if not os.path.isfile(vpath):
            continue  # no verify record for this subject — nothing to gate
        vtext = read(vpath)
        if vtext is None:
            deny("subject '%s' verify record exists but cannot be read; failing closed on §15." % subject)

        findings = parse_findings(vtext)
        blocking = [f for f in findings
                    if f["severity"] == "blocking" and f["addressed_to"] == "coding"]
        if not blocking:
            continue

        cpath = posixpath.join(root, "docs/reports/records", subject, "coding.md")
        ctext = read(cpath) if os.path.isfile(cpath) else ""
        if ctext is None:
            deny("subject '%s' coding record exists but cannot be read; failing closed on §15." % subject)

        # verify record's own loop_state must be cleared for a finding to count resolved.
        vstate_m = re.search(r'^\s*loop_state:\s*([A-Za-z0-9_-]+)\s*$', vtext, re.M)
        vstate = vstate_m.group(1).lower() if vstate_m else None

        for f in blocking:
            fid = f["id"]
            # coding must carry a resolved_findings entry naming the verify record
            # path + a sha, and the verifier's record must currently be `cleared`.
            has_resolved = False
            # look for a resolved_findings section that references verify.md + a sha
            if re.search(r'(?is)resolved_findings', ctext):
                block = ctext
                names_verify = ("verify.md" in block) or (
                    fid is not None and re.search(re.escape(fid), block))
                has_sha = re.search(r'\b[0-9a-f]{7,40}\b', block) is not None
                has_resolved = bool(names_verify and has_sha)
            if not (has_resolved and vstate == "cleared"):
                deny(
                    "verify.md carries an unresolved blocking finding addressed_to: coding for "
                    "subject '%s' (finding id: %s, verify loop_state: %s). Resolve it "
                    "(finding-response + a resolved_findings entry naming the finder path + sha, "
                    "and re-verification to loop_state: cleared) before this commit lands, per "
                    "contract §15." % (subject, fid or "(unnamed)", vstate)
                )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("coding-progress-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "coding-progress-gate.sh: fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"