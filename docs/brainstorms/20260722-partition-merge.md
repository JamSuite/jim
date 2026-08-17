# Brainstorm: Partition Merge

*2026-07-22*

Seeded from [20260722-partition-merge-context.md](../research/20260722-partition-merge-context.md) — the decision-neutral briefing covering the story arc (029→047), split as the mirror template, the three deferred judgment problems, and the consolidated open-question list.

## Session decisions (early)

- **Scope: one spec — mechanism only.** Detector-side work (the merge-signal
  interpretive rule the 044 `Merge signal:` slot lacks, and issue #72's
  chronic-straddle sensing) is deferred out of this spec. `health` keeps its
  inline-LLM judgment for now.
- **Grammar pairs with split.** `merge <src>... into <target>` mirrors
  `split <old> into <new>...`. The target may be a **fresh slug** (fresh-target
  arm — all sources retire) **or an existing group** (absorption arm — the target
  continues, the dual of split's extraction arm).
- **Identity modes: same as split.** All three `spec_migration` modes supported
  where coherent; default `rewrite` (mutate). No new config key — merge inherits
  the project-level preference.

## Finding: invariant ids are semantic slugs, not numbers

Checked `docs/specs/jim/000-blueprint/spec.md` — invariant ids are kebab-case
semantic slugs (`plugin-name`, `no-source-eval`, `script-preamble`), not
sequential tokens. Consequence for judgment problem 1 (invariant-id collision):

- The duality's "renumber-append so id collision dissolves" applies to **spec
  ids only**. Invariant ids have no number space; renumber-append has no analog.
- Collisions are rarer (semantic names) but semantically loaded when they occur.
  Two cases with different resolutions:
  - **Same rule declared in both groups** (e.g. both carry `script-preamble`
    because both follow the convention) → **unify** into one row: identical text
    auto-unifies (mechanical); differing text needs judgment (merged guarantee,
    criticality = max?, check method reconciled).
  - **Homonym** (same slug, different rule) → one side must re-key. The first
    sanctioned break of the identifier ratchet; which side keeps the id is
    judgment, and trend continuity for the re-keyed invariant breaks.
- Detection is mechanical either way (set intersection over source blueprints,
  then text comparison splits auto-unify from needs-judgment).

Same detection/resolution structure applies to judgment problem 3
(provides-surface name collision), with one extra doctrinal wrinkle: surface
names **track code**, so if the collision reflects a genuine code-level name
clash (both sources ship a `config` module), the true fix is a code rename —
which partition never performs. Resolution routes to the **spec-018 issue
batch** (misalignment-as-issues, doctrine invariant #9), with the merged face
disambiguated descriptively in the interim.

## Judgment-load analysis (what the gate must carry)

Where merge's judgment actually lives, problem by problem:

| Problem | Detection | Resolution |
|---|---|---|
| P1 invariant-id collision | mechanical (id-set intersection) | identical-text → auto-unify; differing-text → judgment (small N) |
| P2 edge dissolution vs re-point | mechanical (both endpoints ∈ sources → dissolves; else re-points) | disposition of newly-internal provides is defaultable: **internalize unless a surviving third-party consumer remains** (derivable from the graph — if `Z.requires X.foo` survives, `foo` stays public; forced, not judged). Confirmable rows. Duplicate outbound requires (both sources require `Z.bar`): identical text dedupes mechanically; differing guarantee text needs unification (small N). |
| P3 surface-name collision | mechanical (name-set intersection) | genuine judgment (unify / rename / descriptive disambiguation); code-level clashes route to issues |
| P4 collapse-map order | n/a | mechanical given one rule: absorption target keeps its numbering; absorbed sources renumber-append in **CLI argument order** (explicit human intent, deterministic) |
| Blueprint prose fusion | n/a | always authored judgment (one Responsibility from N, merged Structure, map row/section fusion) — but reviewable as a proposed diff, like split's secret-scrubbed artifact diffs |

Residual judgment after mechanization: differing-text collisions (P1/P2-requires),
surface homonyms (P3), and fused prose. All small-N or diff-reviewable. Merge
looks **more single-gate-viable than the 20260711 prediction feared** — the
prediction assumed interview + analysis; most of the load turns out mechanical.

## Gate shape — the fork (expansion)

Context: the 20260711 brainstorm predicted split/merge "likely need additional
interview + analysis … so a single gate probably doesn't hold"; split shipped
single-gate anyway (whole change-set once, spec-040 presentation, decline
materializes nothing, all-or-nothing). Split got away with it because fission
*derives* content from per-child gatherer evidence — its one judgment case
(spanning) became confirmable gate rows. Merge fusion *authors* new unified
content, which is what the prediction worried about.

Three candidate shapes (C considered and rejected):

- **Shape A — pure single gate (split's shape).** Mechanical prep + per-source
  gatherer evidence → one gate presenting everything: spec remap (rangeable),
  dissolved edges (confirmable each — these are contract *removals*), re-pointed
  edges (rangeable), collision resolutions *with proposed defaults*, fused
  blueprint diffs, RETIRES rows, territory/config rows. Iteration = decline and
  rerun. Cheapest to build; maximally consistent with rename/split. Risk: content
  disagreement (fused prose, a collision resolution) costs a full decline-rerun
  cycle over a large gate; volume may push toward rubber-stamping — the exact
  failure 040 exists to prevent (040 fixes *presentation*, not volume).
- **Shape B — interview + single hard gate (038's shape).** A pre-gate
  conversational phase resolves judgment items interactively (per-collision:
  "cart and wishlist both declare `atomic-write` with differing text — unify as
  …?"; fused Responsibility draft discussed), then one hard gate presents the
  fully-resolved change-set. Decline still materializes nothing. Precedent: 038's
  extract → propose(interview) → gate → materialize. Doctrine-clean: invariant #2
  requires a hard gate before materialization; it says nothing against
  conversation before the gate.
- **Shape B-lite — collision-triggered micro-interview (hybrid).** Judgment
  prompts materialize **only when detected** (any differing-text collision,
  homonym, or non-defaultable disposition → one targeted question each), then the
  single hard gate. Zero-collision merges are indistinguishable from Shape A.
  Fused prose still reviewed as a gate diff. Matches the lean bias: ceremony
  scales with the actual judgment load, which the preflight can count.
- **Shape C — true multi-gate (staged approvals with staged materialization) —
  rejected.** Staged materialization breaks decline-materializes-nothing and the
  revert-and-rerun/no-mid-run-resume security posture from 047. If both gates sit
  pre-materialization it collapses into Shape B with extra ceremony.

Deciding variable: how much judgment survives mechanization (per the table,
little) and whether fused-prose review is acceptable as a gate diff vs needing
conversation. Note the blueprint arm stays caller-driven and does not re-gate
(migrate-arms doctrine), whichever shape wins.

## Noticed along the way (open sub-questions)

- **Grammar sugar.** The commonest merge is 2→1 absorption. Strict mirror of
  split's `target ∈ sources` exemption requires `merge cart wishlist into cart`;
  colloquial CLI usage wants `merge wishlist into cart` (target exists → treat
  as implicit source). Sugar reads naturally but silently expands the source set;
  strict is explicit but slightly awkward. Undecided.
- **Territory in `directory` mode.** Merging two `directory`-mode groups yields
  a group owning **two** directories. Does directory mode admit multiple roots,
  or does the merged group downgrade to `declared-paths` (ladder is "a
  strictness dial, not a goodness dial" — is a downgrade acceptable output)?
  Partition never moves code, so "consolidate the dirs" is not an option here;
  at most a filed issue.
- **Immutable coherence (tentative: coherent on both arms).** Absorption +
  immutable: nothing moves (target continues in place, retired source dirs stay
  put holding frozen specs). Fresh-target + immutable: sources retire in place;
  the target dir is *created*, not moved — 046 AC 9's "no continuing group's
  home directory moves" holds. The AC-9 rename-composition case seems not to
  arise on either plain arm.
- **P3 → issue routing.** Surface collisions rooted in real code-name clashes
  are misalignments, not merge blockers — spec-018 batch, not gate failure.

## Decided: gate shape is B — interview + single hard gate

Rationale: modifying the partition is a high-touch operation the user should be
*engaged* with, not merely approving. The 038 repartition shape (mechanical
prep → interview → single hard gate → materialize) generalizes to merge.

- **Interview agenda (proposed):** differing-text id collisions (P1), surface
  homonyms + code-clash issue routing (P3), non-defaultable edge dispositions
  and divergent duplicate-requires guarantee text (P2), and the fused blueprint
  prose (Responsibility / Structure / map row) discussed as a draft.
- **Never interviewed (stay gate rows):** spec remap, CLI-order append,
  identical-text auto-unify, forced-public dispositions — the mechanical set.
- The single **hard gate is unchanged**: full resolved change-set, spec-040
  presentation, decline materializes nothing, blueprint `--merge` arm is
  caller-driven and does not re-gate.
- **Follow-on filed as an issue:** consider retrofitting split to the same
  interview+gate shape so all partition-changing verbs share one cohesive flow
  (rename likely stays gate-only — its change-set is fully mechanical). Filed:
  `docs/issues/20260722-align-partition-split-flow-to-interview-plus-gate-shape.md`.

## Decided: grammar is intuitive sugar, no hard mirror requirement

User's canonical examples:

- `merge wishlist into cart` — single (2→1 absorption, the commonest case)
- `merge wishlist cart into checkout` — multi; `checkout` may be preexisting
  **or** new

Derived semantics (to confirm):

- **Effective sources = listed sources ∪ {target, if target is a mapped
  group}.** Sugar: an existing target is implicitly a source.
- **ARM rule: absorption iff the target is a mapped group** (listed or not);
  **fresh-target iff the target slug is fresh.** Simpler than split's membership
  test (`extraction iff old ∈ targets`) and matches the colloquial reading of
  "merge X into Y".
- Explicit form stays legal: `merge cart wishlist into cart` ≡
  `merge wishlist into cart` — listing the target as a source is redundant,
  not an error (dedupe into the effective set).
- **Arity gates on the effective set: ≥ 2.** Degenerate `merge a into b` with
  `b` fresh (effective set = {a}) → reject with a pointer: "this is a rename —
  use `/jim:partition rename a b`."
- Per-source structural checks iterate the effective set (source-mapped,
  blueprint-exists); no duplicate listed sources; a target that is an
  unmapped-but-existing directory → collision fail (mirror of split's
  `target-collision`).
- **Anti-invisibility compensation:** because sugar expands the source set
  implicitly, the preflight emits and the gate restates the *effective* source
  set explicitly (e.g. an `ABSORBS cart` row) — the silent expansion is never
  silent at approval time (040 discipline).
- **Confirmed:** degenerate `merge a into b` (b fresh, effective set = 1) is a
  rename in disguise — reject with the pointer. **Confirmed:** the gate restates
  the effective set explicitly; partitioning needs high visibility.

## Expansion: directory mode and multiple roots

Grounded against the substrate (methodology § Readiness, `jimpartition.sh`,
map-methodology § Territory capture, jim's own `BLUEPRINT.md`):

**What exists today.**

1. **Territory is list-shaped everywhere already.** `old_group_territories()`
   harvests *every* backticked path from a group's Territory line; jim's own
   group declares three roots (`skills/`, `agents/`, `tests/`); `aggregate`,
   `coverage`, conformance strays, and the gatherer dispatch all consume path
   lists. Multi-root costs zero script work.
2. **The map surface does not enforce single-root.** The template's Territory
   field is "relative paths" (plural), each validated via `valid-relpath`;
   territory is "data only in this tier." A multi-root write in directory mode
   succeeds today.
3. **Single-root lives in exactly one check:** readiness clean-condition #3
   ("Multi-subtree groups — directory target only: a group whose proposed
   territory does not collapse to a single root directory"), which gates
   *upgrades onto* the rung. Upward moves are earned at assessment time; nothing
   re-verifies the property afterward (target == current → "already there",
   stop).
4. **What the rung actually certifies:** not attribution determinism —
   dir-granular declared-paths (jim itself) is equally deterministic. The rung's
   content is the partition being **physically manifest in the tree** (`ls` ≈
   context map; group owns a subtree).

**The sharpened fork.** *Redefining* the rung to "a set of whole directories"
would collapse it into dir-granular declared-paths — jim's own declared-paths
territory would instantly qualify as directory mode, readiness #3 would lose its
meaning, and the ladder loses its top rung. So true redefinition **dissolves**
the rung rather than extending it. Rejected.

**Split's precedent generalizes instead.** Split's spanning territory file gets
a provisional owner (no coverage gap) + an offered code-split issue routed to
the normal spec→plan→build workflow + no code moves (047 AC 6). Merge's dual:

- The merged group holds N roots as **recorded residue** — the map records the
  truth, the mode stays `directory`, and the merge offers a
  **code-consolidation issue** at merge time (through the spec-018 batch)
  proposing the dir move that would restore single-root. When that spec lands
  via the normal workflow, territory collapses to one root and the residue
  clears.
- **The nag loop closes it.** Post-merge, each absorbed root embeds a retired
  slug (`src/cart/` after `cart` retires). Once `identity-check` parses
  `op=merge` (Seam F, already on the worklist), the 044 name-mismatch sensor
  flags exactly these paths on every health run until consolidated — visible
  pressure, never a veto. Absorption arm nags N−1 roots; fresh-target arm nags
  all N.

**Arm × mode summary.**

| Mode | Merge territory behavior |
|---|---|
| `none` | nothing to do |
| `declared-paths` | union the lists — mechanical; multi-root is already normal here (jim itself); no residue concept; the name-mismatch sensor still nags retired-slug paths, correctly |
| `directory` | union yields N roots = recorded residue; mode unchanged; consolidation issue offered at merge time; sensor nags until a normal code-move spec restores single-root |

**Rejected alternatives.** (a) Redefine the rung — dissolves the ladder
distinction (above). (b) Refuse merge in directory mode until code is
pre-consolidated — inverts the intent→code order; split never demanded
pre-alignment. (c) Auto-downgrade the project to `declared-paths` — a
project-wide penalty for one group's state; doctrine says downward is "a graded
map edit elsewhere," deliberate, never a side effect.

**Lean default (open to challenge):** the consolidation issue is offered only in
`directory` mode — that's the mode with a certified property to restore. In
`declared-paths`, multi-root is normal shape; the retired-slug nag from the
sensor suffices.

## Revision: the sensor is a backstop, not a tracking channel — issue offer is mode-independent

Pressure-tested the lean default above against the shipped mechanics. It was
wrong; **rename's precedent controls.**

**How the nag actually works** (`cmd_identity_check`, methodology § Health):

- Deterministic snapshot, no trend window: for each mapped group G and each
  declared territory path P, emit `MISMATCH` when P whole-token-embeds a
  conflicting identity token — `foreign` (another *current* group's slug) or
  `retired` (an `old=` slug from ledger `op=rename` **and `op=split`** events;
  a split retires `old=` only when it is not among the `new=` list, so an
  extraction's continuing remainder is never flagged). Whole-token matching is
  the false-positive guard (`cart-api` is one token — it does not match `cart`).
- **Three reliability limits:**
  1. **Name-coverage** — it fires only where dir names embed retired slugs. A
     group that owned `src/basket/` under the slug `cart` leaves no token to
     match; the fragmentation is invisible to the sensor.
  2. **Cadence** — health is pull-based by default: an explicit
     `/jim:partition health` run, an accepted post-reconcile conversational
     offer, or the opt-in `auto_health` / `require_health` hooks. No health run,
     no nag.
  3. **Doctrine** — findings are advisory, never a veto, never a standing
     verdict. The nag *recomputes*; it does not *track*.
- **The #71 tell:** the sensor's `retired` arm is explicitly documented as
  catching "the *stalled docs-only rename* of issue #71" — it was built to
  detect an already-filed issue going stale, i.e. as a **backstop behind a
  durable issue**, not as the primary tracking channel. My lean default
  inverted that architecture.

**The controlling precedent — rename AC #9:** rename's code-move fork offers
*move-now* (bounded `rename-tracked` + reference fixes) vs *docs-only*, and
docs-only **files a developer-confirmed code-move issue through `new.sh`** —
territory-mode-independent. Durable tracking lives in the issue; the sensor
catches it stalling. Merge's stale-named absorbed roots are the same residue
class and should route the same way.

**Revised offer rule (replaces the lean default):** offer the consolidation
issue whenever the merge leaves residue —

- `directory` mode: **always** (N ≥ 2 roots break the rung's certified
  property), or
- any mode: **≥ 1 absorbed root embeds a retired source slug** (the
  stale-naming residue rename tracks).

Silent only when neither holds (`declared-paths` + non-slug-named roots):
multi-root is normal shape there (jim's own three-root group) and no stale name
exists — genuinely nothing to track. One issue per merge, covering all residue
roots; developer-confirmed and declinable per spec 018.

**Consolidate-now fork (recommendation: defer).** Rename offers move-now
because one same-name dir move + bounded reference fixes is mechanical. Merge
consolidation is not: it must mint a new home, relocate N trees, decide the
internal layout (flatten vs nest), and fix imports codebase-wide. Recommend v1
keeps split's no-code-moves posture (issue-only), noting rename's fork as a
future enhancement if real merges show the demand. **Signed off:
consolidate-now deferred — v1 is issue-only.**

**Drive-by discoveries for the merge work:**

- `cmd_identity_check`'s *header* comment still says retired slugs come from
  `op=rename` only; the inline comment and code already handle `op=split`.
  Methodology § Health has the same lag ("a retired rename slug"). Both ride
  the Seam F edit that adds `op=merge` — no separate issue needed.
- **`op=merge` grammar implication (feeds the ledger thread):** if the event
  records `old=<effective sources, incl. an absorbed target> new=<target>`,
  the sensor's existing retirement rule — retired = old-tokens ∉ new-tokens —
  extends to merge by adding one `;op=merge;` filter clause, with zero new
  parse logic: rename (old ∉ new trivially), split (remainder exempt), and
  merge (surviving target exempt) all share one rule. Slight lean to this
  grammar over `old= = retired set only` for exactly that uniformity.

## Ledger thread: op=merge event, flooring, and machine consumption

Grounded in `jimledger.sh cmd_vacated_max` and `jimfile.sh cmd_next_id` (read,
not recalled).

**Proposed `op=merge` event shape** (mirrors split's additive-key pattern):

```
partition finished op=merge old=<effective-sources,comma> new=<target>
  moved=<og/onum:ng/nnum>[,...] identity=<mode> frozen=<count>
  outcome=<merged|blocked|declined>
```

- `old=` = the effective source set (including an absorbed target), so the
  uniform retirement rule — retired = old-tokens ∉ new-tokens — covers
  rename/split/merge identically (per the sensor analysis above).
- `moved=` reuses split's exact grammar: repeatable keys, ≤256-byte chunks,
  charset `[a-z0-9-/:,]`, `og` = source group, `ng` = target, onum exactly
  3 digits.
- `immutable` mode emits no `moved=` pairs (nothing moves; retired dirs stay in
  place), `frozen=` counts per 046; the event remains the durable bridge.

**`vacated-max` learns merge — no sibling verb.** The implementation is
op-agnostic after one filter line (`index(";op=split;")` → also accept
`;op=merge;`). The `consider()` charset gate, og-side GROUP match,
inert-on-tamper elements, and floor-only-raises posture reuse byte-for-byte.
The header comment ("owns the op=split event grammar") widens to both ops.

**Flooring scenarios validated:**

- *Target after renumber-append* (`rewrite`/`forward`): moved specs physically
  sit in the target dir → dir-max covers them. `moved=` og-sides are always
  sources, so the target's own floor is untouched — targets never vacate.
- *Retired-source re-mint* (the two-referents case): a later new group reusing
  slug `cart` → `vacated-max cart` reads `op=merge` `moved=` og=cart pairs and
  floors past cart's historical max. `next-id`'s comment already names "the
  retired-group-re-mint case" for split; merge extends the same story.
- *Immutable*: no `moved=` pairs, but retired dirs remain in place → dir-max
  self-covers a re-mint (numbering continues past the frozen specs). Coherent
  without the floor.
- *#79 stays rename's issue*: neither plain merge arm carries a rename
  component (no continuing group's home moves), so merge does not inherit the
  gap. Synergy: the widened filter + uniform retirement rule make #79's
  eventual fix (`op=rename` carrying identity `moved=` pairs) a drop-in.

**Correctness catch — the append seed must honor the vacated floor.** The merge
renumber verb cannot seed from target dir-max alone. Counterexample: `shopping`
had `001–009`, a split moved `006–009` away (dir-max 5, vacated-max 9); a merge
seeded at dir-max would assign an absorbed spec `shopping/006` — re-minting a
vacated id and recreating the two-referents ambiguity 047 closed. **Seed =
`max(dir-max, vacated-max) `** — exactly `next-id` semantics. Whether the verb
takes the seed as a caller-passed argument (orchestrator runs
`jimfile.sh next-id <target>` first; keeps the verb pure and testable) or
composes cross-script is a plan-time detail; the requirement is the floor.

**Security posture (for the future `/jim:sec` pass):** the machine-consumption
expansion is filter-widening only — one more accepted op token over the same
hardened, fail-closed element parse; no new value shapes, no new consumers.
047's marquee control (a tampered ledger element is inert; the floor can only
rise or be ignored) extends unchanged.

**`edges-diff` merge form (Seam F resolved shape):** expected-after =
before-set with every source slug rewritten to the target on the group half,
then consumer==provider rows dropped — the dissolved internals. A pre-merge
graph cannot contain self-edges (the requires face is cross-group by
construction), so post-rewrite self-rows can only be dissolved cross-source
edges; the elision is safe. rc semantics keep the done-condition
(0 = identical-modulo-op).

**Commit choreography (Seam E):** `commit-merge` joins the fixed literal-path
commit set (the `ledger-commit-discipline` blueprint invariant enumerates six
paths today — updating that row rides the build, per normal blueprint cadence);
`move-spec-dir` per absorbed spec; assignment-only — no code commit, per the
consolidate-now deferral.

## Session outcome — disposition of the handoff's twelve open questions

Numbering follows the context handoff §9.

| # | Question | Disposition |
|---|---|---|
| 1 | Merge-signal interpretive rule | **Deferred out of scope** (detector-side); candidate issue offered at wrap |
| 2 | #72 chronic straddle | **Deferred**; stays open as the most merge-shaped future input to 1 |
| 3 | Invariant-id collision | **Shaped**: ids are semantic slugs; detect mechanically; identical-text auto-unifies; differing-text / homonym → interview (a re-key is a knowing, recorded ratchet break) |
| 4 | Edge dissolution vs re-point | **Shaped**: classification mechanical (both endpoints ∈ sources → dissolves); disposition default internalize-unless-surviving-third-party-consumer; confirmable gate rows |
| 5 | Provides-surface name collision | **Shaped**: interview; code-level name clash routes to an issue (partition never moves code) |
| 6 | Collapse-map / renumber-append order | **Decided**: absorption target keeps its numbers; absorbed sources append in CLI argument order; seed = max(dir-max, vacated-max) |
| 7 | Single vs multi-gate | **Decided**: Shape B — interview + single hard gate; split-alignment follow-on filed (`docs/issues/20260722-align-partition-split-flow-to-interview-plus-gate-shape.md`) |
| 8 | Immutable + retired-source coherence | **Coherent on both arms**: retired dirs stay in place; dir-max self-covers a re-mint |
| 9 | AC-9 composition mechanics | **Does not arise** on either plain arm (no continuing group's home moves) |
| 10 | Machine-consumed ledger values | **Resolved**: filter-widening only; 047's hardened fail-closed parse reused byte-for-byte |
| 11 | #79 rename re-mint floor | **Stays rename's issue**; merge's widened machinery makes the fix drop-in later |
| 12 | Verb grammar | **Decided**: sugar — effective sources = listed ∪ existing target; ARM by target-mapped; degenerate 1→1 rejected toward rename; gate restates the effective set |

Session-local additions beyond the handoff's list: territory multi-root =
recorded residue with a mode-independent consolidation-issue offer (rename AC #9
precedent; sensor is backstop, not tracker); consolidate-now deferred (signed
off); `op=merge` event grammar with the uniform retirement rule.

**Right-sized for spec/plan time, not brainstormed:** merge-preflight CHECK-row
set (Seam A cardinality), gatherer collision-case dispatch prose (Seam C),
blueprint `--merge` doc-fusion arm steps (Seam D), interview step ordering, and
`split_repo` fixture reuse for multi-group tests.
