---
spec: "docs/specs/platform/011-rename-path-correctness/spec.md"
status: Needs PM Review
date: "2026-07-29"
---

<!-- Budget: <1500 words total. Never paste >20 lines of code — use file:line-range + 1-sentence summary. -->

# Research: Rename-path correctness gates

Phase 0 (local archaeology) run inline rather than via an `Explore` subagent —
the scoping session had already read every relevant region, and the operator's
standing instruction is no agent dispatch unless asked. Phase 1 (external
intelligence) **skipped**: a bug in this project's own frozen semantics, no
external API, library, or prior-art dependency. Every line anchor below was
re-verified on 2026-07-29 against the working tree.

## Anchors

All implementation sits in one file: `skills/file/scripts/jimalloc.sh`.

**D1 — resolution anchoring**
- `:166-200` `alloc_resolve_spec`. Anchor pass `:173-185` sets `anchor=$i` only in
  the allocate branch (`:177`); the rename-destination branch (`:180`) sets
  `known=1` and leaves the anchor behind. Replay `:187-197` skips `i <= anchor`.
- `:207-246` `alloc_resolve_issue`. Same shape: durable-id→ordinal map `:216-222`,
  anchor pass `:226-235` (allocate `:230`, rename-in `:233`), replay `:237-243`.
- Group redirect already works in replay (`:193-196`), which is why D3 is a
  next-id-only defect.

**D2 / D4 — the high-water fold exists in THREE places, not two**
- `:255-276` `alloc_next_id_spec` — folds allocate ids (`:262-264`) and rename
  destinations (`:265-267`); literal group filter at `:271`.
- `:281-298` `alloc_next_num_issue` — folds allocate (`:286-287`) and rename
  destinations (`:288-289`).
- `:364-380` `alloc_reconcile_realize` — folds allocate (`:371-375`) and rename
  destinations (`:376-378`), and is the D4 divergence: `:373`
  (`alloc_valid_token "$c4" || continue`) skips the record *before* the `max`
  update at `:375`, so a numeric ordinal whose durable id fails the boundary
  never counts here while `alloc_next_num_issue` counts it.

**None of the three folds counts a rename source.** D2 is therefore a
three-site defect, and D4 is a divergence between two of those three.

**D3 — group aliasing**
- `:271` filters group membership on the literal prefix.
- `:253-254` the docstring recording group-rename aliasing as deferred to
  "the spec that begins emitting rename records" — retire it with the fix.
- `cmd_peek` (`:spec` branch) reaches `alloc_next_id_spec` directly, so D3's
  behavior is visible through the public `peek spec` verb, not just internally.

**Tests** — `tests/jimalloc.sh`
- `:99-170` resolution fixtures: multihop `:101`, group-rename `:116`,
  reuse-via-allocate `:129`, cycle-revert `:145`, malformed-skip `:158`. The
  four to preserve unmodified per the spec's shipped-behavior AC.
- `:182-200` issue rename resolution. `:201-241` next-id / next-num, including
  the "rename dst counts" assertion at `:220` — the sibling of the missing
  source assertion.
- `:1212-1266` reconcile realize fixtures (mapping, idempotent,
  marker-independent, high-water-rename, within-batch dup, crafted pending).

## Local Patterns

**Test template for the coder: `tests/jimalloc.sh` itself.** Framework is jim's
own `testlib.sh`, sourced `BASH_SOURCE`-relative (`:22-23`) under
`set -uo pipefail` (never `set -e` — asserts append failure detail and let cases
continue). Asserts: `assert_eq` / `assert_match` / `assert_exit` /
`assert_nonempty` (`testlib.sh:98-145`). Cases are discovered by name.

Two established invocation styles, and the file uses each deliberately:
- **CLI level** — `run_jimalloc_reg "$dir" resolve spec core/009` (`:62`) over a
  registry directory built by `empty_dir` + a `printf`'d log. Every resolution
  fixture uses this.
- **Pure function level** — `source "$SCRIPT_jimalloc"; alloc_next_id_spec dashboard <<< "$log"`.
  Every high-water fixture uses this.

Matching each new fixture to its defect's sibling style keeps the file coherent:
D1 → CLI level, D2/D3/D4 → function level. Heavier fixtures needing a real repo
use `alloc_new_repo` (`:390`) or `seed_repo` (`:997`).

**Validation boundary.** Every replayed token routes through `alloc_valid_token`
/ `alloc_valid_specid` → `jimfile.sh valid-id`. The read path's established
posture is **degrade-and-skip**: a malformed record is `continue`d, never fatal
(`:176`, `:179`, `:191`). Ordinals coerce base-10 via `10#$num` to avoid octal
on leading zeros (`:272`).

**Prior bug specs in this group** — `platform/005-ledger-literal-pathspecs` and
`platform/010-allocator-issue-prefix` are the two precedents for a `type: bug`
spec/plan/build in `platform`; 010 is the closest (same file, same allocator,
reproduce-then-fix with a fixture per defect).

## Security & Performance

**Trust surface is unchanged in kind, widened in fields read.** The registry
lives on a push-writable coordination branch, so every record is untrusted
(`ARCHITECTURE.md` → Security Considerations; `platform/007`'s boundary). These
fixes newly consult three previously-ignored fields: a rename record's *source*
ordinal (D2), group tokens from `group rename` records (D3), and — if D4 is
fixed by relaxing the gate — an ordinal whose sibling durable id is invalid. Each
must pass the same boundary before use, per the spec's External Constraint AC.

**The failure direction is the safe one.** Every D2/D4 change can only *raise* a
high-water. A crafted record therefore wastes ordinals (permanent gaps) rather
than causing reuse — bounded, and consistent with `platform/007`'s non-goal that
an id carries no authority. Worth stating in the plan so it is a decision, not a
side effect.

**Performance is a non-issue at current scale but has one trap.** All folds are
single O(n) passes over a log that today holds 64 spec and 134 issue records.
D3's group aliasing must not become O(n²) by re-walking the group-rename chain
once per record — resolve the chain once into a lookup, then filter. Same for a
multi-hop chain.

## Recommendations

*Options and trade-offs for the architect — not decisions.*

1. **Strongly consider one shared high-water helper.** The three-site finding
   changes the calculus behind the spec's Insight 1. D2 must land in all three
   folds and D4 reconciles two of them: implemented as separate edits that is six
   coordinated changes across three functions, and the spec's AC that allocation
   and reconcile agree "for every log shape" would rest on convention — which is
   precisely what D4 *is*. One helper (fold a log → high-water, taking the kind)
   makes that AC structural. Trade-off: reconcile also needs its
   `existing[full-id]` map from the same pass, so the helper must either return
   both or be called alongside a second pass.
2. **D1 as a two-line anchor change.** Set `anchor=$i` in the rename-destination
   branch as well, keeping the later index. Verified against all four relevant
   fixtures. Termination is preserved because moving the anchor later only
   shrinks the replay window.
3. **Sequence D2 and D4 together, D1 and D3 independently.** D2 and D4 touch the
   same fold(s); D1 is confined to the two resolvers; D3 to the spec fold's
   membership filter. That is also a natural task decomposition.
4. **Retire the `:253-254` deferral docstring** as part of D3 rather than leaving
   a comment that claims the aliasing is still deferred.
5. **Fixture-first per defect**, matching sibling style (above). Each must fail
   before and pass after — the reproductions in the spec's Defect Profile are
   directly transcribable into fixtures.

**Alignment.** This work sits squarely inside `platform`'s declared
responsibility — "keep the paths, ids, config keys, durable counters … in
exactly one deterministic place each" — and its `BLUEPRINT.md` role as the
substrate whose changes carry project-wide blast radius, "which is exactly where
contract checks pay." No divergence from `VISION.md` or `ARCHITECTURE.md`; the
bash-and-POSIX, parse-as-data, single-validation-boundary conventions all hold
unchanged. Recommendation 1 actively *advances* the blueprint's one-place-each
principle rather than straining it.

## Peer Feedback

**For the PM — the D3 AC implies a return-contract change that the spec does not
state.** `alloc_next_id_spec` takes a group and returns `<group>/<NNN>`, and
`cmd_peek spec` surfaces it. Under the settled decision ("asking for the next id
of a group renamed away answers for the group's current name"), a caller asking
about `dashboard` after `group rename dashboard ui` receives **`ui/003`** — an id
whose group differs from the one requested. That is defensible (the group *is*
`ui` now), but it is a public-verb behavior change that the AC leaves implicit,
and a caller doing string work on the returned prefix would be surprised.

Three ways to close it, all cheap: state the prefix-may-differ consequence in the
AC; or have the verb report the redirect alongside the id; or narrow the AC to
say the *ordinal* is correct and leave the returned prefix out of scope. Blast
radius is contained — the allocator's `peek spec` / `allocate spec` are the only
callers, and `jimfile.sh next-id` (which `/jim:spec` and `/jim:partition` use
today) is a separate tree-scan implementation this spec does not touch.

**For the architect — one stale anchor to distrust.** `platform/009`'s review
cites `alloc_reconcile_realize`'s high-water at `:349-355`; it now sits at
`:371-378`. Consistent with the drift already recorded on issues #113 and #122,
treat every inherited line reference in this family as dated and re-verify.
