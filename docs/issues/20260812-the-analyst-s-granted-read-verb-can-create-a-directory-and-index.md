---
id: 20260812-the-analyst-s-granted-read-verb-can-create-a-directory-and-index
num: 321
title: "The analyst's granted read verb can create a directory and index"
status: closed
priority: high
labels: [000-blueprint, verify, issue]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T04:09:11Z
updated: 2026-08-12T09:34:16Z
origin: docs/specs/issue/000-blueprint/spec.md
---

## Description

## Description

The issue-analyst's one granted read verb can create a directory and write an
`INDEX.md` into it, so the agent definition's claim that its write capability is
absent is false.

## Mechanism

`agents/issue-analyst.md:13` grants `[Read, Bash(bash …/render.sh *)]` — no
`Write`, `Edit` or `Agent`. But `render.sh` is not read-only toward the
filesystem. Every verb, including the analyst's own `insights-graph`, calls
`ensure_index` (`render.sh:108-112`), which shells to `index.sh`, which does
`mkdir -p "$dir"` (`index.sh:301`) and writes `INDEX.md` (`:589`, `:602`).

The directory is analyst-chosen: `cmd_insights_graph` passes its argument through
`resolve_dir` with no existence check (`render.sh:622-628`), and a missing
`INDEX.md` counts as stale. So a prompt injection steering that argument can
create a stray directory and index in the developer's checkout.

The agent definition states the opposite in absolute terms:

- `:8-10` — "Has no write or execute capability by design: a prompt injection
  embedded in issue content cannot mutate the collection because the capability
  is absent, not merely forbidden."
- `:24-26` — "Your only tools are `Read` and a single read-only `render.sh`
  invocation. … You **cannot** modify, create, or delete any file."

Risk is low — `INDEX.md` content is deterministically regenerated from issue
files, so injected text cannot author it; no publish is reachable, and a read
handle cannot commit. What is wrong is that an absolute guarantee is stated and
the code does not back it.

`render.sh` already treats this failure mode as a defect elsewhere, and fixed it
for `list` only (`render.sh:369-372`: "Taking it for a directory anyway is how a
mistyped filter got one created for it, by a read verb, in the developer's
checkout").

## Proposed action

Two halves, both wanted:

1. Gate `insights-graph`'s directory argument on existence — or give `render.sh`
   a no-regeneration read mode for the analyst's call — so the capability really
   is absent.
2. Correct the agent definition's absolute wording either way.

The blueprint invariant was already amended to state what is actually guaranteed
(no capability to author content) rather than "write-free".

## Origin

Post-build review of `issue/011`; the `insights-capability-boundary` judge. The
invariant was resolved **fold** at the blueprint fork; this issue carries the
code half, which the fold does not excuse.

## Resolution (2026-08-12)

Fixed in `c13caa9`, both halves the finding asked for.

**The capability.** `ensure_index` is the one function every verb regenerates
through, so the guard sits there: a directory that does not exist is not created.
`cmd_insights_graph` additionally refuses a *named* collection that is not
there, so the analyst's argument cannot select one. The index regeneration itself
stands — the blueprint invariant already records it as a side effect of reading,
and every byte of that file comes from the issue files.

**The wording.** The agent definition claimed the analyst "cannot modify, create,
or delete any file". It could create both a directory and an index. Both the
frontmatter description and the capability-boundary section now state what is
actually guaranteed — that there is no path from anything the analyst reads to
anything a later reader is shown — and say plainly what the one verb does,
rather than resting on a blanket claim that was false.

Pinned by `case_render_read_verbs_create_no_directory`, which drives all three
verbs at a non-existent directory and asserts each refuses and creates nothing.
