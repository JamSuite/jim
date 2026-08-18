# Brainstorm: Issue Epics and Enhanced Filtering

*2026-08-17*

## Starting point

Two capabilities on the existing issue collection: **epics** (a parent container
grouping several issues under an umbrella theme, with its own views and metrics)
and **enhanced filtering** (by user, by spec, by label).

### Current state (as read, 2026-08-17)

- 350 issue files, flat under `docs/issues/`.
- Frontmatter schema: `id`, `num`, `title`, `status`, `priority`, `labels`,
  `relations{blocks, depends-on, related-to, duplicates}`, `created`, `updated`,
  `origin`. **No identity field of any kind** — nothing records who filed or owns
  an issue.
- `list` takes one positional token: `open|closed|critical|high|medium|low`.
  No label filter, no origin filter, no composition.
- Relations are already bidirectionally integrity-checked and already render as
  a Graph in `INDEX.md`.
- `origin` already points at the source spec/plan/brainstorm path.
- ~5k lines of bash across `new.sh`, `index.sh`, `render.sh`, `place.sh`,
  `reconcile.sh`, `backfill.sh`, `migrate.sh`. Issues just moved onto a
  centralized branch with coordinated id allocation.

### Two observations that shape the design

1. **"My tickets" is a schema gap, not a filter gap.** The identity has to exist
   before it can be filtered on.
2. **"Issues for a spec" is mostly already there** via `origin` — it needs a
   filter, not a schema change.

## Epics — design options

### A. Directory-as-epic

`docs/issues/<epic-slug>/` holds member issue files plus an `epic.md`.

**Pros**
- Epic gets its own artifact space — brief, design notes, diagrams.
- Membership is physical and unambiguous; no index needed to resolve it.
- Filtering is a filesystem glob.

**Cons**
- **Membership becomes exclusive.** An issue lives in exactly one directory, but
  real epics overlap (an auth refactor belongs to both "auth-hardening" and
  "q3-tech-debt").
- Joining/leaving an epic is a *file move*. Under centralized branch placement
  that is materially messier than an append or an in-place edit.
- Every script that globs `docs/issues/*.md` has to go recursive — `index.sh`,
  `render.sh`, `reconcile.sh`, `backfill.sh`, `migrate.sh`.
- Turns a flat 350-file tree into a mixed flat/nested one.

### B. Pure label convention

Bless a label prefix, e.g. `epic:auth-hardening`; tooling groups on it.

**Pros**
- Zero schema change, zero migration, zero structural change to any script.
- Multi-membership is free.
- Falls out of the enhanced-filtering work for nothing: `list --label epic:x`.

**Cons**
- **The epic has no body.** Nowhere for the umbrella narrative, goal, or success
  criteria. It's a tag, not an artifact.
- No independent lifecycle — an epic can't be open/closed on its own terms.
- Typo-forks silently: `epic:auth-hardening` vs `epic:auth-harden` are two epics.
- No anchor to hang epic-level metrics on.

### C. Epic-as-issue + typed relation  ← recommended

An epic is a regular issue file marked as an epic; membership is a new relation
pair (`parent-of` / `child-of`) in the existing `relations:` block.

**Pros**
- **Reuses everything**: file format, emitter, id coordination, placement,
  index, graph, reconcile, ledger, status/priority/labels.
- The epic gets a real narrative body for free — it *is* an issue file.
- Relations already carry bidirectional integrity checking and already render as
  Graph edges. "Issues in this epic" is a traversal the index already computes.
- Membership is non-exclusive and mutation-cheap: edit frontmatter, never move a
  file. Matters a lot given the centralized branch.
- The epic has its own `status`, so it closes on its own terms.

**Cons**
- Epics and issues share one ordinal sequence — `#47` might be an epic.
- The `relations` block grows another bucket.
- Needs an explicit rule on nesting (epic-inside-epic).
- No extra *artifact* space for an epic that accumulates diagrams/notes.

### D. Hybrid — C plus an optional directory sidecar

Epic is an issue; epics that genuinely accumulate material get
`docs/issues/epics/<slug>/` for supplementary files. Member issues stay flat.

**Pros**
- C's benefits plus an escape hatch for artifact-heavy epics.
- Membership stays relational — still no file moves.

**Cons**
- Two places to look for epic content; sidecar is a second thing to keep in sync.
- Likely YAGNI now. Better as a later addition *if* C proves cramped.

### E. Separate epics collection

`docs/epics/*.md` with its own numbering; issues carry an `epic:` field.

**Pros**
- Clean tier separation; epics get their own ordinal space and own index.
- Epic-level metrics view arises naturally from a separate collection.

**Cons**
- **Duplicates nearly all the issue machinery** for a second artifact type —
  emitter, index, placement, coordination allocator, reconcile.
- Two collections to place onto the centralized branch.
- Single-parent unless the field is a list.

### F. Dedicated `epic:` frontmatter field (epics still issues)

C, but membership lives in a new top-level field instead of the relations block.

- Strictly more work than C for less: the relations block already has integrity
  checking and graph rendering that a new field would have to reimplement.

## Recommendation — C, with D as a later door

1. **Smallest addition to a load-bearing surface.** Coordination, placement,
   index, graph and reconcile all apply unchanged.
2. **Membership as a relation is non-exclusive and cheap to mutate.** With issues
   now on a shared branch, avoiding file moves is worth a lot.
3. **The epic gets a real narrative body** — the thing B fundamentally can't give.
4. **"Own views and metrics" becomes an index/render concern, not a storage
   concern** — which is where it belongs.

### Open forks under C

- **`type:` field vs reserved label.** A `type:` field is cleaner (mutually
  exclusive, filterable, leaves room for `bug`/`chore` later) but is a schema
  addition across 350 files — `backfill.sh` is the natural home for that. A
  reserved label is zero-migration but muddies the label namespace.
- **Nesting.** Lean no-nesting initially: epic → issue, one level. Recursive
  traversal makes "the epic's issues" and its progress metrics ambiguous.
- **Ordinal sharing.** Accept one sequence, or give epics a distinct display
  prefix (`E12`) while keeping one allocator?

## Filtering — design notes

### 1. By user — blocked on schema

Needs a field first. The real fork is *which identity*:

- **`author`** — who captured it. Immutable, set at emit time from
  `git config user.email`. This is discovery provenance — squarely in scope for
  jim, which frames issue capture as a discovery artifact.
- **`assignee`** — who's doing it. Mutable. This is what "my tickets" usually
  means on a real team — but assignment is a *coordination primitive*, and
  VISION's non-goals explicitly exclude team coordination ("not a project
  management tool ... not as a team-coordination primitive").

Worth deciding deliberately rather than drifting into `assignee`.

Deriving the filer from git commit authorship on the placement branch is
possible but fragile — history rewrites, and `place.sh` falls back to a
`jim-placement@localhost` identity when `user.email` is unset.

### 2. By spec — mostly free

`origin` already holds the spec path. Needs an `--origin`/`--spec` filter with
prefix matching. Open question: issues that *relate* to a spec without
originating from it are invisible to an origin filter.

### 3. By label — needs a filter

Straightforward once the parse surface exists.

### 4. Composition — the real structural change

The current single positional token can't express "open AND high AND labeled
auth". Target shape:

```
list --status open --priority high,critical --label auth --epic auth-hardening --author you@example.com
```

**Syntax fork:** positional tokens (cheap, doesn't compose) vs flags (composes,
bigger bash parse surface — but with no `jq` dependency it's still just a
while/case loop). Leaning flags. Sub-question: keep bare `list open` / `list
high` as ergonomic sugar, or drop them entirely?

---

## Decisions taken (2026-08-17)

- **Epics via option C**, with D available later if an epic proves it needs its
  own artifact space.
- **VISION contention is not a blocker.** Owner/assignment is being built; the
  vision gets amended if it needs to be.
- **`type` is a real field.** Epics are first-class, not a blessed label.
- **Nesting: epic → issue only.** One level.
- **Bare-word sugar is retained** alongside flags where it can be made safe.
- **Richer state than open/closed**, covering owner / assignment / claimed /
  active. Names are open to revision.

## The state model

The listed concepts — owner, assignment, claimed, active — are **two orthogonal
axes** collapsed into one list. Separating them is the core design move:

| Axis | Question | Field |
|---|---|---|
| **Workflow state** | Where is the work? | `status` |
| **Identity** | Who filed it / who holds it? | `filed-by`, `claimed-by` |
| **Kind** | Issue or epic? | `type` |

### Guiding principle: derive what you can, store only what you can't

Two of the listed concepts should **not** be stored at all:

- **"claimed" is not a status** — it is `claimed-by != empty`. Storing it as a
  status value creates an unmaintainable invariant (what does `status: claimed`
  with an empty `claimed-by` mean?). Derive it.
- **"blocked" is not a status** — it is `depends-on` pointing at a non-closed
  issue. The relation already carries this. Derive it.

That keeps the stored state set minimal and every derived view mechanical.

### Proposed stored state

**`status: open | active | closed`**

- `open` — filed, nobody working it
- `active` — being worked
- `closed` — done

`active` earns its place separately from claimed: you can claim five things and
be actively working one. Derived on top: `blocked` (from `depends-on`),
`claimed` / `unclaimed` (from `claimed-by`).

**`type: issue | epic`** — default `issue`; the 350-file backfill sets it.

**Identity fields — naming.** `filed-by` / `claimed-by`:

- **`filed-by`** over `author` or `reporter` — jim's own verb is *file*
  (`/jim:issue add` "files" an issue; the batch reports "Filed N candidates").
  `author` also risks being misread as "who wrote this markdown".
- **`claimed-by`** over `assignee` — `assignee` implies a push model (someone
  assigns you work). The described model is pull/self-service ("if I file an
  issue but haven't claimed it"). `claimed-by` also pairs symmetrically with
  `filed-by`, and makes `unclaimed` fall out for free.
- Alternative if push/pull neutrality is wanted later: `owner`.

**Value format:** store `git config user.email` — the reliably machine-available
handle, and already present in every commit, so it introduces no new PII to the
repo. Terse views can render just the local-part.

**Open question — outcome.** `wontfix` / `duplicate` are *outcomes*, not states.
They would be a separate optional `outcome` field. Skipping it keeps things
lean, at the cost of completion-rate metrics counting abandoned work as done.
Deferred, not decided. *(Resolved below — decided in.)*

## Epic mechanics under C

### Membership: single-sided, derived — not bidirectional

The existing relations are bidirectionally written and integrity-checked. Epic
membership should **break that pattern deliberately**:

- The **child** declares `part-of: [epic-slug]`. That is the only stored fact.
- The **epic's** member list is **derived by the index**.

Why not mirror the existing bidirectional pattern:

- One write per membership change instead of two — filing an issue into an epic
  is a single capture-time field, not a follow-up edit to the epic file.
- No reciprocity to verify, so no integrity check to maintain.
- An epic with 40 children doesn't carry a 40-entry frontmatter list that has to
  stay in sync.
- The Graph is already index-derived, so nothing new is being invented.

Cost: the epic file is no longer self-describing without the index. Acceptable —
jim regenerates `INDEX.md` on every write anyway.

`part-of` lives **in the `relations:` block** (keeping all cross-issue links in
one place) and is a **list**, preserving the non-exclusive membership that made C
preferable to A in the first place.

### Epic status is manual; epic progress is derived

Closing an epic with children still open is a legitimate deliberate act —
deferring the remainder. So the epic's `status` is **author-set**, and views
show **derived progress** (`3/7 closed`) alongside it. Human control plus the
metrics the epic concept is wanted for.

An epic also carries `claimed-by` — the person driving it.

### Epic views and metrics

- `list epic` — all epics, each with derived progress
- `list --epic <slug>` — that epic's members
- `stats` — per-epic rollup
- `INDEX.md` — an Epics section

## Filtering syntax

```
list [bare-words...] [--flags...]
```

### Bare words — safe sugar

Bare words resolve **only against reserved vocabularies**, never against labels,
slugs, or ids:

- status: `open` `active` `closed`
- priority: `low` `medium` `high` `critical`
- type: `issue` `epic`
- derived: `claimed` `unclaimed` `blocked`

Combining rule, which matches how people actually type:

- **OR within an axis** — `list high critical` → priority ∈ {high, critical}
- **AND across axes** — `list open high` → status=open AND priority=high

Anything unrecognized is an **error**. This incidentally fixes open issue #18
(`20260627-read-verb-list-creates-a-stray-directory-from-a-non-filter-arg`),
where a non-filter arg like `list 17` is swallowed as the `<dir>` positional and
`mkdir`s a junk directory — a read verb writing to disk.

### `mine` is ambiguous — deliberately omitted

With two person-fields, a bare `mine` can't be resolved: filed by me, or claimed
by me? Those are exactly the two things called out as needing separate views. So
identity always takes an explicit flag; only the person-free `claimed` /
`unclaimed` get bare words.

### Flags

`--status` `--priority` `--type` `--label` `--epic` `--filed-by` `--claimed-by`
`--spec`

- comma within a flag = OR; separate flags = AND (same rule as bare words)
- `me` resolves via `git config user.email` — `--claimed-by me`, `--filed-by me`
- `--spec` prefix-matches `origin`
- Negation (`--label !flake`) deferred — not in the first cut

Caveat carried forward: `--spec` only sees issues that *originated* from a spec.
An issue that relates to a spec filed from elsewhere stays invisible to it.

---

## Outcome field — decided in

A separate `outcome` field, to keep completion metrics honest.

**Values:** `done | wontfix | duplicate | obsolete`

- `done` — the work was completed
- `wontfix` — a deliberate decision not to do it
- `duplicate` — superseded by another issue; pairs with the existing
  `duplicates` relation
- `obsolete` — the underlying condition evaporated (the code changed, it no
  longer applies)

`obsolete` earns a slot separate from `wontfix` because the *trend* signal
differs: a pile of `wontfix` says scoping is too generous; a pile of `obsolete`
says the backlog rots faster than it drains. Skipped: `invalid`, which in
practice is a judgment call against `obsolete` every time.

**Invariants** (both mechanically checkable):

- `outcome` is non-empty **iff** the issue has ever been closed
- `outcome: duplicate` implies a non-empty `duplicates` relation

The first invariant was originally written as *iff `status: closed`*, which
forced a reopen to discard the outcome. Loosened to *ever-closed* so the reason
an issue was previously finished survives being reopened — which also makes
"reopened" derivable (`status ≠ closed` and `outcome` non-empty) rather than a
stored flag, consistent with how *claimed* and *blocked* are handled above.

**Required at close, defaulting to `done`.** `done` is the overwhelming case, so
the default is nearly always right and closing gains no real ceremony — while
the field stays populated for every closed issue, which is the point.

**Backfill reality:** 232 of the 350 issues are already closed. All get `done`;
any known non-`done` closures are hand-corrected after. Auditing 232 bodies to
reconstruct historical intent is not worth it, and the field's value is
prospective.

### Metrics impact

`stats` reports completion as `done / closed` rather than `closed / total`, and
surfaces the non-`done` buckets separately — `wontfix` and `obsolete` counts are
health signals in their own right, not noise to be hidden.

## `--spec` — origin prefix-match on the spec *directory*

The stated use case is "I built a spec, the process surfaced follow-up work, and
I want to see that work." The origin data confirms the design:

Spec-derived issues by originating artifact:

| Artifact | Issues |
|---|---|
| `review.md` | 163 |
| `spec.md` | 57 |
| `plan.md` | 32 |
| `research.md` | 6 |

**`review.md` is the single largest generator of follow-up work** — by a factor
of ~3 over `spec.md`. So `--spec` must **prefix-match the spec directory**, not
exact-match `spec.md`: matching `spec.md` alone would catch 57 of ~259
spec-derived issues and miss the 163 from review, which are exactly the
"extra work the spec generated" being asked for.

```
--spec issue/011-issue-placement   →  matches docs/specs/issue/011-issue-placement/**
```

Concentration is real and validates the epic concept independently: one spec,
`docs/specs/issue/011-issue-placement`, accounts for **88 issues** on its own —
a body of work no single issue holds, which is precisely what an epic is for.

The earlier caveat stands but is now known to be out of scope: issues that
*relate* to a spec without originating there stay invisible to `--spec`. That is
acceptable — the target is provenance, not association.

## Implementation caution — parse frontmatter, not the file

A whole-file `grep '^status:'` across the collection matches body content: one
issue quotes a shell snippet containing `status: open'` at line 26 of its body.
`index.sh` already parses frontmatter-scoped. Every new field's parser
(`outcome`, `claimed-by`, `filed-by`, `type`, `part-of`) must stay
frontmatter-bounded — no whole-file greps.
