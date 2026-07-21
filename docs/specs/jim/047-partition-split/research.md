---
spec: "docs/specs/jim/047-partition-split/spec.md"
status: "Active"
date: "2026-07-21"
---

# Research: Partition split

## Anchors

**Engine verbs reused as-is (spec 043/046, contract-stable):**

- `skills/partition/scripts/jimpartition.sh:910-999` — `cmd_rename_preflight`: `CHECK\t<name>\t<pass|fail>\t<detail>` grammar (`emit_check` :899), structural-fail rc 1 vs warn-only dirty tree (`DIRT affected|unrelated`, :974-995), `TERRITORY-IDENTITY` facts. Split preflight extends this with per-target checks; the collision check (:944-954, map groups + spec-dir existence) needs an extraction exception (`<old>` ∈ targets).
- `jimpartition.sh:1009-1049` — `cmd_occurrences`: whole-slug-token scan over given paths, location-only `HIT\t<file>\t<line>\t<kind>` (kinds: dotted-key, config-key, config-value, path, prose — a typed `cart/006` ref surfaces as `path`). Reused verbatim for the zero-unclassified sweep (AC 16).
- `jimpartition.sh:1059-1090` — `cmd_edges_diff`: compares two `jimverify.sh edges` TSVs with `<old>→<new>` rewritten in consumer/provider columns only, relies-on surface untouched (the ratchet). Baseline for the split graph check, but see Recommendation 1 — the revealed-edge floor is `aggregate`, not `edges-diff`.
- `jimpartition.sh:296-391` — `cmd_scan`: name-agnostic file→file `EDGE` facts (go/python/js-ts/rust/elixir; `CHANNEL`/`UNMODELED` honesty records). No re-scan logic needed for split.
- `jimpartition.sh:784-829` — `cmd_aggregate`: projects EDGEs onto an arbitrary territories-file (`GROUP\t<slug>\t<path>`, longest-prefix match), emits `GEDGE\t<from>\t<to>\t<count>` + `STRADDLE\t<unit>\t<owner>\t<n>`; intra-group edges dropped. **This is the revealed-edge floor** (Recommendation 1).
- `jimpartition.sh:1130-1231` — `cmd_rewrite_identity`: guards-before-any-edit loop separation (:1147-1168 all-targets guard pass precedes :1179-1228 edit pass); rewrites frontmatter `group:`, dotted-key group-half, typed-ref group-half **only** — the `NNN` number half is explicitly untouched (:1205-1217). One global `<new>` per invocation.
- `jimpartition.sh:1336-1388` — `cmd_identity_check`: retired-slug set derived by a whitelisted `awk -F'\t'` parse of the specs-root ledger, hard-gated on `;op=rename;` (:1348-1364), slug-gated per element. **AC 17's concrete change site** — needs an `op=split` arm.
- `skills/review/scripts/jimledger.sh:265-306` — `rename-tracked`: single whole-path `git mv`, **sibling-constrained** (`dirname(old)==dirname(new)`, :279-284; cross-parent refusal proven at `tests/jimledger.sh:1207-1211`). **Cannot move a spec dir between groups** — see Recommendation 3.
- `jimledger.sh:321-366` — `commit-rename`: literal-path staging, docs/code arms, script-composed messages from slug-validated tokens. Extend with split's message shape.
- `jimledger.sh:369-381` — `cmd_event`: kv tail `;`-joined **verbatim** (no charset/size gate); line = `<epoch>\t<iso>\t<stage>\t<status>\t<kv>`.
- `jimledger.sh:613-681` — reconcile extractors: gate on `blueprint finished` + `;op=reconcile;` (:660-661), 15-key whitelist drops unknown keys silently (:644). **A `partition finished op=split` event is invisible to them — no choke risk** (AC 12 additive-safe).
- `skills/file/scripts/jimfile.sh:283-327` — `cmd_next_id`: **purely directory-glob-derived** max+1 (:311-326); nothing else feeds it, so vacated ids are reused today. AC 11's floor is net-new (Recommendation 4).
- `jimfile.sh:336-395` — `cmd_mv_spec`: plain `mv`, not `git mv` (:390) — fine for uncommitted wip, wrong for tracked moved specs.

**Skill/doc surfaces:**

- `skills/partition/SKILL.md:248-335` — the rename spine (mode resolution :256-280 with degrade-to-rewrite + immutable-not-applicable :276-278; 7 steps preflight→close). The split section mirrors this. **Line budget: 455/500** — protocol detail must land in the methodology, not SKILL.md.
- `skills/partition/references/partition-methodology.md:215-384` — rename protocol + the 046 doctrine: modes-across-split/merge (:367-378, "`immutable` … is the split/merge-native mode") and the composition rule (:379-384, a rename component of a split follows rename's rules). The doctrinal seam 047 extends.
- `skills/blueprint/SKILL.md:467-475` — the `--rename` arm: `--changes` row re-validation (`valid-relpath` + slug, out-of-scope refusal), defers all commits, does not re-gate. Template for `--split`. `--retire` arm :448-465 (always prompts; retired banner + `op=retire`). **Line budget: 498/500 — the `--split` arm must fund its lines** (extraction-to-references precedent: spec 036 / issue #43).
- `agents/gatherer.md:24-37` — rename dispatch role (one artifact cluster, classification residue only) + 046 freeze-on-doubt rule; output schema :87-107 already carries `cross_group_deps` with substrate-EDGE citations — fits revealed-edge evidence.

**Test templates (AC 19):**

- `tests/jimpartition.sh:109-233` — `rename_repo`: 3-group fixture (cart/orders/billing, dotted requires, frozen numbered spec, identity-bearing territory, config keys) with token-discipline notes :104-108. The multi-group fixture to extend (children, movable spec tail 006–009, cross-child import edges).
- `tests/jimpartition.sh:1206-1223` — `rewrite_repo`: numbered-spec identity-position fixture. `:28-44` invokers (`run_jimpartition_in`), testlib `case_*` auto-discovery, `OUT/ERR/RC` globals.
- `tests/jimledger.sh:1147-1159, 1163-1315` — rename-tracked / commit-rename guard cases: the negative-case template for a new move primitive.

## Local Patterns

- **Script-owned git primitives** (043): skills never gain git grants; moves/commits live in `jimledger.sh` with slug/relpath/realpath-under-top guards. Any new cross-parent move verb follows `rename-tracked`'s guard stack verbatim.
- **Facts-not-verdicts / Bash-vs-Prompt**: deterministic enumeration in scripts, judgment (assignment proposals, prose classification) in the skill + gatherer fan-out.
- **BASH_SOURCE-relative composition** (`jimpartition.sh:51`, health-eval :1269): how a script consults a sibling script/config without skill plumbing.
- **Whitelisted ledger parse** (identity-check :1348-1364): the safe pattern for machine-reading ledger content — event-type gate + per-element charset gate before any use.
- **Config**: `spec_migration` resolves bare-name with default `rewrite` (`jimconf.sh:42,99,175`); enum degradation is the consuming skill's job (SKILL.md:265-266). `verify_appetite_<group>` is an existing dynamic family (:158-174) — per-child adds need no jimconf change.
- **Line-budget funding**: 036/#43 precedent — extract protocol detail to `references/` when SKILL.md approaches 500.

## Security & Performance

- **Remap machine-consumption** (spec Insight 2): if the AC 11 floor parses ledger remap keys, those become the first machine-consumed ledger *values*. The identity-check pattern (event-gate + slug/shape-gate per element) is the required guard; flag to `/jim:sec`.
- **Event kv is verbatim and unbounded** (`cmd_event:376-379`): a 40-spec remap on one `k=v` token has no size guard; the 044 `valid_sluglist` 256-byte cap is the bounded-value precedent. Shape decision is the architect's (spec Insight 5) — but any *consumer* must whitelist-parse, never trust size.
- **Guards-before-any-edit** (`rewrite-identity:1147-1168`): the multi-file mutation pattern split must preserve when batching per-child rewrites (a mix of good + guard-failing files edits nothing).
- **Fan-out bounding**: gatherer dispatches batch under `verify_fanout_cap` (038); split adds per-child dispatches — same cap applies.
- **Performance**: `scan` is the dominant cost and runs once; `aggregate` re-runs are awk-cheap; `occurrences` scales linearly over the spec archive.

## Recommendations

1. **Revealed-edge floor = `aggregate` re-run with child territories.** Feed the *proposed per-child* territories-file over the existing scan EDGEs: cross-child `GEDGE` rows are exactly the candidate `requires` edges (with counts as call-site evidence), and `STRADDLE` rows are exactly the spanning units (AC 4, 6). No new derivation engine — the "edges-diff harder cousin" is aggregate + skill-level classification against the declared graph.
2. **`rewrite-identity` reuse by batching per target child.** Group moved files by destination child and invoke once per child — the shipped verb handles the group-half unchanged. Net-new: a **number-remap arm** (typed-ref `NNN` half + archive-wide re-point per AC 8, driven by the remap set), honoring the same guard stack.
3. **A cross-parent move primitive is required.** `rename-tracked` structurally refuses `docs/specs/cart/006-x → docs/specs/checkout/001-x` (different parent). A single `git mv` per spec dir can perform move + renumber in one history-continuous step; the new verb needs `rename-tracked`'s guard stack minus the sibling constraint, plus target-parent existence/no-clobber checks.
4. **Vacated-id floor is net-new in `next-id`.** Directory-derived max+1 reuses vacated tail ids today. Candidate mechanism: consult the specs-root ledger's remap events via the identity-check whitelist pattern (BASH_SOURCE-relative to jimledger's file, or a direct gated awk); alternatives (persisted marker) trade durability homes. Architect's call (spec Insight 2).
5. **`op=split` is additive-safe on the ledger** (extractors gate it out; unknown keys drop), but **`identity-check` needs an explicit `op=split` parse arm** for retired-slug parity (AC 17) — today it matches `;op=rename;` only.
6. **Line budgets shape the doc plan**: split protocol → `partition-methodology.md` (443 lines, room); SKILL.md gets a compact § Split runs; the blueprint `--split` arm must fund lines out of `blueprint/SKILL.md` (498/500) via references extraction.

**Alignment:** the approach preserves ARCHITECTURE's locked constraints — blueprint-surface-only doc writes with deferred commits (038 AC 7 / 043 exception), script-owned git primitives (no skill git grants), Bash-vs-Prompt, never-execute-config, capability-backed read-only gatherer — and VISION's human-gated, transparent workflow (single hard gate; propose-never-auto-apply). No divergence found. Phase 1 (external) skipped: bash-only feature, no external APIs, libraries, or prior art beyond the in-repo 043/046 engine.
