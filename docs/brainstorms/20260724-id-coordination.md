# Brainstorm: ID Coordination

*2026-07-24*

## Problem

Two collision-prone ID spaces in multiuser environments:

- **Issue IDs** — the durable ID (date + slug) is reasonably collision-guarded, but the *display ordinal* (#42) is assigned by INDEX.md generation. It's derived, and re-derived on reindex → duplicate display ordinals, awkward sorting, and hard git collisions in INDEX.md. The ordinal is the handle people actually use (`show #42`, not `show <slug>`).
- **Spec IDs** — per-group dense ordinals (`dashboard/047`) *are* the identity: baked into directory paths, commit trailers, cross-references. Two branches allocating the same NNN is expensive to unwind.

Goal: solve coordination for both, designed for **pluggable mechanisms** (git-based first — no external deps; service-based later).

## Core insight

Git's only atomic primitive is the ref update:

- Remote: `git push` is a compare-and-swap on the ref (non-fast-forward → rejected).
- Local: `git update-ref <ref> <new> <expected>` is a CAS within one clone — shared by all its worktrees.

Every git-based option is a choice of **where the CAS lives** and **what state it guards**. That choice also sets the guarantee tier:

- CAS on a **local ref** → safe across worktrees/agent sessions of one clone (no network needed).
- CAS on an **origin ref** → safe across users/clones (requires reaching origin at allocation time).

Same allocator, two deployment tiers.

## Common allocation loop (optimistic concurrency)

```
fetch coordination ref
compute next ID from registry state
build allocation commit
push / update-ref        # the CAS
rejected → backoff, refetch, recompute, retry (bounded) → hard-fail with clear message
```

Allocation must be durable (CAS succeeded) *before* the ID is used. IDs are never reused. Gaps are allowed (DB-sequence mentality).

## Options

### A. Registry on main (the "coordinate via main" idea)

A small append-only registry (e.g. one log file per ID kind: `issue 042 20260724-wire-consumers`) lives on main. Allocation = commit a new registry line to main and push; push rejection = lost the race, retry.

Two implementation variants for touching main while on a feature branch:

1. **Temp worktree on main** — porcelain, transparent, easy to reason about; some working-dir churn.
2. **Pure plumbing** — `hash-object` → `mktree` → `commit-tree` → `push <sha>:refs/heads/main`. No worktree, no checkout; leaner but plumbing-heavy bash.

Key property: `next` derives from the **registry**, never from listing spec/issue dirs on main — main's *content* always lags unmerged branches (that lag is exactly today's collision).

Sub-fork for issues — what lands on main:

- **Content-on-main**: the whole issue file is committed to main at filing time. Issues are cross-branch discovery artifacts, so arguably they belong on main immediately; feature branches stop carrying issue files and INDEX conflicts vanish entirely. But: a filed-from-branch issue may reference artifacts (`origin:` brainstorm file) that don't exist on main yet, and every filing is a main commit (noise).
- **Reservation-only**: just the registry line lands on main; the issue body stays on the feature branch until merge. Less main noise, `origin:` refs stay valid — but main's INDEX either lists reserved-but-absent issues or omits them until merge.

### A′. Dedicated allocation branch

Same as A, but the registry lives on a normal, visible, *unprotected* branch (e.g. `jim/registry`) instead of main. Dodges branch protection; stays transparent, clonable, inspectable, repairable with ordinary git. Cost: "main always has current state" becomes "the registry branch always has current state."

### B. Custom refs / git notes as ledger

Registry state hangs off `refs/jim/ids/...` (or `refs/notes/jim-ids`) — no files on any branch, push-CAS still applies, branch protection (scoped to `refs/heads/*`) is irrelevant. Cons: **hidden state** — default fetch refspecs don't bring custom refs, host UIs don't show them, users can't inspect or repair with normal workflows. Tension with jim's "not a black box" stance.

### C. Claim-refs (per-ID lock via create-only push)

Claiming `dashboard/047` = atomically creating `refs/jim/claims/spec/dashboard/047` (create-only push via `--force-with-lease=<ref>:` with expected-empty). No shared counter; contention only on the contended ID. Cons: ref sprawl, GC story, still needs a registry to compute "next", same hidden-state problem as B.

### D. Allocate-on-merge (deferred ordinals)

Branches use provisional IDs (slug / `draft-NNN`); final ordinal assigned when the artifact lands on main — ordinal = position in main history, collision-free by construction. Cons: IDs unstable during development; commit trailers and cross-references written on the branch cite provisional IDs → needs a rewrite step at merge. Heavy for specs; more natural for issue *display ordinals* if paired with content-on-main.

### E. No-coordination pole: kill dense ordinals

Specs go date-based like issues (`dashboard/20260724-blueprint-map`); human convenience via git-style short-prefix resolution. Zero coordination needed, ever. Cons: per-group NNN is baked into paths, trailers, and tooling; humans genuinely like small ordinals. Captured as the far pole of the spectrum.

## Spec-ID flow under A (sketch)

1. `/jim:spec` runs on a feature branch; interview proceeds.
2. At ID-assignment time the allocator reserves `dashboard/047` on main: registry line with ordinal, slug, group, date (maybe branch/user).
3. Spec directory `047-slug/` is created on the **feature branch**.
4. Branch merges later; content joins its standing reservation. Registry is always ≥ content on main.

- Abandoned branch → reservation never filled → **gap in ordinals**. Fine (sequences have holes). Optional later: a `reconcile` verb listing reservations with no landed content.
- **Tension**: `rename` / `split` renumber specs today. Under allocate-once coordination, renumbering IDs another branch may reference is hazardous — maybe renumber becomes new-allocation + tombstone. Open.

## Issue display ordinal — root cause and fix shape

Root cause today: the ordinal is **derived at render time** (INDEX.md generation is the allocator). Fix shape: the ordinal becomes **allocated once** at filing via the coordination mechanism and is **stored in the issue file's frontmatter**; INDEX.md becomes a pure projection — idempotent regen, no allocation authority, duplicates structurally impossible. `show #42` resolves via frontmatter/registry lookup.

## Files vs refs (summary)

| | Registry files on a branch (A/A′) | Custom refs/notes (B/C) |
|---|---|---|
| Transparency | Diffable, visible in UIs, clones by default | Hidden; explicit refspec to even fetch |
| Branch protection | Needs push rights to that branch | Unaffected |
| Noise | Commits on main (A) or side branch (A′) | Zero branch noise |
| Repairability | Ordinary git workflows | Plumbing knowledge required |

Jim's "not a black box" non-goal leans files-on-branch.

## Pluggable allocator contract (sketch)

- `allocate <kind> [group]` → id — at-most-once, durable before returning; maybe `peek`, `release`, `reconcile`.
- Backends: `git-main` (A), `git-branch` (A′), `git-refs` (B/C), `local` (today's derive-from-tree; single-user), `service` (later — a GitHub-backed variant could even delegate issue ordinals to GitHub Issues numbers).
- Selected via jimconf.toml; skills call one allocator script. Bash + POSIX only; registry parsed with grep/sed, never sourced.
- Failure semantics: bounded retry then hard-fail loudly. No silent local fallback in multiuser mode — a silently-unpublished allocation is exactly the collision being solved.

## Direction (2026-07-25)

- **Issue placement (content-on-main vs reservation-only): configurable.** Main centralizes nicely, but it's also the most restricted branch — won't work for everyone.
- **Unreachable-origin behavior (hard-fail vs provisional + reconcile): configurable.**
- **Target guarantee tier: origin, out of the box.** Near-term reality is separate users in separate clones working the same repo on different branches. Any team use needs coordination from day one — origin push-CAS at allocation time is the baseline, not an upgrade. Local tier remains the graceful degradation for repos with no remote.

### Synthesis: A and A′ collapse into one mechanism

With the coordination branch configurable, "registry on main" and "dedicated registry branch" are the same mechanism with a `coordination_branch` knob. Teams that protect main point the allocator at an unprotected branch (e.g. `jim/registry`); small teams use main directly and get the "main always has current state" property.

### Emerging config surface (jimconf.toml)

- `mechanism` = `git` (now) | `service` (future)
- `coordination_branch` = `main` | `jim/registry` | any branch
- `issue_placement` = `content` | `reservation`
- `on_unreachable` = `fail` | `provisional`

Config is checked in, so the team's coordination scheme is itself versioned and shared. (Caveat: config is read from the current branch — drift across branches is possible, but jimconf changes are rare.)

### Provisional + reconcile (sketch)

- Provisional IDs must be visibly non-real so they can't collide with allocated ordinals — shape TBD (e.g. `P-<date>-<slug>`).
- Reconcile = on next successful contact with origin, allocate real IDs for pending provisionals and rewrite references. For specs that renames the directory — the same churn as allocate-on-merge (Option D). Provisional mode is effectively *per-artifact deferred allocation*, which argues for `fail` as the default and `provisional` as informed opt-in.
- Reconcile trigger: automatic on next allocator invocation vs an explicit verb. TBD.

### Team onboarding implication

The allocator needs push rights to the coordination branch. That becomes part of jim's team setup story: protect main if you like, but leave the coordination branch writable by everyone running jim.

## Rename / split under allocate-once (expanded 2026-07-25)

### The root tension

A spec's ordinal is doing two jobs at once:

- **Identity** — what commit trailers, issue origins, plans, and humans cite (`Spec: dashboard/047`).
- **Address** — where it lives: directory path, group membership, position in the group sequence.

`rename` / `split` (and a `/jim:partition` repartition) change the *address*. The pain is that identity travels with it: every reference on every unmerged branch — and every trailer already frozen in git history — rots. Single-user, that's an annoyance; multi-user, it's a correctness hazard: user A renumbers `dashboard/047` while user B's branch holds trailers and an in-flight plan citing it. Worst case isn't a dangling reference — it's a *reused* ordinal pointing at a different spec.

### Shape 1: renumber = new allocation + redirect tombstone

A renumber is not a mutation of the registry — it's two appended records:

```
spec allocate widgets/012 <slug> <date> <who>     # normal CAS-guarded allocation in the destination
spec rename   dashboard/047 -> widgets/012 <date>  # redirect tombstone for the old ID
```

- `dashboard/047` is consumed forever — never reallocated. Allocate-once holds unconditionally.
- Resolution follows the redirect chain: `show dashboard/047` → "renamed to widgets/012" → shows it. Chains compose across repeated renames.
- **The big win**: trailers frozen in git history stay *dereferenceable forever*. Today renumbering silently rots history; under a redirect ledger, every ID that ever existed remains resolvable. Coordination doesn't just prevent collisions — it upgrades old references from rot-prone to permanent.

### Shape 2: freeze published IDs

Only specs that never reached the coordination branch may be renumbered. Under origin-out-of-the-box, reservation happens at creation — so effectively nothing is renumberable and split/partition break. Too restrictive as a rule; survives only as a fast path: provisional-mode specs (pre-reconcile) can renumber freely since nobody else can see them.

### Shape 3: separate durable identity from address

Give each spec a never-changing identity (date-slug like issues, or a birth ID) and treat `group/NNN` as the current address; references cite identity, registry maps identity ↔ address. Deepest fix, but: two names per spec, humans will use the ordinal anyway, and the commit-trailer convention (`Spec: group/NNN`) would have to change — a big ripple.

### Synthesis

Shape 1 quietly *contains* Shape 3: the birth ID plus its redirect chain **is** a durable identity, without introducing a second user-facing name or touching the trailer convention. Trailers keep citing whatever the ID was at commit time; the ledger makes that citation permanent. Shape 1 looks like the sweet spot.

### Mechanics that fall out

- **Batch atomicity for free.** A `split` moving N specs = one registry commit (N allocations + N redirects) = one push = one CAS. All-or-nothing, no partial renumbering ever visible. Same for a partition's mass moves.
- **Group-level operations need group-level records.** Renaming group `dashboard` → `dash` changes every member's full ID without renumbering: one `group rename dashboard -> dash` record; resolution applies group redirects before ordinal lookup. Group *merge* (dashboard + widgets → ui) is per-spec fresh allocations in the destination sequence + per-spec redirects — both sources' `001`s land at distinct new ordinals.
- **Content lags registry — same model as creation.** The rename lands in the registry immediately; the directory moves ride A's feature branch until merge. B fetches and sees "renamed, tree not yet updated" — the exact reservation-ahead-of-content semantics allocation already has. One consistency model everywhere.
- **Concurrent edit-vs-rename becomes detectable.** B edits `dashboard/047` while the fetched registry says it was renamed → jim can warn before the git-level rename/modify conflict lands at merge. A drift-detection surface consistent with jim's verify/review DNA.
- **Record shapes stay greppable** (append-only, parse with grep/sed, never sourced):

  ```
  spec  allocate  dashboard/047 <slug> <date> <who>
  spec  rename    dashboard/047 widgets/012 <date>
  group rename    dashboard dash <date>
  issue allocate  042 20260724-wire-consumers <date> <who>
  ```

  Resolution = last-wins replay scan. One log file per kind (`specs.log`, `issues.log`) is likely enough at jim scale; per-group sharding is premature.
- Side effect worth noting: the "spec IDs rot, don't cite them" caveat weakens — ledger-backed IDs are permanently resolvable. (The no-IDs-in-code-comments rule stands regardless; its provenance rationale is independent of rot.)

### Worked example (Shape 1, end to end)

Cast: **ana** and **ben**, separate clones, different feature branches. Config: `coordination_branch = main`.

**T0 — starting state.** `specs.log` on main (append-only):

```
spec allocate core/001 auth-baseline     2026-05-02 ana
spec allocate core/002 session-store     2026-05-11 ben
spec allocate core/003 dashboard-shell   2026-06-01 ana
spec allocate core/004 dashboard-widgets 2026-06-14 ana
spec allocate core/005 billing-webhooks  2026-07-02 ben
```

Tree on main matches: `docs/specs/core/001-auth-baseline/ … 005-billing-webhooks/`. Ben's in-flight branch carries week-old commits with trailer `Spec: core/003` and a plan.md citing it.

**T1 — ana splits dashboards out of core.** On branch `feat/dashboard-group`, the split verb decides core/003 and core/004 move to a new `dashboard` group. The allocator: fetches origin/main → builds ONE commit appending four records →

```
spec allocate dashboard/001 dashboard-shell   2026-07-25 ana
spec rename   core/003 dashboard/001          2026-07-25 ana
spec allocate dashboard/002 dashboard-widgets 2026-07-25 ana
spec rename   core/004 dashboard/002          2026-07-25 ana
```

→ pushes to main (the CAS; succeeds). Then, on her **feature branch**: `git mv docs/specs/core/003-dashboard-shell docs/specs/dashboard/001-dashboard-shell` (and 004 → 002), plus any in-tree reference rewrites. One commit = the whole split is atomic in the registry: no observer ever sees half a split.

**T2 — ben allocates concurrently.** Ben's `/jim:spec` fetched main *before* ana's push and computes next core = 006. His registry push is **rejected** — the ref moved (CAS failure), even though his line doesn't textually conflict with hers: the CAS is on the branch ref, not on file lines. He refetches, now sees the split records, recomputes — still 006 (the split consumed nothing new in core) — reapplies, pushes, succeeds:

```
spec allocate core/006 rate-limiting 2026-07-25 ben
```

Lesson: rejection ≠ collision. Sometimes the recompute yields the same answer and the retry just lands.

**T3 — ben resolves a renamed ID.** `show core/003` replays the log forward, tracking the current name: `allocate core/003` … `rename core/003 → dashboard/001` … end of log ⇒ current name `dashboard/001`. Output: *"core/003 → renamed to dashboard/001 (dashboard-shell)."* His local tree still has the old `core/003-dashboard-shell/` path — ana hasn't merged — so content is shown from there with a "move pending" note. Registry-ahead-of-content, same as reservation.

**T4 — edit-vs-rename warning.** Ben opens core/003's spec.md to fold in review findings. The skill's pre-edit registry fetch sees the rename record → warns: *"core/003 was renamed to dashboard/001 by ana; the directory move is pending on an unmerged branch — coordinate or rebase after it lands."* Today this situation surfaces as a silent rename/modify merge conflict weeks later; here it surfaces at edit time.

**T5 — ana merges.** Main's tree now matches the registry: `docs/specs/dashboard/001-…, 002-…`; core keeps permanent holes at 003/004 (consumed forever; next core is 007, unaffected). Ben rebases; git's rename detection carries his spec.md edit into the new path.

**T6 — months later, a repartition renames the group.** `dashboard` → `ui` is ONE record:

```
group rename dashboard ui 2026-09-14
```

No per-spec records needed. Ben's June trailer `Spec: core/003` — frozen in git history forever — still resolves: forward replay gives `core/003 → dashboard/001` (spec rename), then `dashboard/* → ui/*` (group rename) ⇒ **ui/001**. A two-hop chain, months apart, fully dereferenceable from five greppable lines.

**Resolution algorithm** (POSIX-friendly): single forward scan of the log; hold `current = queried ID`; for each `spec rename src dst` with `src == current`, set `current = dst`; for each `group rename g h` where `current` starts with `g/`, rewrite the prefix. Each record applies at most once, in file order — so even a rename cycle (A→B, later B→A as a revert) terminates: forward replay is cycle-safe by construction, and "revert" is just another rename record, no special record type.

**Edge noted — abandoned rename**: ana never merges. Registry says renamed; content never moves; main still has `core/003-…/`. Harmless but inconsistent — exactly what a `reconcile` verb lists ("renames whose content never landed"), fixed by either landing the move or appending the counter-rename.

## Gaps and gotchas (2026-07-25)

### G1 — Group-name reuse breaks forward replay (correctness hole)

After `group rename dashboard ui`, nothing stops someone from creating a *new* group named `dashboard`. Then `dashboard/001` has two possible referents: the pre-rename spec (now `ui/001`) and the new group's first spec — and a citation carries no date to disambiguate. Naive top-of-log forward replay would also incorrectly rewrite the *new* `dashboard/001` via the old group-rename record. Two-part fix:

- **Group names are allocate-once too**: groups get `group allocate` records; a renamed-away name is consumed forever. (Bonus discovered: group *creation* is a third un-coordinated namespace we hadn't listed — two users can create the same group concurrently today. The registry guards it for free.)
- **Replay starts at the queried ID's allocate record**, not at the top of the log. With unique allocation guaranteed, resolution is unambiguous.

### G2 — The registry only works if it's the only door

Nothing stops someone hand-creating `docs/specs/core/007-foo/` without the allocator (old habits, non-jim tooling). The allocator later issues 007 → collision returns. Allocation must be the sole path to an ID — enforced by detection, not trust: a mechanical check (every spec dir / issue ordinal on the coordination branch has a matching registry record; jim:verify-style, CI-able). Rogue entries get adopted into the registry or flagged.

### G3 — Ledger erosion: force-push and revert

A force-push or `git revert` on the coordination branch can silently *un-append* registry lines → next allocator recomputes from the truncated log and reissues consumed ordinals. The mechanism's integrity needs:

- Branch settings: the coordination branch wants **direct pushes allowed, force-push and deletion denied** — an unusual middle protection profile worth documenting.
- A mechanical growth guard: on every fetch, old registry content must be a byte-prefix of new. Cheap to check; screams loudly on erosion.

### G4 — Busy main: contention, merge queues, required checks

The registry CAS races with *all* pushes to the coordination branch, not just other allocations — on an active repo, every PR merge bumps main and forces a (cheap) retry. Worse: merge queues and required status checks commonly make main **not directly pushable at all**, independent of classic branch protection. In practice `jim/registry` is the de facto default; `coordination_branch = main` fits only small low-traffic teams.

### G5 — Fork-workflow contributors can't allocate

The whole mechanism presumes push access to the shared repo. Fork-based contributors (open-source PRs) push only to their fork — allocating there coordinates nothing. They need provisional mode + maintainer-side reconcile at PR review, or the future service backend. The git mechanism's honest scope: **teams with shared write access**.

### G6 — Citations and current names permanently diverge

Ledger permanence means stale citations are *fine* — but they accumulate: after renames, `grep dashboard/001` no longer finds documents citing `core/003`. Every consumer of an ID (skills, humans, plain grep) must become resolution-aware, or jim opportunistically normalizes stale citations in tree content when it touches a file anyway (a lint/reconcile behavior). Search UX degrades silently otherwise.

### G7 — Push mid-interview: auth and policy hangs

Allocation fires inside `/jim:spec`'s interview flow. A push that triggers an interactive auth prompt (or hangs) mid-interview is bad UX; a sandbox that blocks agent pushes by policy fails it entirely. Mitigations: non-interactive git (`GIT_TERMINAL_PROMPT=0`), treat `on_unreachable` as "cannot **publish** allocation" regardless of cause (network, auth, policy), and allocate as late in the flow as possible so a failure doesn't waste the interview.

### G8 — Changing the coordination config is itself a coordination problem

jimconf is read per-branch; if the team moves `coordination_branch` mid-project, stale branches allocate against the old location → split-brain. Cheap fix: a `moved-to` tombstone file left at the old registry location; the allocator follows or refuses.

### G9 — The durable ID needs guarding too

Date+slug issue IDs collide across users (same day, same natural slug — `20260725-fix-login` twice). Since the allocator is already the gate, its recompute step should validate the durable ID as well and suffix on collision. One guard, both ID forms.

Minor notes: record dates are informational only — **file order is authoritative**, never sort by date (user clocks skew); feature branches carry stale registry copies harmlessly (merge-base identical → git auto-resolves), but an accidental branch-side edit to the registry should be caught by the G2/G3 checks; ledger growth is unbounded but trivially small at jim scale; the coordination branch is typically *less* protected than main, so IDs must never serve as authorization or integrity anchors.

## Open questions

1. ~~Sync-at-allocation UX~~ → configurable (`on_unreachable`), default leaning `fail`.
2. ~~Issue placement~~ → configurable (`issue_placement`).
3. Gaps in ordinals acceptable? (Working assumption: yes — unconfirmed but unobjected.)
4. ~~`rename`/`split` under allocate-once~~ → expanded above; leaning Shape 1 (redirect ledger).
5. Registry granularity: one append-only file per kind? per group? (Leaning: per kind; sharding premature.)
6. ~~Local vs origin tier~~ → origin out of the box; local tier only as no-remote degradation.
7. **Migration** (agreed needed): a `seed` step builds the registry from existing spec dirs + issue INDEX. Sub-fork: historical *duplicate* issue ordinals — renumber the younger dupes once at seed time (breaks some old handles, once, then clean), or grandfather them with dup-tolerant resolution (`show #42` may return two candidates) forever?
8. ~~Reservation-only read path~~ → acceptable ("reserved: <slug>, by <user>"); teams that dislike it configure content placement / central branch.
9. Does `/jim:partition`'s materialization step become an allocator batch operation? (Scoping question for when this becomes a spec.)
