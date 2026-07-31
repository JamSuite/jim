---
spec: "docs/specs/sdlc/018-finish-coordinated-spec-identity/spec.md"
status: Active
date: "2026-07-31"
---

# Research: Finish coordinated spec identity

Phase 0 only — every defect is local; no external APIs, libraries, or prior
art apply (Phase 1 skipped). Anchors verified at `8c2ae74`.

## Anchors

**The unvalidated realized-ordinal flow (AC 2, AC 3 realize half):**

- `skills/spec/scripts/reconcile.sh:223` — `ord="${real##*/}"` taken verbatim
  from the allocator mapping; then used at `:226` (path), `:227` (occupancy
  probe), `:232` (tracked rename via `rename-tracked`), `:237` (untracked
  rename via `mv-spec-id`), `:248` (frontmatter rewrite). The one
  registry/tree-derived token with no gate.
- `skills/spec/scripts/reconcile.sh:184-192` — `ordinal_holder`; its globs at
  `:186` (`"$ord"-*/`, `"$ord"/`) match the ordinal as a literal string, so a
  padding variant is invisible.
- `skills/file/scripts/jimalloc.sh:637-713` — `alloc_reconcile_realize_spec`:
  the `have` branch stores/emits the record's ordinal verbatim
  (`:659` → `:665` → `:698`) while `new` canonicalizes `%03d` (`:711`) — the
  asymmetry feeding the bypass (AC 4).
- `skills/spec/scripts/reconcile.sh:406-427` — `record_realized`; row gates at
  `:413-414` end `|| continue`, silently dropping a rejected row from the
  durable event (AC 5).

**The creation-side halt (AC 3 creation half):**

- `skills/spec/SKILL.md:218` delegates the drift halt to `mv-spec-id`.
- `skills/file/scripts/jimfile.sh:498-554` — `cmd_mv_spec_id`; the only
  collision check is exact-name `[[ -e ]]` at `:545`.
- `skills/ledger/scripts/jimledger.sh:289-291` — `rename-tracked`'s slug gate
  applies to the **new** basename only and accepts `18-alpha`; no source gate
  exists (pinned deliberately — `sdlc/017` plan Task 6 deviation).

**Alias double-resolution (AC 6):**

- `skills/file/scripts/jimalloc.sh:371` — the fold resolves its group
  argument; both production callers already resolved it
  (`:469-472` → `:478` in `alloc_next_id_spec`; `:686` → `:702` in the
  realizer). The only raw-group callers are tests
  (`tests/jimalloc.sh:396,415`).

**Exhaustion ordering (AC 7):**

- `skills/file/scripts/jimalloc.sh:707-710` — realize's guard sits inside the
  pass-2 emit loop, contradicting its docstring at `:633-636`;
  `alloc_next_id_spec` checks before printing (`:480-483` vs `:484`) — the
  correct sibling to mirror.

**Path helper and its call sites (AC 8):**

- `skills/file/scripts/jimfile.sh:783-792` — the `spec|plan|research` arm:
  emptiness checks only (`:785-788`), composition at `:791`. Contrast the
  validated arms: `blueprint` (`is_valid_slug`, `:803`) and `issue`
  (`is_valid_id`, `:814`) — the pattern to mirror.
- Call sites: `skills/spec/SKILL.md:231` (the provisional branch at
  `:220-226` never re-resolves the write path — control falls into the
  two-token form), `skills/plan/SKILL.md:120` (with `Bash(mkdir *)` + `Write`
  granted at `:11`), `skills/research/SKILL.md:38` (fires unattended from
  `/jim:plan`), `skills/plan/assets/plan-template.md:3` (persisted
  `{id}-{name}` back-reference).

**Region-mismatch twins (AC 9) and regen status (AC 10):**

- Spec side: `field_value` at `reconcile.sh:86-90` greps the whole file;
  `rewrite_id` at `:171-178` anchors inside the first `---` block.
- Issue side: `skills/issue/scripts/reconcile.sh:78-82` (`field_value`, whole
  file) vs `rewrite_num` at `:129-136` (frontmatter-anchored).
- Discarded regen status: spec side `reconcile.sh:384`; issue side
  `skills/issue/scripts/reconcile.sh:202`.

**Citation sweep (AC 11, AC 12):**

- `skills/spec/scripts/reconcile.sh:306-387` — `sweep_citations`; the boolean
  fence flip at `:349-350`; the path-vs-typed pick at `:357-366` keying on
  `before == "/"` (`:360`); target enumeration via `git ls-files` at `:323`
  (untracked files invisible — the self-citation gap).
- `mv` without `-T`: `jimfile.sh:549` (`cmd_mv_spec_id`) and `:427`
  (`cmd_mv_spec`); the `-e` pre-checks at `:545`/`:423` are TOCTOU-separated.
- The `--apply` realpath guard: `reconcile.sh:454-461` (comparison at `:457`).

**Blueprints and docs (AC 13, AC 14):**

- `docs/specs/sdlc/000-blueprint/spec.md:100` and
  `docs/specs/jim/000-blueprint/spec.md:233` — both `high`/`judge` rows; the
  `sdlc` copy still names `next-id` as the minting mechanism in a
  parenthetical the `jim` copy lacks — the two restatements should converge
  deliberately.
- `skills/spec/SKILL.md`: `:86` (tree-derivation cue) vs `:92`/`:189`;
  refusal table `:110-113` has no `fail`-mode row (the actual message lives
  at `jimalloc.sh:960`); Step 13 `:358` has no placeholder branch; checklist
  `:395` demands a numeric id.
- `WORKFLOW.md:99-103,371,388` — `{00X}` templates; zero mentions of
  provisional identity or `/jim:spec reconcile` (every "reconcile" hit is the
  blueprint verb).
- `README.md:56,174,178,180` — numeric-id framing; the config table
  (`:108-156`) documents **no** `id_coordination_*` keys at all.
- `skills/spec/assets/spec-template.md:5` **and** `:11` — the H1
  `# {00X} {title}` is a second numeric-id site beyond the frontmatter.

## Local Patterns

- **Test template:** `tests/specreconcile.sh` — invoker `run_specreconcile_in
  <repo> <args…>` (`:24-30`, sets `OUT`/`RC`/`ERR`), fixture helpers
  `specrec_repo` (`:38-46`) and `specrec_prov_dir` (`:51`); model cases
  `case_specreconcile_apply_halts_on_drift` (`:249`) and
  `case_specreconcile_sweep_fenced_code_untouched` (`:388`). For fold-level
  fixtures, `tests/jimalloc.sh`'s `run_jimalloc_reg` (`:62-68`) is the
  log-fixture form; existing alias fixtures cover chains (`:319-335`) and the
  A→B/B→A cycle (`:460-473`) — exactly the shapes where double resolution is
  harmless.
- **Confirmed fixture absences** (matches #145): allocator exhaustion in
  either path, a reused-group-name log at the fold, a padding-variant ordinal
  record, and any provisional-form `path spec|plan|research` invocation
  (`tests/jimfile.sh:567-584` all use real 3-digit ids).
- **Correct fence trackers to reuse (AC 11):**
  `skills/issue/scripts/migrate.sh:326-346` (captures the literal marker run,
  closes on ≥-length same-char) and `skills/issue/scripts/index.sh:216-250`
  (`fence_char`/`fence_len` at `:227-229`, close at `:239-247`). Both are
  awk-embedded; the repo's cross-script sharing precedent for such fragments
  is the `SYNC:` comment + byte-identity fixture (the `is_valid_id` triple,
  the `ts-shape` allowlist).
- **Validation precedent:** the single `is_valid_id` boundary
  (`jimfile.sh valid-id`) — the ordinal gate and `cmd_path` validation should
  route through it rather than adding a copy.

## Security & Performance

- **The crafted-record vector is the payload.** The coordination branch is
  push-writable; the realized ordinal is the one token on this surface that
  skips revalidation, and both recorded security regressions flow from it.
  Gating `ord` (AC 2) plus numeric occupancy (AC 3) closes the vector at the
  choke point; `record_realized`'s loud failure (AC 5) is defense in depth
  behind it.
- **The untracked rename branch runs no `valid-relpath` on its composed
  target** (`reconcile.sh` `apply_pending`; the tracked branch is guarded
  inside `jimledger.sh:277-282`). `mv-spec-id`'s basename gates plus the new
  ordinal gate cover the composition inputs; worth an explicit look at plan
  time rather than an assumption.
- **The fence defect is live, not latent:** 4-backtick outer fences exist in
  the swept corpus today, so a realization can rewrite quoted material now.
- Performance is not a concern in this scope; fold memoization is tracked
  separately (#142, out of scope).

## Recommendations

- **Occupancy predicate placement (AC 3):** the clean option is a small
  `jimfile.sh` verb (numeric sibling-ordinal scan) both the skill-body
  creation flow and `reconcile.sh` call — one implementation, composed via
  the existing `BASH_SOURCE`-relative pattern; the alternative (predicate in
  `reconcile.sh`, mirrored numeric gate in `mv-spec-id`) leaves two copies.
  Compare under `10#$ord`; normalize the `have` branch at the source
  (`jimalloc.sh:659,665,698`).
- **Fold contract (AC 6):** both production callers pre-resolve, so
  fold-accepts-pre-resolved is the smaller change — but the two test-only raw
  callers must then resolve, and the docstring must state the contract either
  way.
- **`cmd_path` provisional form (AC 8):** a two-token arity
  (`path spec <group> <P-token>`) mirrors `mv-spec-id`'s three-arg precedent;
  validate the numeric arm's `group`/`id`/`name` in the same change (mirror
  `:803`/`:814`).
- **Fence tracker (AC 11):** `index.sh`'s tracker is the cleaner lift; since
  both precedents are awk-embedded, expect `SYNC:` + byte-identity fixture
  rather than sourcing across skill directories.
- **Blueprint folds (AC 13):** `sdlc` through
  `/jim:blueprint --from-review docs/specs/sdlc/017-coordinated-spec-identity`;
  `jim` needs its own pass; converge the two rows' text deliberately (they
  differ today).
- **Sequencing (pre-decided):** the ordinal gate + predicate first — it makes
  the silent ledger drop unreachable and gives the first two #145 fixtures
  something to assert — then the creation halt on the same predicate.

**Alignment:** this remediation follows `ARCHITECTURE.md`'s locked
conventions — the Bash-vs-Prompt rule (deterministic gates live in scripts),
the single `is_valid_id` boundary, never-execute-config, and
blueprint-writes-only-through-their-surface — and adds no capability,
consistent with `VISION.md`'s human-in-the-loop, no-black-box posture.
`ARCHITECTURE.md`'s Spec Archive section already documents the provisional
form (refreshed 2026-07-30), so AC 14's docs pass is `WORKFLOW.md`,
`README.md`, the spec template, and the skill body — not `ARCHITECTURE.md`.

## Peer Feedback

**For PM (no feasibility concerns — two widening details for AC 14's docs
pass):** `README.md`'s config table documents none of the `id_coordination_*`
keys, and `skills/spec/assets/spec-template.md`'s H1 (`# {00X} {title}`, `:11`)
is a second numeric-id site beyond the frontmatter `:5`. Both are natural
riders on the #147/#148 pass; no AC change needed if the plan names them.
