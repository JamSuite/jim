# Brainstorm: Partition Migrate Capabilities

*2026-07-11*

## The operations

Practical actions: **rename**, **split**, **merge**. Unclear (so far) what
should be shared between them.

## Surface pattern — subcommands vs flags

Survey of existing argument surfaces:

- **Bare-word subcommands** = skill dispatches over distinct operations:
  `/jim:issue add|list|stats|show|insights`, `/jim:conf get|list|path|keys`,
  `/jim:meta-test scaffold|add|run`, and `/jim:partition` itself
  (`greenfield | repartition | path | directory`).
- **`--flags`** = entry-point adapters / modifiers of one core operation:
  `/jim:verify --contracts|--retirement|--from-review|--since|--appetite`,
  `/jim:blueprint --reconcile|--retire|--since|--from-review`,
  `/jim:review --depth`.

Rename/split/merge are distinct operations → bare tokens fit, and partition
already speaks bare tokens. Stance: stay aligned with existing patterns
unless there's a good reason to diverge.

Open fork: namespace or peers?

- `/jim:partition migrate rename <old> <new>` — `migrate` as a namespace verb
  over the three ops.
- `/jim:partition rename <old> <new>` — ops as peer tokens alongside
  `greenfield`/`repartition` (which are already migration modes in spirit).
  No existing jim surface nests verbs two levels deep.

## Shared-skeleton hypothesis (sample of one)

From the one live rename run: a common phase skeleton —
scan (read-only, enumerate + classify the full ripple set upfront) →
one gate (whole classified change-set approved once) →
materialize (blueprint surface only, fixed commit choreography) →
verify (reconcile-to-clean + identity-grep + graph health).
Ops would differ in classification rules and map-edit shape. Untested
whether split/merge actually fit this skeleton.

## Decisions

- **Peers, no namespace.** `rename` / `split` / `merge` sit as peer tokens
  alongside `greenfield` / `repartition`. `migrate` doesn't earn a nesting
  level.
- **Rename ≠ split/merge on gate structure.** Rename is the mechanical op —
  identity is preserved, the ripple set is enumerable upfront, one gate
  suffices. Split and merge change the partition itself: they likely need
  additional interview + analysis to ensure the resulting graph is aligned,
  so a single gate probably doesn't hold for them.
- **Composition model confirmed.** Split/merge = *scoped repartition* (the
  existing repartition machinery — substrate, gatherer fan-out, interview,
  hard gate, retire arm, reconcile-to-clean — restricted to the affected
  territory) **+ the ripple engine** (rename's contribution: enumerate and
  classify every occurrence of a group identity, re-point in one
  choreographed materialization).
  - split X ≈ repartition scoped to X's territory → N groups + retire X
  - merge X,Y ≈ repartition scoped to X∪Y → 1 group + retire both
  - rename = ripple engine alone
- **Rename ships first** — it's the shared primitive; split/merge build on
  it rather than beside it.

## Forward-compat note (light, not a constraint yet)

The one shape worth keeping in mind while designing rename: the ripple
engine's classified change-set could be keyed as
(occurrence, classification, **target**) rather than assuming a global
old→new substitution. Rename is then the degenerate case (every target the
same new name); split reuses the same output with per-occurrence targets.
Cheap to phrase now, unproven that it matters — don't over-engineer for it.

## Code-move coupling (the heavy fork)

Two reframes before the options:

1. **The fork is conditional, not universal.** Territory embedding the group
   name is a naming convention, not a requirement (`billing` can own
   `src/payments/`). The code-move question only fires when the scan finds
   **identity-bearing territory paths**; the scan classifies that explicitly,
   and with none present there is no fork.
2. **Doctrine demands truth, not name-matching.** A map saying group `<new>`
   owns territory `modules/<old>` is *truthful* — present-tense doctrine is
   about never lying, not about names rhyming. Forcing alignment at write
   time is an operator choice, not a doctrine necessity. Mismatch is a
   partition-health *smell*, not a doctrine violation.

Options weighed:

- **A. Require (code moves in the same operation).** Pros: no mismatch window,
  one mental model, crisp reconcile done-condition, proven live. Cons: puts
  judgment code edits (import fixes) inside a doc op — no tests/plan/review,
  contradicting the skill's own "not for code moves" boundary; inherits the
  environment-gated build check (can end "verification owed" — a code change
  landed without its authoritative gate); balloon risk (module paths,
  published names); forces a code-freeze moment.
- **B. Offer (fork presented once at the gate).** Arms: *(a) move now* —
  in-op git mv + import fixes, recommended when mechanically bounded,
  verification-owed handoff when the environment can't check; *(b) docs-only*
  — rename everything jim owns, territory keeps truthfully pointing at the
  old path, tracked code-move issue routed to the normal spec→plan→build.
  Pro: fits jim's human-gate nature; docs-only arm is always fully
  verifiable in-repo. Con: arm (b)'s follow-up may linger — mitigated by the
  filed issue + partition-health sensors (the #42 family).
- **C. Refuse (block until code moves first).** Strictly dominated: the
  mismatch state exists anyway (other side), plus the ordering absurdity —
  the enabling code-move spec gets filed into the group being dissolved,
  the exact discomfort that motivates renames.

**Reasoned choice: B.** A solves an aesthetic problem by breaking a deeper
rule (jim editing application code outside its own build discipline); C is
dominated. B presents the real fork to the human once, keeps the map
truthful on both arms, and routes code changes to the workflow that owns
them.

**Decision: B — offer, user choice at the gate.** Caveat noted for the
record: the one live run chose the "move now" arm and was glad it did, so
that arm is a first-class path, not a concession. B's value over A is that
the doctrine-clean alternative exists and the human picks.

## Ledger semantics

**Decision: first-class rename support.** A rename records a true event —
`op=rename old=<x> new=<y>` — not the shoehorned drop+add grading
(`additions=1 downgrades=1`) that misdescribes the operation in the durable
record. (Grading conservatism can be preserved — a rename still gates —
without the record lying about what happened.)

## Mechanics to assert (not inherit by luck)

**Decision: all in scope for rename.**

- Fixed commit choreography (code / spec-dirs + blueprints / map + ledger —
  three atomic commits, encoded rather than re-derived).
- In-flight wip spec dirs ride the move — asserted, not accidental.
- next-id continuity in the renamed group — asserted.
- "Verification owed" handoff line when the environment can't run the
  authoritative check (generalized, named, part of the op's closing report).
- Pre-partition / retired group dirs outside the map: out of rename's reach.

## The must-not-change ratchet (invariant ids, provides surface names)

Key distinction: **invariant ids are keys** (verify history, check-data
blocks, filed issues join on them — stability wins); **provides surface
names are descriptions** (they name real code surfaces — truth wins).

Options:

1. **Permanent ratchet** (keep all old-prefixed identifiers forever).
   Pros: continuity free, no engine-join risk, truthful where code keeps the
   old name, zero machinery. Cons: ids fossilize every past name; reports
   speak old names indefinitely; dissonant with "no unclassified stale
   mention".
2. **Documented id-rename with continuity.** Pros: artifacts read clean;
   identity migration total. Cons: continuity machinery required — and the
   alias has nowhere clean to live: an in-blueprint "formerly X" line is
   historical content (the very marker vocabulary the present-tense
   discipline bans), so the mapping must live on the ledger, forcing every
   future history consumer to join across rename events; must atomically
   re-key every id-keyed join (verify-checks, contract-checks, criticality,
   VERIFY-OUTCOME consumers); old ledger events and filed issues go stale or
   get rewritten; and face renames lie even on the move-now arm, because
   git mv + import fixes moves directories, not exported symbols — staying
   truthful would pull API renames into the op (scope balloon).
3. **Split by class: ids ratchet, names track code.** Ids: opaque keys, keep
   forever (reports render the group name alongside; dissonance bounded —
   e.g. `checkout: cart-no-direct-db — holds`). Surface names: follow the
   code, renaming only when the code surface they describe renames — in a
   later work spec, picked up by the existing face-update machinery
   (`--since` / review sensor). The dotted requires key splits naturally:
   group half re-points in the rename op (it keys the graph join), surface
   half stays truthful to code, catches up later
   (`cart.cart-session-api` → `checkout.cart-session-api` →
   `checkout.checkout-session-api`). Zero new machinery; two rules to
   document instead of one.

Worked example (invented names, group `cart` → `checkout`): invariant
`cart-no-direct-db` keeps its id inside the renamed group's blueprint with
its text/params updated to the arm's territory truth; provides
`cart-session-api` stays until `CartSession` actually renames in code.

**Reasoned choice: 3.** Option 2 buys aesthetics with permanent join-across-
rename machinery plus a lie-window on both arms; option 1 needlessly
ratchets surface names even when code renames make updating them truthful
and free. If fossil ids ever prove painful, a documented id-rename can be
added later without pre-building it.

**Decision: 3 — ids ratchet, names track code.**

## Remaining open questions (not resolved here)

- Is the partition substrate (`jimpartition.sh` extraction) name-agnostic,
  or does it need re-running post-rename? (Likely spec-interview material.)
- Split/merge specifics — gate structure, classification rules, how much of
  the scoped-repartition machinery is reused as-is. Deferred until rename
  ships and proves the ripple engine.
- Relation to frozen-spec re-homing: deliberately out of scope here — that
  is its own tracked design question (the freeze-history crux), adjacent but
  separate from the living-artifact migration these ops perform.
