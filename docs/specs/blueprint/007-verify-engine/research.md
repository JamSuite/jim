---
spec: "docs/specs/blueprint/007-verify-engine/spec.md"
status: Active
date: "2026-07-04"
---

# Research: Invariant verification engine core

## Anchors

**Blueprint data the engine consumes**

- `skills/blueprint/assets/blueprint-template.md:42-52` — the Invariants
  section: a 3-column table (`Invariant | Criticality | Verification method`),
  criticality enum `critical/high/medium/low`, method **free text** seeded
  with `lint / type / AST check, test, or judge`. This is the column AC #9
  restructures into engine-consumable `check:` data.
- `docs/specs/jim/000-blueprint/spec.md:149-178` — jim's real invariant
  table: live fixture for the engine. Several rows already record
  `judge (issue #22 engine later)` (L170, L177) — the judge-fallback path
  (AC #10) has real rows waiting. Methods in the wild: `grep … vs call
  sites`, `line / token count check`, `tests/jimledger.sh`, `judge`.
- `BLUEPRINT.md:36` — territory lives in the **project map**, not the group
  blueprint (`Territory: skills/, agents/, tests/`). Territory-scoped floor
  checks (AC #4–5) must read the map, not `000-blueprint`.

**Scripting layer the engine extends**

- `skills/conf/scripts/jimconf.sh:42,48-90,117-148` — `KEYS` registry,
  `default_for()` case arms, and the bare-name disjunction at `:120`. A
  `verify_*` family = three edits (add to `KEYS`, add default arms, extend
  the `:120` disjunction). Closest default-arm templates: `review_*`
  (`:71-73`), `group_*` (`:65-66`).
- `skills/file/scripts/jimfile.sh:215-232` — `cmd_valid_relpath`, the
  territory-path gate (AC #4); `:179-198` `is_valid_id`; `:633-647`
  `path blueprint <group>` (resolves the `000-blueprint/spec.md` slot).
- `skills/review/scripts/jimledger.sh:304` — `LEDGER_STAGES="spec research
  plan sec build review blueprint"`; `verify` appends here. `:208-221`
  generic `event` verb (kv counters ride it — spec 031's
  `violations=/folded=/fixed=` are emitted by the *skill*, not the script);
  `:163-173` `commit-blueprint` (path-scoped, mode-whitelisted) and
  `:184-206` `commit-map` (validates relpath args) — the models for any
  verify ledger commit. Ledger-only commits need no special branch: git
  pathspec staging of `-- <paths>` stages only what changed
  (`skills/blueprint/SKILL.md:363-366` precedent).

**Fan-out orchestration to mirror**

- `skills/review/SKILL.md:71-95` — the full judge-rung template: resolve +
  validate knobs (`review_model` validated against
  `inherit/sonnet/opus/haiku`, junk → `inherit`, `:79`); dispatch one
  `Agent(investigator)` per target with exactly (target, evidence, ground
  truth) (`:89`); bound by `review_fanout_cap`, highest-risk first, naming
  the un-investigated remainder (`:91`); per-spawn `model` parameter from
  config (`:89`).
- `agents/investigator.md:1-15,27-34,66-73` — `tools: [Read, Glob, Grep]`,
  `model: inherit`; untrusted-content instructions transfer verbatim; output
  verdict `satisfied | partial | divergence` maps cleanly onto
  holds/partial/violated. Body is diff-anchored ("one changed region… diff
  hunks supplied") — an invariant judge gets a rule + territory scope, no
  diff.
- `skills/blueprint/SKILL.md:302-329` — the violation→issue offer (U3b):
  title/priority-from-criticality/labels/origin conventions and the
  `new.sh --body-file` emitter call — the exact template for AC #11.
- `skills/blueprint/references/reconcile-methodology.md:129-137,169-196` —
  `<untrusted-face-content path="…">` delimiter and the findings-as-issues
  batch UI (`[file all] [skip all] · per-row: f / e / s`) — AC #13's
  evidence convention and the report/offer shape.

**New files**

- `skills/verify/SKILL.md`, `skills/verify/scripts/jimverify.sh` (+ likely
  `references/` for check-authoring guidance given blueprint SKILL.md sits
  at 497/500), `tests/jimverify.sh`, template edit in
  `skills/blueprint/assets/blueprint-template.md`.

## Local Patterns

- **Test template:** `tests/jimledger.sh:29-94` — `run_jimledger()` invoker
  (OUT/ERR/RC capture), `git_fixture()` (`:39-51`, deterministic git
  identity), `# AC:`-commented `case_*` functions discovered by name, no
  registration array; asserts from `testlib.sh` (`assert_eq:101`,
  `assert_match:115`, `assert_exit:128`, `fixture:159`, `empty_dir:171`).
  Config-knob cases follow `tests/jimconf.sh:121-134`
  (`case_*_default_and_resolve` pairs: empty-dir default + fixture
  override).
- **Flag parsing:** strip a recognized flag from `$ARGUMENTS`, remainder is
  the positional (`skills/review/SKILL.md:29`, mirrored at
  `skills/blueprint/SKILL.md:28-30`) — the pattern for a per-run appetite
  override.
- **Script discipline:** `set -uo pipefail; export LC_ALL=C`, never
  `source`/`eval` scanned or configured content, `--` guards, atomic
  `tmp + mv` — restated in every script header.
- **Config documentation:** `jimconf.toml.example` — `group_*` block
  (`:77-92`) for enumerated selectors; `pre_commit` block (`:31-46`) for a
  path + enforcement-flag pair.

## Security & Performance

- **Registry execution is unprecedented — the riskiest design point.** A
  repo-wide sweep (`eval`, `bash -c`, `sh -c`, `| bash` across
  `skills/*/scripts/*.sh`) found **zero** execution of config-derived
  strings; every script's header explicitly promises config/scanned content
  is data, never code (`jimconf.sh:247-249`, `jimledger.sh:24`). The only
  operator-command precedent is `pre_commit`/`pre_completion`: config
  resolves a *path*, the existence-gated script is run by the **model via
  the Bash tool** (`skills/build/SKILL.md:92-100`), never by a bash script
  mechanically. If `jimverify.sh` `eval`s registry strings it becomes the
  first script to cross that line; see Recommendation 1 for the
  house-consistent split.
- **Command names must be inert at lookup.** A blueprint-recorded registry
  name is untrusted data used as a config key — validate it against the
  slug charset before any lookup (mirrors `is_valid_id` discipline), so a
  hostile name can't traverse or inject at resolve time.
- **Registry command output is untrusted** (AC #6/#13): capture exit code +
  output, never parse it as instruction, contain a crash to one *failed*
  outcome.
- **Performance:** the floor is grep/find over a territory-scoped tree —
  cheap. The judge rung dominates cost; `review_fanout_cap`'s validated-cap
  pattern (`:79`, junk → default, `0` never silently disables) is the
  guard to replicate.

## Recommendations

1. **Split registry execution: script resolves, model executes.** Keep
   `jimverify.sh` purely deterministic-and-inert (floor primitives +
   check-data/territory parsing + result aggregation); have the *skill* run
   registry commands via the Bash tool, mirroring `pre_commit` — each
   command then passes through Claude Code's own permission layer, and no
   jim script ever executes config-derived strings. Alternative: the
   registry stores *script paths* (validated via `valid-relpath`,
   existence-gated) rather than command strings — even closer to the
   `pre_commit` shape. Either satisfies AC #6; the architect picks.
2. **Reuse `investigator` via spawn-prompt composition.** Its capability
   boundary, untrusted-content clause, and verdict enum fit; only the
   diff-anchored framing differs. Compose the judge spawn prompt with
   (invariant rule + criticality, territory scope, "ground truth = the
   invariant text") and map `satisfied|partial|divergence` onto the outcome
   vocabulary — or mint a sibling `judge` agent with identical `tools:` if
   prompt reuse reads forced. `verify_model` should replicate
   `review_model`'s validated per-spawn `model` parameter exactly.
3. **Read territory from the map, invariants from the group blueprint.**
   Two inputs, two parsers; both content-validated (`valid-relpath` per
   path at use). Under `group_territory = none` the floor's scope is the
   whole repo minus other groups' territories — or honestly "unscoped";
   name it in the report either way (AC #3).
4. **Ledger: follow the 031 producer pattern.** `verify` joins
   `LEDGER_STAGES`; the skill emits `event <blueprint-dir> verify
   started|finished <counters>` via the generic verb — no new script logic.
   If the run self-commits, model the verb on `commit-map`'s
   relpath-validated shape; the ledger-only case falls out of pathspec
   staging for free.

**Alignment:** the engine operationalizes VISION.md's "maintain
architectural consistency" claim and stays inside its human-in-the-loop
non-goals (report + offered issues, never auto-fix). It follows
ARCHITECTURE.md's locked conventions: Bash-vs-Prompt split, capability-backed
read-only subagents, one-level nesting (orchestrator inline), the
never-execute-config-content security model (Recommendation 1 keeps it
intact), and the `resolve()` / `LEDGER_STAGES` / testlib extension points.
