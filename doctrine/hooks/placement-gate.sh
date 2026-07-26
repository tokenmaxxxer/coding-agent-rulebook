#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# ^ fail-closed trap-at-top: any abnormal termination (failed source, set -u
#   abort, unbound var, etc.) before the verdict logic runs is forced to
#   exit 2 (DENY), since a PreToolUse hook treats any non-2 exit as
#   NON-BLOCKING (fail-OPEN). Installed as the FIRST executable statement,
#   above any set/source. Legitimate exit 0 (allow) / exit 2 (deny) verdicts
#   pass through unchanged; only other codes are remapped to 2.
# PreToolUse hook (Write|Edit|NotebookEdit): refuses writes under docs/ that
# would land outside the six doctrine buckets.
#
# Scope is docs/ and nothing else. Outside it the gate is silent, whatever the
# extension — source, config, plugin manifests (SKILL.md, agents/*.md), notes
# next to the code. That the doctrine also asks documents not to scatter across
# the repository is the directive's business; this gate only owns the one claim
# a path can settle: inside docs/, this is not one of the six.
#
# Inside docs/ every file is governed regardless of extension — _assets/ is the
# bucket for images and attachments, so a PNG loose under docs/ is a violation
# like any other. Exceptions: docs/README.md (the doctrine a team writes for
# itself), a dot-directory or vendored tree that ALREADY exists (doc-site
# tooling is left alone, but new structure is not invented here), and whatever
# DOCTRINE_ALLOW lists.
#
# This inspects the TOOL INPUT — a path string, before the write happens. It is
# not a pass over generated content, and it makes no judgment about the
# document: which bucket a document belongs in is left to the directive, since
# a path cannot tell you that.
#
# Fails closed. A missing python3 or a payload this gate cannot parse/
# understand (unparseable JSON, non-dict event, non-dict tool_input, missing
# path) is refused rather than silently let through — this gate cannot
# distinguish a legitimate write from a hostile one it failed to read. Only
# genuinely-determined out-of-scope writes (outside the project, symlink
# resolves outside the project, not under docs/, a recognized bucket) still
# allow.
#
# Kill switch:  export DOCTRINE_OFF=1
# Escape hatch: export DOCTRINE_ALLOW="docs/package.json,docs/site"
#               comma-separated; each entry matches a whole path segment or a
#               path prefix relative to the project root.

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and to
# most tooling, but any non-empty value used to disable the hook — the kill switch
# silently killed it on exactly the spelling meant to keep it alive.
case "${DOCTRINE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || {
  echo "doctrine: refused — placement-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat)"

DOCTRINE_PAYLOAD="$payload" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json
    import os
    import posixpath
    import sys

    BUCKETS = ("decisions", "handbooks", "reports", "specs", "proposals", "_assets")
    # Vendored, generated, or otherwise not-ours trees.
    SKIP_DIRS = (
        "node_modules", "vendor", "dist", "build", "target", "out",
        "venv", ".venv", "site-packages", "coverage",
    )


    def allow():
        sys.exit(0)


    def deny(msg):
        sys.stderr.write("doctrine: refused — " + msg + "\n")
        sys.exit(2)


    try:
        event = json.loads(os.environ.get("DOCTRINE_PAYLOAD", ""))
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge a write it cannot parse")

    if not isinstance(event, dict):
        deny("the tool-call payload is not a JSON object; the gate cannot judge a write it cannot parse")

    tool_input = event.get("tool_input")
    if not isinstance(tool_input, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse")

    path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not isinstance(path, str) or not path:
        deny("no usable file_path/notebook_path in tool_input; the gate cannot judge a write it cannot identify")

    normalized = path.replace("\\", "/")

    root = (os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()).replace("\\", "/")
    absolute = posixpath.normpath(
        normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
    )
    root = posixpath.normpath(root)

    # Outside the project entirely (scratch dirs, /tmp) — not this gate's business.
    if absolute != root and not absolute.startswith(root + "/"):
        allow()

    # A bucket entry can be a symlink. What the doctrine governs is where the bytes
    # land, so resolve first and then apply the ordinary rule to the destination: a
    # link out of docs/ is a document that is not in docs/, which this gate has no
    # claim on — exactly as if it had been written there directly.
    resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
    real_root = posixpath.normpath(os.path.realpath(root).replace("\\", "/"))
    if absolute != resolved:
        if resolved != real_root and not resolved.startswith(real_root + "/"):
            allow()
        absolute, root = resolved, real_root

    relative = absolute[len(root) + 1:]
    segments = [s for s in relative.split("/") if s not in ("", ".")]
    if not segments:
        allow()

    directories, name = segments[:-1], segments[-1]

    if "docs" not in directories:
        allow()

    for extra in (os.environ.get("DOCTRINE_ALLOW") or "").split(","):
        extra = extra.strip().strip("/")
        if extra and (extra in directories or relative == extra or relative.startswith(extra + "/")):
            allow()

    # The doctrine file a team writes for itself sits at the top of docs/.
    if directories[-1] == "docs" and name == "README.md":
        allow()

    # Coding's two owned paths (contract v2 section 11) require a collaboration
    # contract to be in force before coding writes to either of them. This is
    # handoff-protocol.md section 2's "Absence behavior" refusal, now enforced
    # here instead of only stated in prose.
    is_build_proposal = (
        directories == ["docs", "proposals"] and name.endswith(".md")
        and "-build-" in name
    )
    is_coding_record = (
        len(directories) == 4
        and directories[:2] == ["docs", "reports"]
        and directories[2] == "records"
        and name == "coding.md"
    )
    if is_build_proposal or is_coding_record:
        if not os.path.isfile(posixpath.join(root, "docs", "specs", "role-handoff-contract.md")):
            print(
                "doctrine: refused — this repo has no collaboration contract yet\n"
                "`%s` is one of coding's owned paths, but `docs/specs/role-handoff-contract.md` "
                "is absent from this repo. Coding does not proceed as if a contract were in "
                "force." % relative,
                file=sys.stderr,
            )
            sys.exit(2)

    scaffolding = None
    for i, directory in enumerate(directories):
        if directory == "docs" or "docs" not in directories[:i]:
            continue
        if directory in BUCKETS:
            allow()
        if directory in SKIP_DIRS or directory.startswith("."):
            # Tooling already on disk is left alone; a new one is new structure.
            if os.path.isdir(posixpath.join(root, *directories[:i + 1])):
                allow()
            scaffolding = "/".join(directories[:i + 1])
        break

    buckets = ", ".join(b + "/" for b in BUCKETS)
    if scaffolding:
        reason = (
            "`%s` would create `%s`, a new directory under docs/ that is not one of the six "
            "buckets. Doc-site tooling already on disk is left alone, but new structure under "
            "docs/ is not invented here." % (relative, scaffolding)
        )
    else:
        reason = (
            "`%s` is under docs/ but not in one of the six buckets. Every file under docs/ "
            "belongs to a bucket — images and attachments go in _assets/." % relative
        )

    print(
        "doctrine: refused — %s\n"
        "The buckets are: %s.\n"
        "Classify by lifetime, not topic: undecided -> proposals/; invalidated by a code change -> specs/; "
        "kept current from now on -> handbooks/; why a hard-to-reverse choice was made -> decisions/; "
        "an observation fixed to a point in time -> reports/ (research under reports/research/).\n"
        "Create the bucket if it does not exist yet, then write there. Only docs/README.md may sit at the "
        "top of docs/; paths in DOCTRINE_ALLOW are exempt. A repository README describing other directories "
        "does not change this — the buckets are enforced here, and DOCTRINE_ALLOW is how a repository adds to them."
        % (reason, buckets),
        file=sys.stderr,
    )
    sys.exit(2)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("placement-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "placement-gate.sh: fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
