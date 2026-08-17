---
spec: "docs/specs/blueprint/004-blueprint-regen-cadence/spec.md"
status: Active
date: "2026-07-03"
---

# Research: Blueprint regen-cadence signal

Local archaeology done directly (the relevant files were read in-session while
scoping): `skills/blueprint/SKILL.md`, `skills/review/scripts/jimledger.sh`,
`tests/jimledger.sh`, `skills/blueprint/assets/blueprint-template.md`. No
external research — this is an internal bash/prompt feature with no new deps.

**Alignment:** Fits ARCHITECTURE.md's Scripting Layer (bash-only, no third-party
deps; a new `jimledger.sh` subcommand consumed via the existing wildcard grant)
and its trust boundary (ledger is untrusted, parse-only). Serves VISION.md's
"transparency over automation" — a visible staleness cue, no new automation or
gate. No divergence from a locked constraint.

## Anchors

- **`skills/review/scripts/jimledger.sh:53-63`** — `append_line`: the sole ledger
  writer. Line format is `<epoch>\t<iso>\t<phase>\t<event>\t<kv>`, iso via
  `date -u +%Y-%m-%dT%H:%M:%SZ`. The new count subcommand parses this.
- **`skills/review/scripts/jimledger.sh:275-289`** — `phase_event_metrics`: the
  exact counting idiom to clone. It already counts `blueprint finished` events:
  `awk -F'\t' -v p="$ph" '$3==p && $4=="finished"{n++} END{print n+0}'`. The new
  `updates-since` is this plus a `$2 > watermark` field filter.
- **`skills/review/scripts/jimledger.sh:358-372`** — `main()` dispatch `case`.
  Add an `updates-since) shift; cmd_updates_since "$@" ;;` arm here.
- **`skills/review/scripts/jimledger.sh:157-163`** — `cmd_commit_blueprint`:
  hardcodes `docs(blueprint): update 000-blueprint`. Add a `[create|update]`
  arg (default `update`); the subject switches on it.
- **`skills/blueprint/SKILL.md:116-126`** — generate Step 5 (write). Where the
  `last_full_generate` watermark is stamped (the single writer).
- **`skills/blueprint/SKILL.md:161-178`** — U2 absent-blueprint fallthrough +
  its close. Passes `create` to `commit-blueprint`; also a full generate, so it
  stamps the watermark. **The ordering hazard lives here** (see Finding 1).
- **`skills/blueprint/SKILL.md:245-271`** — U4 (normal update close). Where the
  cadence signal is read + reported, and where `commit-blueprint … update` is
  called.
- **`skills/blueprint/assets/blueprint-template.md:1-6`** — frontmatter
  (`title`, `group`, `kind`, `updated`). The `last_full_generate` field is added
  here.
- **`tests/jimledger.sh:513-536, 592-618`** — `commit-blueprint` and `diff-range`
  cases: the belt-test template for both new bits.

## Local Patterns

- **Counting idiom (test template + impl template):** clone
  `phase_event_metrics`' awk one-liner. `cmd_updates_since <dir> <iso>` →
  `awk -F'\t' -v w="$iso" '$3=="blueprint" && $4=="finished" && $2>w {n++} END{print n+0}' "$dir/ledger.md"`.
  Guard missing ledger like `cmd_metrics:313-314` (`no ledger` → non-zero).
- **Test conventions (`tests/jimledger.sh`):** name-discovered `case_*` fns;
  `git_fixture <name>` → repo + `spec/` dir; `run_jimledger` sets `OUT/ERR/RC`;
  `assert_eq/assert_exit/assert_match`. Model the new cases on
  `case_jimledger_commit_blueprint_ledger_only` (added this session) and the
  metrics cases — hand-write a `ledger.md` with dated `blueprint finished` lines
  and assert the count.
- **Timestamp comparison is pure string compare — no `date` parsing needed.**
  Both the ledger iso (`append_line:61`) and the watermark source
  (`jimfile.sh now`, `date -u +%Y-%m-%dT%H:%M:%SZ`) use the **identical**
  fixed-width, zero-padded, UTC-`Z` format. That format is lexicographically ==
  chronologically ordered, so awk's `$2 > w` string comparison is a correct
  strictly-after test. This satisfies the "POSIX bash, no third-party deps"
  constraint (CLAUDE.md, ARCHITECTURE.md Scripting Layer) for free.
- **Watermark is a *new* field, not a reuse of `updated`.** The template's
  `updated: "{YYYY-MM-DD}"` is date-only and refreshed on every write;
  `last_full_generate` must be a full second-resolution timestamp (for the
  comparison) written *only* by generate mode. Distinct field.
- **No allowed-tools change.** `skills/blueprint/SKILL.md:14` already grants
  `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/review/scripts/jimledger.sh *)` — a
  wildcard over jimledger args, so a new subcommand needs no new grant.

## Security & Performance

- **Untrusted ledger, parse-only (unchanged boundary).** `updates-since` reads
  `ledger.md`, which ARCHITECTURE.md's trust boundary marks untrusted. It only
  counts lines matching literal `blueprint`/`finished` with a string comparison
  via `awk -v` (no `source`, no eval, no shell interpolation of content) — same
  discipline as `phase_event_metrics`/`ledger_kv`. Safe.
- **Validate the watermark arg (defense-in-depth).** The watermark originates
  from the blueprint's own frontmatter (`last_full_generate`), which is
  trusted-origin (generate-stamped) but developer-editable. A malformed value
  (embedded tab/newline) could skew the `$2 > w` compare. Recommend the plan
  validate it against `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$`
  before use (cheap, mirrors the script's other input-validation posture).
- **Performance:** one extra `awk` pass over a small append-only file per update
  run. Negligible.
- **Fix-only ledger-only-commit (spec 031) — confirmed preserved.**
  `cmd_commit_blueprint:161-162` commits `spec.md` + `ledger.md` path-scoped; when
  `spec.md` is unchanged only `ledger.md` lands (verified by
  `case_jimledger_commit_blueprint_ledger_only`, added this session). Because the
  watermark is written *only by generate mode*, update mode never touches
  `spec.md` to count — so a fix-only update still commits `ledger.md` alone. The
  single-writer choice is exactly what protects AC #4.

## Recommendations

1. **Resolve the create-event ordering hazard (Finding 1) at the root.** See
   Peer Feedback — this is the one real design wrinkle and it needs an explicit
   rule in the plan.
2. **`updates-since` degradation for an absent watermark (AC #7).** Note that
   `awk`'s `$2 > ""` is true for any non-empty `$2`, so calling the subcommand
   with an empty watermark naturally counts *all* `blueprint finished` events. Two
   viable shapes: (a) the skill detects the missing frontmatter field and prints
   the "no baseline recorded" message itself, optionally showing the all-time
   count; or (b) `updates-since` returns a distinct sentinel/rc for an empty
   watermark. (a) keeps the script single-purpose; architect to choose.
3. **Bundle sizing.** Three testable units — `updates-since` (+ tests), the
   `commit-blueprint` create|update arg (+ test), and the skill-prose wiring
   (generate stamp, U2 `create`, U4 report). Natural TDD task order: script bits
   first (they're the dependencies), skill wiring last.

## Peer Feedback

**For the Architect (plan) — Finding 1: create-vs-update ordering hazard.**
The absent-blueprint fallthrough both (a) records a `blueprint finished` event
(the #24 fix, to pair its `started`) and (b) stamps the `last_full_generate`
watermark. If the watermark is stamped *at write* (Step 5) but the `finished`
event is recorded *after* (U2 close), the create's own `finished` iso can be a
second or more **later** than the watermark — so a strictly-after count would
wrongly count the create itself as 1 targeted update on the very next update-mode
run.

Recommended root fix: **stamp the watermark last**, with a fresh `jimfile.sh now`
taken *after* the fallthrough's `blueprint finished` event is recorded, so
`watermark_iso >= create's finished iso` and the strictly-`>` count excludes it.
Sequence in U2: write blueprint → record `blueprint finished` → Edit frontmatter
to stamp `last_full_generate: <now>` → `commit-blueprint … create` (commits the
stamped `spec.md` + `ledger.md` together). Normal generate mode records no
`blueprint finished` event at all, so it has no ordering concern — stamp at
write is fine there. The residual failure mode (a real update completing in the
*same second* as the generate's stamp being excluded, undercount-by-1 for one
second) is benign for a staleness signal. This does not change any AC; it's an
implementation ordering constraint the plan should state explicitly.

This is not a spec feasibility concern — the spec stays as written. It is a
concrete de-risking note for planning.
