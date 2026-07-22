# Partition Merge — Brainstorm Context Handoff

- **Topic:** merging jim spec groups — the `/jim:partition merge` verb (N spec groups → 1).
- **Date assembled:** 2026-07-22
- **Purpose:** a thorough, decision-neutral briefing for a fresh session that will
  brainstorm / scope **partition merge**. It captures the development story arc,
  the doctrine merge must live within, the split feature that is merge's mirror,
  the subsystems merge inherits, the detector that already exists, the concrete
  code seams a merge arm would touch, and every open question on record. It does
  **not** design merge or recommend an approach — decision-making is for the new
  session.
- **How to use:** read §1 for orientation, then §3 (doctrine) and §4 (split as the
  template) before anything else. §6 (the three deferred judgment problems) and §9
  (open questions) are the actual design surface. §11 is a jump-to-source index —
  every mechanic below is cited `file:line` against the repo at HEAD of
  `feat/blueprint`.

> **Status in one line.** The merge *detector* is shipped (spec 044 emits a
> `Merge signal:` line today). The merge *mechanism* is **not built** — it exists
> only as deliberate forward-compat notes across specs 043, 046, and 047, which
> designed their change-set, identity, ledger, and id shapes so "merge is a new
> arm, not a new engine." Merge is the single remaining unbuilt verb in the
> ripple-engine family.

---

## 1. Orientation — what merge is and where it sits

**Merge** collapses two or more spec groups into one: `/jim:partition merge <s1> <s2>...
into <target>` (grammar is unbuilt/undecided — see §9). It is the **N→1 dual of
`split`** (1→N, spec 047, shipped 2026-07-21) and the last member of a verb family
built on one shared "classified ripple engine."

The `/jim:partition` verb surface **today** (`README.md:47`, `skills/partition/SKILL.md:17`):

| Verb | What it does | Spec |
|---|---|---|
| bare (`greenfield` / `repartition`) | migrate a whole project onto the blueprint partition doctrine | 038 |
| `path` / `directory` | territory-target readiness assessment (not a migration) | 038 |
| `rename <old> <new>` | migrate one group's identity across all artifacts (1→1) | 043 |
| `split <old> into <new>...` | fission one group into N children (1→N) | 047 |
| `health` | read-only advisory split/**merge**/name-mismatch read of the reconcile trend | 044 |
| **`merge` (N→1)** | **does not exist** | **the topic** |

**The composition model** (fixed in brainstorm `docs/brainstorms/20260711-partition-migrate-capabilities.md:57-65`):

> Split/merge = *scoped repartition* (the existing repartition machinery —
> substrate, gatherer fan-out, interview, hard gate, retire arm, reconcile-to-clean
> — restricted to the affected territory) **+ the ripple engine** …
> - split X ≈ repartition scoped to X's territory → N groups + retire X
> - **merge X,Y ≈ repartition scoped to X∪Y → 1 group + retire both**
> - rename = ripple engine alone

**The doctrinal bias is anti-merge-by-default.** `skills/partition/references/partition-methodology.md:27-28`:

> Err toward fewer, coarser groups at first — **a group is cheap to split later,
> expensive to un-merge once blueprints calcify it.**

This is the strongest normative statement in the codebase about merge direction:
the doctrine deliberately biases *away* from over-partitioning precisely because
un-merging destroys accreted blueprint/contract/invariant-id/spec-history
investment. That accretion cost is *why* merge is the harder, later mechanism and
*why* its detector must clear a high confidence bar.

---

## 2. The story arc (029 → 047)

Merge sits at the end of a deliberate, ~19-spec lineage that turned "spec group"
from a filing accident into a load-bearing, verifiable context boundary. The
authoritative one-paragraph-per-spec narrative lives in `ARCHITECTURE.md:250-274`.

| Spec | Name | What it added (merge-relevant thread) |
|---|---|---|
| 029 | Group blueprint (`000-blueprint`) | The group-tier living spec: Responsibility / Provides / Requires / Structure / Invariants. |
| 030 | Blueprint update | Targeted diff-driven update (`--from-review`, `--since <ref>`). |
| 031 | Blueprint update guard | Violation fork (fix-code vs fold-intent) + criticality-graded autonomy (Step 4a). |
| 032 | Blueprint regen cadence | `last_full_generate` watermark; drift signal. |
| 033 | Context map (`BLUEPRINT.md`) | **"Group" becomes a designed artifact.** The project-tier partition; `/jim:spec` assignment advisor; `group_axis`/`group_territory`. Merge's whole premise (two designed contexts) starts here. |
| 034 | Contract graph + blast radius | Reconcile pass joins Requires↔Provides into a derived graph; six finding classes; blast radius. The breaking-change class powers 044's merge sensor. |
| 035–037 | Verify engine | `/jim:verify <group>` (invariants), fold-back loop, `--contracts` mode (edges grounded in code). |
| 038 | **Partition migration** (`/jim:partition`) | The remedy: extract → propose → hard gate → materialize via blueprint surface → reconcile-to-clean. `jimpartition.sh`, the read-only `gatherer`, `--retire`. |
| 039 | Graph health | Reconcile measures graph *shape* (density, cycles, fan-in, coverage). **Measurement-only — explicitly excludes split/merge interpretation.** |
| 040 | Gate presentation | Hardens every hard gate against invisible-content approval. Any new gate (merge) must adopt it. |
| 041 | Verify retirement | `/jim:verify --retirement`: signal-only sweep flagging stale invariants/requires/dead-surface. |
| 042 | Plan blast radius | `/jim:plan` Step 8a reads the contract graph and names dependents at plan time. |
| 043 | **Partition rename** (1→1) | **The pivot toward split/merge.** Introduces the *classified ripple engine* the future split/merge verbs reuse; the `(occurrence, classification, target)` change-set keying; script-owned git primitives (no skill gets a git grant); the `op=rename` ledger bridge. |
| 044 | **Partition health sensors** | `/jim:partition health` — the split/**merge** detector. Four signal classes; threshold knobs; extends the reconcile counter contract to 15 keys. |
| 045 | Reconcile face counters | Moves the last four reconcile counters onto `jimverify.sh faces-aggregate` (face-size counters only — **not** the id-floor). |
| 046 | **Spec-migration preference** | `spec_migration` = `rewrite`/`forward`/`immutable`. Resolves the freeze-history contradiction; **explicitly built to unblock split/merge design** (issue #68). |
| 047 | **Partition split** (1→N) | The shipped mirror of merge. Five deterministic verbs, the `--split` doc-fission arm, the id-floor (AC 11), the `(sources, targets, assignment)` engine, and the merge forward-compat notes. |

**Where merge sits:** it is the N→1 dual of 047's split, on the same engine,
using the same identity doctrine (046), the same id-floor (047), the same gatherer
(038/047), the same gate-presentation rule (040), and pointed at by the same
detector (044). Everything below expands these.

---

## 3. Core vocabulary & doctrine merge operates within

Precise definitions (canonical one-liners quoted where they exist). Sources:
foundations briefing over specs 029–042, `ARCHITECTURE.md:250-274`, `BLUEPRINT.md`,
and the blueprint/map templates.

- **Group (spec group).** The unit of partition; physically a directory under
  `docs/specs/<group>/`. **Identity is path-derived** — no deterministic script
  reads a numbered spec's `group:` frontmatter or a `Spec: <group>/NNN` trailer;
  membership = which directory the spec sits in (`ARCHITECTURE.md:272`;
  `docs/brainstorms/20260720-spec-identity-on-group-move.md:18-25`). This single
  fact de-fuses merge's identity problem into an *archive-coherence* concern, not a
  functional break.
- **Partition.** The declared division of a project into groups. `BLUEPRINT.md` is
  "the sole authority for the partition" (`033/spec.md:78`).
- **The two blueprint tiers** (the word "blueprint" names both):
  - **Project-tier `BLUEPRINT.md`** = the *context map*: "the declared partition of
    this project into spec groups, each a deliberate context boundary"
    (`map-template.md:9-12`). Sections: header (`Axis`/`Territory`), `## Context Map`
    (`| Group | Role | Purpose | Relations |`), `## Groups` (per-group Purpose / Role
    / Boundary rationale / Relations / Territory / Blueprint pointer), and the derived
    `## Contract Graph`.
  - **Group-tier `000-blueprint/spec.md`** = "a group's living, present-tense
    specification" (`029/spec.md:14-15`), one per group at a reserved slot sorting
    ahead of `001`. Five sections: Responsibility, Provides, Requires, Structure,
    Invariants (`| Id | Invariant | Criticality | Check |`).
- **Faces (the provides/requires surface).** Each group blueprint declares a
  **Provides** face (`` `{surface}` — {guarantee} ``) and a **Requires** face
  (`` `{other-group}.{surface}` — {guarantee relied on} ``). The dotted
  `{other-group}.{surface}` key is load-bearing: **the group half keys the graph
  join; the surface half tracks code.** This split is what lets rename re-point only
  the group half (the ratchet), and what merge collapses (cross-group `X.surface` →
  internal).
- **Contract graph.** The *derived* cross-group dependency graph — "the join, not a
  copy" of Requires against Provides, written into `BLUEPRINT.md` as
  `| Consumer | Relies on | Provider |`. Carries **no verdicts**
  (`034/spec.md:69-76`). Six finding classes: boundary leak, breaking change, dead
  surface, unresolved require (incl. partition gap), undeclared relation, stale
  relation (`034/spec.md:83-107`).
- **Territory.** The group↔code binding — which source paths a group owns. Three
  modes on a strictness ladder: `none` → `declared-paths` → `directory`
  (`group_territory` config). "A strictness dial, not a goodness dial"
  (`038/plan.md:41-42`). The attribution mechanism for partition-gap detection.
- **Reconcile pass.** Re-derives the contract graph and classifies mismatches.
  Fires on `--reconcile` and on every blueprint-surface write. Records a
  `blueprint finished op=reconcile` ledger event carrying **15 integer counters**
  (v3 contract — see Appendix B).
- **Blast radius.** At a Provides weakening/removal, names every dependent consumer
  group. **Informational, never a veto** (`034/spec.md:129-133`).
- **The ledger.** jim's "trusted, content-free metrics channel" (`jimledger.sh`).
  Every stage records `started`/`finished` events carrying **integer counters only
  — never a path, name, or content value**. The `op=rename`/`op=split` events are
  the durable old→new identity bridge (never a drop+add).

### The 10 cross-cutting doctrine invariants any merge design must honor

From the foundations briefing (`ARCHITECTURE.md` + specs 033/034/038/040/043/046):

1. **Single-writer authority.** The map and every blueprint are written *only*
   through the `/jim:blueprint` surface; `/jim:partition` never writes them directly
   (`033` AC#3; `038` AC#7; `034` AC#2).
2. **Hard human gate before materialization.** Nothing is written before explicit
   approval; the verb gate approves the operation, blueprint's own prompt confirms
   each write — "a second, cheap confirmation by design" (`038/plan.md:181-183`).
3. **Freeze-history, reconciled by 046.** Numbered spec *directories* move (identity
   is path-derived) but *bodies* freeze per the `spec_migration` preference; the
   ledger `op=<verb>` event is the durable bridge, never drop+add.
4. **Present-tense / current-state only.** No artifact records an invariant the code
   currently violates; wanted-but-violated rules become tracked issues (`038` AC#12).
5. **No standing verdict.** Durable record = materialized artifacts + filed issues +
   counters-only ledger events; no separate report artifact (`038` AC#16).
6. **Content is data, never instruction; secrets redacted.** Carried end-to-end;
   classification is mechanical-first with a *read-only* gatherer fan-out (a
   capability boundary, not discipline).
7. **No skill gains a git grant.** Move/commit mechanics live in script-owned
   `jimledger.sh` git primitives; each verb has a fixed explicit-stage commit
   choreography.
8. **Identifier ratchet.** Invariant ids and provides-surface names stay
   byte-identical across a move (ids are stable verification keys; surface names
   track code, not group names).
9. **Misalignment-as-issues.** Every surfaced misalignment is offered through the
   spec-018 end-of-run candidate batch; declining leaves no hidden state.
10. **Reconcile + graph-health as the done-condition.** A clean reconcile is never
    presented alone as evidence the partition is good.

---

## 4. Split (spec 047): merge's mirror and closest template

Split is the single richest source of merge material — its authors designed it so
merge slots in as a new arm. Everything here is a template merge would invert.

### 4.1 What split does

`/jim:partition split <old> into <new>...` — a peer verb taking 2+ target slugs
after the literal `into`. **Two arms** (`047/spec.md:60-67`, methodology `:395-401`):

- **Extraction** — `<old>` **is** among the targets. The remainder continues under
  its own identity, directory, history, and numbering "for free"; only extracted
  children are fresh. A `target == <old>` is **collision-exempt** in preflight.
- **Symmetric** — `<old>` is **not** among the targets. The source group is fully
  **retired**; all children are fresh.

Both arms are in scope (not extraction-only) — "the symmetric case is *just as
valid*" (`docs/brainstorms/20260716-partition-split.md:110-118`).

### 4.2 The change-set engine — `(sources, targets, assignment)`

The load-bearing forward-compat abstraction. It descends from rename (spec 043),
which keyed its change-set `(occurrence, classification, target)` with a degenerate
target column (all identical). Split generalized it to `(sources, targets,
assignment)` so the three verbs are one engine:

| Verb | sources | targets | assignment |
|---|---|---|---|
| rename (1→1) | `{old}` | `{new}` | trivial (one global old→new) |
| split (1→N) | `{old}` | N child slugs | per-occupant → child owner |
| **merge (N→1)** | **N group slugs** | **`{target}`** | **collapse-map (all sources → the one target; the hard part is the id remap + collisions)** |

Verbatim (`skills/partition/references/partition-methodology.md:544-550`, "Merge
duality"):

> The change-set shapes stay `(sources, targets, assignment)`-parameterized so
> merge is a future *arm*, not a new engine: split renumbers fresh children ↔ merge
> renumber-appends absorbed sources (id collision dissolves — never two `001`s to
> reconcile); split reveals internal→cross-group edges ↔ merge collapses
> cross-group→internal and re-points third-party edges; one invariant spanning N
> children ↔ N invariants colliding in one group. Merge's three judgment problems
> stay deferred to its own spec.

### 4.3 Split mechanics — the shipped catalog (each is a merge template)

Built on the 043/046 ripple engine: five deterministic verbs + one blueprint arm +
the gatherer's third role.

- **`split-preflight <map> <specs-dir> <old> <new>...`** (`jimpartition.sh:1015`) —
  structural gate. Emits `ARM\t<extraction|symmetric>`, per-target `CHECK` rows
  (map-exists, old-mapped, blueprint-exists, targets-arity ≥2/no-dups,
  `target-slug-valid:<t>`, `target-collision:<t>` — **skipped when `t==old`**),
  `TERRITORY-IDENTITY`, `DIRT`. rc 0 clean / 1 structural fail / 2 usage.
- **`renumber-map <old> <targets-csv> <assign-file>`** (`jimpartition.sh:1143`) —
  the deterministic id remap, "no LLM arithmetic — the 045 doctrine." Continuing
  child (child==old) keeps numbers; each fresh child densifies its arrivals to
  `001..N` by ascending source id. Emits `MAP\t<old>/<src>\t<child>/<new>`.
- **`rewrite-identity <old> <new> <file>...`** (`jimpartition.sh:1349`, spec 046) —
  **the ONE mutating verb.** In-place whole-token identity rewrite (frontmatter
  `group:`, dotted-key group-halves, typed `group/NNN` refs); free prose left to the
  gatherer. Clears a full containment guard over all targets *before any edit*.
  Location-only output (`REWROTE\t<file>\t<line>\t<kind>`).
- **`rewrite-refs <remap-file> <file>...`** (`jimpartition.sh:1485`, spec 047) —
  remap-keyed `group/NNN` rewriting. **The remap table IS the whitelist** — a ref to
  an unmoved spec is unrewritable by construction.
- **`edges-diff <before> <after> <old> <new>`** (`jimpartition.sh:1278`) — post-op
  graph check via the old==new identity trick (pure multiset diff). rc 0 =
  identical-modulo-op (the done-condition).
- Git primitives in `jimledger.sh` (script-owned, no skill grant):
  `move-spec-dir` (cross-parent `git mv`), `vacated-max` (see §5.3), `commit-split`
  (docs), `commit-map`.
- **Blueprint `--split` arm** (`skills/blueprint/references/migrate-arms.md:29-58`) —
  doc-fission: fission the map row+section into N, edit remainder in place
  (extraction) or mint all fresh (symmetric), retire the symmetric source **without
  the standalone `--retire` prompt** (the split gate authorized it), rewrite the
  Contract Graph, defer commits, return the touched-file list.
- **The gatherer's split-dispatch role** (§8.3) — one read-only dispatch per proposed
  child, returning assignment evidence + spanning-case disambiguation.

### 4.4 The single hard gate

Split is single-gate: the whole change-set is presented once (per the spec-040
presentation rule), and a decline materializes nothing (`047/spec.md:141-147`). The
human sees, in one turn's final message: assignment rows (rangeable, e.g.
`006–009 → checkout/001–004`), revealed edges (each confirmable), spanning rows, the
spec remap, config rows, a REFERENCES block, secret-scrubbed old→new artifact diffs
(under `rewrite`), and — on the symmetric arm — an explicit `RETIRES <old>` row.
Approval is all-or-nothing.

> **Gate note for merge.** The migrate-capabilities brainstorm predicted split/merge
> "change the partition itself: they likely need additional interview + analysis …
> so a single gate probably doesn't hold for them"
> (`20260711:50-54`). Split shipped single-gate anyway. Whether merge — which
> collapses graph structure and collides identities — can also stay single-gate is
> **untested and open** (see §9).

### 4.5 The merge duality (every verbatim forward-compat note)

Split's authors reasoned about merge in four consistent places. Reproduced so the
new session need not re-derive them.

**Spec 047 Insight 7 — "Merge forward-compat (the duality, as notes)"** (`047/spec.md:346-361`):

> - **Surfaced as:** design the change-set, edge derivation, and ledger shapes as
>   `(sources, targets, assignment)` so merge is a new arm, not a new engine. The
>   duality: split renumbers fresh children ↔ merge renumber-appends absorbed sources
>   (so id collision dissolves — never two `001`s to reconcile); split reveals
>   internal→cross-group edges ↔ merge collapses cross-group→internal and re-points
>   third-party edges; one invariant spanning N children ↔ N invariants colliding in
>   one group.
> - **Deflection reason:** Razor — building merge now is unproven need; the notes are
>   cheap and the shapes are being designed anyway.
> - **Routing hint:** Architect to keep the shapes parameterizable; merge's three
>   judgment problems stay deferred to its own spec.

**Spec 047 Out of Scope — "Merge mechanics"** (`047/spec.md:231-235`):

> The `merge` verb, collapse-map assignment, and its three named judgment problems
> (invariant-id collision, edge dissolution-vs-re-point, provides-surface name
> collision) are their own future spec. This spec only keeps the change-set shapes
> N→1-compatible.

**Brainstorm duality table** (`docs/brainstorms/20260716-partition-split.md:208-213`):

| Axis | Split (1→N) | Merge (N→1) |
|---|---|---|
| Numbering | renumber fresh children | renumber-append absorbed sources |
| Edges | reveal internal → cross-group | collapse cross-group → internal, re-point 3rd-party |
| Spanning thing | one invariant spans N children | N invariants collide into one group |

**Spec 043 Insight 2** (the origin of the keying, `043/spec.md:247-261`) and its
Out-of-Scope entries (`043/spec.md:207-209`, `043/plan.md:418-420`) confirm the
reuse contract: "`split` / `merge` verbs — future specs consuming the ripple-engine
contract."

---

## 5. The three reusable subsystems merge inherits

### 5.1 The ripple engine (spec 043 rename)

The reusable spine: enumerate and classify every occurrence of a group identity,
then re-point them in one choreographed materialization. Its mechanical parts
(`docs/brainstorms/20260720-spec-identity-on-group-move.md:107-112`): "`occurrences`
enumeration, identity/code-surface/historical classification, `rename-tracked`
git-mv, three-commit choreography, `op=` ledger, `edges-diff`, the zero-unclassified
sweep."

Three read-only, stdout-only rename verbs (all reusable by merge, run per source):
`rename-preflight`, `occurrences` (`HIT\t<file>\t<line>\t<kind>`, **content never
emitted**), `edges-diff`. The **Bash-vs-Prompt split** (`043/spec.md:264-276`):
enumeration is deterministic-script territory; classification (identity vs
code-surface vs historical) is judgment — mechanical-first + a read-only gatherer
for the residue, fail-closed.

### 5.2 Identity-on-move doctrine (spec 046) — THE central question for merge

**The question** (`20260720:9-16`): "What does a spec's recorded group identity mean
when the group's identity changes — an immutable historical fact, or a live pointer
that should track the move? … unavoidable for split/merge (the source group ceases
to exist, so a frozen `group: cart` points at nothing)." Because identity is
path-derived (§3), this is an **archive-coherence / human-readability** problem, not
a functional break.

**The three modes** — project-level config `spec_migration` (default `rewrite`):

| Mode | Dir moves? | Body identity | Alias | Merge behavior |
|---|---|---|---|---|
| `rewrite` (default) | yes | rewritten (label + refs; substance byte-frozen) | ledger `op=` | **re-homes** history into the merged group; **forces** the id-collision problem (physical collapse) |
| `forward` | yes | frozen | **yes** — bridges frozen body ↔ new home | re-homes via the alias; also forces collision |
| `immutable` | **no** | frozen | ledger only | **sidesteps** id-collision by leaving retired sources' dirs in place; only the living merged group's map/blueprint/future-filing change. "The split/merge-native mode." |

**The reconciled doctrine** (`046` AC 2, `spec.md:63-68`; methodology `:357-365`):
the spec **directory** is the live group binding; a numbered spec's **body**
identity is governed by the preference; the ledger `op=` event is the durable
old→new bridge **in every mode**; and the `000-blueprint` re-identifies in every
mode. History is never revised.

**How each mode applies to MERGE — 046 AC 8, verbatim** (`046/spec.md:90-95`):

> The recorded doctrine states how each mode applies to split and merge — that
> `immutable` sidesteps split's per-child assignment and merge's id-collision by
> leaving continuing-or-retired sources' histories in place, while `rewrite`/`forward`
> re-home histories into the new partition — so the deferred split/merge specs
> implement against a settled foundation. This states behavior, not mechanics; the
> split/merge verbs remain out of scope.

**Composition rule — 046 AC 9** (`spec.md:96-99`, methodology `:379-384`): `immutable`
is coherent wherever **no continuing group's home directory moves**; an operation
that *also* relocates a continuing group (e.g. an absorbing merge where one source's
dir becomes the merged home) "follows rename's rules for that component." This
settles the *behavior* but leaves the *mechanics* to merge's own spec (AC 8 is
explicitly "behavior, not mechanics").

The `op=` event gains additive keys `identity=<mode>` and `frozen=<count>` (046
Insight 5), and split extended it to `moved=<og/onum:ng/nnum>[,...]` — merge would
carry an analogous per-spec remap.

### 5.3 Face counters (spec 045) + the id-floor (spec 047 AC 11 — corrected)

> **Attribution correction (carry this forward).** The id-floor / vacated-id
> mechanism is **spec 047 (split), AC 11 — not spec 045.** Spec 045 is *only* the
> deterministic face-size counters (a refactor moving LLM arithmetic into
> `jimverify.sh faces-aggregate`). A separate minor quirk: the `jimpartition.sh:1311`
> section banner reads "rewrite-identity (spec 046)" but the `rewrite-refs` verb
> inside that section is spec 047.

**Face counters (spec 045).** Four reconcile counters computed by
`jimverify.sh faces-aggregate`: `faces` (total provides entries), `faces_max` (max
any single group carries), `faces_max_group` (the group(s) at the max — sorted,
comma-joined, slug-validated, ≤256 bytes), `fanin_group`. Display-only; never
consumed by a threshold predicate. **Merge relevance:** merge collapses N provides
faces into one, so the merged group likely becomes the new `faces_max_group` — which
the health sensor reads as a *split* smell (§7). The counters are thus the feedback
loop that would flag a *bad* merge (over-fattening one group), and a good merge's
post-merge reconcile must land clean with the collapsed graph.

**The id-floor (spec 047 AC 11).** The mechanism most load-bearing for merge's
id-collision. Two parts:

- **`jimledger.sh vacated-max <specs-dir> <group>`** (`skills/review/scripts/jimledger.sh:509-550`)
  — scans the specs-root ledger for `op=split` events and prints the highest OLD
  number any split ever vacated *from* `<group>`, so `next-id` can floor past it.
  Fail-closed: gated on `;op=split;`, every `moved=` pair charset-gated to
  `og/onum:ng/nnum` (onum exactly 3 digits); a failing element is inert, "the floor
  only ever raises."
- **`jimfile.sh next-id` floor** (`skills/file/scripts/jimfile.sh:289-357`) — computes
  directory-max, then `max(dir-max, vacated-max) + 1`; the "**monotonic merge**"
  (047 plan task 4: "dir-max wins when higher"); a `>999` result refuses (never a
  4-digit id).

**Why this matters when groups collapse:** the merge duality says merge
"renumber-appends absorbed sources (id collision dissolves — never two `001`s to
reconcile)." When `cart/001..006` + `wishlist/001..004` collapse into `shopping/`,
absorbed specs are **renumber-appended** (append after the tail) rather than
colliding on `001`. Security note (`047/spec.md:287-290`): the `moved=`/`vacated-max`
mechanism makes ledger values **machine-consumed** (not display-only) for the first
time — flagged for re-examination against the 044 display-data-only precedent.
Merge extends this reliance.

---

## 6. Merge's three named judgment problems (deferred by design)

Named identically in four places (`047/spec.md:231-234`, `:346-361`; brainstorm
`20260716:218-220`, `:334-335`; methodology `:550`). These are the genuinely net-new
design surface merge inherits — "a known list, not a surprise":

1. **Invariant-id collision.** Invariant ids ratchet permanently and are never
   renamed (the identifier ratchet, invariant #8). When N groups' blueprints merge,
   N invariants can collide on one id in one group. The dual of split's "one invariant
   spanning N children." Unsettled: how to resolve the collision without breaking the
   stable-verification-key guarantee.
2. **Edge dissolution-vs-re-point.** Merge collapses cross-group edges to internal
   (they *dissolve* — the consumer and provider now live in the same group) and must
   *re-point* third-party edges (edges from/to groups outside the merge) at the merged
   group. Distinguishing which edges dissolve vs re-point is the judgment.
3. **Provides-surface name collision.** Two sources may export identically-named
   surfaces into one merged Provides face. Unsettled: rename, namespace, or unify.

Plus the mechanical companion:

4. **Collapse-map assignment / renumber-append order.** Named "collapse-map
   assignment" (`047/spec.md:231`). Largely mechanical (all sources → one target),
   but the **id remap** — the renumber-append order across sources, and which source
   (if any) continues its numbering — is unspecified. This is the sharpest code seam
   (§8.5, Seam B).

---

## 7. The detector side — "when to merge?"

**Key finding:** the merge *detector* already shipped (spec 044), but it recommends
*split* in every worked example, and **no spec anywhere defines the
sensor-reading → "merge" interpretive rule.** Defining "what combination of sensors
says *collapse these two groups*" is an open detector-side design question the merge
work inherits.

### 7.1 The health sensors (spec 044)

`/jim:partition health` (read-only, advisory) reads the accumulated reconcile trend
+ map and closes with "a reasoned split/merge or rename-follow-up proposal." Four
signal classes (AC #2, `044/spec.md:59-65`; methodology `:571-586`):

- **(a) Breaking churn** — recurring cross-group `breaking>0` findings across recent
  reconciles. "Chronic churn at a boundary is a merge/split smell; a single spike is
  not."
- **(b) Graph-shape trends** — edge density (`edges`/`groups`), `cycles`, `fanin`
  concentration (the god-group / blast-radius signal, attributed via `fanin_group`),
  `uncovered` coverage.
- **(c) Face growth** — a group's provides surface widening across reconciles (read
  from `faces`/`faces_max`, `faces_max_group` naming the fattening group). "A
  steadily-growing lead face is a split candidate."
- **(d) Name mismatch** — the `identity-check` snapshot (a group's territory path
  embedding another current group's slug, or a retired rename slug).

**Trend source:** `jimledger.sh reconcile-series` → `jimpartition.sh health-eval`.
**Threshold knobs** (default `"0"` = disabled): `health_threshold_cycles` / `_fanin`
/ `_uncovered` / `_faces_max` (latest ≥ N) and `_breaking_runs` (trailing consecutive
reconciles with breaking>0 ≥ N). **Minimum trend window = 3 events**; fewer reports
"insufficient history (N events)" explicitly. **Trigger model:** default = one
conversational offer; `auto_health` = unattended; `require_health` = holds the
reconcile-carrying run until the check completes. **Findings are always advisory —
never a veto.**

### 7.2 The "Merge signal" interpretive gap

The one merge-specific artifact in the codebase — the 044 UI mockup
(`044/spec.md:138-159`) — ends its Read block with:

> platform is drifting toward god-group shape … **Split signal:** carve the
> messaging surface out of platform. **Merge signal: none.**

The `Merge signal:` line is a first-class output slot, but **no spec text defines the
pattern of the four sensors that constitutes a *merge* recommendation** (as opposed
to split). The sensors are symmetric in name ("split/merge smell") but the
interpretive rule that turns readings into "merge these two groups" is left entirely
to the inline LLM's judgment. This is the detector-side gap merge inherits.

### 7.3 The measurement/interpretation boundary (039 ↔ 044)

**Doctrine, not incidental** (`039/spec.md:105-109`): spec 039 *measures* the graph
(density, cycles, fan-in, coverage) and explicitly excludes "**Split/merge proposals
or any interpretation** of the measurements — the partition-health sensors (issue
#42) consume this substrate." Preserve this boundary: a merge feature *interprets*;
it does not add measurements to the reconcile pass. Spec 042 (plan-time blast radius)
is the plan-time consumer of the same graph — read-only, makes no split/merge
judgment.

### 7.4 What "one vs many groups" means (the conceptual basis for merging)

From `docs/brainstorms/20260703-context-aware-spec-group-definition.md`: health/
evolution is one of four lifecycle moments (`:36-44`) — "detecting that an existing
partition has gone bad (low cohesion, high inter-group coupling) and proposing
splits/merges." The intended doctrine is "intelligence as sensor, not architect"
(Approach C, `:57-61`). Distinguishing signal: **high fan-in on a platform group is
healthy** ("what a platform group is *for*"); high fan-in on a feature group is a
smell (`partition-methodology.md:35-39`). The failure mode merge addresses: fat/chatty
faces where "every feature crosses boundaries … blast radius reports 'everything
affects everything'" and "contracts + blueprint content **calcify the bad
partition**" (`:292-300`). Two groups that are chronically leaky / co-changing across
their boundary are the merge candidate — the inverse of the split condition.

### 7.5 The one open detector-side issue on the merge path

**Issue #72 — "Record and sense chronic domain↔domain straddle flags"** (OPEN, low
priority, `docs/issues/20260712-record-and-sense-chronic-domain-domain-straddle-flags.md`).
The origin issue (#42) listed chronic domain↔domain straddle as its **first** merge
signal, but 044 scoped it out. It needs (a) a recording surface in `/jim:spec`'s
assignment advisor to log straddle flags durably as content-free traces, and (b) a
trend sensor reading them. This is arguably the *most* merge-shaped signal (two
specific groups chronically straddling each other → collapse candidate) and it is the
only detector-side gap still open. (Distinct from the code-level "straddle count"
metric, which is separately deferred behind spec 038's extractor fork.)

---

## 8. The code/script substrate — verb catalog, security, and seams

Grounded in `skills/partition/scripts/jimpartition.sh` (76 KB), `agents/gatherer.md`,
`skills/partition/references/partition-methodology.md`, `skills/partition/SKILL.md`,
and `skills/blueprint/references/migrate-arms.md` + `reconcile-methodology.md`.

### 8.1 `jimpartition.sh` verb catalog

Dispatch table `main()` at `:1754-1772` (13 subcommands). `set -uo pipefail`,
`export LC_ALL=C`. Two headline exit codes (`:32-34`): `0` success (counts may be
>0 — a report, not an error), `2` malformed invocation / malformed caller input /
not a git tree. Several verbs additionally use rc `1` as a non-fatal
divergent/structural-fail signal.

| Verb | Spec | Purpose | rc notes |
|---|---|---|---|
| `coverage` | 038/039 | files under no proposed territory, by dir + TOTAL | 2 on bad input |
| `ingest` | 038 | validate one extractor's untrusted raw edges → clean deduped set + hygiene counts (the trust choke point) | 2 usage |
| `scan` | 038 | native import scan over `git ls-files` (Go/Py/JS-TS/Rust/Elixir) | 2 not-a-git-tree |
| `aggregate` | 038/039 | file EDGEs × territories → group edges, straddles, unassigned | 2 bad input |
| `rename-preflight` | 043 | 1→1 structural preflight | 0/1/2 |
| `occurrences` | 043 | whole-slug-token hits (content never emitted) | 2 bad slug |
| `edges-diff` | 043 | pre/post edge-set compare modulo op | 0 identical / 1 divergent / 2 |
| `split-preflight` | 047 | 1→N preflight; names ARM | 0/1/2 |
| `renumber-map` | 047 | deterministic split id remap | 0/1/2 |
| `rewrite-identity` | 046 | **the ONE mutating verb**; in-place identity rewrite | 0/2 |
| `rewrite-refs` | 047 | remap-keyed `group/NNN` rewrite (remap = whitelist) | 0/2 |
| `health-eval` | 044 | threshold eval over reconcile series | 0/1/2 |
| `identity-check` | 044 | name-mismatch sensor (foreign/retired) | 0/2 |

### 8.2 Security posture in code (merge inherits all of it)

- **`san()` / `san_field`** — control-strip + 512-cap on every emitted field (awk
  `san()` at four emit sites; bash `san_field` at `:845` for map/git-derived
  untrusted fields). "All output is TAB-separated and field-sanitized."
- **Read-only / stdout-only substrate.** Header `:6-11`: partition judgment, the
  interview, invariant authoring, and every map/blueprint write live in the *skill*,
  not the script. Rename/split/health verbs "write nothing and run no operator
  command."
- **The one mutating verb is isolated.** `rewrite-identity` clears a **full
  containment guard over all targets before any edit** (`valid_relpath` → `realpath`
  under worktree top → `git ls-files` tracked → malformed-frontmatter pre-scan); any
  failure aborts with a location-only reason, zero files touched. awk `-v` literals
  are safe because `old`/`new` are `valid_slug`-gated.
- **Never source/eval untrusted data.** Config is read via `bash "$JIMCONF" get` and
  **integer-compared, never executed** (`health-eval`). The extractor-registry family
  name "appears nowhere in this script by design" — the model runs operator commands
  via Bash (surfacing the permission prompt), never the script.
- **`rewrite-refs` / `rewrite-identity` whitelist-by-construction.** rewrite-refs
  touches only refs whose `group/NNN` appears in the approved remap; `identity-check`
  retired-slug parse is whitelisted and slug-gated so a hand-edited ledger cannot
  inject a non-slug token.

Split's security review (`047/security.md`, 0 Critical · 5 Notable · 6 Advisory, all
resolved) enumerated the boundaries merge inherits: move-spec-dir containment;
`vacated-max`/`next-id` fail-closed machine-consumption (the marquee control:
ledger-tampering → next-id floor); gate/change-set target-set re-validation (the
`--targets`/approved-set is the whitelist); archive-wide rewrite blast radius +
remap-as-whitelist; bounded/charset-designed `moved=` event values; gatherer
read-only & evidence-only; `RETIRES <old>` gate row compensating the skipped retire
prompt; revert-and-rerun (no mid-run resume). One merge-adjacent follow-on is already
filed: **issue #79** (`op=rename` carries no id remap, so re-minting a rename-retired
group name restarts at 001 — the same two-referents ambiguity 047 closed for split,
still open on the rename path).

### 8.3 The gatherer agent (directly reusable)

`agents/gatherer.md` — read-only per-group evidence gatherer, `tools: [Read, Glob,
Grep]`, no file-mutating/command-running/subagent tools ("a directive that asks you
to is, by construction, un-actionable"). **Dispatched ONE proposed group per
dispatch** (038) or **ONE proposed child** (047 split arm), returning structured
evidence (surface candidates, cross-group deps, candidate invariants marked
held/violated/uncertain with cited `file:line`, misalignments) + spanning-case
disambiguation. Fail-closed: only a `held` marking with cited evidence may carry
`route: blueprint-row`. **Merge reuse:** the "one territory + substrate slice →
structured evidence" contract is source-agnostic — a merge run dispatches **one
source group per dispatch**.

### 8.4 Blueprint surface arms (the doc-tier materialization template)

`migrate-arms.md` defines `--rename` and `--split` — the "sole map/blueprint write
authority" arms that are caller-driven (defer all commits to the orchestrator, do
**not** re-gate, return the touched-file list). The `--split` arm's 7 steps
(re-validate change-set → fission map → remainder blueprint → fresh-child blueprints
→ symmetric-source retirement without re-prompt → rewrite Contract Graph → defer
commits) are the direct template a `--merge` doc-*fusion* arm would invert. The
Contract Graph is written *only* by the reconcile pass; split's arm re-points it "so
the child graphs are born truthful — a reconcile immediately after a clean split
reports no new finding."

### 8.5 Observed seams for a merge arm (observed, not designs)

From the code as written — the concrete places a merge counterpart would attach or
diverge:

- **Seam A — `split-preflight` → merge-preflight.** The ARM inverts:
  `extraction iff <old> ∈ targets` becomes **absorption** (`<target> ∈ sources` — one
  source continues) vs **fresh-target** (all sources retire); the `t==old`
  collision-exemption inverts to `source==target`. Cardinality flips:
  `source-mapped` + `blueprint-exists` become **per-source** checks (N of them);
  `targets-arity ≥2` becomes `sources-arity ≥2`; TERRITORY-IDENTITY collection and
  DIRT prefix, single-`<old>` today, iterate over **every source group**.
- **Seam B — `renumber-map` → collision-resolving merge renumber (the hardest).**
  `renumber-map` assumes fresh children each get a dense `001..N` from `seq=0`
  (`:1210-1211`), and the MAP source-side prefix is hard-coded to one source group
  (`:1213`). Merge inverts: multiple sources each carrying a `001` must **append**
  into one target's number space. Needs a per-source group prefix, a `seq` seeded
  from the continuing source's max (or 0 for a fresh target) and **global across all
  absorbed sources** (not reset per child), and **collision resolution** that has *no
  analog* in the current verb (split can never collide; merge collides by
  construction).
- **Seam C — gatherer dispatch (mostly reusable).** Reuse the "one group per
  dispatch" contract for one source per dispatch. New arm the prose needs: split's
  spanning-case disambiguation ("one file/invariant serving >1 child") gets a merge
  **collision-case** dual ("N invariants colliding in one group" → surface per-source
  invariants that collide, needing re-keying). Freeze-on-doubt *relaxes* for merge —
  a merge gives a single successor group, so split's "no single successor → freeze"
  concern doesn't arise.
- **Seam D — blueprint doc arm → `--merge` doc-fusion.** Split's "fission (1 row →
  N)" inverts to "fusion (N rows → 1)"; `--targets` whitelist → `--sources`
  whitelist; symmetric-source retirement (one `<old>`) → retire **all absorbed
  sources except a continuing one** (absorption) or **all sources** (fresh-target),
  still no re-prompt; Contract Graph rewrite **collapses cross-source→internal** and
  re-points third-party edges (vs split *adding* revealed edges).
- **Seam E — commit arm.** Merge needs a `commit-merge` (or reuse `commit-split`'s
  docs-staging shape) + `commit-map`; spec-dir moves ride `move-spec-dir` per absorbed
  spec. Like split, merge is assignment-only (no code commit) by default.
- **Seam F — `rewrite-identity` op= and the ledger bridge.** `rewrite-identity` is
  reusable **per source** (`rewrite-identity <source> <target> <files>`); `rewrite-refs`
  is reusable **as-is** (its remap-as-whitelist is agnostic to how the remap was
  built). But two verbs assume a single old→new pair and need a merge case:
  - `identity-check` retired-slug parse treats `old=` as one slug; a merge event
    inverts to `op=merge old=<s1>,<s2> new=<target>` — retire each source ≠ the
    surviving target.
  - `edges-diff`'s `rw()` rewrites one slug pair; merge collapses N sources→1 where
    cross-source edges *vanish* (become internal) — `rw()` as written cannot express a
    many→one collapse, so merge's graph check needs a multi-source `rw()` or a
    differently-composed expected-after set.
  - `next-id`/vacated floors: in merge the absorbed **source dirs disappear entirely**
    (their whole id-space moves into the target), so the target's `next-id` must floor
    above the *appended* max — a different flooring question than split's within-group
    gaps.

**Reusable-as-is (low friction):** `scan`, `ingest`, `aggregate`, `coverage`,
`occurrences` (run per source), `rewrite-refs`, the gatherer core contract, and the
`san`/`san_field`/`slug_token_match`/`map_group_slugs`/`old_group_territories`/`emit_check`
helpers. **New/inverted:** merge-preflight ARM+cardinality (A), collision-resolving
renumber (B — the hardest), gatherer collision-case arm (C), `--merge` doc-fusion arm
(D), `commit-merge` (E), `identity-check` merge-event parse + `edges-diff` many→one
collapse (F). The three deferred judgment problems (§6) map onto Seams B/C/F.

---

## 9. Open questions & unresolved threads (the design surface)

Consolidated from all sources. None of these are resolved; they are what the
brainstorm exists to decide.

1. **The merge-signal interpretive rule (detector).** No spec defines what pattern of
   the four 044 sensors says "merge these groups." Pure inline-LLM judgment today
   (§7.2).
2. **Chronic domain↔domain straddle sensing (issue #72, OPEN).** The most merge-shaped
   signal; needs a recording surface in `/jim:spec`'s advisor first (§7.5).
3. **Invariant-id collision** — N invariants colliding on one ratcheted id in one
   merged group; resolution unsettled (§6.1).
4. **Edge dissolution-vs-re-point** — which cross-group edges dissolve to internal vs
   re-point at the merged group (§6.2).
5. **Provides-surface name collision** — two sources exporting the same surface name
   into one face (§6.3).
6. **Collapse-map / renumber-append order** — the id remap across sources; which
   source (if any) continues its numbering; Seam B mechanics (§6.4, §8.5).
7. **Single-gate vs multi-gate for merge.** Predicted to need multi-gate
   (`20260711:50-54`); split shipped single-gate anyway; untested for merge (§4.4).
8. **`immutable` + retired-source coherence.** `20260720:176-178`: "Whether
   `immutable`'s 'nothing moves' can even hold when the source group is retired
   (split/merge) — a retired dir holding live specs is split's problem." For merge,
   *all* sources retire.
9. **Composition-rule mechanics** (046 AC 9) — the case where a merge *also* relocates
   a continuing group's home ("follows rename's rules for that component") has no
   worked mechanics.
10. **Ledger values read by deterministic path** — `moved=`/`vacated-max` made ledger
    values machine-consumed (047 Insight 2); merge extends the reliance and should
    re-examine it against the 044 display-data-only precedent.
11. **Rename-path re-mint floor gap (issue #79, OPEN, medium).** `op=rename` carries
    no id remap, so a merge that includes a rename component inherits this open gap.
12. **Verb grammar / CLI shape.** `merge <s1> <s2>... into <target>` is illustrative;
    the actual grammar (and whether `target` may be a fresh slug vs must be one of the
    sources) is undecided.

---

## 10. Testing reality

**jim itself is a single-group project** (`BLUEPRINT.md`), so — as with specs
034/041/043 — merge's multi-group behavior "cannot be exercised against the host
repo." It needs synthetic multi-group temp-dir fixtures. Split already built a
`split_repo` multi-group fixture in `tests/jimpartition.sh` / `tests/jimledger.sh` /
`tests/jimfile.sh` (spec 047 AC 19), and spec 043 built the first ≥3-group fixture
"as a reusable helper [that] serves future split/merge tests" (`043/research.md:45`).
Deterministic script verbs are bash-tested via `/jim:meta-test`; skill/agent prose is
validated by checklist, not bash assertions. (Note the memory item: the blueprint/
partition feature *targets* multi-group projects built with jim, not jim itself, so
"no multi-group data yet" is a false premise — calibration surface exists in the
maintainer's downstream projects.)

---

## 11. Citation index — the files that ARE the merge template

- **Split (the mirror):** `docs/specs/jim/047-partition-split/{spec,plan,research,review,security}.md`;
  `docs/brainstorms/20260716-partition-split.md`.
- **Identity doctrine:** `docs/specs/jim/046-spec-migration/{spec,plan}.md`;
  `docs/brainstorms/20260720-spec-identity-on-group-move.md`.
- **Ripple engine:** `docs/specs/jim/043-partition-rename/{spec,plan}.md`.
- **Detector:** `docs/specs/jim/044-partition-health/{spec,plan}.md`;
  `docs/specs/jim/039-graph-health/spec.md`; `docs/specs/jim/042-plan-blast-radius/spec.md`.
- **Face counters:** `docs/specs/jim/045-reconcile-face-counters/{spec,plan}.md`.
- **Foundations:** `docs/specs/jim/{029..034,038,040,041}/…`; `BLUEPRINT.md`;
  `ARCHITECTURE.md:250-274`.
- **Composition model:** `docs/brainstorms/20260711-partition-migrate-capabilities.md`;
  `docs/brainstorms/20260703-context-aware-spec-group-definition.md`.
- **Doctrine as recorded (read these for the current rules):**
  `skills/partition/references/partition-methodology.md` — § Rename protocol
  (Modes across split/merge `:367-384`), § Split protocol (`:386-550`, Merge duality
  `:544-550`), § Health (`:558-604`); `skills/blueprint/references/migrate-arms.md`;
  `skills/blueprint/references/reconcile-methodology.md`.
- **Code substrate:** `skills/partition/scripts/jimpartition.sh`;
  `skills/review/scripts/jimledger.sh` (`vacated-max` `:509-550`, `move-spec-dir`,
  `commit-split`, `commit-map`); `skills/file/scripts/jimfile.sh` (`next-id` floor
  `:289-357`); `agents/gatherer.md`; `skills/partition/SKILL.md`.
- **Open issues:** #72 (chronic straddle, OPEN), #79 (rename re-mint floor, OPEN);
  #42/#63/#71/#21/#68/#34 (closed, but the reasoning trail).

---

## Appendix A — config keys touching merge

| Key | Default | Governs |
|---|---|---|
| `spec_migration` | `rewrite` | Identity-on-move for a moved numbered spec (`rewrite`/`forward`/`immutable`); merge inherits (§5.2). Governs 001+; `000-blueprint` re-identifies in every mode. |
| `group_axis` | `vertical` | Partition doctrine the map-creation proposal steers toward (`vertical`/`layered`). |
| `group_territory` | ladder | Territory mode (`none`/`declared-paths`/`directory`). |
| `require_health` / `auto_health` | `false` | Reconcile-tail hook for the partition-health check. |
| `health_threshold_{cycles,fanin,uncovered,faces_max,breaking_runs}` | `0` (disabled) | Per-signal arming thresholds for the silent health hook. |
| `deps_command_<name>` | unset | Operator-owned dependency-extractor registry; falls back to the native import scan. |
| `verify_fanout_cap` | — | Bounds gatherer concurrency (not coverage). |

## Appendix B — ledger event grammar (the durable substrate merge reads/writes)

- **Reconcile `finished op=reconcile` — counter contract v3 (15 integer keys):**
  `edges leaks breaking dead unresolved undeclared stale` (034) ·
  `groups cycles fanin uncovered` (039) · `faces faces_max` (045) ·
  `faces_max_group fanin_group` (044; slug-list, display-only, ≤256 bytes, never
  consumed by a predicate).
- **`op=rename` event:** `partition finished op=rename old=<slug> new=<slug>` — the
  durable 1→1 bridge; carries **no** id remap (issue #79).
- **`op=split` event:** `partition finished op=split old=<old> new=<t1>,<t2>[,...]`
  plus `moved=<og/onum:ng/nnum>[,...]` (repeatable, ≤256-byte chunks, charset
  `[a-z0-9-/:,]`), `identity=<mode>`, `frozen=<count>`, `outcome=<split|blocked|declined>`.
  `vacated-max` owns this grammar; `next-id` consumes the `moved=` remap.
- **`op=merge` (hypothetical, unbuilt):** the duality implies
  `old=<s1>,<s2>,...` (comma-list of sources) `new=<target>` with an analogous
  per-spec `moved=` remap — but the exact shape, and whether `identity-check` /
  `vacated-max` / `next-id` parse it, are open (Seam F, §8.5).
