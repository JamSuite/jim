# The Pipeline Ledger

The ledger is jim's flight recorder: an append-only, committed event log that captures how the SDLC actually ran — when each stage started and finished, what the build's code boundary was, how each review's verdict moved, and what every blueprint, verification, and partition operation concluded. It is the durable record behind every "how did this go?" question the pipeline can answer, and the trusted data channel those answers are read through.

Git alone can't tell this story: research leaves no commits, an interrupted stage leaves no trace, and causality isn't in the diff. The ledger captures the process realities — interruptions, re-runs, durations, outcomes — as they happen, in a form that is grep-parseable now and mineable across specs later.

## What it looks like

Each ledger is a plain `ledger.md` of TAB-separated lines:

```
<epoch>  <iso8601>  <stage>  <event>  [k=v;k=v…]
```

A real spec's ledger, mid-pipeline:

```
1784767634  2026-07-23T00:47:14Z  build   started   base_sha=29ff5068…
1784770888  2026-07-23T01:41:28Z  build   finished  head_sha=ed684cae…
1784774777  2026-07-23T02:46:17Z  review  started
1784775430  2026-07-23T02:57:10Z  review  finished  alignment=minor-drift;findings=2
```

Append-only is the design, not an implementation detail — it captures the hard cases for free:

| Reality | How the ledger shows it |
| :--- | :--- |
| Interruption | A `started` with no matching `finished` |
| Re-run | A repeated `started`/`finished` pair |
| Duration | The timestamp delta between boundaries |
| Verdict history | Each review run appends its verdict; nothing is overwritten |

## The three ledger homes

**The spec ledger** — `docs/specs/<group>/<NNN>-<slug>/ledger.md`, beside `spec.md`. Every instrumented stage (`spec`, `research`, `plan`, `sec`, `build`, `review`) records its own start/finish. `/jim:build` additionally records the build's boundary — the baseline SHA at start and head SHA at finish — which is what lets [the review](review.md) scope "what this build changed" exactly, even when several specs share one feature branch. `/jim:review` appends its alignment verdict and findings count on completion, so re-running a review overwrites the `review.md` snapshot but the verdict *trajectory* (`major-drift → aligned`) survives here.

**The group blueprint ledger** — `docs/specs/<group>/000-blueprint/ledger.md`. Blueprint update runs record their guard outcomes (`violations=`/`folded=`/`fixed=`), `/jim:verify` runs record per-invariant outcome counts, and the cadence signal counts `blueprint finished` events against the blueprint's `last_full_generate` watermark to report targeted updates since the last full regeneration.

**The specs-root ledger** — `docs/specs/ledger.md`, carrying project-tier events tagged `tier=project`: map-tier blueprint writes, the reconcile pass (`op=reconcile`, with its fifteen finding/health/face counters), cross-group contract and retirement verification runs, and the partition operations (`op=rename` / `op=split` / `op=merge` / `op=health`). On a partition move this ledger is the durable old→new **bridge**: the event records the identity mapping (and on split/merge the complete per-spec remap), which is what keeps a frozen or re-homed archive traceable — git history is unrewritable, so the ledger event is the alias every migration mode leans on.

## Design features

**A trusted read-back channel.** Consumers never parse ledger prose. They read through `jimledger.sh metrics` (and its siblings), which emits a **fixed, code-literal key set** with shape validation: SHAs pass the `valid-id` gate before any git use, verdicts are checked against the known vocabulary (`aligned` / `minor-drift` / `major-drift`), counts must be non-negative integers, and attribution values must be valid group slugs. No key is ever derived from ledger text — so a tampered or malformed ledger can surface at most a bounded, well-formed value, never inject keys or steer a consumer.

**Content-free events.** Events carry numbers, validated SHAs, and validated slugs — never file paths, names, or prose lifted from scanned content. Rich detail (which directories are uncovered, which cycle formed) lives in the run's conversational report; the ledger keeps only the countable trace.

**Committed durability.** The ledger is a permanent artifact, not session state. Stage events normally ride the same commit as the artifact they describe; stages with no approval gesture to ride commit their own record through path-scoped commit verbs (`commit-review`, `commit-blueprint`, `commit-map`, `commit-verify`, and the partition choreography) — literal paths behind a `--` guard, never `git add -A`, so unrelated working-tree changes can never be swept into a ledger commit.

**Graceful degradation.** Instrumentation is optional per stage: a stage that never ran simply has no keys, and consumers report the gap rather than failing. A pre-ledger build still reviews; a malformed event is excluded from a series with the exclusion named, never silently absorbed.

**No standing verdict.** For the runs that persist no report artifact — verification, reconciliation, partition health — the ledger's outcome counters are deliberately the *only* durable trace. A violation nobody filed as an issue remains attributable after the fact, without a persisted "verified ✓" artifact that would rot into misplaced trust.

## Who reads it

- **`/jim:review`** derives its process metrics (per-stage `_runs` / `_interruptions` / `_duration_seconds`), resolves the build range for its diff, and surfaces the verdict trajectory. See [the review feature](review.md).
- **`/jim:blueprint`** consumes the review's shape-validated verdict in its `--from-review` update adapter, counts targeted updates for the regen cadence (`updates-since`), and reads the prior reconcile event (`last-reconcile`) to render each health measurement's delta.
- **`/jim:partition health`** evaluates its trend signals over the full reconcile counter series (`reconcile-series`) — rising cycles, recurring breaking findings, face growth — entirely from the ledger, no new storage.
- **The partition verbs** machine-consume their own history: the identity sweep derives retired group slugs from the recorded `op=` events, and `pair-events` reads a move's durable `moved=` remap so the allocator can lift those pairs into registry records. Ordinal authority itself is the registry's, not the ledger's — a vacated ordinal is recorded as a rename source there rather than inferred from an event a fresh clone may never have seen.
- **Future mining** — per-spec now, aggregate later: the fixed-key format means a cross-spec dashboard is a grep sweep away, with no new format needed. (No aggregator ships today; the data is mineable by construction.)

## `jimledger.sh` at a glance

The ledger's single owner is `skills/ledger/scripts/jimledger.sh` — bash + POSIX, no third-party dependencies, and the only jim script that reads git operationally.

| Group | Subcommands |
| :--- | :--- |
| Record | `start`, `finish` (build boundary), `event` (generic stage event) |
| Read | `events`, `metrics`, `updates-since`, `last-reconcile`, `reconcile-series`, `pair-events` |
| Build range | `files`, `diff` (ledger-resolved), `files-range`, `diff-range` (validated ad-hoc range) |
| Commit | `commit-review`, `commit-blueprint`, `commit-map`, `commit-verify`, `commit-rename`, `commit-split`, `commit-merge` |
| Moves | `rename-tracked`, `move-spec-dir` (guarded `git mv` — staging, never committing) |

Ledger content is untrusted on read: it is parsed, never `source`d or eval'd, and everything extracted from it passes validation before use.
