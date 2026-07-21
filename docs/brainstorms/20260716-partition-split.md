# Brainstorm: Partition Split

*2026-07-16*

Follow-on to [`20260711-partition-migrate-capabilities`](20260711-partition-migrate-capabilities.md)
(which seeded rename, shipped as spec 043) and the split/merge line it deferred.
Scope here: the **split** mechanism (1 group → N), with **merge** (N → 1) noted
as the inverse over the same engine.

**Status at close: tabled.** A verified blocker — spec identity on group-move,
tracked as issue #68 — must be resolved before split/merge mechanism design
continues. See *The blocker* below.

## The core asymmetry: rename relabels, split decides

Rename is a **bijective relabel** — every occurrence of `cart` becomes
`checkout`, one global target. That is why its engine is mostly mechanical:
`occurrences` enumerates, `edges-diff` confirms the graph is preserved *modulo
the name*, the change-set's target column is degenerate (all identical).

Split is **fission**: `cart → {catalog, checkout}`. The engine enumerates the
same way, but the load-bearing act — *which child owns each spec, surface,
invariant, territory path, and requires-edge* — is an assignment decision no
`sed` encodes and no single global substitution captures. Spec 043 cut the seam
for exactly this: Insight 2 keyed the change-set as `(occurrence,
classification, target)` precisely so "split reuses the same shape with
per-occurrence targets." Split fills in the target column rename left constant.

### Inherited for free (shipped in 043, contract-stable)

- `occurrences` (jimpartition.sh) — location-only enumeration, reused verbatim
  for `<old>`
- mechanical-first / gatherer-residue classification with fail-closed precedence
- the spec-040 single gate, the `commit-rename` literal-path-staging discipline,
  the ledger `op=` grammar, `verify_appetite_<group>` config handling,
  out-of-scope advisory listing
- the orchestration split: partition orchestrates; blueprint materializes docs;
  commits deferred to caller

### Net-new (no rename analog)

1. **Assignment** — the whole front half. Who gets what.
2. **Revealed cross-child edges** — the marquee capability (below).
3. **Blueprint create-N** — a `--split` arm minting N child blueprints from one,
   vs `--rename` editing one in place.
4. **Map fission** — one row → N rows, one section → N sections, Relations
   re-pointed *per owner*.

## The one hard analytical problem worth the feature

When `cart` was one group, a call from checkout-code into catalog-code was an
**internal** call — invisible to the blueprint contract graph. After the split
it is a **cross-group edge** that *should* be a `requires`. A split that ignores
these mints child blueprints that lie about the contract graph from birth, and
the first `/jim:verify` or reconcile floods with findings.

This is why split is more than "rename run N times." The substrate already
exists: `/jim:partition`'s native import scan computes the real dependency
graph. Split should feed the assignment into that graph and **propose the new
`requires` edges** the split reveals — grounded in real imports, human-confirmed
at the gate. This is `edges-diff`'s harder cousin: not "graph preserved modulo
name" but "graph = external re-points + newly-surfaced internal edges."

## Proposed flow (mirrors rename's spine)

```
/jim:partition split cart into cart checkout

Preflight ✓ (map, source mapped, 2 target slugs, no collision, blueprint, clean tree)

Proposed split: cart → cart (remainder) + checkout (extracted)
grounded in the import substrate — edit any row, then approve

  PROVIDES surface → owner
    cart-session-api    → checkout   (used by 4 checkout-side modules)
    catalog-query-api   → cart
  REVEALED CROSS-CHILD EDGES (new requires, from real imports)
    checkout requires cart.catalog-query-api   (3 call sites)   [confirm]
  INVARIANTS → owner   (ids ratchet unchanged — assigned whole, never split)
    inv-9c1d session-ttl        → checkout
    inv-3fa2 price-consistency  → SPANS both — keep with cart? [decision]
  SPEC HISTORY
    docs/specs/cart/001–006     (disposition depends on #68 — see blocker)
    checkout                    fresh dir, next-id 001
  TERRITORY (assignment only — no code moves)
    modules/cart/checkout/**    → checkout
    modules/cart/**             → cart
    modules/cart/shared.ts      → SPANS both — file code-split issue [decision]
  CONFIG
    verify_appetite_cart stays; checkout → default (offer add)
  OUT-OF-SCOPE MENTIONS (informational)  ROADMAP.md:20, README.md:44

Approve, edit a row, or decline? _
```

The **spanning rows** (invariant across both children, file across both) are the
cases a naive engine gets wrong by silently picking. The engine surfaces them and
refuses to guess — solve at the root, don't skirt.

## Design forks

### A. Arity & symmetry — DECIDED: both arms in scope

- **Extraction (keep-one):** `cart → cart + checkout`. The remainder keeps
  identity, dir, history, and numbering for free; only the extracted child is
  fresh. The common "pull a subgroup out" case, and the best case for history.
- **Symmetric N-way:** `cart → {catalog, checkout}`, old group fully retired,
  all children fresh.

**Decision (jrko):** both are valid and must be supported — extraction is the
best case, the symmetric case is *just as valid*. Not an extraction-only v1.

Consequence: the symmetric arm is exactly the one that collides head-on with the
#68 blocker (old group ceases to exist → every historical spec is stranded under
a nonexistent identity, with no continuing name to fall back on). Extraction
sidesteps it only for the *remainder*, not the extracted child.

### B. Assignment mechanism — OPEN (leaning: proposed-default-then-edit)

jim already proposes a grounded map at greenfield `/jim:partition` behind a hard
gate; split is the same doctrine scoped to one group. A gatherer/substrate
proposal (cluster by territory subtree + requires-locality), the developer edits
rows, one all-or-nothing gate ratifies. Keeps the single-gate doctrine intact.
Declarative-manifest and pure-interactive alternatives weighed against
(heavier authoring / multi-gate creep respectively). Not ratified.

### C. Spec-history disposition — BLOCKED on #68

This is the fork the whole session pivoted on. Forces the freeze-history crux
(#68). Deferred until #68 is resolved — see *The blocker*.

### D. Revealed internal edges — OPEN (leaning: detect-and-propose)

Detect from the import substrate and propose the new `requires` edges the split
reveals; propose, never auto-apply; human-confirmed at the gate. This is the
feature's whole justification. Not ratified.

### E. Territory / code — OPEN (leaning: assignment-only, no code moves)

Split's territory step points each child at existing paths; where code is not
cleanly separable (the spanning file), file a tracked code-split issue routed to
normal spec→plan→build. Rename's move-now worked because a whole dir moved
atomically; split has no atomic-move equivalent (multi-file code partition is
unbounded judgment work). Not ratified.

### F. Own verb vs generalized core — OPEN (leaning: own verb, shared shape)

Insight 2 hints at unifying rename/split/merge as one `(sources, targets,
assignment)` transform (rename = 1→1 identity, split = 1→N, merge = N→1). Lean:
build split as its own verb reusing the shipped primitives, but design its
change-set + edge-derivation as the shared shape so **merge** slots in later —
the same forward-compat discipline rename used for split. Generalizing the core
now is unproven need. Not ratified.

## The blocker — spec identity on group-move (issue #68)

Surfaced from a real `/jim:partition rename` run in a consumer project. Verified
this session against the jim source.

### What rename does today (verified, spec 043, shipped)

Rename does **two different things** to numbered specs — conflating them is what
made this confusing:

| Concern | Shipped rename | Result |
| :--- | :--- | :--- |
| Spec directory location | `rename-tracked` git-mv's the *whole* dir `docs/specs/cart/ → docs/specs/checkout/` (history-continuous; wip dirs ride along) | Numbered specs **physically move** to the new group's dir |
| Spec internal identity | `NNN-*` body classified **historical** → frozen, never rewritten | `group:` frontmatter, body mentions, `Spec: cart/NNN` trailers **stay the old name** |

So the shipped behavior is **"half-moved"**: files sit under
`docs/specs/checkout/` but still *say* they belong to `cart`. (The `000-blueprint`
*is* re-identified correctly — only specs 001+ freeze.) This is the spec-043
change jrko made — flipping repartition's freeze-everything into rename's
git-mv-with-accurate-blueprint — deliberately *not* tackling history rewriting at
the time.

**Severity:** the stale identity is **not machine-read** — group is
*path-derived* (the directory name); no script parses a numbered spec's `group:`
frontmatter or `Spec:` trailer. So it is an archive-coherence / human-readability
staleness, not a functional break. But it directly undercuts VISION's "archive as
a reliable onboarding reference": a spec filed under `checkout/` that reads
`group: cart` is incoherent to a reader.

### Why it blocks split/merge

- **#68 as filed** is scoped to *repartition* mode (spec 038), which doesn't move
  specs **at all**. The rename era (043) introduced a *second, distinct* gap #68
  doesn't yet name: dir moves, internal identity freezes.
- In **rename** the domain continues under a new name, so a frozen `Spec:
  cart/003` is arguably a truthful historical fact.
- In **split/merge** the source identity *ceases to exist* — every moved spec's
  `group: cart` points at a group that is simply gone, **and** split must first
  *decide which child* each spec belongs to. Freeze-in-body produces specs
  stranded under a nonexistent identity, with no continuing name to fall back on.
  The symmetric arm (fork A, in scope) makes this unavoidable.

### The real design fork underneath #68

**What does a spec's recorded group identity mean when the group's identity
changes — an immutable historical fact, or a live pointer that should track the
move?** Unanswered for rename today; unavoidable for split. Sub-questions #68
already flags: move-vs-forward (physical relocation vs a redirect/alias over an
untouched archive), id + trailer semantics (ids are per-group; re-homing implies
new ids or collisions), git-history continuity, and `--retire` interaction.

## Decisions this session

- **Both split arms in scope** — extraction *and* symmetric N-way (fork A).
- **#68 is a real, verified blocker** — still open, unaddressed by any spec or
  branch; the rename era already opened a narrower version of it that the issue
  text doesn't yet capture.
- **Table the split brainstorm; resolve #68 first.** Update #68 to reflect
  current rename behavior and reference this doc as the blocking context.

## Open, for when this resumes

- Fork B (assignment mechanism), D (revealed edges), E (territory), F (own verb
  vs generalized core) — leanings recorded above, none ratified.
- Merge specifics — the inverse over the same engine; collapse-map assignment,
  edge-set union, dual-source retire. Deferred with split.
- Spanning invariants and spanning files — the engine must surface, never guess.
