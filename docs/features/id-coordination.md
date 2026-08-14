# ID coordination

Jim binds every identity that has to be unique across clones — spec ordinals, group names, issue display ordinals and durable issue ids — through a shared allocator rather than a local scan of whatever happens to be on disk. This document is the mechanism; the features that consume it describe what they do with the identities they get.

An ordinal computed as *the highest number I can see, plus one* is computed over a different tree in every clone and on every branch. Two developers mint `#42`, or `core/012`, and neither finds out until the branches merge. For an issue that is an annoyance. For a spec it is expensive: the ordinal is frozen into the directory path, into every `Spec:` commit trailer that cites it, and into every artifact that references the spec — so unwinding a collision means renaming directories and rewriting citations that have already been pushed.

## Table of Contents
1. [What is coordinated](#what-is-coordinated)
2. [The registry](#the-registry)
    * [Records](#records)
    * [Allocation](#allocation)
    * [Guarantees](#guarantees)
3. [Working offline](#working-offline)
    * [Realizing a provisional identity](#realizing-a-provisional-identity)
4. [Registry integrity](#registry-integrity)
    * [Seeding an existing project](#seeding-an-existing-project)
    * [Checking and repairing](#checking-and-repairing)
5. [Identity that moves](#identity-that-moves)
6. [Trust and safety](#trust-and-safety)
7. [Configuration](#configuration)

---
[Jump to configuration](#configuration)

## What is coordinated

| Identity | Shape | Bound at | Frozen into |
| :--- | :--- | :--- | :--- |
| **Spec ordinal** | `<group>/<NNN>` — three digits, unique within the group | `/jim:spec`, at scoping | The spec directory name, `Spec:` commit trailers, every artifact that cites the spec |
| **Group name** | A slug | Emitted alongside the first spec allocated into a group the registry has not seen | Every spec path in the group, its territory declarations, its per-group config keys |
| **Issue ordinal** | `num:` — a positive integer, project-wide | The issue emitter, at file time | The display handle (`#350`) |
| **Issue durable id** | `<prefix>-<slug>` | The same allocation | The issue filename, and every citation of it |

The zero-valued ordinal in each group — `<group>/000` — is reserved for the group [blueprint](blueprints.md) and is never allocated. `0`, `00` and `000` are one rule, so no spelling of it can slip through.

Consumers: [`/jim:spec`](../../WORKFLOW.md) binds a spec ordinal before it writes anything; the [issue](issues.md) emitter binds an ordinal and a durable id for every issue, interactive or batch-filed; [`/jim:partition`](blueprints.md#partition-operations) binds the rename records that let a moved identity still resolve.

## The registry

Identities come from an append-only registry on a dedicated coordination branch — `jim/registry` by default. That branch carries the registry logs and nothing else: no specs, no issues, no project content. It is created on first use.

Two logs, one per kind, file order authoritative: `specs.log` holds the spec and group records, `issues.log` the issue records.

### Records

One line per event, space-separated:

```
group allocate platform 20260726 jim-seed
spec  allocate blueprint/001 blueprint-spec 20260726 jim-seed
spec  rename   jim/001 sdlc/001 20260725 jim-lift
spec  realize  core/P-20260728-widget core/012 20260728 alice
issue allocate 350 20260813-foo-widget-lacks-input-validation 20260813 alice
```

The last two fields are the date and a provenance tag — the allocating user, or `jim-seed` / `jim-catchup` / `jim-lift` where a bootstrap or a repair wrote the record. **Provenance is advisory only.** It is self-asserted, never consulted for authorization, and never used to order anything: the log's own file order decides every outcome, not a wall clock and not a name.

### Allocation

An allocation reads the branch tip, derives the next identity from the log it just read, and lands its record with a **compare-and-swap**. Where the clone has a remote, the CAS is the push itself — git's non-fast-forward rejection is the check, so the record lands only if the tip has not moved since the read. Where a clone has no remote at all, the same discipline runs locally against the ref, coordinating that clone's own sessions and worktrees.

A loser re-reads the new tip and retries with jittered backoff, bounded. Exhausting the retries fails loudly and allocates nothing — contention is never resolved by guessing.

All of it runs through git plumbing: objects are written and the ref is moved directly, so the coordination branch is never checked out and your working tree is never touched mid-flow. Git runs non-interactive throughout, so a credential prompt can never hang a phase mid-allocation — an unreachable coordination point surfaces as a failed command instead.

### Guarantees

**Durable before use.** An identity reaches the caller only after its record has landed. There is no window in which a file carries an identity the registry does not know about.

**Spent, never reclaimed.** The log only grows. Abandoning work behind an allocated identity leaves a permanent gap in the ordinals, and a refusal that fires *after* allocation still burns one. That is the honest cost of never issuing the same identity twice.

**Rewrites are refused, not absorbed.** Each clone remembers the registry content it last saw, in its own `.git` — never on a branch, never fetched or pushed. If the branch no longer contains that content as a prefix, the history was truncated or force-pushed, and allocation stops rather than allocating over it. A clone with no baseline yet cannot detect an erosion that predates its first fetch, so branch protection on the coordination branch is the primary control and this is defense in depth.

## Working offline

`id_coordination_unreachable` decides what happens when the coordination point cannot be reached — offline, no push access, a fetch that fails:

- **`fail`** (default) — no identity is issued and the run says so. Nothing uncoordinated is ever written, and there is no silent local fallback.
- **`provisional`** — a local-only identity is bound immediately. It contacts nothing and performs no compare-and-swap, so it never blocks on the network and never fails for unreachability.

A provisional identity carries a reserved `P-` prefix in its ordinal slot. Real ordinals are digits, so the two grammars are disjoint by construction and nothing can pass one off as the other. It never enters the registry, so a pending provisional can never inflate a later real allocation.

The two consumers wear it differently:

- **A spec** wears it as its entire directory name — `docs/specs/core/P-20260728-widget/` — with its frontmatter claiming the same identity. Research, plan, sec and build all run against it unchanged.
- **An issue** keeps its durable id and carries `P-<id>` in `num:`. Read views render it as `(provisional)`, never as a settled `#N`.

### Realizing a provisional identity

`/jim:spec reconcile` and `/jim:issue reconcile` are twins. Both preview the provisional → real mapping and ask before applying; both publish the real identities to the registry *before* any file is touched; both are idempotent and resumable, mapping an already-realized identity to its existing ordinal rather than minting a second one; and both halt loudly rather than write an identity they are unsure of. Still offline is not an error — nothing changes and the run reports that.

What each rewrites differs:

- **Specs** — the directory is renamed onto its ordinal (a tracked directory moves with `git mv`, crossing into another group if the registry answers under a different one), the frontmatter id is rewritten, and a citation sweep updates in-tree references across the specs, brainstorms and debug roots plus the issue collection wherever `issue_placement` puts it.
- **Issues** — only `num:` changes. The filename and the durable `id:` never move.

One ordering surprise worth knowing: realization walks pending directories in name order, so within a single day's batch the ordinals fall alphabetically by slug rather than in the order the specs were scoped.

## Registry integrity

The registry prevents collisions only while it faithfully represents the repo. Identities created outside the allocator — old habits, non-jim tooling, a move made before the registry could witness it — leave it answering below the tree, and the next allocation then hands out an identity the project already owns.

### Seeding an existing project

A project adopting jim, or one that predates coordination, bootstraps the registry once from what it already has:

```bash
bash skills/file/scripts/jimalloc.sh seed            # preview the derived records
bash skills/file/scripts/jimalloc.sh seed --apply    # land them as one commit
```

`seed` derives both kinds from the tree — spec directories and issue files. A conflict in either halts the whole seed with the offenders named and nothing written, rather than bootstrapping a registry that contradicts itself. It refuses a registry that already has records; converging a populated one is `catch-up`'s job.

### Checking and repairing

Three hand-run allocator verbs — a read-only check, and two repairs drawing on different evidence:

```bash
bash skills/file/scripts/jimalloc.sh sweep              # read-only: what drifted, and what was not covered
bash skills/file/scripts/jimalloc.sh catch-up           # preview the records the registry is missing
bash skills/file/scripts/jimalloc.sh catch-up --apply   # append them, under an allocation's CAS + erosion guard
bash skills/file/scripts/jimalloc.sh lift               # preview the rename records a past move left unrecorded
bash skills/file/scripts/jimalloc.sh lift --apply       # record them, so a citation frozen before the move resolves
```

**`sweep`** compares every spec directory and issue file against the coordination branch, classifying each finding — `missing-record` (the collision risk), `mismatch`, `duplicate-ordinal`, `duplicate-id`, `reserved-slot` — and reporting records with no tree counterpart as *informational*, since another clone allocating first is legitimate. It then names what it did **not** cover: reserved blueprint slots, pending provisionals, groups outside coordination entirely, and ids known only as rename sources. It exits `0` clean, `3` drift, `4` could-not-check, so a check that could not run is never read as a pass. It mutates nothing.

**`catch-up`** appends exactly what the sweep classified as `missing-record` and nothing else, rendering every record verbatim before `--apply` lands them as one commit. It refuses to repair a mismatch, a duplicate, or an identity sitting on an ordinal a rename vacated — choosing which side is right is an operator decision, not a mechanical append — and it exits non-zero when it leaves one behind, so a partial repair never reads as a clean run.

**`lift`** repairs a different gap: a rename, split or merge that moved identities before the registry could record moves, so a citation frozen against the old id resolves nowhere. It reads the durable old→new pairs from the [ledger](ledger.md) as a *witness, not an instruction* — a pair becomes a record only where the registry independently establishes its destination and holds no live claim on its source. It repairs an absence; it never adjudicates a conflict.

Wire the sweep into [`/jim:verify`](blueprints.md#the-verification-engine) as an operator check and it runs with every verification:

```toml
verify_command_id-sweep = "bash skills/file/scripts/jimalloc.sh sweep"
```

## Identity that moves

A group rename, split or merge relocates identities that other artifacts already cite. Those operations propose their identities at their gate and *bind* them at the close, through one emission verb that writes the rename records — and that refuses rather than resolves a contradiction: a destination already claimed, or an ordinal an earlier rename vacated, is named and nothing is written. That refusal is why a vacated ordinal is never re-minted; it is closed to arrivals, not merely avoided by convention.

Git history is never rewritten, so the [ledger](ledger.md) event each operation records is the durable old→new bridge, and `spec_migration` decides what happens to the moved bodies. See [partition operations](blueprints.md#partition-operations) for the full lifecycle.

## Trust and safety

- **The registry is untrusted input.** Anyone who can push the coordination branch can lengthen the log, so every id, slug and group token read back is revalidated through the same id boundary before it can reach a git command, a ref, or a filesystem path. A malformed record is degraded and skipped — parsed as data, never sourced or executed. The worst a crafted record achieves is a wasted ordinal.
- **Reports cannot be forged.** Every field printed by the integrity verbs is sanitized on emission — tabs and newlines flattened, length capped — so a crafted value cannot fake a row or shift a column in a report an operator reads.
- **Evidence is corroborated, not obeyed.** `lift` reads identity pairs from the ledger but records only those the registry independently establishes, so branch content nobody vetted cannot redirect a citation at a destination of its author's choosing.
- **Provenance is not authorization.** The `<who>` field is self-asserted and advisory; nothing keys a decision on it.
- **Nothing runs unattended against your tree.** Allocation touches only the coordination branch, through plumbing. `seed`, `catch-up` and `lift` preview by default and mutate only behind `--apply`; `sweep` never mutates at all.

## Configuration

| Key | Default | Effect |
| :--- | :--- | :--- |
| `id_coordination_mechanism` | `"git"` | How identities are coordinated between clones; `git` uses the append-only registry described here. An unrecognized value is refused, never silently degraded |
| `id_coordination_branch` | `"jim/registry"` | The branch holding the registry logs — never project content. It is also the one branch `issue_placement` refuses as a destination |
| `id_coordination_unreachable` | `"fail"` | What happens when the coordination point cannot be reached: `fail` issues no identity and says so, `provisional` binds a local `P-…` token for `/jim:spec reconcile` or `/jim:issue reconcile` to realize later |

The keys are read from the checked-in `jimconf.toml` on the current branch, so a team's coordination scheme is itself versioned and shared — there is no per-machine setup.
