---
spec: "docs/specs/blueprint/008-verify-loop/spec.md"
status: Active
date: "2026-07-05"
---

# Research: Verification engine loop integration

## Anchors

Two framing facts before the anchor list. **(1)** The engine is whole-group
only: the floor runs every pattern/structure invariant over the territory,
and the judge rung judges every above-appetite invariant over the whole
territory scope — no mechanism anywhere narrows verification to a diff or an
invariant subset. Diff-scoping (spec AC #2, #7) is net-new surface. **(2)**
No `Skill(jim:verify)` call exists in any skill — the engine is reached only
by slash command or the reviewer agent's preload. 036 introduces the first
programmatic caller.

- `skills/verify/SKILL.md:122-131` — the judge rung: `Agent(judge)` dispatch
  with territory-scope paths, `verify_fanout_cap`, appetite gating. The rung
  036 makes selection-scoped.
- `skills/verify/SKILL.md:102-107` — the mechanical floor ("always runs —
  never gated by appetite"); the sensor's whole-group half reuses this as-is.
- `skills/verify/SKILL.md:21-29` — argument routing (`--appetite` strip);
  where a scoped-invocation mode's flags land.
- `skills/verify/scripts/jimverify.sh:335-370` — `cmd_check`, the floor
  executor (territory resolve at 346-356, UNSCOPED sentinel 357-358); a
  scope parameter would extend this verb. Output contract: `emit_outcome`
  at 200-204 (`id \t outcome \t evidence`).
- `skills/verify/scripts/jimverify.sh:67-131` — `cmd_parse` TSV
  (`id/criticality/method/params/invariant`); legacy 3-col tables fall to
  all-judge under synthesized `inv-<n>` ids (121, 126).
- `skills/review/SKILL.md:67-110` — Step 4 (triage → investigator fan-out →
  verdict); Step 4d emits `review finished` *before* composing `review.md`
  (spec 028 ordering) — the sensor must sit before this boundary if its
  counts ride review's event, or emit its own verify event.
- `skills/review/SKILL.md:184-197` — Step 10, the `--from-review` blueprint
  update invocation; the sensor→fork hand-off crosses here.
- `skills/review/SKILL.md:13` — review's `allowed-tools`: **no
  `Skill(jim:verify)`, no `Agent(judge)`** — a capability grant is required.
- `skills/review/assets/review-template.md:33-35, 65-87` — frontmatter slot
  for a violations counter (beside `plan_deviations`/`security_regressions`)
  and the body seam for a living-intent section (after `## Investigation`,
  before `## Metrics`).
- `skills/blueprint/SKILL.md:262-341` — U3: the violation fork. Detection
  today is pure LLM judgment over diff + Invariants table (264-271) — the
  exact text engine grounding replaces/augments. Fork presentation 272-297,
  resolutions 288-292, issue offer 302-330.
- `skills/blueprint/SKILL.md:157-181` — U1: adapter diff acquisition
  (`--from-review` 170-173; `--since` 174-177); the `--since` engine call
  slots here. U4 counters + `commit-blueprint` at 352-359.
- `agents/judge.md:39-45, 67-79` — judge input contract (**line 44: "There
  is no diff; you read the current code"**) and verdict shape
  (`holds|partial|violated` + `locations_examined`/`evidence`).
- `agents/reviewer.md:33-35, 66` — `skills: [review, verify]` preload;
  `tools` has `Agent(investigator)` but **not `Agent(judge)`**; inline-run
  constraint.
- `skills/review/scripts/jimledger.sh:211-226, 324` — `commit-verify`
  (ledger-only, path-scoped) and `LEDGER_STAGES` already containing
  `verify`; `cmd_files` 282-290 gives the trusted changed-file list for
  channel classification.
- `skills/conf/scripts/jimconf.sh:88-91, 148-164` — `verify_appetite`
  default `low` (everything judge-eligible out of the box), `verify_fanout_cap`
  `10`, `verify_model` `inherit`, `verify_registry_timeout` `120`; dynamic
  `verify_command_*`/`verify_appetite_*` family arm.
- `docs/specs/jim/000-blueprint/spec.md:146-181` — jim's own Invariants
  table is **legacy 3-column** (no `Id`/`Check`, no `verify-checks` block,
  ~29 rows): the live example of the all-judge fallback path.
- Tests: `tests/jimverify.sh` (19 `case_*`, e.g. parse/check cases at
  54-423) and `tests/jimledger.sh` (verify-stage cases at 797-851) are the
  templates for new deterministic coverage.

## Local Patterns

- **Inline skill composition keeps nesting legal.** `Skill(jim:<name>)`
  bodies run inline in the main thread (ARCHITECTURE.md → Skill Invocation),
  so `review → Skill(jim:verify) → Agent(judge)` is still one agent level —
  same shape as review → `Skill(jim:blueprint)` at Step 10. Namespaced
  `allowed-tools` token + explicit args (no `$ARGUMENTS` auto-forward).
- **Flag-strip argument convention** — `--depth` (review), `--appetite`
  (verify), `--from-review`/`--since` (blueprint): strip the flag, remainder
  positional. A scoped-mode flag follows this.
- **Ledger conventions:** stage events via `jimledger.sh event`; verify
  events live on the group's `000-blueprint/ledger.md` and self-commit via
  the existing ledger-only `commit-verify` arm — no new commit choreography
  needed for AC #12.
- **Untrusted-evidence discipline:** delimited blocks
  (`<untrusted-change-evidence>` in U3a; verify's judge-evidence handling) —
  the sensor's outcomes crossing into the fork reuse this verbatim.
- **Test template:** hand-rolled bash framework (`testlib.sh`), `case_*`
  discovery by name, `run_<name>` invoker, mktemp sandbox + heredoc
  fixtures — `tests/jimverify.sh:54` (`case_jimverify_parse_wellformed`) is
  the closest model.

## Security & Performance

- **The two-channel classifier is load-bearing.** Routing a violation to
  "fork" vs "report + issue" (AC #4) must not be steerable: classify by
  intersecting outcome **evidence paths** with the **trusted** changed-file
  list (`jimledger.sh files`), and treat evidence paths from judge/registry
  output as untrusted data — a spoofed path in adversarial output could
  otherwise re-route a build-caused violation away from the fork.
- **Registry commands in the sensor are the cost risk.** They run verbatim
  via Bash with `verify_registry_timeout` (default 120s); an
  operator-registered test suite on every review could dominate review
  wall-clock. The spec's open question (registry whole-group vs
  diff-scoped) is a real cost/fidelity fork — data below.
- **Double-run avoidance (AC #5)** also bounds cost: without it, a reviewed
  change pays judge fan-out twice (sensor + fork grounding).
- **Coverage regression risk is real but bounded:** default
  `verify_appetite=low` means every invariant is judge-eligible
  out-of-the-box; the non-regression AC (#8) only bites where an operator
  raised appetite — the fallback mechanism matters exactly there.

## Recommendations

1. **Scope selection, not evidence.** Read AC #2's diff-scoping as *which
   invariants get judged* (selection), not *what the judge reads*. The judge
   contract (`judge.md:44` — no diff, current code) can stand unchanged; the
   verdict stays "does the invariant hold now". Optionally pass changed-file
   hints to focus reading. This makes Insight 1 cheap: no judge redesign.
2. **Touch heuristic = mechanical prefilter + LLM triage.** Floor outcomes
   already carry evidence paths; for judge-rung invariants, intersect
   invariant scope/params with `jimledger.sh files` output where possible,
   and fall back to LLM triage (the 027 risk-classification lineage) for
   prose invariants. Keep the classifier's *inputs* trusted (files channel).
3. **Integration shape:** review gains a sensor step invoking
   `Skill(jim:verify)` in a scoped mode (new flag, e.g. `--for-review
   <spec-dir>` or `--scope <range>`); blueprint's `--since` adapter invokes
   the same mode (AC #7). Grants: review `allowed-tools` +
   `Skill(jim:verify)`; blueprint `allowed-tools` + `Skill(jim:verify)`.
   The reviewer agent needs no `Agent(judge)` grant if the fan-out happens
   inside the verify skill's inline body (its `allowed-tools` already
   carries it).
4. **Hand-off in-conversation.** Step 10 runs inline immediately after the
   sensor in the same session, so outcomes pass as conversation context
   (delimited, untrusted) — no persisted verdict artifact (034/035
   doctrine). A scratchpad temp file is the fallback if context pressure
   appears at plan time.
5. **Non-regression via inline-sweep fallback.** Prefer spec Insight 3's
   option (a): keep U3a's existing diff-vs-table LLM sweep as the detection
   floor for invariants the engine didn't cover (skipped / unconfigured /
   failed / legacy-no-data), with engine outcomes superseding where present.
   Option (b) (appetite-exempt judges) buys depth at real fan-out cost and
   still misses `unconfigured`/`failed`.
6. **Registry rung: lean diff-scoped in the sensor.** Registry commands are
   whole-project invocations the operator tuned for on-demand runs; in the
   per-review sensor, gate them with the judges (diff-scoped selection)
   rather than the always-on floor, or the sensor inherits unbounded
   operator command cost every review. Architect may override with data.
7. **Blueprint SKILL.md budget is a prerequisite problem:** 497/500 lines —
   U3a grounding edits cannot land without restructuring (issue #43) or
   routing the new methodology to `references/` (extend
   `check-authoring.md` or a sibling loop-integration reference). Treat
   issue #43 as effectively blocking 036's blueprint-side tasks.
8. **jim's own blueprint is the legacy path.** Its 3-col table means the
   sensor on jim runs all-judge fallback with zero mechanical floor checks;
   regenerating it with structured `check:` data (035 authoring path) is
   the natural way to exercise 036 end-to-end at full strength.

**Alignment:** wiring the engine into review/update follows ARCHITECTURE.md's
locked patterns — inline `Skill()` composition, one-level nesting, ledger
stage events + path-scoped commits, capability-backed read-only judges,
untrusted-content discipline — and serves VISION.md's "maintain architectural
consistency" mechanism (the fold-back loop keeping living intent honest). No
divergence from locked constraints identified.
