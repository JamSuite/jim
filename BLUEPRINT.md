> This document is generated and maintained by `/jim:blueprint`. Edit via
> the skill to preserve the partition's coherence.

# Blueprint — jim

*Axis: vertical · Territory: declared-paths*
*Last updated: 2026-07-25 (via /jim:blueprint)*

*The project-tier context map: the declared partition of this project into
spec groups, each a deliberate context boundary. Current state only — the
authoritative intent that the group blueprints sit beneath and that
`/jim:spec`'s assignment advisor consumes. The cross-group contract graph is
derived from the group blueprints' provides/requires faces; it is never
re-declared here.*

## Context Map

| Group | Role | Purpose | Relations |
| :--- | :--- | :--- | :--- |
| sdlc | domain | The phase-gated SDLC pipeline, strategic docs, agent personas, and authoring toolchain | requires ← platform, issue, blueprint · provides → platform, blueprint |
| blueprint | domain | Living intent: group blueprints, the context map, contract graph, verification, partition lifecycle | requires ← platform, issue, sdlc · provides → sdlc |
| issue | domain | Discovery capture: structured, indexed, analyzable issue files with a single emitter | requires ← platform · provides → sdlc, blueprint, platform |
| platform | platform | The deterministic substrate: config, path/id, ledger, and test-framework CLIs | requires ← issue, sdlc · provides → sdlc, blueprint, issue |

## Groups

### sdlc

- **Purpose:** The phase-gated lifecycle (spec → research → plan → sec →
  build → review), the strategic documents, the agent personas staffing every
  stage, and the meta toolchain jim authors itself with.
- **Role:** domain
- **Boundary rationale:** One domain language — the pipeline, its gates, its
  personas, its living documents. It is also the enforcement home of the
  plugin-wide authoring conventions (the meta-skill/meta-agent checklists).
- **Relations:** requires `platform` (CLI substrate), `issue` (candidate
  batches), `blueprint` (assignment advisor, blast-radius facts, living-intent
  sensor, canonical gate rule); provider to `blueprint` (personas its skills
  bind) and `platform` (personas its scaffold gates dispatch).
- **Territory:** skills/spec, skills/spec-check, skills/research, skills/plan, skills/build, skills/debug, skills/sec, skills/review, skills/vision, skills/roadmap, skills/arch, skills/brainstorm, skills/meta-skill, skills/meta-agent, skills/meta-matrix, skills/meta-matrix-bash-invocation, skills/meta-matrix-conditional-evaluation, skills/meta-matrix-fork-probe, skills/meta-matrix-preload-probe, skills/meta-matrix-skill-invocation, skills/meta-matrix-variable-setting, agents/pm.md, agents/architect.md, agents/researcher.md, agents/coder.md, agents/security.md, agents/reviewer.md, agents/investigator.md, agents/meta.md, agents/meta-matrix-probe.md
- **Blueprint:** docs/specs/sdlc/000-blueprint/

### blueprint

- **Purpose:** The living-intent machinery: group blueprints and the project
  map behind one write surface, the derived contract graph, the verification
  engine, and the partition's own lifecycle operations.
- **Role:** domain
- **Boundary rationale:** A coherent machinery cluster with its own domain
  language (faces, edges, invariants, territory) behind a small, documented
  interface to the pipeline.
- **Relations:** requires `platform` (CLI substrate, test framework), `issue`
  (offered-issue emission), `sdlc` (personas its skills bind); provider to
  `sdlc` (advisor, blast-radius facts, living-intent sensor, canonical rules).
- **Territory:** skills/blueprint, skills/verify, skills/partition, agents/judge.md, agents/gatherer.md, tests/jimverify.sh, tests/jimpartition.sh, tests/gatepresentation.sh, tests/presenttense.sh, tests/provenance.sh, scripts/jim-deps-refs.sh
- **Blueprint:** docs/specs/blueprint/000-blueprint/

### issue

- **Purpose:** Discovery capture — actionable findings become structured,
  indexed, analyzable issue files through one emitter, with read views and a
  read-only insights persona.
- **Role:** domain
- **Boundary rationale:** A self-contained vertical with the project's
  widest-fan-in provides face after the platform CLIs; every stage emits into
  it through one narrow contract.
- **Relations:** requires `platform` (path/id/config CLIs, test framework);
  provider to `sdlc`, `blueprint` (emitter + candidate-batch contract), and
  `platform` (validator-lockstep).
- **Territory:** skills/issue, agents/issue-analyst.md, tests/issues.sh
- **Blueprint:** docs/specs/issue/000-blueprint/

### platform

- **Purpose:** The deterministic substrate every group composes with: config
  resolution, file/path/id operations, the SDLC ledger channel, and the bash
  test framework.
- **Role:** platform
- **Boundary rationale:** Total fan-in on stable CLIs justifies the shared
  surface — a change here has project-wide blast radius, which is exactly
  where contract checks pay.
- **Relations:** requires `issue` (validator-lockstep, dev-time), `sdlc`
  (personas the meta-test scaffold dispatches); provider to `sdlc`,
  `blueprint`, `issue` (the CLIs and test framework).
- **Territory:** skills/conf, skills/file, skills/ledger, skills/meta-test, tests/jimconf.sh, tests/jimfile.sh, tests/jimledger.sh, tests/metatest.sh
- **Blueprint:** docs/specs/platform/000-blueprint/

## Contract Graph

*Derived from the group blueprints' provides/requires faces — regenerated
on every blueprint write; do not edit. Last reconciled: 2026-07-26T05:55:10Z
(via /jim:blueprint)*

| Consumer | Relies on | Provider |
| :--- | :--- | :--- |
| sdlc | jimconf-cli (`jimconf.sh` resolver) | platform |
| sdlc | jimfile-cli (`jimfile.sh` path/id CLI) | platform |
| sdlc | jimledger-cli (`jimledger.sh` ledger CLI) | platform |
| sdlc | emitter (`new.sh` single emitter) | issue |
| sdlc | candidate-batch-contract (§ 7a) | issue |
| sdlc | advisor (`/jim:blueprint` map read) | blueprint |
| sdlc | blast-radius-facts (`jimverify.sh` edges) | blueprint |
| sdlc | living-intent-sensor (`/jim:verify` + judge) | blueprint |
| sdlc | gate-presentation-rule (canonical rule docs) | blueprint |
| blueprint | jimledger-cli (`jimledger.sh` ledger CLI) | platform |
| blueprint | jimconf-cli (`jimconf.sh` resolver) | platform |
| blueprint | jimfile-cli (`jimfile.sh` path/id CLI) | platform |
| blueprint | testlib (meta-test framework) | platform |
| blueprint | emitter (`new.sh` single emitter) | issue |
| blueprint | candidate-batch-contract (§ 7a) | issue |
| blueprint | personas (`agent:` bindings — architect, reviewer) | sdlc |
| issue | jimfile-cli (`jimfile.sh` path/id CLI) | platform |
| issue | jimconf-cli (`jimconf.sh` resolver) | platform |
| issue | testlib (meta-test framework) | platform |
| platform | validator-lockstep (byte-identical `is_valid_id`) | issue |
| platform | personas (scaffold-gate dispatch — pm, researcher, architect) | sdlc |
