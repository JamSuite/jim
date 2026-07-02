---
num: 2
id: 20260531-typed-frontmatter-relations-absorb-same-target-body-wikilinks
title: "Typed Frontmatter Relations Absorb Same-Target Body Wikilinks"
status: closed
priority: low
labels: [issues-system, index-graph, refinement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-05-31T00:00:00Z
updated: 2026-05-31T00:00:00Z
origin: conversation
---

## Description

### The redundancy

The current dedup key in `skills/issues/scripts/index.sh` is
`(source, type, target)`. So `A --blocks--> B` and `A --related-to--> B`
are distinct edges and both render in the Graph section. An author who
writes `blocks: [B]` in frontmatter AND drops `[[B]]` in body prose
(e.g. "Blocks `[[B]]` (sequence 6 of 6).") produces two edges — a typed
structural one and a related-to shadow. Likewise for `depends-on` and
`duplicates` paired with a same-target wikilink.

### The semantic argument

The four relation types form an implicit hierarchy where the first three
imply the fourth:

| Type        | Implies related-to? | Inverse        |
|-------------|---------------------|----------------|
| blocks      | yes                 | depends-on     |
| depends-on  | yes                 | blocks         |
| duplicates  | yes                 | (none)         |
| related-to  | (terminal)          | related-to     |

The system already encodes part of this asymmetrically: `RELATION_INVERSE`
pairs blocks ↔ depends-on, but the dedup treats all four as orthogonal.
A graph that emits both the typed edge AND the related-to shadow to the
same target carries strictly redundant information — the typed edge is
a refinement of related-to.

### The narrow refinement (Flavor A)

In the `index.sh` accumulator, track typed targets per source, and skip
body wikilinks that would emit a related-to to a target already covered
by a typed frontmatter relation. ~5 lines:

```bash
declare -A typed_target_for   # key: <source>|<target>

# In the frontmatter loop, after validating type/target:
if [[ "$type" != "related-to" ]]; then
  typed_target_for["$slug|$target"]=1
fi

# In the wikilink loop, before adding to outgoing_all:
if [[ -n "${typed_target_for[$slug|$wl]:-}" ]]; then
  continue   # typed edge already covers this target
fi
```

Frontmatter `related-to: [B]` alongside frontmatter typed relations is
intentionally **not** absorbed — the current dedup already handles
same-type overlap, and an author who explicitly populates both structured
fields presumably means both. This refinement only suppresses the
*wikilink-sourced* related-to in the presence of a typed frontmatter
edge.

### Behavioral diff

```
# Before
A --blocks--> B
A --related-to--> B          ← from [[B]] in A's body

# After
A --blocks--> B
```

Unaffected cases:

- Frontmatter `related-to: [B]` + body `[[B]]` → still deduped to one
  edge (current behavior).
- Body `[[B]]` only, no typed coverage → `related-to` edge as before.
- Frontmatter typed edge only, no wikilink → typed edge as before.
- Bidirectional integrity check (already walks `outgoing_fm` only).
- "Blocking" view in `/jim:issues` (already uses typed edges only).
- Cluster views by label / origin.

### Tests to add (jim:meta-test)

1. Frontmatter `blocks: [B]` + body `[[B]]` → one `--blocks-->` edge, no
   `--related-to-->` shadow.
2. Frontmatter `depends-on: [B]` + body `[[B]]` → one `--depends-on-->`
   edge, no `--related-to-->` shadow.
3. Frontmatter `duplicates: [B]` + body `[[B]]` → one `--duplicates-->`
   edge, no `--related-to-->` shadow.
4. Frontmatter `related-to: [B]` + body `[[B]]` → one `--related-to-->`
   edge (unchanged from current dedup).
5. Body `[[B]]` only, no typed coverage → `--related-to-->` edge
   (unchanged).
6. Existing bidirectional checks still pass.

### Tradeoffs

**For:**

- Removes graph noise that carries no semantic value.
- Authors can drop wikilinks in prose for readability without paying the
  price of redundant edges.
- Matches the existing "frontmatter is canonical" precedence; extends it
  to "typed frontmatter absorbs same-target wikilink claims."

**Against:**

- Hidden behavior. An author writing `[[B]]` next to `blocks: [B]` might
  expect both edges. Mitigation: one-line note in `skills/issue/SKILL.md`.
- Loss of fidelity in a near-zero use case (claiming both "blocks AND
  independently related-to" via mixed channels). Mitigation: leaves the
  explicit frontmatter `related-to: [B]` route unaffected; an author who
  wants both can populate both buckets.
- Cross-channel asymmetry. Frontmatter `blocks: [B]` + frontmatter
  `related-to: [B]` would still produce two edges; only wikilinks are
  absorbed. Could extend to symmetric frontmatter absorption (Flavor B,
  not proposed here) but that overrides explicit author intent in
  structured fields and is harder to justify.

### Suggested SKILL.md update

Add a sentence to the `relations` bullet in `skills/issue/SKILL.md`:

> When a typed frontmatter relation (`blocks` / `depends-on` /
> `duplicates`) and a body wikilink both point to the same target, the
> wikilink is absorbed and does not produce an additional `related-to`
> edge — the typed edge already expresses the relationship more
> precisely. To express both a typed relation AND an explicit
> `related-to` to the same target, populate both frontmatter buckets.

### Origin context

Surfaced during the floop project's BACKLOG.md → issues migration
(2026-05-31). Two pairs in that corpus exhibited the pattern:
`dashboard-notification-refactor` ↔ `auto-mark-as-read` (blocks +
depends-on + 2× related-to shadows) and
`routeresolver-dispatch-dimension-unification` ↔
`deep-linked-notification-routing` (same shape). Not a bug — cosmetic
noise. The earlier design-fix handoff that resolved frontmatter/wikilink
redundancy at the same-type level closed only part of the precedence
story; this issue is the remainder.

### Sequencing

Independent. No blockers. Single self-contained ~5-line change to
`index.sh` plus test additions and a SKILL.md sentence. Can be picked
up whenever someone is in jim and wants a small win.
