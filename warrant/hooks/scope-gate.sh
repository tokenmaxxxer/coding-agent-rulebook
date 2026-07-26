#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|NotebookEdit|Bash): enforces the two mechanical
# halves of the protocol.
#
#   1. While a proposal is approved and in progress, edits land only in paths
#      its frontmatter froze.
#   2. While one is in progress, a commit carries the `Proposal:` trailer.
#
# Both read the TOOL INPUT — a path, a command string — before anything happens.
# Neither reads generated content, and neither judges the work: which bucket, or
# whether the change is any good, is the directive's business.
#
# Inert unless exactly one proposal is `status: approved`. No open unit, none
# approved, or several at once (ambiguous) — the gate stands down rather than
# guessing.
#
# Fails closed on a missing python3 or an unreadable/malformed intake
# payload (unparseable JSON, non-dict event, non-dict tool_input) — the gate
# cannot judge a write it cannot parse. The core write-set/root/bash-target
# logic downstream remains default-deny as before.
# Kill switch: export WARRANT_OFF=1

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and to
# most tooling, but any non-empty value used to disable the hook — the kill switch
# silently killed it on exactly the spelling meant to keep it alive.
case "${WARRANT_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || {
  echo "warrant: refused — scope-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat)"

WARRANT_PAYLOAD="$payload" python3 <<'PY'
import fnmatch
import json
import os
import posixpath
import re
import sys

# `approved`, `Approved`, and `approved   # go` are the same intent; a value that
# is none of the three known states is reported rather than read as "not approved".
STATUS = re.compile(r"^status:\s*([A-Za-z]+)\s*(?:#.*)?$", re.M)
KNOWN_STATES = ("proposed", "approved", "landed")
# Same comment-tolerant shape as STATUS, parsing a record's declared `kind:`
# instead of a proposal's `status:` — `kind: build-proposal  # re-scoped`
# parses as `build-proposal`, per contract v2 section 2's rule that kind
# parsing must tolerate a trailing comment.
KIND = re.compile(r"^kind:\s*(\S+)\s*(?:#.*)?$", re.M)
# `git commit`, `git  commit`, `git -C path commit` are one command.
GIT_COMMIT = re.compile(r"\bgit\b(?:\s+-[A-Za-z]\S*(?:\s+\S+)?|\s+--\S+)*\s+commit\b")
FILE_ITEM = re.compile(r"^\s*-\s*(.+?)\s*$")


def allow():
    sys.exit(0)


def deny_intake(msg):
    sys.stderr.write("warrant: refused — " + msg + "\n")
    sys.exit(2)


try:
    event = json.loads(os.environ.get("WARRANT_PAYLOAD", ""))
except ValueError:
    deny_intake("the tool-call payload is not valid JSON; the gate cannot judge a write it cannot parse")
if not isinstance(event, dict):
    deny_intake("the tool-call payload is not a JSON object; the gate cannot judge a write it cannot parse")

tool = event.get("tool_name") or ""
tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny_intake("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse")

# --- gate-protection root resolution (contract: docs/proposals/2026-07-26-gate-root-from-project-dir.md) ---
# root candidate: CLAUDE_PROJECT_DIR when set; otherwise the git top-level of
# cwd. Without CLAUDE_PROJECT_DIR the cwd could be anywhere, so the
# git-toplevel fallback anchors the gate on a real project root rather than a
# scratch directory.
import subprocess

_env_project_dir = os.environ.get("CLAUDE_PROJECT_DIR")
if _env_project_dir:
    root = posixpath.normpath(_env_project_dir.replace("\\", "/"))
else:
    root = posixpath.normpath((os.getcwd()).replace("\\", "/"))
    try:
        top = subprocess.run(["git", "-C", root, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=5).stdout.strip()
        if top:
            root = posixpath.normpath(top.replace("\\", "/"))
        else:
            allow()
    except (OSError, subprocess.SubprocessError):
        allow()

# root VALIDITY (contract): the resolved root must be a plausible project
# root — either a git work-tree top-level, or a directory that itself
# carries docs/specs/role-handoff-contract.md. A CLAUDE_PROJECT_DIR pointing
# at an unrelated or empty directory (neither) is INDETERMINATE and refused
# outright rather than silently treated as "nothing to enforce here" — the
# default-deny this contract requires, since a stand-down (allow()) would
# quietly let a write into the real project's owned tree through unchecked.
def _is_git_toplevel(path):
    try:
        result = subprocess.run(["git", "-C", path, "rev-parse", "--show-toplevel"],
                                 capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return False
    top = result.stdout.strip()
    if not top:
        return False
    return posixpath.normpath(os.path.realpath(top).replace("\\", "/")) == \
        posixpath.normpath(os.path.realpath(path).replace("\\", "/"))


_root_has_contract = os.path.isfile(posixpath.join(root, "docs", "specs", "role-handoff-contract.md"))
if not (_root_has_contract or (os.path.isdir(root) and _is_git_toplevel(root))):
    print(
        "warrant: refused — the resolved project root (%s) is not a recognizable project root "
        "(no docs/specs/role-handoff-contract.md there, and it is not a git work-tree top-level "
        "itself). Refusing rather than trusting an unvalidated root." % root,
        file=sys.stderr)
    sys.exit(2)

proposals_dir = posixpath.join(root, "docs", "proposals")


def nested_units():
    """Proposal directories this gate does not read — a monorepo's packages/*/docs/proposals."""
    found = []
    for base, dirs, files in os.walk(root):
        depth = base[len(root):].count("/")
        if depth >= 4:          # packages/<name>/docs/proposals and no deeper
            dirs[:] = []
        dirs[:] = [d for d in dirs if not d.startswith(".") and d != "node_modules"]
        if base == proposals_dir:
            continue
        if base.replace("\\", "/").endswith("/docs/proposals") and any(
            f.endswith(".md") and f != "README.md" for f in files
        ):
            found.append(posixpath.relpath(base, root))
    return found


def stand_down():
    """Nothing enforceable here — but say why if the reason is reach, not absence."""
    nested = nested_units()
    if nested:
        print(
            "warrant: %s holds proposals, but this gate reads the repository root only "
            "(docs/proposals). Nothing is being enforced for those units."
            % ", ".join(nested), file=sys.stderr)
        sys.exit(1)
    allow()


if not os.path.isdir(proposals_dir):
    stand_down()


# Comment-tolerant fence match: the opening delimiter may be followed by
# trailing whitespace or a comment on the same line (`--- # frontmatter`),
# same as STATUS/KIND tolerate a trailing comment on their own lines. The
# fence line itself is still exactly three dashes, optionally trailed by
# whitespace/comment — this is the block form every proposal in this repo
# actually writes, not a new convention.
FENCE_OPEN = re.compile(r"\A[ \t]*---[ \t]*(?:#.*)?\r?\n")
FENCE_CLOSE = re.compile(r"\r?\n[ \t]*---[ \t]*(?:#.*)?[ \t]*(?:\r?\n|\Z)")


def frontmatter(path):
    try:
        with open(path, encoding="utf-8-sig") as handle:
            text = handle.read(65536)
    except (OSError, UnicodeDecodeError):
        # Unreadable bytes are as blinding as a missing closing `---`; both are
        # reported by the caller rather than crashing the gate open.
        return None
    opened = FENCE_OPEN.match(text)
    if not opened:
        return None
    closed = FENCE_CLOSE.search(text, opened.end())
    return text[opened.end():closed.start()] if closed else None


approved = []
malformed = []
for name in sorted(os.listdir(proposals_dir)):
    if not name.endswith(".md") or name == "README.md":
        continue
    block = frontmatter(posixpath.join(proposals_dir, name))
    if block is None:
        malformed.append(name)
        continue
    found = STATUS.search(block)
    state = found.group(1).lower() if found else None
    if state == "approved":
        approved.append((name, block))
    elif state not in KNOWN_STATES:
        malformed.append(name)

# No unambiguous unit in flight — nothing to enforce against. A proposal whose
# frontmatter will not parse is reported rather than passed over in silence: an
# unreadable warrant is how the gate would quietly stop existing.
if len(approved) != 1:
    if len(approved) > 1:
        print(
            "warrant: %s are all marked approved. One unit is enforceable at a time, so the write "
            "set and trailer rules are OFF until exactly one is approved — set the finished ones to "
            "`landed`." % ", ".join("docs/proposals/" + n for n, _ in approved),
            file=sys.stderr)
        sys.exit(1)
    if malformed:
        print(
            "warrant: %s cannot be read — the frontmatter has no closing `---`, or its status is "
            "not one of proposed/approved/landed. The gate is standing down until it is valid."
            % ", ".join("docs/proposals/" + n for n in malformed),
            file=sys.stderr,
        )
        sys.exit(1)
    stand_down()

name, block = approved[0]
proposal_path = "docs/proposals/" + name

write_set = []
if "files:" in block:
    for line in block.split("files:", 1)[1].splitlines():
        item = FILE_ITEM.match(line)
        if item is None:
            if line.strip():
                break          # the next key ends the list
            continue
        entry = item.group(1).strip().strip("'\"").strip("/")
        # `---` is a delimiter, never a path; a bare key is not a path either.
        if not entry or set(entry) == {"-"} or entry.endswith(":"):
            continue
        write_set.append(entry)

# Approval covers the work, so while a unit is in flight the shell is open by
# default. Two things stay outside that grant: landing the work is the user's
# call, and irreversible damage should never ride in on a build approval.
WITHHELD = [
    (re.compile(r"\bgit\s+push\b"), "pushing is a landing step"),
    (re.compile(r"\bgit\s+merge\b"), "merging is a landing step"),
    (re.compile(r"\bgit\s+rebase\b"), "rebasing rewrites landed history"),
    (re.compile(r"\bgit\s+reset\s+--hard\b"), "hard reset discards work"),
    (re.compile(r"\bgit\s+branch\s+-[dD]\b"), "deleting a branch is cleanup after landing"),
    (re.compile(r"\bgit\s+clean\s+-[a-z]*f"), "clean -f discards untracked work"),
    (re.compile(r"\brm\s+-[a-z]*[rR]"), "recursive delete"),
    (re.compile(r"\bsudo\b"), "privilege escalation"),
    (re.compile(r"\|\s*(sudo\s+)?(ba)?sh\b"), "piping into a shell"),
    (re.compile(r"\bmkfs\b|\bdd\s+if="), "raw disk write"),
    # Writing files THROUGH the shell goes around every path-based gate — this
    # one's write set and doctrine's buckets both. Approval covers running the
    # work, not editing by redirection, so those keep their permission prompt.
    (re.compile(r"(?<![0-9&])>{1,2}(?![&|])"), "writing a file by shell redirection"),
    (re.compile(r"\btee\b"), "writing a file with tee"),
    (re.compile(r"\b(sed|perl|ruby)\b[^|]*\s-i\b"), "in-place file edit"),
    (re.compile(r"\btruncate\b"), "truncating a file"),
]


def withheld(command):
    for pattern, why in WITHHELD:
        if pattern.search(command):
            return why
    return None


# --- write-target resolution (contract: docs/proposals/2026-07-26-fix-state-gate-writeop-bypass.md) ---
# Whether a write is in scope is decided by the TARGET PATH it lands on, never
# by matching the command string against a whitelist of known write idioms.
# The idiom list below (WRITE_HINTS) is used only to decide "does this command
# write at all" — a much coarser, and deliberately over-inclusive, question
# than the old code's "does this look like one of the write shapes we
# recognize, and if not, let it through unchecked." A command that writes but
# whose exact target cannot be pinned down (a variable, an expression) is
# default-denied rather than trusted, exactly like an unreadable file_path on
# a Write/Edit call.
# Single source of truth for "does this command write at all" — shared
# verbatim by the write-set enforcement below and the records-tree
# path-reference default-deny further down (RECORDS_WRITE_IDIOM_RE is an
# alias of this same object, not a second, narrower idiom list). Per the
# frozen contract, this is deliberately over-inclusive: enumerate every
# write-capable idiom this gate knows of; anything it can't prove is NOT
# one of these falls to "target unknown -> default-deny" downstream, never
# to a silent allow. `.write_text(` / `.write_bytes(` / `os.write(` are the
# idioms that were missing from the old WRITE_HINTS (round-1 defect B).
WRITE_IDIOM_RE = re.compile(
    r"\bopen\s*\([^)]*,\s*['\"]?[wax]"      # open(path, 'w'/'a'/'x'-mode)
    r"|\.write\s*\("
    r"|\.write_text\s*\("
    r"|\.write_bytes\s*\("
    r"|\bos\.write\s*\("
    r"|(?<![0-9&])>{1,2}(?![&|])"           # shell redirection
    r"|\btee\b"
    r"|\b(sed|perl|ruby)\b[^|]*\s-i\b"      # in-place edit
    r"|\btruncate\b"
    r"|\bcp\b|\bmv\b|\binstall\b"
    r"|\bdd\b"                              # dd (of= or otherwise)
    r"|\brsync\b"
    r"|-[oO]\s+\S"                          # curl -o / wget -O
)
WRITE_HINTS = WRITE_IDIOM_RE
# Same idiom set, minus the shell-redirection alternative: used only where
# redirection is checked as its own separate, required condition (the
# records-tree "plain self-redirection" carve-out below) so that presence
# of `>` doesn't double-count as "another write idiom is also present."
WRITE_IDIOM_NO_REDIRECT_RE = re.compile(
    r"\bopen\s*\([^)]*,\s*['\"]?[wax]"
    r"|\.write\s*\("
    r"|\.write_text\s*\("
    r"|\.write_bytes\s*\("
    r"|\bos\.write\s*\("
    r"|\btee\b"
    r"|\b(sed|perl|ruby)\b[^|]*\s-i\b"
    r"|\btruncate\b"
    r"|\bcp\b|\bmv\b|\binstall\b"
    r"|\bdd\b"
    r"|\brsync\b"
    r"|-[oO]\s+\S"
)

# Path-shaped tokens pulled out of a Bash command as candidate write
# targets. This does not parse shell semantics; it is a superset scan, and
# every candidate is adjudicated the same way a Write/Edit's file_path
# would be. Quoted substrings are extracted first and preferred exclusively
# when present — a call like `open('/a/b', 'w').write('x')` has no
# whitespace around the quoted path, so a whitespace-delimited bare-token
# scan would instead grab `open('/a/b',` (prefix and trailing punctuation
# glued on) as one garbage "token" and misjudge it. Only when the command
# has no quoted strings at all does this fall back to whitespace-delimited
# bare tokens (the shape a plain `cp /a/b /c/d` or `> /a/b` redirect uses).
SINGLE_QUOTED = re.compile(r"'([^']*)'")
DOUBLE_QUOTED = re.compile(r"\"((?:[^\"\\]|\\.)*)\"")
BARE_TOKEN = re.compile(r"\S+")


def bash_write_targets(command):
    # Scanned independently, not as one alternation: a Bash-quoted `-c`
    # argument is itself double-quoted and commonly contains single-quoted
    # Python string literals inside it (e.g. `python3 -c "open('/a/b',
    # 'w')..."`); an alternation regex would match the whole outer
    # double-quoted span as one token first and never see the inner
    # single-quoted path. Single-quoted tokens are checked first — they are
    # the common case for an embedded path literal — then double-quoted,
    # then bare whitespace-delimited tokens.
    single = [m.group(1) for m in SINGLE_QUOTED.finditer(command) if "/" in m.group(1)]
    if single:
        return single
    double = [m.group(1) for m in DOUBLE_QUOTED.finditer(command) if "/" in m.group(1)]
    if double:
        return double
    return [t for t in BARE_TOKEN.findall(command) if "/" in t]


def resolve_relative(raw_path):
    """Resolve a path (possibly relative, possibly a symlink) against root and
    return its repo-root-relative path, or None if it escapes the repo."""
    normalized = raw_path.replace("\\", "/")
    absolute = posixpath.normpath(
        normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
    )
    resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
    real_root = posixpath.normpath(os.path.realpath(root).replace("\\", "/"))
    if resolved != real_root and not resolved.startswith(real_root + "/"):
        return None
    return resolved[len(real_root) + 1:]


def _write_set_entry_matches(relative, entry):
    """Match one frozen write-set entry against a repo-root-relative path.

    Per the frozen contract: a write-set entry is a glob, not a literal
    path — `<root>/**` (i.e. an entry ending in `/**`) matches every path
    under `<root>` at ANY depth. `fnmatch` is used for any entry carrying
    other glob metacharacters (`*`, `?`, `[...]`); a plain entry with no
    glob syntax keeps the original exact-match-or-directory-prefix
    behavior. The `/**` and general-glob cases both compare against the
    entry's own literal, normalized prefix (`entry.rstrip("/") + "/"` or
    `fnmatch` against the literal pattern text) — never a re-expanded or
    re-resolved root — so a sibling directory that merely SHARES a prefix
    (`<root>-evil/`) can never satisfy it: `"foo-evil/x".startswith("foo/")`
    is False, and `fnmatch.fnmatch("foo-evil/x", "foo/**")` is likewise
    False because the pattern's literal `foo/` boundary does not appear.
    """
    entry = entry.rstrip("/")
    if not entry:
        return False
    if entry.endswith("/**"):
        base = entry[:-3]
        return relative == base or relative.startswith(base + "/")
    if any(ch in entry for ch in "*?["):
        return fnmatch.fnmatch(relative, entry) or fnmatch.fnmatch(relative, entry + "/*")
    return relative == entry or relative.startswith(entry + "/")


def in_write_set(relative):
    return any(_write_set_entry_matches(relative, entry) for entry in write_set)


def in_scope(relative):
    """Same containment rule the Write/Edit path applies below: the proposal's
    own file, anything under docs/, or an entry in the frozen write set."""
    if relative == proposal_path:
        return True
    if relative.split("/")[0] == "docs" or "/docs/" in "/" + relative:
        return True
    return in_write_set(relative)


RECORDS_ROOT_REL = "docs/reports/records"


def _records_tree_reference(command, repo_root):
    """If `command` text references a path inside the owned record tree
    (docs/reports/records/<subject>/...), return (raw_token, subject, rest)
    for the first such reference found; else None. Same superset token
    scan bash_write_targets() below uses for write-target candidates, but
    run over EVERY path-shaped token in the command (not only quoted ones),
    since a plain reference for read-only purposes need not be quoted."""
    real_root = posixpath.normpath(os.path.realpath(repo_root).replace("\\", "/"))
    records_root = real_root + "/" + RECORDS_ROOT_REL
    for m in re.finditer(r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"|(\S+)", command):
        tok = m.group(1) if m.group(1) is not None else (m.group(2) if m.group(2) is not None else m.group(3))
        if not tok or "/" not in tok:
            continue
        tok_norm = tok.replace("\\", "/")
        if RECORDS_ROOT_REL + "/" in tok_norm or tok_norm.rstrip("/") == real_root + "/" + RECORDS_ROOT_REL:
            om = re.search(r"docs/reports/records/([^/\s'\"]+)/([^\s'\"]+)", tok_norm)
            subject = om.group(1) if om else None
            rest = om.group(2) if om else None
            return tok_norm, subject, rest
    return None


# --- path-reference default-deny (contract: docs/proposals/2026-07-26-gate-nested-shell-default-deny.md) ---
# Replaces WRITE_HINTS-idiom-triggered detection for the owned record tree
# specifically: a Bash command that references a path inside
# docs/reports/records/<subject>/ — coding's own record or another role's
# — is DEFAULT-DENIED unless the reference is provably read-only (no shell
# nesting, no command substitution, no write idiom, read-only commands
# only). This governs the record tree only; the pre-existing WRITE_HINTS /
# frozen-write-set logic below is unchanged for every other path.
# Same regex object as the write-set enforcement's WRITE_IDIOM_RE above —
# single source of truth for "is this a write" (frozen contract: unify
# write-detection with the records-tree default-deny rather than
# maintaining a second, narrower idiom list).
RECORDS_WRITE_IDIOM_RE = WRITE_IDIOM_RE
RECORDS_NESTED_SHELL_RE = re.compile(r"\b(?:sh|bash)\s+-c\b|\beval\b")
RECORDS_READ_ONLY_CMDS = {
    "cat", "grep", "egrep", "fgrep", "head", "tail", "test", "ls", "[",
    "wc", "find", "stat", "file", "sort", "uniq", "cut", "diff",
    "md5sum", "sha256sum",
}


def _records_command_substitution_free(cmd):
    return "$(" not in cmd and "`" not in cmd


def _records_no_nested_shell(cmd):
    return RECORDS_NESTED_SHELL_RE.search(cmd) is None


def _records_no_write_idiom(cmd):
    return RECORDS_WRITE_IDIOM_RE.search(cmd) is None


def _records_only_read_commands(cmd):
    for seg in re.split(r"[;\n]|&&|\|\|", cmd):
        for part in seg.split("|"):
            part = part.strip()
            if not part:
                continue
            words = part.split()
            if not words:
                continue
            idx = 0
            while idx < len(words) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[idx]):
                idx += 1
            if idx >= len(words):
                continue
            first = words[idx].rstrip("()")
            if first not in RECORDS_READ_ONLY_CMDS:
                return False
    return True


def _records_proven_read_only(cmd):
    return (
        _records_command_substitution_free(cmd)
        and _records_no_nested_shell(cmd)
        and _records_no_write_idiom(cmd)
        and _records_only_read_commands(cmd)
    )


def records_tree_gate(command, repo_root):
    """Returns "allow" (nothing more to say / proven read-only), "own-write"
    (a plain self-redirection to coding's own record — caller still runs
    the normal frozen-write-set / scope check on it below), or refuses
    outright via sys.exit(2)."""
    hit = _records_tree_reference(command, repo_root)
    if hit is None:
        return "allow"
    raw_tok, subject, rest = hit
    if _records_proven_read_only(command):
        return "allow"

    own_hit = rest is not None and (rest == "coding.md" or rest.startswith("coding/"))
    plain_redirect_only = (
        _records_command_substitution_free(command)
        and _records_no_nested_shell(command)
        and re.search(r"(?<![0-9&])>{1,2}(?![&|])", command) is not None
        and WRITE_IDIOM_NO_REDIRECT_RE.search(command) is None
    )

    if own_hit and plain_redirect_only:
        # Own record, plain redirection: not proven read-only, but not
        # refused outright either — falls through to the ordinary
        # frozen-write-set / scope check below (contract: "자기 레코드
        # 평이 리다이렉션 write가 합법 상태전이면 여전히 허용" — this repo
        # has no per-record state machine of its own, so "legal" here is
        # exactly what the frozen write set / docs-allow rule already
        # decides for any other in-scope write).
        return "own-write"

    print(
        "warrant: refused — this Bash command references the owned record tree "
        "(docs/reports/records/) at %r and this reference cannot be proven read-only "
        "(no shell nesting, no command substitution, no write idiom). Path-reference "
        "default-deny applies to any such reference, whether it names coding's own "
        "record or another role's." % raw_tok,
        file=sys.stderr,
    )
    sys.exit(2)


if tool == "Bash":
    command = tool_input.get("command")
    if not isinstance(command, str) or not command.strip():
        allow()

    records_tree_gate(command, root)

    reason = withheld(command)
    if reason is not None:
        # Not refused — warrant simply declines to vouch, and the normal
        # permission prompt decides.
        allow()

    if GIT_COMMIT.search(command) and "Proposal: " + proposal_path not in command:
        print(
            "warrant: refused — this commit carries no warrant.\n"
            "A unit is in progress (%s), so every commit for it ends with:\n"
            "    Proposal: %s\n"
            "Add the trailer as the last line of the commit message."
            % (proposal_path, proposal_path),
            file=sys.stderr,
        )
        sys.exit(2)

    if WRITE_HINTS.search(command):
        candidates = [resolve_relative(t) for t in bash_write_targets(command)]
        in_repo_candidates = [c for c in candidates if c is not None]
        if not in_repo_candidates:
            # The command writes something, but no path-shaped token in it
            # resolves to a location inside this repo — most often because
            # the actual target is built from a shell variable or other
            # expression this scan cannot follow. That is exactly the
            # "target path unknown" case: a write-capable tool call with an
            # indeterminate destination is default-denied, never trusted.
            print(
                "warrant: refused — this command writes (matches a known write idiom) but its "
                "target path could not be determined from the command text. A write-capable Bash "
                "call with an indeterminate target is refused by default rather than trusted."
                "\ncommand: %s" % command,
                file=sys.stderr,
            )
            sys.exit(2)
        out_of_scope = [c for c in in_repo_candidates if not in_scope(c)]
        if out_of_scope:
            print(
                "warrant: refused — this Bash command's write target `%s` is outside the write set "
                "frozen by %s.\nApproved paths: %s\n"
                "Finish what the proposal covers and report the rest; the discovered work becomes "
                "the next proposal. Widening the set mid-build is what the gate exists to prevent — "
                "including via a Bash write instead of Write/Edit."
                % (out_of_scope[0], proposal_path, ", ".join(write_set) or "(none listed)"),
                file=sys.stderr,
            )
            sys.exit(2)

    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason":
            "warrant: %s is approved and in progress; approval covers the work it described."
            % proposal_path,
    }}))
    sys.exit(0)

path = tool_input.get("file_path") or tool_input.get("notebook_path")
if not isinstance(path, str) or not path:
    allow()

normalized = path.replace("\\", "/")
absolute = posixpath.normpath(
    normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
)
# A path inside the write set can still be a symlink pointing elsewhere; judge the
# destination, not the name. realpath resolves the parent chain for files that do
# not exist yet, which is the normal case for a first write.
resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
real_root = posixpath.normpath(os.path.realpath(root).replace("\\", "/"))
if resolved != real_root and not resolved.startswith(real_root + "/"):
    if absolute != resolved:
        print(
            "warrant: refused — `%s` resolves to `%s`, outside the repository. A symlink does not "
            "widen the write set." % (absolute[len(root) + 1:] if absolute.startswith(root + "/")
                                      else absolute, resolved),
            file=sys.stderr)
        sys.exit(2)
    allow()
relative = resolved[len(real_root) + 1:]

# The proposal itself stays writable: status flips and checklist ticks are the
# protocol's own bookkeeping, not the work.
if relative == proposal_path:
    allow()

# A coding-authored write landing under docs/proposals/ with a declared
# `kind` other than `build-proposal` is a mechanically detectable
# NEVER-OVERWRITE violation: contract v2 section 11 keeps docs/proposals/
# shared between product and coding, disambiguated by filename tag, and
# coding's own write set only ever freezes a `docs/proposals/<date>-build-
# <slug>.md` path. This only confirms the self-declared value; it does not
# validate content against it (contract v2 section 14).
if relative.startswith("docs/proposals/") and relative != proposal_path:
    content = tool_input.get("content")
    if not isinstance(content, str):
        content = tool_input.get("new_string")
    if isinstance(content, str):
        found_kind = KIND.search(content)
        if found_kind and found_kind.group(1) != "build-proposal":
            print(
                "warrant: refused — `%s` declares `kind: %s`, not `build-proposal`.\n"
                "coding's writes under docs/proposals/ must declare kind: build-proposal; "
                "a different declared kind is a strong signal of writing into another "
                "role's docs/proposals/ lane." % (relative, found_kind.group(1)),
                file=sys.stderr,
            )
            sys.exit(2)

# So is the record the work produces. doctrine asks for a decision record, a
# report, or a handbook update at the moment the work creates one; a write set
# listing only code would make that impossible, and the two plugins would
# deadlock with the record silently never written. Documents are bookkeeping
# here, not scope — doctrine's own gate still decides where they may land.
if relative.split("/")[0] == "docs" or "/docs/" in "/" + relative:
    allow()

if in_write_set(relative):
    allow()

print(
    "warrant: refused — `%s` is outside the write set frozen by %s.\n"
    "Approved paths: %s\n"
    "Finish what the proposal covers and report the rest; the discovered work becomes the next "
    "proposal. Widening the set mid-build is what the gate exists to prevent."
    % (relative, proposal_path, ", ".join(write_set) or "(none listed)"),
    file=sys.stderr,
)
sys.exit(2)
PY

exit $?
