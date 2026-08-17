---
title: "Allocator honors the configured issue-id prefix"
type: bug
group: "platform"
id: "010"
status: approved
origin:
  - "docs/specs/issue/010-ordinal-coordination/plan.md"
---

# 010 Allocator honors the configured issue-id prefix

## Overview
The coordination allocator mints every issue durable id as `YYYYMMDD-slug`,
ignoring the `issue_id_prefix` scheme that the tree-based `next-id issue` path
honored; now that issue filing coordinates through the allocator, teams on a
non-default scheme silently lose it. This restores scheme-faithful durable ids
at the allocator while preserving the frozen record grammar and resolution.

## Defect Profile
- **Steps to Reproduce:**
  1. In `jimconf.toml`, set a non-default scheme, e.g. `issue_id_prefix = "sequential"` (or `timestamp`, or `project` with `issue_id_project`).
  2. File an issue through the coordinated path (`/jim:issue add`, or any surfacing-skill candidate batch — `new.sh`'s fallback now calls `jimalloc.sh allocate issue`).
  3. Inspect the created issue's durable id / filename.
- **Actual Behavior:** the durable id is always `YYYYMMDD-slug`. `alloc_durable_issue_id` hardcodes the date prefix; the configured scheme is silently dropped.
- **Expected Behavior:** the durable id honors `issue_id_prefix` — the same shape `jimfile.sh next-id issue` (via `resolve_issue_prefix`) produced before filing was routed through the allocator.
- **Environment:** any repo with a non-default `issue_id_prefix`; surfaced by the `issue/010` build (DD1 routed `new.sh`'s identity fallback through the allocator). Default (`date`) config is unaffected.

## Acceptance Criteria
- [ ] A durable issue id minted by the allocator honors the configured
      `issue_id_prefix` scheme — matching the id shape the uncoordinated
      `next-id issue` path produced — for every scheme whose prefix is derivable
      at allocation time, including the ordinal-based schemes, which use the
      allocation's own coordinated ordinal rather than a separate tree scan.
- [ ] Where the prefix cannot be derived at allocation time — a provisional
      allocation has no numeric ordinal, so an ordinal-based scheme cannot
      render, and a non-re-derivable template cannot be reconstructed — the
      durable id degrades to the default date-slug form. The degradation is a
      clear, documented fallback: never an error, never a malformed id.
- [ ] The durable id stays coordinated and internally consistent: it passes the
      allocator's registry disambiguation for collision-prone schemes, and where
      the scheme embeds the ordinal, the durable id's prefix equals the
      allocation's own coordinated ordinal.
- [ ] The default configuration (`issue_id_prefix = "date"`) produces a
      byte-for-byte unchanged durable id and registry record, so the frozen
      `platform/007` record grammar and forward-replay resolution are unaffected.
- [ ] Every derived prefix and durable id is revalidated through the id boundary
      before it becomes a filename, a registry token, or a git argument, so a
      config-supplied project string or template can never inject an option, a
      path traversal, or a malformed id. *(External Constraint — sourced to
      `platform/007`'s injection-guard AC and the parse-as-data / `is_valid_id`
      boundary convention in `CLAUDE.md` → Bash scripts.)*
- [ ] Regression test covers the reported scenario: a non-default
      `issue_id_prefix` flows through the coordinated allocation path and yields
      the scheme-appropriate durable id, and a provisional allocation under an
      ordinal-based scheme degrades to date-slug rather than erroring.

## Out of Scope
- **Changing, adding, or removing `issue_id_prefix` schemes.** This consumes the
  existing schemes (`date` / `timestamp` / `sequential` / `project` / template)
  exactly as `resolve_issue_prefix` defines them; it does not alter the scheme
  set or their semantics.
- **The issue-group consumer wiring.** `issue/010` already routes `new.sh`
  through the allocator; this spec fixes only what the allocator *returns*. No
  issue-group script changes here.
- **Re-prefixing already-filed issues.** Retroactively migrating existing issue
  ids to a newly-configured scheme is `migrate.sh`'s job, unchanged.
- **Spec ids (`group/NNN`).** Only issue durable ids are affected; spec-id
  allocation is untouched.
- **Retroactively upgrading a provisional issue's durable id at reconcile.** A
  provisional issue's filename is fixed at filing; `reconcile` realizes its
  ordinal but does not rename the file, so a provisional-mode ordinal-scheme
  issue keeps its date-slug fallback id permanently (a documented limit).

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the architect — not requirements, not exclusions. Treat each as a starting point to evaluate, not a directive.*

### Insight 1: Reuse the existing `prefix-from` helper

- **Relates to AC:** *"honors the configured `issue_id_prefix` scheme … using the allocation's own coordinated ordinal"* (AC 1)
- **Surfaced as:** `jimfile.sh prefix-from <created> <num>` already re-derives every scheme's prefix and takes the ordinal as an argument (no tree scan), which is exactly the shape the allocator needs — it already holds the coordinated `num` before it builds the durable id (`alloc_build_issue` computes `num` first).
- **Levelled-up requirement (already in the ACs):** the AC fixes the observable id shape; the helper is one realization.
- **Deflection reason:** Delegation — `prefix-from` is the obvious reuse, but the architect owns whether to compose it, extend it, or factor a shared routine.
- **Architect note:** `alloc_durable_issue_id` would take the `num`, call `prefix-from`, append the slug, then run its existing disambiguation loop unchanged. `prefix-from`'s own failure paths (empty `issue_id_project`, un-derivable `{date:…}`) already emit a reason and non-zero — treat any failure as the AC 2 fallback.

### Insight 2: Pass `now` (ISO), not `date`, to the prefix helper

- **Relates to AC:** *"honors … for every scheme derivable at allocation time"* (AC 1)
- **Surfaced as:** the allocator derives its date via `jimfile.sh date` (compact `YYYYMMDD`), but `prefix-from` validates `created` as ISO `YYYY-MM-DD[Thh:mm:ssZ]` and rejects the compact form.
- **Resolved (research):** the allocator must pass `jimfile.sh now` (ISO). It is forced by the input format — not a fork — and as a bonus renders the `timestamp` scheme at real sub-day precision (`…Thhmmss`) rather than day-start.
- **Routing hint:** Settled by research; carry into planning.

### Insight 3: The fallback boundary is where degradation is decided

- **Relates to AC:** *"degrades to the default date-slug form … never an error"* (AC 2)
- **Surfaced as:** the provisional path (`alloc_provisional_issue`) computes the durable id over an empty log with no numeric ordinal; ordinal-based schemes cannot render there, so the fallback must trigger for provisional allocations specifically.
- **Levelled-up requirement (already in the ACs):** AC 2 states the observable fallback; the trigger points are the mechanism.
- **Deflection reason:** Delegation — the real vs provisional build paths decide when to attempt the scheme vs fall back.
- **Routing hint:** Architect to decide.

## Open Questions
- [x] ~How far to honor schemes at mint time given provisional/template limits~ → honor every derivable scheme; degrade to date-slug where not derivable (provisional ordinal-based, non-re-derivable templates) as a documented fallback.
- [x] ~Timestamp granularity: `now` vs `date`~ → resolved by research: pass
  `now` (ISO). The compact `date` fails `prefix-from`'s input validation, so it
  is forced — and it renders `timestamp` at real sub-day precision (Insight 2).
