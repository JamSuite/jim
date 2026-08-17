# Brainstorm: Spec identity on group move

*2026-07-20*

Resolving **issue #68** — the freeze-history crux that tables the split/merge
design line ([`20260716-partition-split.md`](20260716-partition-split.md)).

## The one question

> **What does a spec's recorded group identity mean when the group's identity
> changes — an immutable historical fact, or a live pointer that should track
> the move?**

Unanswered for rename today; unavoidable for split/merge (the source group
ceases to exist, so a frozen `group: cart` points at nothing).

## Ground truth (verified against the source this session)

- **Group identity is entirely path-derived.** No deterministic script reads a
  numbered spec's `group:` frontmatter or a `Spec: <group>/NNN` trailer — grep
  is empty. Group membership = which `docs/specs/<group>/` directory a spec sits
  in; group→territory comes from `BLUEPRINT.md`; retired slugs come from
  `op=rename` ledger events. So #68 is **archive-coherence / human-readability**,
  **not a functional break**.
- **The `Spec: <group>/NNN` trailer is never even written** in jim — it's an
  aspirational convention a brainstorm explicitly says jim "does not mandate,"
  and the coder commits without it. The trailer sub-fork is lighter than #68's
  text implies (moot for jim; a live question only for consumer projects that
  adopt the trailer convention).
- **Rename's "half-moved" state is real and by design.** `rename-tracked`
  git-mv's the *whole* `docs/specs/<old>/` dir (history-continuous, wip dirs
  ride along); `Skill(jim:blueprint) --rename` re-identifies the `000-blueprint`
  (frontmatter `group:`, prose, map row/section/Relations, sibling dotted
  `requires` group-halves) and ratchets invariant ids + provides names
  byte-for-byte; numbered `001+` bodies are classified **historical** and frozen
  (frontmatter `group:`, prose, any old-name mentions left untouched).

## The anchor tension

Two shipped specs contradict each other, and the contradiction *is* the crux:

- **038 AC** (freeze-history): "*No mode of this skill moves, renumbers, or edits
  a numbered spec directory.*"
- **043 rename**: `rename-tracked` **moves the whole dir**.

043 silently narrowed freeze-history from **"don't move"** to **"don't edit
content."** That narrowing was never ratified as doctrine — it was an
implementation choice. This session decides whether it *is* the doctrine, or
whether identity should track the move.

## Already decided elsewhere (not relitigating)

From [`20260711-partition-migrate-capabilities.md`](20260711-partition-migrate-capabilities.md):

- **ids ratchet / names track code** (decision 3) — invariant ids are opaque
  keys kept forever; provides surface names follow the code they describe.
- **`op=rename` is a first-class ledger event** — not a drop+add pair.
- **move-vs-docs-only fork (B)** — code moves are the developer's choice at the
  gate; a docs-tier op never forces unreviewed code edits.

From [`20260716-partition-split.md`](20260716-partition-split.md):

- **Both split arms in scope** (fork A) — extraction (keep-one) *and* symmetric
  N-way. The symmetric arm is the one that makes stranded identity unavoidable.

## Core decision (jrko): identity-on-move is a user preference

Not a universal doctrine to settle — a **config knob**. Three stances become
three modes:

- **`rewrite` (default)** — jim self-maintains identity. On a move, a numbered
  spec's `group:` tracks the new owner. Rationale: fits jim's living-document
  instinct — ARCHITECTURE.md and the 000-blueprints are *already*
  self-maintained / present-tense; identity coherence is the same reflex applied
  to the spec label.
- **`immutable`** — bodies frozen; a spec's `group:` is an authored-era fact.
  For users who want the point-in-time archive faithful to when each spec was
  written.
- **`forward`** — bodies frozen **plus** a redirect/alias resolving old→new, so
  discoverability survives without editing history.

The knob exists because rewrite is the right *default* but too dynamic for some;
immutable/forward are the opt-outs.

### Refined mode model — two axes (dir-move × body-identity), alias bridges the gap

| Mode | Dir follows group? | Body identity | Alias | Result |
| :--- | :--- | :--- | :--- | :--- |
| **`rewrite`** (default) | yes | rewritten (label + refs) | ledger `op=` for history | coherent in the working tree |
| **`forward`** (2nd) | yes | frozen | **yes** — bridges frozen body ↔ new home | coherent *via* the alias |
| **`immutable`** (3rd, least-used) | **no** | frozen | ledger only | archive faithful to authoring |
| ~~today's 043~~ | yes | frozen | **none** | orphaned in-between — the incoherence #68 names |

Key realizations (jrko):

- **`rewrite` scope = label + references, never substance.** Group
  name/metadata/prose-name/refs track the move; the spec's decisions and intent
  stay byte-frozen. Rewrite keeps the *pointer* current, it does not re-history.
- **`immutable` means nothing moves at all** — not even the dir. Today's
  half-moved state is already a mutation away from "frozen," so it is *not*
  immutable.
- **`forward` is the principled rescue of today's half-moved state**: same
  physical move rename already does, bodies still frozen, but an alias supplies
  the cohesion 043 left missing.

## Gaps in riding the existing rename engine (jrko asked)

The engine's mechanical spine — `occurrences` enumeration, identity/code-surface/
historical classification, `rename-tracked` git-mv, three-commit choreography,
`op=` ledger, `edges-diff`, the zero-unclassified sweep — is reusable. The knob
is largely *"do numbered-spec-body identity occurrences classify as `identity`
(rewrite) or `historical` (freeze)?"* But real gaps:

1. **Safe rewrite scope is narrower than "all prose."** Frontmatter `group:` and
   *typed/structured* refs (dotted keys, wikilinks, `Spec:` trailers) are
   mechanically safe. Free prose is judgment: "cart" the group vs "cart" the
   domain noun — `occurrences` can't tell (it buckets both as `prose`).
   Blind prose rewrite risks corrupting substance, violating "don't re-history."
   → Lean conservative: rewrite frontmatter + typed refs; free-prose mentions
   need the gatherer judgment layer, or stay out of scope.
2. **Git commit history is unrewritable.** `Spec: cart/003` trailers and group
   mentions in past commits are frozen forever, in every mode. So even `rewrite`
   achieves coherence only in *working-tree files* — the durable old→new bridge
   for history/reference consumers is the **ledger `op=` alias**. That means the
   alias isn't unique to `forward`; it's a **shared substrate all three modes
   lean on**. `forward` just *surfaces* it as first-class discoverability.
3. **Split adds per-spec assignment; the engine has none.** The rename engine
   assumes one global old→new target (degenerate column). Split must decide
   *which child* owns each numbered spec — net-new judgment (Insight 2's
   per-occurrence target keying was cut for exactly this). Unavoidable in the
   symmetric arm.
4. **Merge adds id-collision / renumber.** `cart/001` + `wishlist/001` → one
   `shopping/` dir collides on `001`. Renumbering is arguably a form of
   re-historying and breaks `Spec: cart/003` refs; not renumbering means the
   merged dir can't hold both. Rename never faces this (1:1, no collision).
5. **Is the `000-blueprint` subject to the knob, or always-live?** The blueprint
   is present-tense by doctrine (029) and rename *always* re-identifies it. Lean:
   the knob governs **numbered specs 001+ only**; the blueprint re-identifies in
   every mode, even `immutable`. (So "immutable = nothing moves" applies to the
   frozen numbered archive, not the living blueprint.)
6. **Shipping this changes rename's current default and orphans existing
   half-moved projects.** New default `rewrite` edits numbered bodies where 043
   did not; projects already renamed under 043 sit in the now-unnamed half-moved
   state. May owe a one-time reconciler to land them in a chosen mode.

### Decisions on the gaps (jrko)

- **Rewrite scope = full prose.** The mechanical occurrences (frontmatter
  `group:`, dotted keys, typed refs) are scripted; everything ambiguous —
  free-prose group-mentions, "cart-the-group vs cart-the-noun" — leans on **LLM
  judgment**, the read-only gatherer fan-out the rename engine already uses
  (spec 043 Insight 5). Bash for the deterministic floor, judgment for the rest.
- **Scope of resolving #68 = foundation only.** #68 lays the doctrine and
  unblocks the split brainstorm — it does **not** design split/merge mechanics.

## What "resolving #68" delivers (the foundation)

In scope:

1. The **identity-on-move knob** — `rewrite` (default) / `forward` / `immutable`
   — governing numbered specs 001+, as the two-axis model above.
2. **Reconciled freeze-history doctrine.** Replaces the 038 "no mode *moves* a
   numbered spec dir" ⟂ 043 "*moves* but doesn't *edit*" contradiction with:
   *the directory is the live binding; body identity is governed by the knob;
   the ledger `op=` alias is the durable old→new bridge in every mode.*
3. **Rewrite mechanism** — scripted mechanical floor + gatherer-judgment prose,
   confined to identity (never substance).
4. The **ledger alias as shared substrate** — surfaced first-class in `forward`,
   relied on by all modes for history/reference continuity.
5. The `000-blueprint` re-identifies in **every** mode (present-tense doctrine
   029); the knob touches only the numbered archive.

Explicitly deferred to the split/merge spec (foundation names, does not solve):

- **Split per-child assignment** — which child owns each numbered spec.
- **Merge id-collision / renumber** policy.
- Whether `immutable`'s "nothing moves" can even hold when the source group is
  retired (split/merge) — a retired dir holding live specs is split's problem.
- The **one-time reconciler** for projects already in the 043 half-moved state.

## Split brainstorm: UNBLOCKED

Fork C (spec-history disposition) in
[`20260716-partition-split.md`](20260716-partition-split.md) was *blocked on
#68*. Its answer is now: **split applies the identity knob**; the per-child
assignment mechanics are split's own net-new design. The tabled brainstorm can
resume once this foundation is specced.
