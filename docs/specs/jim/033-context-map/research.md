---
spec: docs/specs/jim/033-context-map/spec.md
status: Active
date: "2026-07-03"
---

# Research: Context map — deliberate spec-group definition

## Anchors

- `skills/blueprint/SKILL.md:23-34` — argument-routing table (flag-strip rule
  L25-27; `<group>` / `--from-review` / `--since` arms). The project-tier
  mode's dispatch entry point.
- `skills/blueprint/SKILL.md:89-114` — Step 4a shared downgrade
  classification. The grading rule the map's update path should extend or
  mirror (partition edits are high-consequence).
- `skills/blueprint/SKILL.md:142-365` — update mode U1–U4: ledger events
  (`blueprint started` L155, `finished` L186/L346), `commit-blueprint` call
  sites (L202, L243, L347), diff-and-approve flow the project tier mirrors
  (AC 9, 10).
- `skills/blueprint/assets/blueprint-template.md` — group-tier template; the
  map needs a sibling project-tier template (spec mockup is the seed). No
  `references/` dir exists under `skills/blueprint/` yet.
- `skills/spec/SKILL.md:48-53` — Step 3 group identification; L52 ("Identify
  the target group. If ambiguous, suggest a noun-based group name or ask.")
  is the advisor's exact insertion point (ACs 11–15).
- `skills/spec/SKILL.md:10, 182-186` — `allowed-tools` token line and the
  `Skill(jim:spec-check)` invocation; the pattern (and the place) for adding
  `Skill(jim:blueprint)` for mint-new (AC 13).
- `skills/conf/scripts/jimconf.sh:42, 48-87, 114-143` — `KEYS` array,
  `default_for()`, `resolve()` dispatch: bare-name predicate at L117 (new
  `group_axis`/territory keys extend it, cf. `blueprint_regen_threshold`
  named literally), path-suffix else-branch at L128 (`blueprint_path` needs
  only `KEYS` + a default arm).
- `skills/file/scripts/jimfile.sh:69, 213-230, 570-580, 599-613` — `KINDS`
  (contains `blueprint`), `get <key>` delegation, single-arg `path <key>`
  form, and `path blueprint <group>` (group tier). The kind-vs-key namespace
  collision lives here (see Security & Performance).
- `skills/review/scripts/jimledger.sh:267, 171-184, 159-169` — stage
  allowlist (already contains `blueprint` — no allowlist change for AC 10),
  dir-based `event` verb (`<dir>/ledger.md`), and `commit-blueprint`
  (hardcodes `spec.md` + `ledger.md` — needs generalization for a root-level
  `BLUEPRINT.md`).
- `skills/arch/SKILL.md:54-79` — Step 4 scan targets + Step 5 generation:
  AC 4's hook. The arch skill has zero partition/blueprint awareness today.
- `skills/vision/SKILL.md:20-105` — the strategic-interview precedent shape
  (seed → context → wordsmith/interview → generate → silent self-check →
  present-and-stop) for the creation flow (AC 5).
- `docs/specs/jim/000-blueprint/spec.md:15, 34, 79, 96, 127` — group-tier
  faces (Responsibility / Provides / Requires / Structure / Invariants): the
  content the map's Context Map table references, never duplicates.
  Frontmatter carries `kind`/`updated` — no `last_full_generate` yet.
- `jimconf.toml.example:18-19, 47-70` — key-documentation pattern (comment
  block + flat `KEY = "value"`, optional keys commented out) for the three
  new keys.
- New files: `BLUEPRINT.md` (root, generated), a project-tier map template
  under `skills/blueprint/assets/`, interview methodology under a new
  `skills/blueprint/references/`.

## Local Patterns

- **Test template:** `tests/jimconf.sh` on the `testlib.sh` framework —
  `run_*` invoker, `case_*` function discovery, `OUT` capture + `assert_eq`,
  `mktemp` sandbox. Path-key default shape: `case_pre_commit_default`
  (L338-343); bare-name shape: `case_jimconf_auto_blueprint_default_and_resolve`
  (L85-94). New cases must carry the `case_jimconf_` prefix — issue #23
  documents the `run.sh jimconf` false-coverage trap for unprefixed names.
- **Skill-to-skill inline invocation:** namespaced `Skill(jim:<name>)` token
  in `allowed-tools` + Skill tool in body + args passed explicitly
  (`$ARGUMENTS` does not auto-forward).
- **Flag-style dispatch:** `--from-review`/`--since` precedent — strip the
  flag, remainder is the group.
- **Bash-vs-prompt rule:** interview/proposal/pushback = prompt; path
  resolution, config, group-count for nudge suppression = `jimfile.sh` /
  `jimconf.sh` (deterministic, testable).
- **Clean namespace:** zero grep hits for `BLUEPRINT.md`, `context map`,
  `group_axis`, `blueprint_path` across `skills/`, `agents/`, `WORKFLOW.md`,
  `README.md`, spec 029 — no collisions in prose.

## Prior Art

Flat list (<5). Cited from stable canonical knowledge — no WebFetch run (the
spec has no external API dependency; guardrail respected). File tables
omitted: repos not locally accessible.

- **DDD strategic design / bounded contexts** (Evans) — the doctrine's
  source; a context is a language boundary, which grounds AC 6's
  vertical-first framing.
- **Context mapping** (Brandolini) — relationship-pattern vocabulary between
  contexts (upstream/downstream, conformist, ACL) — candidate vocabulary for
  the map's Relations entries.
- **Context Mapper** (contextmapper.org) — an existing DSL that formalizes
  context maps; evidence the map-as-artifact approach is established
  practice. jim's markdown + config approach is deliberately lighter.
- **C4 model** (Brown) — altitude comparison: the map sits at ~C2
  (containers) but with contracts, not just boxes.

## Security & Performance

- **Namespace collision (real risk):** `jimfile.sh` has KIND `blueprint`
  (`path blueprint <group>` → group tier, L599-613) while AC 1 adds a
  `blueprint_path` config key (`get blueprint` / single-arg `path blueprint`,
  L570-580). Arity/verb ambiguity must be resolved deliberately (see
  Recommendations #2) or the resolver will mis-route.
- **Line budget (real risk):** `skills/blueprint/SKILL.md` is at 388/500.
  The project-tier mode cannot fit inline; a `references/` split is required
  (none exists yet).
- **Commit discipline:** extending `commit-blueprint` to a root-level file
  must preserve literal path-scoped commits with the `--` guard (never
  `git add -A`) — `jimledger.sh:159-169` is the precedent.
- **Trust class:** `BLUEPRINT.md` is developer-owned strategic content (same
  class as `VISION.md` — read as locked constraint). Its write path is gated
  by explicit approval (AC 5); both modes must keep the no-silent-write
  invariant.
- **Advisor cost:** one small file read per `/jim:spec` plus a cheap
  `jimfile.sh` glob for the ≤1-group nudge suppression — negligible.

## Recommendations

1. **Dispatch arm:** no-arg `/jim:blueprint` (ergonomic, currently
   underspecified) vs an explicit flag (`--project` / `--map`, unambiguous
   against future group names). Architect decides; the flag-strip precedent
   (L25-27) fits either.
2. **Key naming:** `blueprint_path` works at the TOML level; disambiguate
   `jimfile.sh` by verb+arity (`get blueprint` = doc key; `path blueprint
   <group>` = group kind) or give the CLI short name a distinct token.
3. **Ledger home for project-tier events (AC 10):** the `event` verb is
   dir-based. Options: project-root `ledger.md` (clutter); a reserved dir;
   or record mint-new-triggered events in the consuming spec's dir. One
   decision at plan; stage name `blueprint` is already allowlisted.
4. **`commit-blueprint`:** parameterize the committed filename(s) or add a
   sibling commit arm for the map; keep the `create|update` mode whitelist.
5. **AC 4 (arch references map):** smallest possible touch — one scan-target
   line in arch Step 4 plus a template line.
6. **Map template frontmatter:** follow group-tier (`kind`, `updated`);
   consider `last_full_generate` parity (spec 032) from day one.
7. **Pre-existing gaps folded into scope (spec ACs 16–17):**
   `agents/architect.md` `skills: [plan, arch]` omits `blueprint` although
   the skill declares `agent: architect`; and `WORKFLOW.md` carries only
   command/artifact table rows for `/jim:blueprint` with no lifecycle
   section. Both resolve through 033's ecosystem-consistency ACs rather
   than as filed issues.

**Alignment:** This approach directly serves VISION.md's "maintain
architectural consistency" and follows ARCHITECTURE.md's Plugin Conventions —
the bash-vs-prompt decision rule, skill-to-skill invocation pattern,
zero-config jimconf defaults, path-scoped commit discipline, and the 500-line
progressive-disclosure constraint. No divergence from locked constraints
identified.
