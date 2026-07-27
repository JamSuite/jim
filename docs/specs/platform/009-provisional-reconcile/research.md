---
spec: "docs/specs/platform/009-provisional-reconcile/spec.md"
status: Active
date: "2026-07-27"
---

# Research: Provisional allocation and reconcile (unreachable-origin mode)

All logic lands in the existing allocator `skills/file/scripts/jimalloc.sh`
(platform/007+008); this is an extension, not a new script. Anchors below are the
exact reuse and extension points.

**Alignment.** Clean against both locked constraints. `ARCHITECTURE.md` (Scripting
Layer, the `jimalloc.sh` entry) already documents `provisional` as a
*reserved-and-rejected* mode — #115 implements the pre-anticipated extension with no
structural divergence; the Bash-vs-Prompt rule places the deterministic
provisional/reconcile logic in the script and the preview/UX judgment in the
consumer skill. `VISION.md` — provisional mode keeps offline *discovery-artifact
capture* working; it does not turn issues into team-coordination tickets (the
Non-Goal). No new library or dependency.

## Anchors

**The mode gate to flip (this is the whole entry point):**
- `jimalloc.sh:483-496` `alloc_preflight` — resolves `id_coordination_unreachable`
  (490) and **rejects any non-`fail` value** with "not implemented" (491–494).
  Provisional mode replaces this rejection with an accept-and-branch. Called only
  from the mutation paths `alloc_cas_append` (712) and `cmd_seed` (943), never
  from peek/resolve.
- `jimalloc.sh:479-482` header already names `service` / `provisional` as reserved.
- `tests/jimalloc.sh:504-512` `case_..._unreachable_provisional_not_implemented`
  asserts the *current* rejection — this test flips to assert provisional issuance.
  Sibling `:492-500` (mechanism=service) stays as-is.

**Reachability probe provisional intercepts:**
- `jimalloc.sh:552-566` `alloc_origin_tip` — `git ls-remote`/`fetch`; the
  "coordination remote '…' is unreachable" → rc 1 hard-fail (555–557). Under
  provisional this rc-1 becomes "issue a provisional id" instead of failing.
- `jimalloc.sh:855-862` `alloc_peek_refresh` — the *non-fatal* best-effort fetch
  peek already uses; the model for provisional's offline tolerance.
- `jimalloc.sh:537-545` `alloc_coord_remote` (origin vs local tier by reachability).

**CAS land machinery reconcile reuses (realizes N provisionals in one commit):**
- `jimalloc.sh:965-991` `alloc_seed_commit` — the **N-record, ≥1-blob, single
  commit** builder (008). This, not the 1-blob `alloc_build_commit` (659–673), is
  the shape a batch reconcile wants.
- `jimalloc.sh:1021-1081` `alloc_seed_land` — seed's retry loop that **inlines**
  the push / `update-ref` CAS instead of calling `alloc_origin_cas` (691–699) /
  `alloc_local_cas` (679–683). See Peer Feedback — reconcile is the third writer.
- `jimalloc.sh:709-783` `alloc_cas_append` — the canonical single-record bounded
  retry (5 attempts, erosion check 742, sole id emit 767/774, jittered backoff).

**Erosion baseline (reconcile arms it post-commit, like seed):**
- `jimalloc.sh:579-614` `alloc_baseline_dir`/`_file`/`alloc_check_erosion`/
  `alloc_update_baseline`; `:624-638` `alloc_write_contained` (symlink-escape guard,
  runs before any write); seed arms via `alloc_seed_arm_baselines` (1010–1015).

**Identity/ordinal split that makes issue reconcile light (confirms spec refinement 1):**
- `jimalloc.sh:298-318` `alloc_durable_issue_id` — the issue durable id is
  date+slug with a `-2/-3` collision suffix, i.e. **offline-computable**; only the
  ordinal (`alloc_next_num_issue` 274–291) is a shared high-water. So a provisional
  issue can carry its real date-slug filename and defer only `num`.
- `jimalloc.sh:805-813` `alloc_build_issue` returns `"<full-id>\t<num>"`; sole
  durable emit at 767/774 inside the CAS-success branch only.

**Validation boundary (every replayed/derived token):**
- `jimalloc.sh:107-109` `alloc_valid_token` → `jimfile.sh valid-id` (single copy,
  no fourth); `:113-120` `alloc_valid_specid`; ordinal numeric-class checks
  (380/427); git guards `--end-of-options` (730/1043), `--` (92/599), leading-dash
  reject + `check-ref-format` (`alloc_valid_branch` 512–517). No `--literal-pathspecs`
  in this script — foreclosed via `--end-of-options` + allowlist instead.

**Issue-side integration (the consumer contract's future counterpart — #111, not here):**
- `new.sh:61,91-92` accepts a pre-resolved `--num` or falls back to
  `jimfile.sh next-num`; writes `num:` at frontmatter line 141. It does **not**
  call the allocator.
- `index.sh:132-153,366` reads `num` from frontmatter (never derives it);
  `render.sh:512-561` `cmd_show` resolves an ordinal **only against the indexed set**.
- **No existing script edits an in-place `num` value** — `backfill.sh` only inserts
  a missing `num`, `migrate.sh`/`render.sh` only read it. So the reconcile num-rewrite
  is genuinely new issue-group surface — correctly deferred to #111.

**Test harness seams (for the new mechanism + fixture-consumer tests):**
- `tests/jimalloc.sh:62-68` `run_jimalloc_reg` (the `JIMALLOC_REGISTRY_DIR` fixture
  seam); `:275-281` `alloc_new_repo`; `:364-378` `alloc_new_bare`/`alloc_new_clone`
  — the **two-clone bare-remote** helpers are exactly what the concurrent-reconcile
  determinism AC needs; `:608-958` the seed block templates a `reconcile` block;
  `:492-512` templates the unreachable-mode flip.

## Local Patterns

- **Preview-then-apply migration doctrine** — `cmd_seed` (008) and `migrate.sh`
  are bare-run-preview, explicit `--apply` to land. Reconcile follows it (spec AC 9).
- **Sole-durable-emit discipline** — an id/mapping is reported only inside a
  successful-CAS branch (767/774). Reconcile's realized mapping must obey the same:
  durable before the consumer rewrite (spec AC 6).
- **Parse-as-data, single boundary, no fourth id copy** — every token through
  `alloc_valid_token`; registry/artifacts never sourced.
- **Test template for the coder:** `tests/jimalloc.sh` (sources
  `skills/meta-test/scripts/testlib.sh` at :23; `assert_*`, `TMP_BASE`,
  `empty_dir` from there). Copy the seed block (:608-958) for reconcile fixtures
  and the two-clone helpers (:364-378) for concurrency.

## Security & Performance

- **Injection boundary (spec AC 12):** pending markers ride in branch-writable
  artifacts and provisional tokens derive from untrusted subjects — both revalidate
  through `alloc_valid_token` + the git guards above before any git/ref/fs use,
  exactly as 007/008 do. No new sink class is introduced.
- **Offline path touches no network** (spec AC 3): provisional issuance must not
  call `alloc_origin_tip`/`fetch`/`push`. `alloc_peek_refresh`'s non-fatal pattern
  is the reference.
- **Contention:** reconcile realizes N provisionals as **one** CAS commit (seed's
  builder), so it costs one push/retry regardless of N — no per-item round trip.
  Its erosion + non-ff CAS backstop are unchanged from 007.

## Recommendations

*(Options and trade-offs for the architect — not decisions.)*

1. **Where provisional branches:** intercept at `alloc_preflight` (accept
   `provisional`) + at `alloc_origin_tip`'s rc-1 (return a provisional id rather
   than propagating the hard-fail). Keep `fail` byte-identical when the key is `fail`.
2. **Reconcile land step:** reuse `alloc_seed_commit` (N-record builder). Strongly
   consider factoring the shared tier-select + CAS + baseline-arm step now (see
   Peer Feedback) rather than adding a third inline copy.
3. **Pending discovery:** the consumer contract (spec AC 11) surfaces pending
   provisionals; 008's precedent shows platform code may *scan* consumer frontmatter
   as data, but the *write-back* must go through the issue group's emitter surface
   (#111), since no in-place `num` editor exists today.
4. **Testing #115 alone:** a fixture consumer over `JIMALLOC_REGISTRY_DIR` +
   `alloc_new_clone` proves the mechanism (issuance, batch realize, atomicity,
   concurrency, resumability) without the #111 issue wire.

## Peer Feedback

*For the architect (at plan time — no plan.md exists yet, nothing invalidated):*

- **Consolidate the third registry writer.** `alloc_seed_land` (1021–1081)
  re-implements the push / `update-ref` CAS inline instead of calling
  `alloc_origin_cas`/`alloc_local_cas` — the 008 review flagged this (Finding 3) as
  a second write path kept in sync by convention. Reconcile is the **third** writer.
  The plan should factor one shared land step (tier-select + CAS + erosion-baseline
  arm, accepting the N-blob builder) so allocate / seed / reconcile share a single
  implementation — turning the 008 debt into a net simplification rather than
  compounding it. This directly serves spec AC 4 ("no second, weaker write path").
