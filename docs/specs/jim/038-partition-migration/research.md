---
spec: "docs/specs/jim/038-partition-migration/spec.md"
status: Active
date: "2026-07-07"
---

# Research: Partition migration skill

## Anchors

- `skills/blueprint/SKILL.md:26-38` — mode/adapter routing table; the
  migration skill's own arg routing (mode auto-detect + override) should
  mirror this shape.
- `skills/blueprint/SKILL.md:353-409` — map-tier M1–M3 flow (both-directions
  creation, `valid-relpath` territory validation, `commit-map`); the surface
  the migration delegates all map writes into (AC #7).
- `skills/blueprint/SKILL.md:93-140` — Step 4a grading + `auto_blueprint`
  gate governing post-approval blueprint generation (AC #6).
- `skills/blueprint/SKILL.md:411-432` — reconcile pass + counters the
  reconcile-to-clean loop drives to zero (AC #8/#9).
- `skills/blueprint/references/map-methodology.md:46-65` — creation
  interview method the migration's interview phase extends with the three
  forks (AC #5).
- `skills/spec/SKILL.md:52-77,10` — the mint-new `Skill(jim:blueprint)`
  delegation precedent, incl. the `allowed-tools` token declaration.
- `skills/verify/SKILL.md:201-214` — registry rung execution
  (`verify_command_<name>`: slug-validated, operator-owned, Bash-executed
  under `verify_registry_timeout`); the template for extractor wiring.
- `skills/verify/scripts/jimverify.sh:197-241,251-256` — territory
  extraction from the map + `safe_path_param` validation; directly reusable
  for the coverage set-difference (AC #4) and upgrade-mode conformance
  assessment (AC #15).
- `skills/conf/scripts/jimconf.sh:96-109,133-196` — dynamic-suffix key
  family resolution (`verify_command_?*`); a new extractor family means
  touching `KEYS`, `resolve()`, defaults, and tests here.
- `skills/review/scripts/jimledger.sh:230-242,189-210` — `event` verb
  (counters ride `k=v` on `finished` lines) and `commit-map`; the
  `tier=project` specs-root precedent for migration events (AC #16).
- `skills/issue/scripts/new.sh:54-64` — emitter interface for the
  punch-list batch (AC #13).
- `agents/investigator.md:13`, `agents/judge.md:15` — read-only
  `tools: [Read, Glob, Grep]` narrowing precedent for per-group evidence
  gatherers (Handoff Insight 3).
- **New files:** `skills/migrate/SKILL.md` (+ `references/` methodology);
  likely `skills/migrate/scripts/` for the native extraction/coverage
  scripts; `tests/<script>.sh`; possibly one read-only evidence agent.

## Local Patterns

- **Bash conventions:** `set -uo pipefail`, POSIX-only, never source user
  data, `BASH_SOURCE`-relative composition (`CLAUDE.md → Bash scripts`;
  canonical header `skills/meta-test/scripts/testlib.sh`).
- **Test template:** `tests/jimverify.sh` — sourced by
  `skills/meta-test/scripts/run.sh`, `OUT=$(...)` capture assertions,
  temp-dir fixtures from testlib; scaffold via `/jim:meta-test scaffold`.
- **Line budget:** SKILL.md < 500 lines; blueprint sits at 464 — confirms
  the migration must be its own skill with methodology in `references/`,
  not a blueprint mode.
- **Skill→skill inline invocation:** callee's tool calls run under the
  caller's grants; args passed explicitly (never auto-forwarded); watch the
  one-level subagent nesting limit if blueprint generation fans out judges
  while migration also fans out gatherers.
- **Untrusted-content discipline:** delimited evidence blocks + secret
  redaction (`skills/blueprint/references/reconcile-methodology.md`,
  `skills/verify/SKILL.md:228-231`).
- **Claim-check:** no existing skill/agent/script claims a
  migration/onboarding surface (grep sweep over `skills/`, `agents/`,
  scripts; only docs/issues reference it).

## Prior Art

External dependency-extraction tooling (operator-wired candidates; no
versions pinned — resolve at wiring time):

**Tier 1 — study closely**
- `go list -deps -json ./...` (Go, stdlib-only) — the exemplar zero-install
  per-language import extractor; JSON per-package deps.
- dependency-cruiser (JS/TS) — configurable rules + multiple output formats;
  closest existing analog to "extract graph, validate declared rules".

**Tier 2 — study for specific patterns**
- import-linter / grimp (Python) — "declared contracts checked against the
  import graph" is precisely the reconcile-validates-faces pattern.
- jdeps (Java, JDK built-in) — package-level dependency listing.
- `cargo metadata` (Rust) — workspace dependency graph.

**Tier 3 — reference only**
- madge (JS), pydeps (Python) — visualization-oriented import graphs.

Synthesis: **imports are the only coupling channel with mature generic
tooling.** Event topics, service-registry lookups, DI, and reflection have
no off-the-shelf extractor — in the dry-run those channels carried most
real edges and were found by reading module manifests. The honest native
fallback is therefore an import-scan (git-grep patterns per language)
**plus operator-suppliable patterns for project-specific channels** (e.g. a
topic-declaration regex), with unmodeled channels named in the coverage
label — not a promise of channel completeness. This grounds the spec's
first open question. (File-level prior-art tables omitted: external repos
not fetched, per WebFetch guardrails.)

## Libraries

None for jim itself — the scripting layer stays bash+POSIX (`CLAUDE.md`).
Extractors are operator-wired external commands via config, mirroring
`verify_command_<name>`; jim gains no dependency.

## Security & Performance

- **Registry trust boundary (reuse 035 Finding 1):** extractor commands
  come only from operator config with slug-validated dynamic suffixes
  (`jimconf.sh:148-163`), executed by the model via Bash under a timeout —
  scripts never execute config-derived strings; any blueprint/map-recorded
  tool name stays inert.
- **Extractor output is untrusted:** emitted paths validated through
  `valid-relpath`/`safe_path_param` before use; graph/evidence content
  wrapped in delimited blocks; secret-looking values redacted before any
  issue or map write (spec 018/034 discipline).
- **Integrity risk — falsely sparse graph:** a shallow extractor yields a
  clean-looking lie; the coverage label (AC #2/#3) is the mitigation and
  must be derived from what actually ran, never from tool claims.
- **Performance:** extract once deterministically, then fan out per-group
  evidence readers over that substrate (dry-run lesson: no per-group
  re-grepping); bound fan-out per the `verify_fanout_cap` precedent. A
  12-group run implies ~12 blueprint generations + reconcile — budget the
  session accordingly.

## Recommendations

1. **Extractor config family:** a new dynamic family (e.g.
   `extract_command_<lang>`) rather than overloading `verify_command_*`
   (different semantics: graph emission vs check execution). Cost: KEYS +
   `resolve()` + defaults + tests in `jimconf.sh`.
2. **Coverage set-difference:** reuse the territory machinery — either
   compose `jimverify.sh territory` per proposed group or ship a small
   migration-owned script; keep ownership clean (verify owns checking,
   migrate owns proposing).
3. **Delegation shape:** seed map creation by invoking the blueprint
   skill's M2 flow with the extracted-graph-grounded proposal as args
   (mint-new precedent); per-group generation then runs kernel-first under
   `auto_blueprint`. The blocked terminal state (AC #11) never invokes the
   blueprint surface at all — ledger + issues only.
4. **Ledger:** `tier=project op=migrate` events on the specs-root ledger
   (the 033/034/037 precedent), counters shape-validated per spec 028.
5. **Graph-health dependency (#63):** nothing in-tree computes health
   today — reconcile emits finding counters only. Sequence #63 before this
   build, or plan a degraded mode (see Peer Feedback).

This approach aligns with VISION.md (human-in-the-loop phase gates,
transparency over automation, not-a-black-box) and follows ARCHITECTURE.md's
established patterns: the blueprint surface as sole map author, the
registry trust boundary, read-only subagent narrowing, path-scoped ledger
commits, and the candidate-batch issue contract. No divergence identified.

## Peer Feedback

- **For PM (spec 038) — resolved 2026-07-07:** AC #10 requires presenting
  graph health, which issue #63 (reconcile-layer metrics) supplies — and
  #63 is unbuilt. PM decision: sequence #63 ahead of 038's build as a hard
  prerequisite; AC #10 stands unsoftened.
- **For Architect:** no plan.md exists yet; note the one-level nesting
  interaction (Insight 3's gatherer fan-out vs blueprint's judge fan-out
  cannot nest under each other in a single inline chain).
