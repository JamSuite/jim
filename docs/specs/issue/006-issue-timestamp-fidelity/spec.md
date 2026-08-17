---
title: "Second-resolution timestamps for issue created/updated"
type: feature
group: "issue"
id: "022"
status: approved
origin:
  - "docs/specs/issue/007-issue-id-rederive/spec.md"
---

# 022 Second-resolution timestamps for issue created/updated

## Overview
Records issue `created` / `updated` as second-resolution UTC timestamps stamped
deterministically — `created` at capture, `updated` refreshed on each
jim-mediated edit — so issues order by true wall-clock time and by genuine
recency, robust even where the decentralized `num` ordinal collides across
worktrees, while existing date-only issues keep working and can be
format-normalized on demand.

## Problem Statement
Issue `created` / `updated` are recorded at date resolution only and are written
by the LLM at capture time. Same-day issues therefore carry no intrinsic time
ordering: the list view sorts by `created` and falls back to `num` as the
tiebreaker — but `num` is the spec-019 *decentralized, worktree-duplicate-tolerant*
ordinal, so in exactly the parallel-work scenario where fine ordering matters
most, two issues filed the same day in different worktrees can share a `num` and
their true creation order is lost. There is no reliable way to tell which of two
same-day issues came first, and a hand-written date can't carry the precision to
settle it. And because `updated` is written once at capture and never refreshed,
sorting by recency is meaningless — an issue reworked over several days still
looks as stale as the moment it was filed.

## User Stories
- As a developer running parallel work across git worktrees, I can trust that
  issues filed the same day sort in true creation order even when their `num`
  ordinals collide, so my list and triage reflect what actually happened.
- As a developer reviewing recent activity, I can rely on issue timestamps being
  accurate to the second of creation and recorded automatically, rather than a
  hand-written date that can only ever be day-resolution.
- As a developer with an existing date-only collection, I keep a fully working
  collection with no forced rewrite, and can opt into normalizing old issues to
  the new format when I want uniformity.
- As a developer who scans issues by recency, I can trust that `updated` reflects
  when an issue was last changed through jim, so recency views surface
  genuinely-active work instead of resting at the creation date.

## Acceptance Criteria
- [ ] New issues record `created` and `updated` as second-resolution timestamps
  in one canonical, unambiguous representation that sorts correctly as a plain
  string — UTC, ISO 8601 with a `Z` suffix (e.g. `2026-06-13T14:45:30Z`) — and
  that representation is visible in the issue file and the `show` view.
- [ ] The creation timestamp reflects the actual wall-clock second the issue was
  filed and is recorded deterministically rather than hand-written, so the stored
  time is the real creation time to second precision. *External Constraint —
  sourced from `ARCHITECTURE.md` → Bash-vs-Prompt Decision Rule (machine-known,
  deterministic values belong in the bash layer, not LLM composition) and
  `CLAUDE.md` (determinism boundary).*
- [ ] Existing date-only issues are not rewritten and continue to function: `list`,
  `stats`, `show`, the index, and sorting all operate over a collection that mixes
  date-only and full-timestamp values, with a date-only value ordering as that
  day's start and `num` remaining the final tiebreaker.
- [ ] List and stats ordering disambiguates same-day issues by their timestamps
  where present, so two issues created moments apart on the same day sort in true
  creation order even when their `num` ordinals collide.
- [ ] A one-shot, opt-in command normalizes existing date-only `created` /
  `updated` values into the canonical timestamp format on demand: it is run
  deliberately (never automatically), is idempotent (already-normalized values are
  left untouched), and announces that the normalized time is a day-start
  placeholder, not recovered precision.
- [ ] The change is backward-compatible: existing behavior and tests for a purely
  date-only collection are unaffected — sorting, rendering, and indexing over an
  all-legacy collection produce the same results as before.
- [ ] When an issue is modified through jim's tooling — its skills or agents — its
  `updated` field is refreshed to the current second-resolution timestamp
  (recorded deterministically, the same way `created` is), so `updated` reflects
  the real time of the last jim-mediated change rather than resting at creation
  time.
- [ ] A `created` or `updated` value that does not match the expected
  date-or-timestamp shape never corrupts the `list` / `stats` views or `INDEX.md`:
  such a value is ordered deterministically as that day's start and is skipped
  (with a warning) by normalization, rather than being passed through into the
  rendered output or the index. *(Added per security.md Finding 1.)*

## UI Mockup
```
# Frontmatter — before (date-only, LLM-written)
created: 2026-06-13
updated: 2026-06-13

# Frontmatter — after (second-resolution UTC, deterministically stamped)
created: 2026-06-13T14:45:30Z
updated: 2026-06-13T14:45:30Z

# updated advances on a later jim-mediated edit (e.g. closing the issue):
#   created: 2026-06-13T14:45:30Z   (unchanged)
#   updated: 2026-06-14T09:12:05Z   (refreshed to the edit time)

# list ordering — two issues filed seconds apart, same day, num collided
# (parallel worktrees both computed num: 8). Today they tie + render in
# arbitrary order; with timestamps they sort in true creation order:
  #8  2026-06-13T14:45:30Z  high    wire-consumer-a
  #8  2026-06-13T14:45:33Z  high    wire-consumer-b

# Mixed collection — a legacy date-only issue orders as that day's start:
  20260612-legacy-issue        2026-06-12          (orders before any 06-12 timestamp)
  #9  2026-06-13T09:02:11Z     2026-06-13T09:02:11Z
```

## Out of Scope
- **Catching out-of-band edits.** The `updated` refresh covers modifications made
  through jim's skills and agents; an issue hand-edited directly in an editor (or
  by a non-jim tool) is not auto-stamped. Guaranteeing a refresh for every edit
  regardless of origin would need a commit hook or a mandatory mutation surface —
  a deferred follow-on.
- **A dedicated issue-mutation verb.** The `updated` refresh rides on a
  skill/agent convention for now; introducing a `/jim:issue` mutation verb
  (close / set / edit) that owns the write as a single chokepoint is a later option
  if the convention proves insufficient, not part of this spec.
- **Recovering true historical sub-day times.** Existing issues never captured a
  sub-day creation instant, so it cannot be recovered. The opt-in normalization is
  cosmetic format uniformity (day-start), explicitly not reconstructed precision;
  proxy sources (file mtime, git history) are not used.
- **`num`'s semantics.** `num` stays the spec-019 decentralized display ordinal and
  the final sort tiebreaker; second-resolution timestamps complement it, they do
  not replace or recompute it.
- **Sub-second precision.** Second resolution only — no milliseconds or finer.
- **Per-view timezone rendering.** Storage is canonical UTC; views render the
  stored value verbatim with no localized timezone conversion.
- **Timestamps on other artifacts.** Only the issue schema's `created` / `updated`
  fields change; spec, plan, and other artifact dates are untouched.
- **A tamper-evident audit trail.** `created` / `updated` are self-reported by the
  local clock and freely editable in frontmatter; they are advisory ordering
  metadata, not authoritative provenance. Treating them as a tamper-proof audit
  record is a non-goal, consistent with VISION's "not a project management tool"
  (security.md Finding 4).
- **Mitigating activity-metadata exposure.** Per-second timestamps in a public
  repo reveal finer working-pattern signals than a date; this is a deliberate
  tradeoff for accurate ordering. The canonical UTC representation already avoids
  leaking the developer's local timezone, and no further obfuscation is in scope
  (security.md Finding 5).

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the architect — not requirements, not exclusions. Treat each as a starting point to evaluate, not a directive.*

### Insight 1: Deterministic stamping moves from the LLM into jimfile.sh

- **Relates to AC:** the canonical-format AC (AC #1), the deterministic-stamping External Constraint (AC #2), and the on-edit `updated` refresh (AC #7).
- **Surfaced as:** today the `/jim:issue add` flow has the LLM write `created` / `updated` as `YYYY-MM-DD`; the model cannot reliably produce a wall-clock value to the second.
- **Levelled-up requirement (already in the ACs):** the recorded time is the real creation time to second precision, produced by the machine, not the model.
- **Deflection reason:** Delegation — the exact command name and shape are the architect's call.
- **Architect note:** `jimfile.sh` already has `today_yyyymmdd()` (`date +%Y%m%d`) as the single source of truth for the date prefix and a `date` subcommand. A sibling that emits `date -u +%Y-%m-%dT%H:%M:%SZ` (UTC, `LC_ALL=C` already set in the preamble) is the natural home; the `/jim:issue add` step that fills `created`/`updated` would consume it the same way it consumes other resolver output. Decide whether this is a new subcommand (e.g. `now`) or an option on the existing `date` command. The same helper backs both the `add`-time stamping and the on-edit `updated` refresh (Insight 4).

### Insight 2: Opt-in normalization extends the existing backfill script

- **Relates to AC:** the opt-in normalization AC (AC #5).
- **Surfaced as:** the developer asked to "modify the backfill script for one-shot normalizing as-needed" rather than add a separate tool.
- **Levelled-up requirement (already in the ACs):** a deliberate, idempotent, announced one-shot that brings existing date-only values into the canonical format.
- **Deflection reason:** Delegation — whether the normalization is a new subcommand/flag on `backfill.sh` versus a separate script, and how it is invoked, is the architect's call.
- **Architect note:** `skills/issue/scripts/backfill.sh` is the established one-shot migration (it assigns `num:` ordinals) and already carries the right properties — idempotent, announced, per-file atomic `tmp + mv`, not wired into the verb flow. Normalization maps a date-only `YYYY-MM-DD` to `YYYY-MM-DDT00:00:00Z`; an already-timestamped value is left untouched (idempotency). Keep the day-start placeholder honest in the announcement (it is not recovered precision).

### Insight 3: ISO 8601 UTC sorts losslessly against legacy date-only values

- **Relates to AC:** the mixed-collection functionality AC (AC #3) and the same-day disambiguation AC (AC #4).
- **Surfaced as:** `render.sh` sorts the `created` column as a plain string (`sort -k5,5`) with `num` as the secondary key (`-k2,2n`).
- **Deflection reason:** Constraint-Sourcing — the requirement that the existing read views keep working over a mixed collection is the constraint; confirming the sort behavior is the mechanism.
- **Architect note:** ISO 8601 UTC-`Z` strings sort lexically in chronological order, and a date-only `2026-06-13` is a prefix of `2026-06-13T…`, so it sorts before any same-day timestamp (a date-only issue orders as that day's start). The existing `sort -k5,5 -k2,2n` key structure works unchanged — `num` still breaks ties between identical timestamps or two same-day date-only values. A researcher pass against `tests/issues.sh` sort cases can confirm the mixed-value ordering and add coverage for the same-day-collision case.

### Insight 4: `updated`-on-edit is a skill/agent convention, not a script

- **Relates to AC:** the on-edit `updated` refresh AC (AC #7).
- **Surfaced as:** the developer chose the lightweight option — refresh `updated` via the bash timestamp helper whenever an issue is edited through jim/Claude — over a heavier mutation verb or commit hook, with the explicit intent to switch to a verb later only if the convention proves insufficient.
- **Levelled-up requirement (already in the ACs):** `updated` reflects the real time of the last jim-mediated change.
- **Deflection reason:** Delegation — where the convention is documented and which skills/agents carry it is the architect's call.
- **Architect note:** Unlike `created` (stamped at one place, `/jim:issue add`), issue edits today are freeform — closure is a manual frontmatter edit, and a "close issue #5" request goes through the agent's Edit tool with no skill mediating it. The convention therefore needs a documented home (issue `SKILL.md` edit guidance, and/or a project convention in `ARCHITECTURE.md` / `CLAUDE.md`) so an agent editing an issue knows to refresh `updated` via the helper from Insight 1. This is checklist-validated (an LLM-prompt convention), not unit-testable like the helper itself — per jim's "skill prompts validated by checklist, scripts by the suite" rule. It degrades gracefully: an out-of-band manual edit simply isn't stamped (the deferred hardening in Out of Scope).

## Open Questions
- [x] ~How to treat existing date-only issues~ → Forward-only: leave them date-only and fully functional; provide an opt-in `backfill`-based normalization for developers who want format uniformity.
- [x] ~Canonical timestamp representation~ → UTC, ISO 8601 with `Z`, second resolution.
- [x] ~Auto-maintaining `updated` on edits~ → In scope via a skill/agent convention: edits made through jim's tooling refresh `updated` using the bash timestamp helper. Catching out-of-band manual edits (a commit hook) and a dedicated mutation verb are deferred follow-ons.
- [x] ~Normalization fabricating precision~ → The opt-in normalization uses a day-start placeholder announced as such; no proxy (mtime/git) reconstruction.
