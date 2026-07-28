---
spec: "docs/specs/issue/010-ordinal-coordination/spec.md"
status: Needs PM Review
date: "2026-07-28"
---

# Research: Coordinated issue display ordinals

## Anchors

- `skills/issue/scripts/new.sh:87-107` — identity resolution. `--slug`/`--num`
  overrides win; else falls back to `jimfile.sh next-id issue "$title"` (:89) and
  `next-num issue` (:91). `:96` hard-rejects a non-numeric `--num`
  (`^[0-9]+$`); `:106` `path issue "$slug"`. **The swap site**: `:89`/`:91`
  become `jimalloc.sh allocate issue "$title"` (returns `<fullid>\t<num>`).
- `skills/issue/SKILL.md:92-152` — `/jim:issue add` pre-resolves slug (`:97`
  `next-id issue`), num (`:105` `next-num issue`), path (`:113`), timestamp
  (`:121`), shows the confirm-or-edit block (`:126-138`), then calls `new.sh`
  with `--slug`/`--num` (`:145-152`). **Second entry point**: the candidate
  batch (`SKILL.md:207`, the eight surfacing skills) calls `new.sh` *without*
  overrides, so the emitter resolves identity. Both entry points must coordinate.
- `skills/issue/scripts/index.sh:139,366` — INDEX generation reads `num` from
  frontmatter verbatim; it is already a pure projection (no derivation). No
  jimfile/jimalloc calls.
- `skills/issue/scripts/render.sh:512-559` — `show`. Resolves `#N`/slug/full-id
  **against INDEX.md only** (`:531-534` numeric-ordinal match on the `nums[]`
  column; slug/prefix/substring otherwise), composes the path from the *indexed*
  slug (never raw input). **Calls neither jimfile nor jimalloc.** `list`
  (`:326-372`) carries `num` as a column and a sort key.
- `skills/file/scripts/jimalloc.sh` — issue verbs and their stdout:
  `alloc_allocate_issue :985` → `<fullid>\t<num>` (`:884`); `alloc_resolve_issue
  :207` → current ordinal, one line (`:245`); `cmd_reconcile :1378` reads pending
  full-ids on **stdin** (`:1355-1357`), preview prints `<full-id>\t<ordinal>`
  (`:1374`), realize tags `new|have` (`:381,:384`); `alloc_provisional_issue`
  returns `<fullid>\t<P-ordinal>`.
- `skills/file/scripts/jimfile.sh:295-316` — the `next-id` overload (issue-kind
  vs group). `cmd_path :633-694` and `cmd_next_num :455-466` are **not**
  overloaded.
- Tests: `tests/issues.sh` (issue scripts, incl. `new.sh`) and
  `tests/jimalloc.sh` (allocator) are the templates; both run under
  `skills/meta-test/scripts/testlib.sh` (`bash tests/issues.sh` standalone).

## Local Patterns

- **Emitter override contract already exists.** `new.sh` accepting `--slug`/
  `--num` and only *falling back* to a resolver is the seam the wiring rides —
  no new interface. The clean shape: `new.sh`'s fallback calls `allocate issue`
  (covers the batch path in one place), and `/jim:issue add` shows its preview
  from `peek issue` (advisory, non-binding — Insight 5) while `new.sh`'s
  `allocate` is what binds, as late as possible (G7).
- **Kind-first allocator grammar.** Every `jimalloc.sh` verb is
  `<verb> <kind> [args]` with `kind ∈ {spec,issue}` first; a group named `issue`
  only ever appears *after* an explicit `spec` keyword (`cmd_peek`/`cmd_resolve`/
  `cmd_reconcile`, `alloc_allocate_spec`). It is structurally immune to the
  group-vs-kind overload that bites `jimfile.sh next-id`.
- **Validated-id-before-path discipline** (`new.sh:100`, `render.sh` indexed-set
  resolution, security 019 Finding 1): every id passes `valid-id` before path
  composition. The reconcile rewrite must reuse this exact boundary (AC 10).
- **Atomic tmp+mv writes** (`new.sh:130-158`, `index.sh`): the frontmatter
  rewrite on realization must follow the same pattern to preserve
  `atomic-index-write` / `single-emitter`.

## Security & Performance

- **Untrusted registry input.** The coordination branch is push-writable, so
  every ordinal/full-id read back (allocate, resolve, reconcile) is attacker-
  influenced; revalidate through `valid-id` before any path/git use (AC 10;
  `platform/007` guard). `alloc_resolve_issue` returns a bare ordinal — treat it
  as data until validated.
- **Filing becomes network-touching under a remote.** Today `new.sh` is a pure
  local writer. After wiring, every `add` *and every candidate-batch item*
  performs a push-CAS. The batch path (eight skills, N issues/run) would do N
  serialized round-trips racing every other push to the branch — this is
  load-bearing, not cosmetic (Insight 2). The allocator's `alloc_publish` batch
  path (one CAS for N records) is the mitigation to expose.
- **`num` widening.** `new.sh:96` rejects a non-numeric `num`; `index.sh`,
  `render.sh` `show` (`:531` numeric branch), and `list` sort all assume numeric.
  Storing a provisional `P-…` ordinal (AC 6) requires widening the emitter guard
  and every reader/sort to treat `P-…` as a distinguishable non-settled ordinal
  (AC 9). Small but touches multiple files.
- **Provisional durable-id is undisambiguated** (`alloc_provisional_issue`
  computes the full-id over an empty log). Two offline filings, or an offline vs
  a concurrent real filing, can share a durable id / filename; reconcile keys on
  that id (Insight 3). Verify the built `alloc_reconcile_realize` never collapses
  two distinct issues onto one ordinal, or disambiguate locally at filing.

## Recommendations

1. **Route both entry points through one call site.** Prefer having `new.sh`
   allocate in its fallback (covers `add` *and* the batch), with `/jim:issue
   add` switching its preview to `peek issue`. Keeps the emitter the single
   coordination point and preserves the override contract for tests. Architect
   weighs this against `new.sh` becoming network-touching (Insight 1).
2. **Expose a batch issue-allocate** over `alloc_publish` so a candidate batch is
   one CAS, not N (Insight 2).
3. **Keep `#123` out of this spec.** The collision is confined to `next-id`'s
   overload and never reaches the issue runtime path; the spec-ID consumer
   (`#112`) is *also* immune because it will call `allocate spec issue`. Fold
   nothing in — fix `#123` independently as an authoring-ergonomics papercut.

## Peer Feedback

*For the PM (spec feasibility):*

- **AC 4 (`show` resolves through the registry) looks over-specified for
  issues.** Because `issue_placement` is deferred, issue content and frontmatter
  stay on-branch; realization rewrites the frontmatter `num` and reindexes, so
  `show #42` already resolves via INDEX with no registry call — and `render.sh`
  today touches neither resolver. Registry `resolve issue` is essential for
  *specs* (rename records) but marginal for issues: it cannot help a peer whose
  branch lacks the rewritten file anyway. **Recommend** reframing AC 4 to the
  observable outcome — *an ordinal realized from a provisional resolves to its
  issue* — and letting the architect choose INDEX-reprojection (simpler) over
  wiring `show` to the registry. This trims real surface.
- **The network-touching behavior change (esp. the auto candidate-batch)
  deserves an explicit scope acknowledgement in the spec** — filing under a
  remote now pushes, including at the end of every pipeline run. It aligns with
  jim's transparency stance (a visible git op, like the ledger commits) but it
  is a real change from today's local-only filing and should be named, not
  implied.

*Alignment:* `ARCHITECTURE.md:388` names this consumer as the frozen
follow-on 009 anticipated — squarely aligned; the only architectural touchpoint
is the `num` widening. `VISION` (issue capture as a discovery artifact, not a
team-coordination primitive; not-a-black-box) is respected: this is id hygiene
plus a *visible, previewed* reconcile, not workflow tooling.
