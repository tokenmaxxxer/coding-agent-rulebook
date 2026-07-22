# doctrine

Decides where a document goes before it is written. The failure this targets:
AI writes documentation constantly and scatters it — `SUMMARY.md` at the
repository root, `IMPLEMENTATION_NOTES.md` next to the code, a fourth file
restating what three others already said. Six months later nobody knows which
file is current, and half of them are false.

doctrine gives every repository document exactly one home, chosen by how long
the document is meant to live:

| Directory | What lives there |
|---|---|
| `decisions/` | Why a hard-to-reverse choice was made. Fixed at the moment of the decision. |
| `handbooks/` | Current state. Edited from now on to stay true. |
| `reports/` | An observation fixed to a point in time. Research goes in `reports/research/`. |
| `specs/` | Design and specification. Updated in the same PR as the code. |
| `proposals/` | Not adopted yet — drafts, RFCs. |
| `_assets/` | Images and attachments. The underscore marks it as not a document class. |

Classification is by lifetime, not topic. One incident produces a postmortem in
`reports/`, an operational rule in `handbooks/`, and a structural decision in
`decisions/` — three documents, three lifetimes, linked to each other.

## Two layers

**`UserPromptSubmit` directive** — steers the judgment. Which bucket this
document belongs in, that the six must exist before writing, that a change
which falsifies a document fixes it in the same turn, and that no document
restates a fact another one owns. Surface-gated: inert on turns that touch no
documentation.

**`PreToolUse` gate** — enforces the one rule that needs no judgment. A write is
refused unless it lands in a bucket, with the buckets and the classification
test in the refusal message. It reads the tool input (a path string) before the
write happens; it never reads a finished document.

Scope differs on the two sides of `docs/`. Inside a `docs/` tree every file is
governed regardless of extension — `_assets/` exists so that images and
attachments have a bucket, and a PNG loose under `docs/` is as much a violation
as a stray note. Outside it, only `.md`/`.mdx` are governed; source and config
are none of this gate's business.

The rule is an allow-list rather than a `docs/`-only check, because
`SUMMARY.md` dropped at the repository root is the exact failure the plugin
exists to prevent — a gate that only guards inside `docs/` would wave it
through. Allowed outside the buckets: `README.md` at any level, the root files
an ecosystem fixes by name (`LICENSE`, `CHANGELOG.md`, `CONTRIBUTING.md`,
`CODE_OF_CONDUCT.md`, `SECURITY.md`, `AGENTS.md`, `CLAUDE.md`), anything inside
a dot-directory or a vendored/generated tree, and whatever the repository adds:

```sh
export DOCTRINE_ALLOW="content,blog,_posts/drafts"
```

Each entry matches a whole path segment or a path prefix from the project root.
A documentation-site repository (Hugo `content/`, Docusaurus `blog/`, Jekyll
`_posts/`) needs this — without it the gate refuses writes the site layout
requires.

That split is deliberate. A path can prove a document is in the wrong place;
it cannot tell you whether a design note is a `spec` or a `proposal`. The
mechanical half is mechanical, and the rest stays direction.

The gate fails open: no `python3`, an unreadable payload, or an unexpected
schema lets the write through. It also only sees tool calls — a document
written by a shell redirect goes around it.

## Where the doctrine text lives

In `hooks/directive.sh`, and only there. An earlier version also shipped a
template `docs/README.md` carrying the same rules, which made two sources of
truth for one contract — the failure this plugin exists to prevent. Nothing
installed the template either, so the text moved into the hook and the template
was removed.

A repository that keeps its own `docs/README.md` still wins: the directive
tells the model to read that file and follow it instead. Teams that want the
doctrine visible to humans on GitHub write their own copy and edit it freely.

## Relationship to the rest of the stack

no-footgun steers which patterns get written; no-mock steers what the structure
must be; doctrine steers where the record of both goes. It is the only plugin
in the stack that ships a `PreToolUse` gate, because it is the only one whose
rule reduces to a path comparison. Nothing here is a verification pass:
prevention happens at write time, and no finished artifact is re-read.

Prose style — voice, cohesion, how much a reader is assumed to know — is out of
scope. doctrine decides placement and lifetime, not how the sentences read.

## Kill switch

```sh
export DOCTRINE_OFF=1
```

Disables both hooks.
