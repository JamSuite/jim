---
spec: "docs/specs/platform/008-registry-seed/spec.md"
status: Needs PM Review
date: "2026-07-27"
---

# Research: Registry seed from existing artifacts

## Anchors

- `skills/file/scripts/jimalloc.sh:54-317` — the pure record layer the seed reuses:
  `alloc_log_file` (kind→`specs.log`/`issues.log`, :74-80), the record-grammar
  comment (:62-70), the `alloc_encode_allocate_*` encoders (:139-147), and the
  high-water `alloc_next_id_spec` (:247-268) / `alloc_next_num_issue` (:273-290)
  the seed must produce a log consistent with.
- `skills/file/scripts/jimalloc.sh:514-644` — the CAS landing the seed's write
  reuses: `alloc_build_commit` (:514-534, **one logfile per commit**, root-commit
  arm for a new branch), `alloc_local_cas`/`alloc_origin_cas` (:536-560), and the
  retry loop `alloc_cas_append` (:562-644). `JIMALLOC_REGISTRY_DIR` seam at :86-100.
- `skills/file/scripts/jimfile.sh:317-361` — `cmd_next_id`'s spec-group path: the
  seed enumerates dirs the same way (glob `"$group_dir"/*/`, ordinal `${name%%-*}`,
  `sed 's/^0*//'`), and this is the **pre-seed tree scan** AC 2 must match — note
  its vacated-id floor (:338-354) shelling to `jimledger.sh vacated-max`.
- `skills/file/scripts/jimfile.sh:735-793` — `cmd_glob specs [<group>]`, the
  canonical specs-tree walker (lists every dir, incl. `000-blueprint`); `slug`
  (:278-285), `date` (:287-289), `valid-id` (:217-219) the seed calls per token.
- `skills/issue/scripts/index.sh:107-153` — `extract_frontmatter` + the one-pass
  `parse_scalar_fields` (reads `num`, `id`, `created` …); `:285-296` the issue-file
  enumeration (glob `*.md`, exclude `INDEX.md`). The seed reads `issues.log` fields
  from here, not `INDEX.md`.
- `skills/ledger/scripts/jimledger.sh:634-663` — `cmd_vacated_max`, the floor over
  the specs-root ledger's `op=split`/`op=merge` `moved=` pairs — the crux of the
  Peer Feedback below.
- `tests/jimalloc.sh:62-68, 265-286, 364-381` — fixture seam (`run_jimalloc_reg`
  over `JIMALLOC_REGISTRY_DIR`) and git-repo/bare-remote helpers the seed's tests
  reuse; representative cases at `:206-223` (record layer), `:292-304` (local CAS),
  `:419-436` (origin race), `:457-473` (erosion).
- New file: `tests/jimalloc.sh` (extend) — the seed is a `jimalloc.sh` verb, so its
  tests live in the existing allocator test file, not a new one.

## Local Patterns

**Spec identity is path-derived — the seed reads no numbered-spec frontmatter.**
Nothing in jim machine-reads a numbered spec's `group:`/`id:` (`docs/specs/blueprint/018-spec-migration/spec.md:13-40`);
group is the parent dir, ordinal+slug the basename. So `specs.log` reconstructs
from directory names alone; only `issues.log` parses frontmatter (`num`/`id`/`created`).

**One-time migration doctrine — preview-then-apply, all-or-nothing, halt-on-conflict, idempotent.**
Three precedents converge on the same shape:
- `skills/issue/scripts/migrate.sh` (issue-id rederive) — bare run prints a plan +
  `PLAN-HASH` and mutates nothing; `--apply` recomputes the hash and aborts if the
  collection drifted (:164-175); all-or-nothing tmp-stage-then-`mv` with rollback
  (:196-234); idempotent no-op (:188-194).
- `skills/issue/scripts/backfill.sh:1-40` — states the doctrine verbatim: "one-shot,
  opt-in … NOT wired into the verb flow"; idempotent, ordered assignment.
- `skills/partition/scripts/jimpartition.sh:905-1017` — `emit_check` + preflight:
  hard-fail on structural conflict, warn on soft, materialize after a hard human gate.

This directly informs the seed: it should be **preview-then-apply** (which also
answers the spec's open question about a dry-run mode — jim's migration doctrine
is uniformly preview-first) and **halt-and-name on conflict** (already AC 6).

**Test template:** `tests/jimalloc.sh` — record-layer cases drive the pure logic via
`JIMALLOC_REGISTRY_DIR` (no git); landing cases use `alloc_new_repo`/`alloc_new_bare`.

## Security & Performance

- **Untrusted-input surface is smaller but non-empty.** Directory names and issue
  frontmatter are developer-authored, not branch-writable like the registry — but
  a crafted dir name (`--foo`, `..`, ref metachars) still becomes a git argument,
  so AC 9's revalidation through `jimalloc.sh`'s `valid-id` boundary before any git
  use stands (mirrors `jimalloc.sh:102-119`). No `source`/`eval`; grep/sed/awk only.
- **Atomicity vs. the one-file-per-commit builder.** `alloc_build_commit` sets a
  single logfile; AC 4 wants both logs seeded as one all-or-none commit. The plan
  must either extend the builder to set two blobs in one tree, or land per-kind and
  scope AC 4's atomicity per-kind — a design point, not a blocker.
- **Erosion baseline.** A fresh clone has no baseline (`jimalloc.sh:456-464`); the
  seed should write it post-commit (like `alloc_update_baseline`) so the first
  post-seed allocate is guarded from the seeded state, not from empty.
- Performance is a non-issue: jim-scale is ~65 specs + ~120 issues, one pass.

## Recommendations

1. **Home:** a `seed` verb on `jimalloc.sh` (reuses the grammar, CAS, config, and
   `valid-id` boundary in one place — no second registry-writing path, per AC 8).
2. **Shape:** preview (default, prints derived records + any stop conditions, mutates
   nothing) then `--apply` — matching `migrate.sh`. Fold the spec's dry-run open
   question in as the default behavior.
3. **Reads:** `specs.log` from dir basenames (skip `000-blueprint`); `issues.log`
   from per-file frontmatter via the `index.sh` parsers.
4. **Landing:** reuse `alloc_cas_append`'s plumbing/CAS/erosion path; decide the
   one-commit-both-logs question above.

**Alignment.** Consistent with VISION.md — the id-coordination arc serves "small
teams working on tightly-coupled codebases," and seeding is the adoption on-ramp
for jim's own self-hosting (Phase 1: "Jim builds Jim"). Consistent with the
platform blueprint / ARCHITECTURE Scripting Layer: a deterministic bash verb that
parses artifacts as data (never `source`/`eval`), revalidates every token through
the single `is_valid_id` boundary, composes via `BASH_SOURCE`-relative paths, and
adds no third-party dependency. No locked constraint is contradicted; the only
tension is AC 2's over-promise, raised below for the PM.

## Peer Feedback

**→ PM (spec feasibility): AC 2 overpromises for retired / partition-source groups —
jim itself is the counterexample.**

AC 2 requires the post-seed `next-id` to equal the pre-seed tree scan for *every*
group. The pre-seed scan is `jimfile.sh next-id`, which floors past ordinals a
split/merge vacated (`vacated-max`). jim's own `docs/specs/ledger.md` records two
`op=split` events that moved `jim/001..jim/052` into sdlc/blueprint/issue/platform;
the retired `jim` group now holds only `000-blueprint`, so:

- pre-seed `jimfile.sh next-id jim` = **053** (floored on `vacated-max`=052);
- a dir-scan, allocate-only seed emits **no** `jim/*` records → registry
  `alloc_next_id_spec jim` = **001**.

The registry's high-water never consults the ledger, and the frozen grammar
(AC 1 forbids changing it) has no floor record — so an allocate-only, dir-scan seed
**cannot** reproduce the floor for a group whose top ordinals were vacated and left
no directory. jim's four live groups (platform/sdlc/issue/blueprint) and simple
within-group gaps are unaffected — only retired/partition-source groups break.

Two ways to resolve, PM's call:

- **(A) Scope it out (lean, recommended).** Refine AC 2 to guarantee parity for
  fully-materialized (live) groups; add an Out-of-Scope line deferring retired /
  partition-source groups (whose vacated top ordinals left no dir) to the
  rename-emitting follow-on (#113), which owns the redirect records that make both
  `next-id` *and* `resolve` correct for moved ids. Name jim's retired `jim` group
  as the example. Residual risk: a stray `allocate spec <retired-group>` before #113
  could reissue — negligible (retired groups aren't allocated into) and #113 closes it.
- **(B) Cover it now.** The seed consults the specs-root ledger's `moved=` pairs and
  emits an `allocate` record for each vacated source ordinal (slug recovered from the
  destination dir). Gives exact parity for all groups now and pre-satisfies #113's
  Finding-2 invariant ("every rename source has its own allocate record") — at the
  cost of ledger parsing + slug recovery, and of recording moved ids as plain
  allocations (resolve-to-current stays #113's job either way).

Recommend **(A)** for leanness and a clean allocate-vs-rename boundary; (B) if you
want jim's own registry fully faithful at seed time. This changes the spec (AC 2 +
Out of Scope), hence Needs PM Review.
