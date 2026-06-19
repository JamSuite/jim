# Brainstorm: jim review phase

*2026-06-19*

## Core framing

The review phase closes the loop after code is written — jim currently runs
spec → research → sec → plan → sec → build, but nothing reviews the *actual diff*
once it lands. (`/jim:sec` already references a "planned `/jim:review`".)

- **What it catches:** (1) drift from spec/plan — did the build do what was
  scoped? — and (2) security regressions in the real diff (vs. `/jim:sec`'s
  design-time analysis of spec/plan).
- **Where it sits:** a gate *after* `/jim:build`.
- **Who reviews:** a new `@reviewer` agent, with an optional call to
  `@jim:security` for deeper security review.

## Naming — streamlined on "review"

Everything aligns on the word `review`, preserving jim's command↔agent↔artifact
symmetry (`/jim:spec` → `spec.md`, etc.):

- **Skill / command:** `/jim:review`
- **Agent:** `@reviewer`
- **Artifact:** `review.md`

## Constraint: diff scoping can't rely on `Spec:` trailers

Important correction surfaced during ideation. Jim's build does **not** stamp
commits with `Spec: <group>/<NNN>` trailers — it only mandates conventional
*prefixes* (`test:`/`feat:`/`fix:`/`refactor:`, see `skills/build/SKILL.md:80`
and `references/tdd-guide.md`). The `Spec:` / `Issue:` *trailer* convention
lives only in the user's personal global `~/.claude/CLAUDE.md`; it is **not**
part of jim. Every `Spec:` reference inside jim's skills/agents is the spec
*frontmatter field* or a gate that locates an approved spec — never commit
metadata.

Implication for `/jim:review`: a portable jim can't assume trailer-based diff
scoping. The reviewer must bound "what build changed" some other way (branch
divergence from main, working-tree diff, or an explicit range arg). Trailer
scoping could be an *optional enhancement* when the convention happens to be
present, but not the primary mechanism.

## Instrumenting the pipeline (multiple specs per branch)

The user sometimes runs **multiple specs in a single feature branch**, so
branch-divergence scoping (`main...HEAD`) is ambiguous. Solution: instrument the
pipeline with a clear marker of where/when a spec's build starts, giving the
reviewer (a) an exact diff range and (b) process metrics to report — not just
build-alignment verification.

### The marker: a build baseline

`/jim:build` records the **baseline SHA at build start** (and head SHA at
finish). Build is the only phase that knows when a spec's work begins. This does
NOT violate build's "no next-phase auto-invocation" rule — it leaves
breadcrumbs, it doesn't call review. Storage options:

| Mechanism | Pro | Con |
|-----------|-----|-----|
| **Sidecar record in spec dir** (`build.md` frontmatter: `base_sha`, `head_sha`, timestamps) | Version-controlled, grep-parseable, fits jim's artifact pattern; doubles as metrics home | Extra artifact build must write + commit |
| **Git tag** `jim-build-<group>-<NNN>` | Git-native, trivial range resolution | Clutters tag namespace, gets pushed |
| **Git note** | Doesn't pollute refs | Obscure, not pushed by default, easy to lose |

Leaning sidecar record — it's the natural home for metrics too.

### Metrics, tiered by achievability

Constraint: bash + POSIX, no `jq`/`yq`, language-agnostic, grep/sed-parseable.

**Tier 1 — free, derivable from git at review time (zero instrumentation):**
- Commit count, files changed, insertions/deletions (`git diff --shortstat`,
  `git rev-list --count`).
- **Commit-type ratio** — counts of `test:`/`feat:`/`fix:`/`refactor:`. A
  TDD-discipline signal: lots of `feat:` with no `test:` ⇒ Red-Green skipped.
- **Test-vs-production line ratio** — diffstat split by test vs. source paths.
- **Rework signal** — count of `fix:` commits / reverts = how bumpy the build was.

**Tier 2 — cheap, via artifact-existence checks (process completeness):**
- **Phase coverage** — did the spec traverse research? sec (which phases)? was
  the plan approved? Surfaces "this spec skipped security review" at a glance.
  One of the most useful + underrated metrics.
- **Task fidelity** — plan task count vs. commits: did every planned task land,
  and nothing extra?

**Tier 3 — needs build to actively record (richer instrumentation):**
- **Wall-clock time** — build stamps start/finish (more accurate than git dates,
  which miss research/setup time inside the phase).
- **Test counts** — if the project has a parseable runner, capture pass/total.
  Language-agnostic jim ⇒ project-dependent, best-effort.

**Tier 4 — aspirational / not portably achievable:**
- **Tokens** — no bash-reachable token meter a skill can read. Out of reach
  without harness support. Flagged so we don't design around an unattainable
  number.

### Division of labor

- **Build** drops the minimal baseline (Tier 3 fields optional).
- **Review** derives Tier 1 + 2 itself from git + artifact existence.

This keeps build simple while making the reviewer's report rich.

## Reframe: instrument the *whole pipeline*, not just build

Scope confirmed **per-spec**. Primary goal: verify the build was to spec and
note deviations. Deviations are not just build defects — they are an
**opportunity for a feedback loop to improve the process overall** (and hook
into `/jim:issue`, per earlier).

The realities (interruptions, re-runs, sec-triggered amendments, research
duration) are exactly what the metrics should *capture*, not edge cases to
dodge. Target shape: a **clear start, a clear end, and the pipeline in between
captured and reviewed** — structured so aggregate data can be mined at the
project level over time.

### The pipeline ledger (flight recorder)

A per-spec **append-only event log**; each phase appends as it runs. An
append-only log captures the listed realities naturally:

| Reality | How the ledger captures it |
|---------|----------------------------|
| **Interruption** | `started` with no matching `finished` = a dangling phase. Reviewer detects it for free. |
| **Re-run** | Build runs twice ⇒ two `build started/finished` pairs. Repetition needs no special logic. |
| **Causality** (sec → spec/plan update) | Amendment event carries `reason=sec-finding`. |
| **Duration** (research time, etc.) | Timestamp delta between phase `started` / `finished`. |

Git can't surface most of this — research has no commits, causality isn't in the
diff, interruptions leave no trace. So the reviewer fuses **two sources plus
ground truth**:

1. **Git** (`base..head`) → *code* metrics (commits, diffstat, type ratios).
2. **The ledger** → *process* metrics (durations, interruptions, re-runs,
   amendment causality, deviations).
3. **spec / plan / ARCHITECTURE.md** → alignment ground truth (+ optional
   `@security` pass for regression check).

Pipeline "start" = spec creation; "end" = the review itself (review is the
natural closing event + synthesizer).

### Mineable by construction

`review.md` uses jim's standard **dual structure** so per-spec-now becomes
aggregate-ready-later with zero new storage:

- **Frontmatter** = flat, stable, machine-mineable keys: `base_sha`, `head_sha`,
  `commits_test`, `commits_feat`, `commits_fix`, `commits_refactor`,
  `files_changed`, `insertions`, `deletions`, `research_minutes`, `sec_findings`,
  `sec_triggered_amendments`, `plan_deviations`, `build_interruptions`,
  `build_runs`, `phase_coverage`, `alignment: aligned|minor-drift|major-drift`,
  `deviation_count`.
- **Body** = human narrative: deviations, feedback-loop observations, findings.

A future project-level aggregator is then just a `grep` sweep over every
`review.md` frontmatter — no new format, consistent with how jim already stores
specs (frontmatter + body).

### Instrumentation surface (the cost)

Full-pipeline capture means every phase skill (spec, research, sec, plan, build)
must append to the ledger — a cross-cutting change. Mitigations:

- **Centralize** via a shared helper: `jimledger.sh append <spec> <phase>
  <event> [k=v...]` (one script, bash + POSIX, grep/sed-parseable lines).
- **Roll out incrementally**: instrument build first (highest value: baseline +
  deviations), then sec (causality), then research (duration), etc. Ship value
  early; expand coverage over time. The reviewer degrades gracefully — it reports
  on whatever events exist and notes gaps.

### Bonus signal: specs that die before build

If the pipeline "starts" at spec creation, a spec that never reaches build
leaves a ledger with no `build` events. At the project level this surfaces
spec→build conversion rate and abandoned scope — free feedback-loop signal.

## Decisions

- **Ledger persistence:** **committed** — the raw event log is a permanent
  artifact alongside `review.md`. Full audit trail / transparency (on-brand for
  "not a black box"); accept the append-during-run commit choreography.
- **Rollout:** **build-first** — instrument build first (baseline + deviations),
  then expand to sec (causality), research (duration), etc. over subsequent
  specs. Reviewer degrades gracefully on phases not yet instrumented.

## Summary of the shape

- `/jim:review` skill, `@reviewer` agent, `review.md` artifact (command ↔ agent
  ↔ artifact symmetry).
- Runs as a **gate after `/jim:build`**; produces a **findings report**, not a
  blocking pass/fail; hooks into `/jim:issue`.
- Verifies build-to-spec alignment against **git diff vs. spec ACs + plan tasks
  + ARCHITECTURE.md**; optional `@jim:security` pass for security regressions.
- Fuses **git** (code metrics) + a **committed append-only pipeline ledger**
  (process metrics) + spec/plan/arch ground truth.
- `review.md` = mineable frontmatter + human body ⇒ per-spec now,
  project-level aggregation later via a `grep` sweep.
- Cannot rely on `Spec:` commit trailers (user-CLAUDE.md convention, not jim).
- Tokens are not portably capturable (no bash-reachable meter) — out of scope.

## Drift detection — inputs

The analyst compares the **git diff** (what build actually changed) against
**all three** of:

1. **spec ACs** — was each acceptance criterion met?
2. **plan task list** — did it do the tasks, and *only* the tasks (no scope creep)?
3. **ARCHITECTURE.md** — did it respect architectural conventions?

## Verdict shape

- Output is a **findings report**, not a blocking pass/fail gate — consistent
  with jim's "transparency over automation / human-in-the-loop" non-goals.
- Hooks into **`/jim:issue`** like the other phases (end-of-phase candidate
  batch), so drift/security findings can be captured as actionable issues.

## Artifact

- Writes `review.md` into the spec dir alongside `spec.md` / `plan.md` /
  `research.md` / `security.md` — so the archive captures "here's how the build
  measured up."
