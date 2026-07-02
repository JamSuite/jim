# Brainstorm: Issue command consolidation — `/jim:issue` subcommands

*2026-06-03*

## The idea

Today there are two commands: `/jim:issue` (capture) and `/jim:issues` (trend
view). Consider collapsing them into a single `/jim:issue` with subcommands.
Leaning toward an **explicit capture verb** to keep dispatch clean.

## Starting context

- `/jim:issue` is an **LLM skill** (`agent: pm`): drafts from conversation,
  confirm-or-edit moment, writes the file, regenerates INDEX.md.
- `/jim:issues` is a **deterministic wrapper** (no `agent:` binding, mirrors
  `/jim:conf` / `/jim:file`): runs `render.sh`, prints output verbatim.

### Subcommand precedent in jim

Four skills use subcommand dispatch — all deterministic or meta:
`/jim:conf`, `/jim:file`, `/jim:meta-test`, `/jim:meta-matrix`. None mix an
LLM-narrative mode with a deterministic mode under one verb namespace.

### Tensions surfaced so far

- **Mixed execution model.** A merged `/jim:issue` would be jim's first skill
  dispatching between an LLM-drafting path (capture) and a pure-bash render path
  (view). Novel for jim.
- **Name collision.** Today `/jim:issue auth swallows 401s` passes the whole
  string as a free-form subject. Adding verbs makes `/jim:issue list` ambiguous
  (verb vs. subject). The explicit-capture-verb choice resolves this.

### Correction: no runtime execution-model conflict

The `agent: pm` field on `/jim:issue` is **documentation only** (jim convention:
no `context: fork`). The skill body runs in the main conversation loop either
way. So a merged command has no real runtime fork conflict between an
LLM-capture path and a deterministic-view path — both run inline. The merge is
about conceptual clarity, `allowed-tools` union, and the doc-level `agent:`
label, not a runtime barrier.

## Decided shape

### Scope: minimal — viewing & sense-making

Focus is the **read / sense-making surface**. No lifecycle mutation
(`close` / `open` / `edit`) in this round — issues are still closed via direct
file edit, per 017. Capture stays as-is, just behind an explicit verb.
`/jim:issues` is hard-removed (no deprecation alias).

### Verb surface

| Command | Behavior | Kind |
| :-- | :-- | :-- |
| `/jim:issue` (bare) | Help — list of subcommands | deterministic |
| `/jim:issue add <subject>` | Capture (LLM draft → confirm-or-edit → write → regen) | LLM |
| `/jim:issue list` | All issues (flat enumeration) | deterministic |
| `/jim:issue list <priority\|status>` | Filtered list (e.g. `list open`, `list high`) | deterministic |
| `/jim:issue stats` | High-level counts (open/closed, by priority, by label) | deterministic |
| `/jim:issue trends` | Clusters (by origin/label) + blocking (by out-degree) | deterministic |
| `/jim:issue show <id>` | View the full issue file | deterministic |

### Notes / observations

- **One LLM verb (`add`), the rest deterministic.** The skill becomes a hybrid:
  SKILL.md branches `add` → LLM drafting; everything else → bash render engine.
  Natural fit for extending `render.sh` into a subcommand dispatcher (mirrors
  `/jim:file` → `jimfile.sh` `case`), with the SKILL.md only special-casing
  `add`.
- **`list <priority|status>` disambiguation is free** — the value sets are
  disjoint (`open`/`closed` vs `critical`/`high`/`medium`/`low`), so a single
  positional arg resolves unambiguously.
- **Read-surface decomposition.** Today's `/jim:issues` trend view bundles
  summary counts + clusters + blocking. The new surface splits that:
  `stats` = counts, `trends` = clusters + blocking, and adds `list` (flat
  enumeration) + `show` (single file).
- **`add` replaces free-text capture.** Old muscle memory
  `/jim:issue <subject>` no longer captures — must be `/jim:issue add <subject>`.
  Accepted cost of explicit verbs.
- **Unknown first token** (e.g. `/jim:issue fix the thing`) → error + show help,
  NOT fall-through to capture (preserves clean dispatch).
- **Ripple:** the 018 batch protocol's "review later via `/jim:issues`" pointer
  (inlined in 7 skills) must change to the new review entry point
  (likely `/jim:issue list`).

## Refinements (round 2)

### `trends` is an LLM-analytical view, not deterministic

Big reframe. `stats` and `trends` are NOT two renderings of the same data —
they're different kinds of work:

- **`stats`** — deterministic. Counts (open/closed, by priority, by label) +
  basic clustering. Roughly today's `/jim:issues`. Pure `render.sh`.
- **`trends`** — **LLM-analytical**. Thicker, prose-driven: describe the
  clustered areas, analyze *why* an area is of interest, and reason about
  sequencing — why is this area a better candidate to implement before others?
  How does it slot into the development timeline? A large cluster signals
  pressure building in an area; the value is interpreting the bigger picture and
  guiding "the right thing at the right time," not just printing counts.

**Motivation — scale.** Even a small project accumulates dozens→hundreds of
issues quickly. Deterministic counts don't help a developer *choose what to work
on next*. `trends` is the prioritization/sequencing advisor.

**Consequences:**
- The skill has **two LLM verbs** (`add`, `trends`); `list`/`stats`/`show`/help
  stay deterministic over `INDEX.md`.
- `trends` is the **first concrete consumer reading issue bodies into agent
  context** — the exact case 017 plan DD #8 / 018 AC-S2 anticipated. Must apply
  the `<untrusted-issue-content>` wrapping discipline (already in skill prose).

### `list` — terse, grouped, configurable default

- Terse rows; default **grouped by status**, **sorted by date** within groups.
- The default view is a good **config candidate** (`jimconf.toml`) so each user's
  default `list` aligns with their preference (sort / grouping / columns — TBD).
- Likely the new "review later" entry point from the 018 batch protocol.

### `show` — cleaned-up render, forgiving id

- Cleaned-up view: frontmatter as a header block + body + resolved relation
  links (not a raw `cat`).
- Accept **both** the bare slug (`auth-swallows-401s`) and the full date-prefixed
  id (`20260603-auth-swallows-401s`). Bare-slug collisions across dates need a
  tiebreak (e.g. list the matches).

### Open: mock before build

User wants to see mockups of `stats` vs `trends` before committing to a build —
the distinction is worth making concrete first.

## Mockups (exploratory — not final)

### `/jim:issue` (bare → help)

```
jim issue — capture & review discovery artifacts

  add <subject>          capture a new issue from the conversation
  list [priority|status] terse list, grouped by status (default)
  stats                  counts + clustering (deterministic)
  trends                 analytical view — pressure areas & sequencing
  show <id>              view a single issue (cleaned-up)

  Issues live in docs/issues/. Close one by editing its `status:` field.
```

### `/jim:issue list`

```
Issues — docs/issues/   (47 open · 12 closed)

open (47)
  #106  2026-06-03  critical  credential-leak-log-trace
  #105  2026-06-03  high      auth-middleware-swallow-401
  #103  2026-06-01  medium    csrf-token-rotation
  #98   2026-05-29  low       audit-log-tamper-check
  …

closed (12)
  #91   2026-05-28  high      session-fixation-vector
  …
```

`show 106` (number), `show cred` (prefix), or `show
20260603-credential-leak-log-trace` (full id) all resolve the same issue.

`/jim:issue list open` → only the open group. `/jim:issue list high` → only
`priority: high` rows (across status). Disjoint value sets disambiguate the arg.

### `/jim:issue stats`  (deterministic — ≈ today's /jim:issues)

```
Issue Collection — docs/issues/

  Open: 47    Closed: 12

  By priority      By label                By origin
    critical   2     auth         9          docs/specs/jim/016-sec/   5
    high      11     middleware   6          docs/brainstorms/…        2
    medium    20     security     6          (unattributed)           18
    low       14     session      4

  Blocking (top by out-degree)
    credential-leak-log-trace      blocks 4
    session-fixation-vector        blocks 2
```

### `/jim:issue trends`  (LLM-analytical — thicker)

```
Issue Trends — 47 open · 12 closed                       2026-06-03

Pressure is building around three things. My read on what to build next:

1. A message queue is becoming load-bearing.        ← LATENT CAPABILITY
   8 issues across 4 different labels (ingest, notifications, audit,
   rate-limit) independently point at async/decoupled delivery. None of
   them names a queue — each is shippable today with an in-memory stopgap.
   But that's the trap: every stopgap is a future refactor. The longer
   this waits, the more features get built on the wrong foundation.
     · 20260601-notification-fanout-blocks-request
     · 20260529-audit-write-on-hot-path
     · 20260527-ingest-backpressure
     · … (5 more)
   → Strong candidate to build NEXT, ahead of the 8 features that lean on
     it. Building it now avoids refactoring all 8 later.

2. Auth / session handling — densest explicit cluster.
   13 issues, 2 critical. `credential-leak-log-trace` (critical) blocks 4
   downstream items via explicit relations. This one is already entangled
   in the graph, not latent — the blocking root gates the rest.
   → Resolve the blocking root first; the cluster unlocks behind it.

3. Index / tooling hygiene — background noise.
   5 low-priority issues from build-phase candidate batches. No pressure,
   no convergence — pure trend signal.
   → Defer or batch into a hygiene pass.
```

Note the difference from `stats`: item 1 is invisible to deterministic
clustering — those 8 issues share no label and no `relations:` edge. Only
semantic reasoning surfaces the convergence. That's the core value of the
LLM verb.

## Refinements (round 3)

### Pressure = latent structural convergence (NOT time)

Chose option (c): no time axis. Time is unreliable as a signal — priorities
shift, a solo dev takes vacation and "last N days" goes stale.

**Definition of pressure:** a cluster forming around a latent theme or
capability. Multiple issues — often across *different* labels/origins, with no
explicit `relations:` edge between them — converge on the same missing
load-bearing thing (canonical example: a message queue). Each issue is
individually shippable with a stopgap (in-memory), but every stopgap is a
future refactor / security gap / deferred feature. The more issues converge,
the higher the pressure to build the load-bearing thing *now* and avoid
refactoring N already-built features later.

**Why this forces `trends` to be the LLM verb:** the convergence is *semantic*.
Deterministic clustering sees explicit labels and relation edges; it cannot
notice that 7 issues with different labels all imply "we need a message queue."
That inference is the entire point of `trends`, and only an LLM can make it.

### Input boundary: index + selective full reads

`trends` reasons primarily over `INDEX.md` (cheap, structured metadata) and
pulls **full issue bodies selectively** — only for the issues in the candidate
pressure clusters it's analyzing. Never "read every body every time."

### Analysis cache + delta integration

To make repeated `trends` runs cheap at scale:

- Persist the last analysis as a **cache artifact** (e.g.
  `docs/issues/.trends-cache.md`), alongside a snapshot of the collection state
  it was computed against (issue id → status/updated, or a hash).
- On the next `trends` run: read the cached analysis + compute the **delta**
  (issues added / closed / reprioritized since the cache) and integrate only
  the delta into the prior analysis — rather than re-reading the whole
  collection.
- Open sub-questions:
  - Force-refresh escape hatch (e.g. `trends fresh` / a flag) to recompute from
    scratch.
  - Large-delta threshold → full recompute instead of incremental.
  - Cache is jim-generated but derived from untrusted bodies; re-reading it
    carries forward any injected content the prior run reproduced. Low concern,
    note it.
  - This makes `trends` a *writer* (of its own cache), though still read-only
    w.r.t. the issue collection — same posture as auto-generated `INDEX.md`.
  - Does the cache ship in v1, or is it a fast-follow once `trends` exists?

## Remaining open items (for spec/plan)

- **Config keys.** `list` default view (sort / grouping / columns); possibly a
  `trends` cache toggle. Naming TBD (bare vs `auto_` per jim convention).
- **`show` tiebreak.** Bare-slug collision across dates → list the matches and
  ask, or require the full id.
- **Script relocation ripple.** `index.sh` + `render.sh` live under
  `skills/issues/scripts/`. Removing the `issues` skill means moving them to
  `skills/issue/scripts/` — which touches the `${CLAUDE_PLUGIN_ROOT}/skills/
  issues/scripts/index.sh` references inlined in all 7 batch protocols plus
  `/jim:issue`'s own write path. Alternatively leave the scripts in place
  (scripts dir without a SKILL.md) — uglier but zero reference churn. Decide at
  plan time.
- **Batch-protocol pointer.** "review later via `/jim:issues`" (×7) →
  `/jim:issue list`.
- **`render.sh` → dispatcher.** Grow it into a subcommand `case`
  (`list` / `stats` / `show` / help) mirroring `jimfile.sh`; SKILL.md branches
  `add` and `trends` to the two LLM paths.

## ID scheme review

### Critique of the current scheme (`YYYYMMDD-slug`)

- 017 chose the date prefix for "collision-tolerance under parallel feature
  branches / multi-agent worktrees." But day-resolution barely helps: two
  branches both creating `20260603-fix-login.md` collide identically on merge —
  the date only avoids collision when the *slugs* differ. Real cross-branch
  safety needs a **random** component, not a coarse timestamp.
- The date's genuine value is chronology + provenance + reducing same-slug
  collisions to same-*day*-same-slug — weak collision avoidance, not the
  headline feature it was sold as.
- `show <id>` is hampered: a slug id must be copy-pasted; can't be typed from
  memory like a short number (`show 105`).

### Use cases the id serves

1. Filename uniqueness under decentralized/parallel creation.
2. Human reference / typing in `show <id>`.
3. Stable cross-reference in `relations:` (`blocks: [X]`) and `[[wikilinks]]`.
4. Sorting / chronology / provenance in `list` / INDEX.
5. Mention in conversation / commits / external docs (short AND stable).

### Scheme × use-case matrix

| Scheme | 1 collision-safe | 2 typeable | 3 stable ref | 4 chrono |
| :-- | :-- | :-- | :-- | :-- |
| Sequential int (`105`) | ✗ worst | ✓ best | ✗ breaks on merge | ➖ |
| Date+slug (current) | ➖ weak | ➖ copy-paste | ✓ | ✓ |
| Hi-res timestamp+slug | ✓ | ✗ long | ✓ | ✓ |
| Short random (`k7m2`) | ✓ | ➖ opaque | ✓ | ✗ |
| Slug only | ✗ | ➖ prefix | ✓ | ✗ |

### Two decisive findings

1. **Date critique is correct.** Coarse date ≠ collision safety. Cross-branch
   safety requires randomness or post-merge reconciliation.
2. **The relations graph forbids sequential ids *as the reference key*.** If
   `id` is sequential, two branches minting `106` force a renumber on merge,
   and every `blocks: [106]` / `[[106]]` edge rots. Date+slug and hashes are
   assign-once-never-change → never break references. Sequential is the worst
   choice for use case 3.

### Resolution: decouple reference key from display handle

Use case 2 (typing) and use case 3 (stable ref) need NOT be the same token.

- **Reference key** (filename, `relations:`, `[[wikilinks]]`): stays a stable,
  assign-once, collision-tolerant slug-based id. The graph keys off this.
- **Display handle** for `show`: an ergonomic alias resolved at lookup,
  never stored in the graph.

Three ways to deliver an ergonomic `show` without changing the reference key:

- **(i) Prefix / fuzzy match** — `show cred` → `credential-leak-log-trace` if
  unique (git short-hash UX). No new state, works today. Ambiguous → list
  matches. *(Recommended baseline.)*
- **(ii) Ephemeral list ordinal** — `list` numbers rows `1..N`; `show 5` = row 5
  of the most recent list. Short & numeric, but unstable across runs.
- **(iii) Persisted display ordinal** — sequential number stamped in frontmatter
  at creation, *alongside* the slug. Collisions only make `show 106` ambiguous
  (→ list both), never break a relation edge (relations key off the slug).

### Independent lever: strengthen collision safety

Orthogonal to ergonomics — swap the coarse date for a short random suffix:
`20260603-a3f9-auth-swallow-401.md`. Keeps chronology, gains real cross-branch
safety, costs a slightly longer filename the user never types.

### DECIDED

- **Filename / reference key:** keep `YYYYMMDD-slug` unchanged. `id:` stays the
  date-slug; relations + wikilinks keep keying off it. (Collision-scheme change
  deferred — date+slug is good enough for the reference key.)
- **`show` resolver: persisted ordinal (mode i + ii + iii).** Add a sequential
  `num:` field, stamped in frontmatter at creation, stable across runs. `show`
  accepts: a number (`show 106`), a bare slug / prefix (`show cred`), or the
  full id. Plus list-relative ephemeral ordinals from the most recent `list`.
  `num` is **display-only** — never used in `relations:` / `[[wikilinks]]`, so a
  cross-branch duplicate `num` is harmless (→ `show 106` lists both, never
  breaks the graph).

### Persisted-ordinal mechanics (for spec/plan)

- **Assignment:** at `add` time, `num = max(existing num across collection) + 1`.
  Decentralized scan, no counter file — consistent with "duplicates are
  harmless." Where the max-scan lives (extend `jimfile.sh`, a new helper, or
  `index.sh`) is a plan-time call; the scan reads `num:` frontmatter only.
- **Schema:** add `num:` to the 017 issue template; `index.sh` parses it;
  `list` / `stats` / `show` display it (likely a leading `#106` column in
  `list`). `num` ascends with creation, so sorting by `num` ≈ chronological.
- **`show` resolution precedence:** pure-integer arg → `num` lookup
  (0→not found, 1→show, >1→list matches & ask); else exact id → exact slug →
  unique prefix → ambiguous-prefix lists matches. Edge: a purely numeric *slug*
  (issue literally titled "401") collides with num addressing — pure-int =
  num wins; reach such a slug via prefix of its full date-slug. Note in spec.
- **Legacy backfill:** existing `docs/issues/` files predate `num:`. Open
  decision: (a) assign going-forward only, legacy addressable by slug; (b)
  one-shot backfill by created-date order; (c) `index.sh` derives a display num
  for un-numbered issues. jim's own dogfood collection is small → a one-shot
  backfill is cheap. Decide in spec.

## Parallel-work / implementation-independence analysis

Question raised: can we identify issues that are **isolated & independent in
implementation**, so they can be parallelized with low merge-conflict risk? Is
that safe from issue context alone, or does it need a codebase view?

### What determines "safe to parallelize"

Merge-conflict independence = disjoint code footprints. Three layers, hardest
last:

1. **File-set overlap** — dominant signal; disjoint files ≈ ~0 textual conflict.
2. **Shared hot files** — lockfiles, config, route tables, DI containers,
   barrel/index files, schema. Conflict magnets even across unrelated features.
   So "zero conflict" is rarely real — target "disjoint *core* footprints,
   tolerate trivial manifest conflicts."
3. **Logical coupling** — disjoint files but a shared contract (A changes an
   interface B consumes). Textual merge succeeds, build breaks. Invisible to
   file-overlap analysis.

### What issue context alone gives: a weak, asymmetric heuristic

Better at ruling *out* than ruling *in*:

- `relations:` graph → declared coupling rules a pair OUT; absence of a relation
  does NOT imply independence (relations are author-declared, incomplete).
- labels/origin → same label weakly implies same area (overlap); label-
  disjointness is an UNRELIABLE independence signal (cf. message-queue: different
  labels, one capability).
- body prose → LLM can guess components, but that's speculation about a
  non-existent diff.

**Asymmetry drives the design:** a false "independent" is the expensive error
(parallel work collides, trust erodes). → conservative bias: assert independence
only at high confidence, always "likely safe — VERIFY," never a guarantee.

### Real determination needs a codebase view

Fidelity ladder:

| Tier | Input | Output | Cost |
| :-- | :-- | :-- | :-- |
| 1 | Issue context (graph + labels + bodies) | *Candidate* isolated nodes; reliably flags declared coupling | cheap (fits `trends`) |
| 2 | + codebase: predict per-issue file/symbol footprint, check disjointness | Real independence signal + confidence | heavy (≈ research probe per issue) |
| 3 | + git-history co-change analysis | Catches hidden coupling + hot-file magnets footprints miss | medium, deterministic |
| 4 | actual diffs | ground truth — but defeats the purpose | n/a |

**Inherent ceiling:** even tier 2–3 yields a *prediction* (impl may sprawl) and
cannot see logical coupling (layer 3). Ceiling = "high-confidence, verify before
commit," NOT "proven conflict-free." This is fundamental, not a tooling gap.

### Scope decision

- **Tier-1 hint → fold into `trends`.** It already does graph analysis; can
  surface "these N issues are graph-isolated → parallel-work candidates,
  footprints unverified." Cheap, honest, conservative.
- **Tier-2 (codebase-aware footprint independence) → its own spec.** Most
  ambitious item discussed. Composes with jim's `Explore` / `/jim:research`
  machinery (footprint probe per candidate, then disjointness + hot-file +
  co-change check). Needs repo access; needs careful "predicted not proven" UX.
  Out of scope for the consolidation spec — file as a future-spec issue.

### `/jim:issue show <id>`

```
┌─ #105 · 20260603-auth-middleware-swallow-401 ───────────────┐
│ status   open            priority  high                      │
│ labels   auth, middleware                                    │
│ origin   docs/specs/jim/016-sec/                             │
│ created  2026-06-03      updated   2026-06-03                │
│ relations                                                    │
│   related-to → csrf-token-rotation                           │
└─────────────────────────────────────────────────────────────┘

## Description

The auth middleware catches 401 responses from upstream and converts
them to 200 before they reach the client. Token expiry is masked.

Surfaced during /jim:sec review of the spec-016 plan.
```
