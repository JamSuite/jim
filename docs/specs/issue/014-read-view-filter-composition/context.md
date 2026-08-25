# Context — read-view filter composition

A **mid-flight** handoff, written immediately before `/jim:build` and
immediately before this session's context is compacted. Unlike the closing
handoff in `013-recorded-identity-schemes/context.md`, this is not a cold start
for someone else — it is a warm restart for the same work, at a known point.

It records what is **expensive or impossible to re-derive from the artifacts**:
facts established by running things, two corrections made mid-flight that a
re-reading could easily reverse, and the environment traps that cost time. What
`spec.md`, `research.md`, `security.md` and `plan.md` already say well is
pointed at, not repeated.

---

## 1. Where this stands

Everything before the build is done. Nothing is committed.

| artifact | state |
| :--- | :--- |
| `spec.md` | `approved` — 35 acceptance criteria |
| `research.md` | `Needs PM Review` |
| `security.md` | `Needs Plan Review` — two passes; findings 1–8 resolved, 9–12 routed into the plan |
| `plan.md` | `approved` — 21 tasks, 11 design decisions, 35/35 AC coverage |
| `ledger.md` | spec → research → sec → spec finished → plan → sec → plan finished |

**Next action:** `/jim:build docs/specs/issue/014-read-view-filter-composition`.
No gate blocks it, but the reason is no longer the one this doc first recorded.
`require_security` and `auto_security` are now `true`, so the build's Step-2
gate is live — it passes only because `security.md`'s `reviewed_phases` already
includes `plan`. `require_review` and `auto_review` are `true` as well, which
makes `/jim:review` a blocking completion phase: the plan cannot be marked
`complete` until that review produces a `review.md`.

Two frontmatter values look wrong and are not — the same trap 013's handoff
records:

- **`security.md` stays `Needs Plan Review`.** The field records what a review
  *found*, not whether it was acted on. All four open findings are routed into
  the plan. Do not "fix" it.
- **`research.md` is `Needs PM Review`** because Peer Feedback carries the
  `VISION.md` contention. It is explicitly non-blocking and the issue is filed.

### Where this sits in the larger arc

Spec 014 is the **third** spec out of
`docs/brainstorms/20260817-issue-epics-and-enhanced-filtering.md`, after 012
(schema and state model) and 013 (recorded identity schemes). Two remain, and
this decomposition lives nowhere but here:

1. **Epics** — 012 shipped `type` and `part-of`; nothing produces or consumes an
   epic. There are 0 epics and every `part-of` is `[]`. Missing: filing one
   (`new.sh:331` hardcodes `type: issue`), joining one (no transition verb
   mutates `part-of`), the derived roster and progress, an INDEX Epics section,
   and enforcement of the one-level nesting rule.
2. **Honest stats** — completion as `done / closed` rather than `closed / total`,
   with `wontfix` / `obsolete` / `duplicate` surfaced as their own signals.

**014 was deliberately sequenced first** so that both later increments build
*views* rather than a second parse surface. That ordering is the reason
`--type` and `--epic` ship here against fields that are schema-valid and empty.

## 2. Read order for rebuilding depth

1. `plan.md` — the 11 design decisions carry nearly all the reasoning.
2. `security.md` § Findings 9–12 and § Artifact Misalignment — these drove
   tasks 8 and 9 and DD 1, 5, 11.
3. `research.md` § Local Patterns — the finding that reshaped the work (below).
4. `spec.md` § Open Questions — the four forks and how each resolved.
5. `docs/specs/issue/000-blueprint/spec.md` — the group's Provides and
   Invariants; the plan's Constitution Check maps against it directly.

## 3. Facts established by running things

Every one of these was verified in-session against the real scripts. Do not
re-derive them from reading code alone — two of them contradict what a careful
reading first suggested.

**The substrate is smaller than the spec implies.** `parse_relations`
(`index.sh:178-207`) is type-agnostic — it emits any `<type>: [<slugs>]` pair
under `relations:` — so `part-of` is *already* rendered into the index's Graph
section, as is `depends-on`. Only four scalars (`type`, `filed-by`,
`claimed-by`, `outcome`) need to reach the Issues row. `parse_scalar_fields`
(`index.sh:153-171`) already allowlists all four; `index.sh:489-492` already
stores them. Nothing parses them into a row today.

**Measured widening cost:** +16,544 bytes on a 140,061-byte index → **+11.8 %**.
Measured by summing the four frontmatter fields across `docs/issues/*.md`, not
estimated.

**Issue #18 was already fixed** before this spec existed. `render.sh list 17`
refuses with a non-zero status and creates nothing. My first answer in this
session claimed 014 would fix it; that was wrong. It is now `closed` /
`outcome: obsolete` (num 18).

**A read verb does write to the checkout.** `render.sh list docs` binds `docs`
as the collection (trailing argument that is a directory) and then writes
`docs/INDEX.md` into it. Verified by removing the file and re-running: it comes
back. `ensure_index`'s `[[ -d "$dir" ]] || return 0` guard prevents creating a
*directory*, not writing an index into an existing one. **A stray `docs/INDEX.md`
was produced during this session while probing and has been removed** — if it
reappears in `git status`, that is the cause, and it is not a build artifact.

**`dir_given` breaks under both new argument shapes.** Probed against the real
logic in isolation:

| invocation | `dir_given` | effect |
| :--- | :--- | :--- |
| `list --label auth` (with `./auth` existing) | TRUE | routing declined — serves the working tree |
| `list --label nosuchdir` | false | routes correctly |
| `list open high` | false | routes correctly |
| `list open` | false | routes correctly |
| `stats --spec x` | TRUE | routing declined — **any** filter breaks it |

Confirmed live: `render.sh stats --spec issue/011` already reports
`error: '--spec' is not an existing collection directory`. This project runs
`issue_placement=branch`, so both are day-one, not latent. Task 8 exists for
this and nothing else.

**The Graph slug narrowing is real but latent here.** `render.sh:324` and
`:703` both match `[a-z0-9-]+`; `is_valid_id` (`render.sh:560`) allows
`^[A-Za-z0-9][A-Za-z0-9._-]*$`. Every id in this collection is lowercase
date-prefixed, so nothing is dropped today; under `issue_id_prefix=project` it
would be. Filed as
`20260825-graph-edge-readers-narrow-slugs-below-what-is-valid-id-allows`
(num 381) and fixed by task 4 rather than deferred.

**`need_operand` already exists** at `migrate.sh:73-86`, refusing both a missing
operand and an operand that is another known flag. Task 5 writes a sibling, not
a copy — see DD 4 for why a sync marker would assert a falsehood.

## 4. Two corrections — do not silently reverse them

Both are recorded inline in the artifacts, but a fresh reading of the code could
plausibly re-derive the original wrong version.

**Security Finding 1 was rewritten twice.** Its first form claimed the parse
ordering was the only guard and that a bound directory would reach `index.sh`'s
`mkdir -p`. That is false — `ensure_index` refuses a non-existent directory. The
*first correction* then overcorrected, calling the residue "merely a silent
wrong answer." Also false: the retarget writes an `INDEX.md` into whatever
existing directory it lands on, which was verified by running it. The finding
now carries both steps of the correction. **The current text is the right one.**

**Issue #18 is not in this spec's scope.** The brainstorm predicted that strict
bare words would incidentally fix the stray-directory bug. The fix landed
independently first. Handoff Insight 6 in `spec.md` says so; the AC preserves
and widens an existing guard rather than creating one.

## 5. Decisions whose reasoning lives only here

- **Widening the index row over a sidecar or a direct frontmatter read** was
  chosen on measured cost: +11.8 % against roughly +100 % for a second
  representation, and a third frontmatter parser for the direct read. The full
  comparison is in `research.md` and DD 2, but the *rejection* of the sidecar
  turned on the group's invariants being written around there being exactly one
  index — that reasoning is in DD 2's Rejected clause and nowhere else.
- **`--cols` and `unblocked` were explicit additions requested by the
  developer**, beyond what the first cut proposed. They were raised as out of
  scope and pulled in deliberately. Do not treat them as scope creep to trim.
- **`identity-validated-before-record` is not engaged, and that is stated rather
  than ticked.** The invariant governs identities that are *written*; a person
  filter compares and never records. The plan routes query values through the
  same `identity.sh normalize` anyway, so the definition stays single. See the
  Constitution Check's note.

## 6. Traps and environment

- **The Bash tool's working directory persists between calls.** A `cd docs/issues`
  early in this session broke a later relative-path invocation of a repo-root
  script. Prefer absolute paths or `cd /mnt/src/jim && …`. This is the same trap
  `docs/notes/notes.md` records for `index.sh`.
- **The coordination remote is unreachable from this VM.** `jimalloc allocate`
  returns a `P-` provisional identity; the developer realizes it on the host.
  Already done for this spec (`P-20260825-read-view-filter-composition` →
  `issue/014`, landing on the ordinal `peek` had advised) and for the six issues
  filed this session (nums 380–385). No pending identities remain.
- **`issue_placement=branch` with `issue_placement_ack=false`**, so `new.sh`
  requires `--reviewed` and the candidate batch always takes the interactive
  path. `--auto` exits 4.
- **Agent fan-out is authorized for this session** — the developer granted it at
  the build's start. The review and verify surfaces fan out on `sonnet` with a
  cap of 20 (`review_model` / `review_fanout_cap`, `verify_model` /
  `verify_fanout_cap`). The grant is per-session rather than standing.
- **Never hand-edit `ARCHITECTURE.md`** — it is refreshed by the build-completion
  gate via `/jim:arch`.
- **Do not push.** Git push is host-only from this sandbox.
- `wc -w` counts markdown syntax and backticked paths, so `research.md`'s
  1500-word budget is approximate; it reads at ~1540 by that measure.

## 7. Resuming the build

Run `/jim:build docs/specs/issue/014-read-view-filter-composition`.

Worth watching:

- **Task 8** is the one neither the spec nor the first security pass saw. It is
  the only task addressing a defect that is live today rather than introduced by
  this feature.
- **Task 9** asserts *no `INDEX.md` was written*, not merely *no directory was
  created*. The weaker assertion passes against the bug described in § 3.
- **Task 4** changes two existing surfaces (the stats blocking rollup and the
  insights graph) rather than only adding new ones, so its blast radius is wider
  than its task text suggests.
- Tasks 10–18 all depend on task 10 or earlier; the dependency notes are
  accurate as written and were renumbered twice, so trust the notes over any
  remembered numbering.

**Uncommitted state at handoff** (branch `feat/issue-epics`, HEAD `3c6e347`):

```
 M docs/issues/20260627-read-verb-list-creates-a-stray-directory-from-a-non-filter-arg.md
 M docs/issues/INDEX.md
 M docs/specs/ledger.md
?? docs/issues/20260825-*.md                       (6 files, nums 380–385)
?? docs/specs/issue/014-read-view-filter-composition/
```

**One open item unrelated to the build:** `VISION.md:67` still reads "not as a
team-coordination primitive" while 012 shipped `claim` / `release` and 014 makes
the holder queryable. Filed as num 380. `/jim:spec`'s alignment gate will raise
it against every future spec in this area until the vision is amended.
