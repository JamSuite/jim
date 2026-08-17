# Brainstorm: Partition Split

*2026-07-16*

Follow-on to [`20260711-partition-migrate-capabilities`](20260711-partition-migrate-capabilities.md)
(which seeded rename, shipped as spec 043) and the split/merge line it deferred.
Scope here: the **split** mechanism (1 group → N), with **merge** (N → 1) noted
as the inverse over the same engine.

**Status: resumed & closed 2026-07-21 — all forks decided, ready for `/jim:spec`.**
The blocker (issue #68, spec identity on group-move) was resolved by spec 046
(spec-migration); every design fork below is now ratified. See *Decisions —
session 2* for the closing decisions and *The blocker* for how #68 was settled.

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
    inv-3fa2 price-consistency  → SPANS both — owner cart + cross-child issue
  SPEC HISTORY   (spec_migration=rewrite: assigned child, fresh child renumbers)
    docs/specs/cart/001–005     → cart   (remainder keeps its numbers)
    docs/specs/cart/006–009     → checkout/001–004   (fresh child, renumbered)
  TERRITORY (assignment only — no code moves)
    modules/cart/checkout/**    → checkout
    modules/cart/**             → cart
    modules/cart/shared.ts      → SPANS both — owner cart + code-split issue
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

### B. Assignment mechanism — DECIDED: proposed-default-then-edit

jim already proposes a grounded map at greenfield `/jim:partition` behind a hard
gate; split is the same doctrine scoped to one group. A gatherer/substrate
proposal (cluster by territory subtree + requires-locality), the developer edits
rows, one all-or-nothing gate ratifies. Keeps the single-gate doctrine intact.
Declarative-manifest and pure-interactive alternatives weighed against
(heavier authoring / multi-gate creep respectively).

**Decision (jrko):** proposed-default-then-edit, one hard gate. With #68 resolved,
fork C collapses into this fork: **numbered specs are assignment occupants too** —
each proposed a child from the same territory + import substrate, alongside
surfaces, invariants, territory paths, and requires-edges. Assignment decides
*which child*; the `spec_migration` knob (fork C) then decides *how that spec's
identity moves* (rewrite / forward / immutable).

### C. Spec-history disposition — RESOLVED (spec 046) → collapses into B

The fork the whole session pivoted on. **Spec 046 (spec-migration) settled it:**
identity-on-move is a project preference — `spec_migration = rewrite` (default)
`| forward | immutable` — with the reconciled doctrine that the spec *directory*
is the live group binding, a numbered spec's *body* identity is governed by the
preference, and the ledger `op=` event is the durable old→new bridge in every mode
(the `000-blueprint` re-identifies in every mode regardless). **Split does not
reopen freeze-history — it applies the knob.** So spec-history disposition stops
being a policy question and becomes pure *assignment* (which child) — fork B.

**Numbering on move — DECIDED: fresh-vs-continuing, per destination.** The one
mechanic 046 handed to split. `rewrite-identity` (046) keeps a spec's number and
rewrites only the group half — correct for rename, where the whole dir moves 1:1.
Split is different, and fork A already says so (*"only the extracted child is
fresh"*):

- **Continuing destination** (the extraction remainder; a rename target) — keeps
  its numbers (fork A's "for free"). Interleaved-extraction gaps are truthful:
  they mark what left. The remainder never re-histories.
- **Fresh / absorbing destination** (an extracted child; every child of a
  symmetric split) — renumbers to a clean `001..N`, ordered by original number.
  Worked example under `rewrite`: `cart/001–005` stay, `cart/006–009 →
  checkout/001–004`, bodies' `group:` rewritten, `next-id checkout = 005`.
- The **ledger `op=` event** records the per-spec `(old-group/old-num →
  new-group/new-num)` map — the same alias substrate 046 built, carrying a *set*
  of remaps instead of rename's single group swap.
- Under **`immutable`** nothing moves, so no renumber: extracted specs stay frozen
  in the source dir and the fresh child inherits nothing (the point-in-time-
  fidelity trade-off). `rewrite` (default) is the renumber-in norm.

Substrate note for the plan: `rewrite-identity` is **group-only (keeps `NNN`)** —
a fresh child's renumber needs an extension arm (rename the `NNN-slug.md` file
*and* update in-body typed self-refs), so "reuse the shipped primitives" is not
quite free. (A `forward`-mode wrinkle — renumbered filename vs frozen body number,
reconciled only via the ledger — is a plan-time detail.)

### D. Revealed internal edges — DECIDED: detect-and-propose

Detect from the import substrate and propose the new `requires` edges the split
reveals; propose, never auto-apply; human-confirmed at the gate. This is the
feature's whole justification.

**Decision (jrko):** detect-and-propose — grounded in real imports, presented at
the gate with call-site counts, never auto-applied. See the **spanning invariant**
(below): its invariant-side twin — the cross-group *contract* a shared invariant
reveals, the part imports cannot see.

### E. Territory / code — DECIDED: assignment-only, no code moves

Split's territory step points each child at existing paths; where code is not
cleanly separable (the spanning file), file a tracked code-split issue routed to
normal spec→plan→build. Rename's move-now worked because a whole dir moved
atomically; split has no atomic-move equivalent (multi-file code partition is
unbounded judgment work).

**Decision (jrko):** assignment-only. The spanning file is surfaced, assigned a
provisional owner so territory coverage has no gap, and filed as a code-split
issue. Solve at the root; route judgment to the workflow that owns it.

### F. Own verb vs generalized core — DECIDED: own verb, shared shape

Insight 2 hints at unifying rename/split/merge as one `(sources, targets,
assignment)` transform (rename = 1→1 identity, split = 1→N, merge = N→1). Build
split as its own verb reusing the shipped primitives, but design its change-set +
edge-derivation as the shared shape so **merge** slots in later — the same
forward-compat discipline rename used for split. Generalizing the core now is
unproven need.

**Decision (jrko):** own verb, shared shape — and pin merge's forward-compat to
*notes, not code* (option A). The shared shape is the **split/merge duality**;
naming it is the deliverable:

| Axis | Split (1→N) | Merge (N→1) |
| :--- | :--- | :--- |
| Numbering | renumber fresh children | renumber-append absorbed sources |
| Edges (fork D) | reveal internal → cross-group | collapse cross-group → internal, re-point 3rd-party |
| Spanning thing | one invariant spans N children | N invariants collide into one group |

If the split spec makes each row a *parameter* of the change-set / `edges-diff` /
ledger shapes, merge is a new arm, not a new engine. Merge's *arity + numbering*
are pinned by these notes (spec-number collision dissolves — renumber-append means
there's never two `001`s to reconcile). Its three genuinely net-new judgment
problems — **invariant-id collision**, **edge dissolution-vs-re-point**, and
**provides-surface name collision** — are named and **deferred to merge's own
spec**, so merge inherits a known list, not a surprise.

### Spanning invariant — DECIDED: owner + cross-child contract issue

An invariant that genuinely constrains *both* children after the split
(`inv-3fa2 price-consistency` across catalog + checkout). Invariant ids are keys
(verify history, check-data, filed issues join on them), so it can be neither
**split** (breaks the join) nor **duplicated** (ambiguous per-invariant join). It
must live in exactly one blueprint; the open question was the *other* child's
obligation.

**Decision (jrko):** the engine surfaces it, proposes a **primary owner from the
substrate** (the child holding the most code it references — editable at the gate,
fork-B consistent) so `inv-3fa2` stays live and coverage is not lost, and files a
tracked **cross-child contract** issue routed to spec→plan→build. The issue
carries the id + text, the two children it spans, the per-side substrate evidence,
and a concrete imperative (author a boundary contract, or re-key into per-side
invariants under a shared contract). This is the invariant-side twin of fork D:
where imports reveal the mechanical `requires` edge, a mutual semantic guarantee
is the part imports cannot see, so it drops to the same human-routed follow-up as
the spanning file (fork E). Rejected: *owner-only* (silently under-covers the
symmetric case — a `requires` edge is directional, the guarantee is mutual) and
*block-until-resolved* (chicken-and-egg — you cannot author the boundary contract
until the split gives both sides identities to contract between).

## The blocker — spec identity on group-move (issue #68) — RESOLVED

**Resolved 2026-07-21 by spec 046 (spec-migration), shipped & reviewed
`aligned`; issue #68 closed.** Identity-on-move is now the `spec_migration`
preference (`rewrite` default / `forward` / `immutable`); the reconciled doctrine
and the `rewrite-identity` verb are in place. The analysis below is the
pre-resolution record of *why* it blocked — kept for context; fork C above carries
the resolution.

Surfaced from a real `/jim:partition rename` run in a consumer project. Verified
against the jim source.

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

## Decisions — session 1 (2026-07-16)

- **Both split arms in scope** — extraction *and* symmetric N-way (fork A).
- **#68 is a real, verified blocker** — the rename era opened a narrower version
  of it than the issue text captured.
- **Table the split brainstorm; resolve #68 first.** Update #68 to reflect current
  rename behavior and reference this doc as the blocking context.

## Decisions — session 2, resumed (2026-07-21)

#68 resolved by spec 046; brainstorm resumed and closed. Every fork ratified:

- **B — assignment:** proposed-default-then-edit, single gate; numbered specs are
  assignment occupants, the `spec_migration` knob governs their identity.
- **C — spec-history:** resolved by 046 (apply the knob), collapses into B.
  **Numbering:** fresh destinations renumber to `001..N`; the continuing remainder
  keeps its numbers; the ledger `op=` event carries the per-spec remap set.
- **D — revealed edges:** detect-and-propose from imports, human-confirmed.
- **E — territory:** assignment-only; spanning file → provisional owner + tracked
  code-split issue.
- **F — verb shape:** own `split` verb, shared shape; merge pinned as
  forward-compat *notes* (the duality table), its three judgment problems named
  and deferred to merge's own spec.
- **Spanning invariant:** primary owner (proposed, editable) + tracked cross-child
  contract issue — the invariant-side twin of fork D.

## Ready for `/jim:spec`

**Scope for the split spec** = forks B–F + numbering + spanning-invariant, over
the extraction *and* symmetric arms; merge is forward-compat notes only.

**Deferred to merge's own spec:** invariant-id collision, edge dissolution-vs-
re-point, provides-surface name collision.

**Named substrate work the plan inherits:** `rewrite-identity` grows a
number-remap arm (fresh-child renumber); `edges-diff` grows the reveal-edges
(fork D) derivation; blueprint gains a `--split` create-N arm; the ledger `op=`
event carries a per-spec remap set.
