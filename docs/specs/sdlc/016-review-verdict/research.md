---
spec: "spec.md"
status: Active
date: "2026-06-26"
---

# Research: Instrument /jim:review as a ledger stage and preserve verdict history

Phase 0 (local archaeology) only — this is entirely internal jim plumbing
(`jimledger.sh`, the review skill/template, the test suite). Phase 1 (external)
skipped: no external APIs, libraries, or prior art are involved.

## Anchors

**`skills/review/scripts/jimledger.sh`** (the stage-event log + metrics channel):
- `:173` — `LEDGER_STAGES="spec research plan sec build"`. Add `review` here; the
  per-stage triplet then falls out for free (AC #1).
- `:187-202` — `phase_event_metrics` emits `<stage>_runs` / `_interruptions` /
  `_duration_seconds` over the fixed allowlist. Note `_duration_seconds` =
  *first-started → last-finished* (relevant to the re-run Open Question).
- `:108-127` — `ledger_kv <ledger> <phase> <event> <key> first|last`. The
  extraction primitive; `last` is exactly how `head_sha` is surfaced — reuse it
  for the latest `alignment` (AC #4).
- `:204-242` — `cmd_metrics`. Where to add a `review_alignment` / `review_findings`
  extraction *and* the AC #9 value-validation (enum / non-negative int).
- `:93-106` — `cmd_event`. Review emits via this:
  `event <dir> review finished alignment=<v> findings=<n>` (AC #2).
- `:43-55` — `append_line` creates `ledger.md` via `>>` when absent (but requires
  the spec-dir to exist, which it always does for review). The "create ledger if
  absent" path (Insight 4) is therefore free (AC #6).
- `:19-22` — security comment: *"The script never commits; the build commits
  ledger.md."* This documented invariant must change if the commit lands here
  (AC #10 / Insight 6).
- `:244-255` — `main()` `case` dispatch (`start|metrics|files|diff|finish|event`).
  A new `commit-review` subcommand slots in here (AC #8/#10).
- `:57-60`, `:154`/`:166`/`:219` — `validate_sha` + the `git … --` end-of-options
  guard pattern: the precedent for AC #10's safe, literal-path commit.

**`skills/review/SKILL.md`**:
- `:13` — `allowed-tools` grants `Bash(bash ${CLAUDE_SKILL_DIR}/scripts/jimledger.sh *)`
  but **no git**. A `commit-review` subcommand rides the existing permission — no
  broad git grant needed (AC #10).
- Step 1 `:33-39` — spec.md precondition. Emit `review started` after this.
- Step 2 `:45-54` — current `jimledger.sh metrics` call **(before the verdict)**.
- Step 4d `:88-94` — verdict determined (`aligned`/`minor-drift`/`major-drift`).
  Emit `review finished alignment=… findings=…` after this.
- Step 8 `:108-110` — write `review.md` (overwrite on re-run).
- `:53` — graceful-degradation contract (absent ledger/metrics → empty keys,
  best-effort, never fail).

**`skills/review/assets/review-template.md`**:
- `:89-96` — Metrics rows. `Stage runs (spec·research·plan·sec·build)`,
  `Stage durations (research·plan·sec·build)`, `Interruptions (research·plan·sec·build)`.
  AC #7 adds a `review` column to all three; doing so also adds the `spec` column
  the durations/interruptions rows omit — **absorbing issue #16**.
- `:1-34` — frontmatter. `alignment: "{aligned | minor-drift | major-drift}"`
  **already exists** (`:32`), as do the per-stage metric fields — so `review.md`
  already records the verdict; AC #3/#9's "review.md is authoritative" is natural.

**`tests/jimledger.sh`** (coder's test template):
- `:36-51` — `git_fixture` builds a throwaway repo + spec-dir (needed for the
  commit subcommand test).
- `:89-94` — `case_jimledger_event_appends_line` (event-emit assertion template).
- `:224-241` — `case_jimledger_metrics_per_stage` (per-stage metrics template —
  copy for a `review`-stage case).

## Local Patterns

- **Stage-event convention:** `started` after the precondition, `finished` at
  completion/approval. Review breaks the mould twice: its `finished` carries a
  **payload** (`alignment`, `findings`) where every other stage's is bare, and it
  must fire **before** `review.md` is composed (so the file can read its own
  metrics) — not "at the very end" like the others.
- **Verdict surfacing reuses `head_sha`'s shape:** `ledger_kv … last` for the
  latest verdict; key names literal in `cmd_metrics` (the no-key-injection
  property).
- **Test framework:** hand-rolled bash (`tests/jimledger.sh` sources
  `skills/meta-test/scripts/testlib.sh`); `run_jimledger` invoker capturing
  `OUT`/`ERR`/`RC`; `case_*` functions; asserts `assert_exit`/`assert_match`/
  `assert_eq`/`assert_nonempty`. New cases: `review`-stage metrics, the
  `commit-review` subcommand, and AC #9 verdict-value validation (incl. a
  tampered-value case).

## Security & Performance

- The two Notables are already ACs (#9 verdict validation, #10 least-privilege
  commit). Concrete anchors: validate the extracted verdict in `cmd_metrics`
  (`:204-242`) against the three-value enum; build `commit-review` on the
  existing `validate_sha` + `--`-guard pattern with literal `review.md`/`ledger.md`
  paths, never `git add -A`; and update the `:19-22` "never commits" comment.
- **Performance:** negligible — the ledger grows ~2 lines per review run, one
  commit per run, and `cmd_metrics` is `awk` over a tiny file.

## Recommendations

*Options and trade-offs for the architect — not decisions.*

1. **Emit-ordering wrinkle (the load-bearing finding).** `cmd_metrics` is read at
   SKILL **Step 2**, but the verdict lands at **Step 4d** and `review finished`
   must follow it. For `review.md` to report its *own* `review_*` metrics (AC #7),
   the metrics that feed `review.md` must be (re-)read **after** `review finished`
   is emitted. Options: (a) move the `review.md`-feeding metrics read to Step 8;
   (b) keep Step 2's read for build/upstream metrics and add a second review-only
   read after `finished`; (c) compute review's own triplet inline. AC #7 is fully
   satisfiable — it just forces this reordering. Architect's call.
2. **Verdict surfacing + key names.** Extract `review_alignment` (latest, via
   `ledger_kv … last`) and `review_findings` in `cmd_metrics`, validating the
   enum / integer (AC #4 + #9). Namespaced names (`review_alignment` /
   `review_findings`) match the existing triplet — resolves the spec's key-naming
   Open Question.
3. **Commit mechanism.** Recommend a `jimledger.sh commit-review <spec-dir>`
   subcommand (`git -C … add -- review.md ledger.md && git commit`, `--`-guarded,
   literal paths) over a broad git grant or a separate script — least new surface,
   and review already holds the `jimledger.sh *` permission. Trade-off: overturns
   the "never commits" invariant; confine it to that one audited function.
4. **Create-vs-skip ledger (Insight 4).** `append_line`'s `>>` already creates the
   ledger, so "create when the build wasn't instrumented" is the zero-effort
   default; "skip" would need an added guard. Recommend just letting it create.
5. **Re-run duration (Open Question).** `_duration_seconds` spans first-start →
   last-finish; review re-runs days apart will read as a large span. Keep
   (consistent with all stages) or special-case review per-run. Low stakes —
   flag, don't block.

## Peer Feedback

None that invalidates the spec — AC #7 is achievable; Recommendation 1 is an
integration constraint for the plan, not a feasibility gap. Both deliberate
deviations from documented invariants — the content-free → fixed-key metrics
reframe (AC #4) and the "non-build stages don't commit" exception (AC #8/#10) —
require updating `ARCHITECTURE.md`'s ledger-convention text. That regen is
pipeline-owned: the `/jim:build` completion gate runs `/jim:arch`, so it is not a
follow-on issue.

**Alignment:** Consistent with VISION (the verdict trajectory as compounding
institutional memory; auto-commit transparency honours "not a black box") and
with ARCHITECTURE — this extends the existing `jimledger.sh` ledger component
rather than adding a new store, and the two invariant changes are scoped,
sourced, and ARCHITECTURE-tracked.
