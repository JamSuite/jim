---
spec: "docs/specs/blueprint/016-partition-health/spec.md"
status: Active
date: "2026-07-12"
---

# Research: Partition-health sensors

## Anchors

**Hook attach point and threshold analog**

- `skills/blueprint/SKILL.md:415-449` — § Reconcile: Step 2a renders the 039
  health block (`:431-440`); Step 3 records the eleven-counter
  `blueprint finished tier=project op=reconcile` event and runs `commit-map`
  (`:441-449`). The reconcile-tail hook (AC #5/#7) attaches here.
  **The file is at 500/500 lines — the cap** (see Peer Feedback).
- `skills/blueprint/SKILL.md:245-285` — U2a `blueprint_regen_threshold`
  wiring: the exact fail-safe wording (`:266-267`) and firing `IF` (`:269`)
  that AC #6's threshold semantics mirror.
- `skills/blueprint/references/reconcile-methodology.md:246-279` — the
  eleven-counter contract (int-or-na carve-out `:259-265`; whitelist rule
  `:275-279`). **The doc AC #4's new face-size counters must update.**
  Health-block rendering rules at `:281-329`.

**Trend series (the gap)**

- `skills/review/scripts/jimledger.sh:608-644` — `last-reconcile`: selects
  only the *latest* `op=reconcile` event (`:621-624`), validates counters
  against the fixed whitelist (`:615-618`, int-or-na awk `:636-638`).
  **No verb extracts the full event series** — the sensors' trend input
  needs a new verb; this parse is its reusable substrate.
- `skills/review/scripts/jimledger.sh:580-592` — `updates-since`: the ISO
  watermark regex + rc-2 discipline (`:585-586`) a series verb should copy.
- Event line format: 5 TAB fields, kv `;`-joined (`jimledger.sh:78`,
  `:367-371`). Counter keys are exactly
  `edges leaks breaking dead unresolved undeclared stale groups cycles
  fanin uncovered` — note **`fanin`, not `fanin_max`** (see Peer Feedback).

**Signal-class substrate**

- `skills/verify/scripts/jimverify.sh:991-1117` — `health` verb:
  measurement-only facts (`:986-987`) with evidence rows the report can
  reuse (`CYCLE` members `:1042`, `FANIN_GROUP` `:1050-1055`,
  `UNCOVERED_DIR` `:1113`, `UNCOVERED\tna` degradation `:1077-1088`).
- `skills/verify/scripts/jimverify.sh:682-754` — `faces` verb: 6-column TSV
  per Provides/Requires entry; counting `kind == provides` rows per group is
  the face-size measurement (AC #4).
- `skills/partition/scripts/jimpartition.sh:858-885` — `map_group_slugs` +
  `old_group_territories`: slug-gated map parsing; `slug_token_match`
  (`:840-853`) is the whole-token matcher; **rename-preflight already emits
  `TERRITORY-IDENTITY` records** (`:953-961`) — the name-mismatch
  comparison (AC #8) substantially exists.

**Surfaces, knobs, gates**

- `skills/partition/SKILL.md:31-44` — routing table; a `health` row slots
  after `:40` (rename), section modeled on Territory-target runs
  (`:212-245`). File at 329 lines — headroom exists. In-run health
  consumption precedent at `:171-190`.
- `skills/partition/references/partition-methodology.md:149-214` — natural
  slot for a `## § Health` methodology section.
- `skills/conf/scripts/jimconf.sh:42,48-94,167` — generic key resolution:
  `require_health`/`auto_health` route via the `require_*`/`auto_*`
  prefixes once defaults land; per-signal threshold keys need a prefix
  family added to the `:167` test (or the dynamic-family mechanism
  `:150-166`).
- Gate wording to mirror: `skills/build/SKILL.md:226` (`require_review`
  completion hold), `skills/review/SKILL.md:214,221` (`require_blueprint`
  terminal-stage hold; any-answered-fork rule).

## Local Patterns

- **Bash-vs-Prompt rule:** facts as TAB-separated records from script;
  framing/judgment in skill (`jimverify.sh:986-987` states it for health).
  Threshold evaluation is deterministic → script side.
- **Injection-proof counter extraction:** fixed-key whitelist, unknown keys
  dropped (`jimledger.sh:635`) — the pattern any new series verb reuses.
- **Test template:** `tests/jimverify.sh:1044-1055`
  (`case_jimverify_health_acyclic`) — `run_jimverify` capture (`:31-36`),
  `tsv_field` (`:45-47`), `hmap` fixture builder (`:1020-1034`). Ledger
  side: `tests/jimledger.sh:837-849` asserts a full eleven-counter
  reconcile line (fixture literal at `:840`). Conventions per
  `skills/meta-test/scripts/testlib.sh` header; scaffold via
  `/jim:meta-test scaffold`.
- **Phase 1 (external) skipped:** no external APIs, libraries, or examples
  in scope — bash + POSIX only per project constraint; all substrate local.

## Security & Performance

- **Untrusted map/blueprint content:** group names and territory paths are
  parsed data — existing slug gates (`jimpartition.sh:864`,
  `jimverify.sh:236`) and `safe_path_param` (`jimverify.sh:278-288`) are
  the boundary; report quotes ride the AC #12 delimiters. Firing decisions
  read only whitelisted counters (the trusted channel).
- **Content-free health event (AC #11):** counters only — no group names in
  kv, matching the spec-026 doctrine the whole ledger enforces.
- **Write-cycle guard:** partition already invokes `Skill(jim:blueprint)`
  (materialization); the hook adds blueprint → `Skill(jim:partition)`. No
  runtime cycle *only because* health mode is read-only (AC #1) — a health
  run must never trigger a blueprint write. Worth an explicit plan-level
  invariant. No `Agent` fan-out in health mode, so the one-level nesting
  limit is untouched; blueprint's `allowed-tools` (`SKILL.md:17`) must gain
  `Skill(jim:partition)`.
- **`na` handling:** coverage can be `na` (not computable) — a trend
  reading `na` as 0 would fabricate health; the int-or-na carve-out
  (`jimledger.sh:636-638`) must carry through series extraction (AC #9's
  never-read-as-healthy).
- **Cost:** silent hook = one script invocation per reconcile, zero LLM
  spend (AC #5); series extraction is a single linear ledger pass.

## Recommendations

1. **Series verb home: `jimledger.sh`** (e.g. a reconcile-series verb
   generalizing `last-reconcile`'s whitelisted parse to all matching
   events, oldest-first). It owns event parsing and validation; jimverify
   owns graph facts; jimpartition owns map facts. Alternatives noted for
   the architect, but ownership lines are clean.
2. **Threshold evaluation script-side**, emitting `CROSSED`-style facts the
   skill consumes — keeps the blueprint SKILL.md hook to a few lines (the
   500-cap pressure) versus a U2a-style skill-side `IF` chain.
3. **Face-size counters at Step 2a/3:** count `faces` provides rows per
   group during the reconcile; ride the existing event. Three sync points:
   the contract doc (`reconcile-methodology.md:246-279`), the producer
   (`SKILL.md:441-449`), the whitelist (`jimledger.sh:615`). Aggregate
   encoding (a total + a max, int-or-na) fits the fixed-key contract.
4. **Name-mismatch facts in `jimpartition.sh`:** reuse/extract the
   `TERRITORY-IDENTITY` comparison from rename-preflight rather than
   reimplementing in jimverify — the token matcher and map parsers live
   there (spec-043 precedent).
5. **Hook prose budget:** blueprint SKILL.md has zero headroom; put hook
   methodology in `reconcile-methodology.md` (adjacent to § Graph health)
   and keep the SKILL.md delta near-zero — or pair with the open
   restructure issue (#43). The architect should treat the cap as a hard
   planning constraint.
6. **Knob wiring:** defaults `"false"` for `require_health`/`auto_health`
   in `default_for` + `KEYS`; pick the threshold key family (e.g. a
   `health_*` bare-name prefix vs the dynamic-suffix mechanism) — architect
   call, with the `:167` prefix test as the decision point.

## Peer Feedback

**For PM (spec corrections — both trivial, neither affects feasibility):**

- Spec Handoff **Insight 1 misnames the fan-in counter `fanin_max=`** — the
  shipped key is `fanin=` (`jimledger.sh:617`;
  `reconcile-methodology.md:255-257`). Amend the example so the architect
  isn't handed a wrong anchor.
- Spec Handoff **Insight 5 cites "455/500 post-036" — stale.** Verified
  today: `skills/blueprint/SKILL.md` is at **500/500**, the constraint cap
  (ARCHITECTURE.md → Skills → Key Constraints). The insight's "architect's
  call" framing understates it: the hook *cannot* add net lines. Open issue
  #43 (blueprint SKILL.md restructure) is the standing remedy and is
  strengthened by this finding — consider naming it in the insight as a
  likely companion/prerequisite.

No plan.md exists yet — no plan-invalidation signals.

## Alignment

The approach follows ARCHITECTURE.md's locked patterns — Bash-vs-Prompt
split, trusted content-free metrics channel (spec 026), fixed-key
shape-validated counters (034/039/028), path-scoped self-commits, and the
no-standing-verdict doctrine — and VISION.md's human-in-the-loop stance:
findings stay advisory, the remedy (`/jim:partition`) stays
human-initiated, and every run leaves a transparent ledger trace ("not a
black box"). No divergence found.
