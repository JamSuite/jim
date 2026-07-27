---
title: "Provisional allocation and reconcile (unreachable-origin mode)"
spec: "docs/specs/platform/009-provisional-reconcile/spec.md"
type: feature
status: approved
---

# Provisional allocation and reconcile (unreachable-origin mode) — Plan

## Overview

Extend `skills/file/scripts/jimalloc.sh` with an opt-in `provisional`
unreachable-origin mode (allocate returns a grammar-distinct, local-only
provisional identifier instead of hard-failing) and a preview-then-apply
`reconcile` verb that realizes pending provisionals into real coordinated ids
through **one shared, erosion-guarded batch-publish** — the consolidation that folds
issue #122 and makes reconcile's realization byte-for-byte as guarded as a normal
allocation.

## Design Decisions

### 1. Extend `jimalloc.sh`; no new script

- **Chosen:** All logic lives in `skills/file/scripts/jimalloc.sh`, reusing its record grammar, CAS machinery, validation boundary (`alloc_valid_token`), erosion baseline, and config resolution.
- **Why:** Provisional/reconcile *is* the allocator's unreachable-origin behavior; the ARCHITECTURE.md `jimalloc.sh` entry already names `provisional` a reserved mode. A separate script would fork the exact CAS/boundary machinery spec AC 4 forbids duplicating.
- **Rejected:** A standalone `reconcile.sh` — a second registry-writing path, the anti-pattern AC 4 exists to prevent.

### 2. One shared, erosion-guarded batch-publish — folds #122

- **Chosen:** Factor a single publish helper (`alloc_publish`): tier-select (origin/local) → **in-loop erosion re-check** → N-record commit (the `alloc_seed_commit` builder) → CAS (push non-ff / `update-ref` old-value) → baseline-arm on success → bounded retry. Fold the seed's current inline publish (`jimalloc.sh:1021-1081`) into `alloc_publish` (seed *gains* the erosion re-check it currently omits — closes **#122**); reconcile uses it.
- **Why:** Security Finding 1 + research Peer Feedback: reconcile is the *third* registry writer, and the seed's current inline publish (`jimalloc.sh:1021-1081`) re-implements the CAS without the erosion check `alloc_cas_append` (`:742`) has. Consolidating turns that 008 debt into a fix and makes AC 4's "same guarantees" literal — a truncation between a provisional's offline filing and its reconcile is detected, never reissued onto a truncated log.
- **Rejected:** A third inline CAS copy for reconcile — compounds the drift and silently re-drops the erosion re-check. Also rejected: folding the single-record allocate path (`alloc_cas_append`) into the same helper now — it is already erosion-guarded and heavily tested; leaving it minimizes regression blast radius (a future cleanup, not this spec).

### 3. Provisional-mode intercept points

- **Chosen:** `alloc_preflight` (`:483-496`) *accepts* `provisional` (still rejects `service` mechanism and unknown unreachable values). The allocate flow branches on reachability: origin reachable → normal CAS (007 unchanged); unreachable + `fail` → hard-fail (007 unchanged, byte-identical); unreachable + `provisional` → **provisional issuance** (local, no `ls-remote`/`fetch`/`push`, no CAS).
- **Why:** Research shows the whole entry point is flipping `alloc_preflight`'s rejection and turning `alloc_origin_tip`'s unreachable rc-1 (`:555-557`) into "issue provisional." `alloc_peek_refresh` (`:855-862`) is the model for touching the network non-fatally.
- **Rejected:** A new top-level verb for provisional allocation — provisional is a *mode* of `allocate`, selected by config, not a separate command (AC 1 / one interface, User Story 4).

### 4. Provisional grammar: reserved, non-numeric, never in shared state

- **Chosen:** A provisional identifier is grammar-distinct from every allocated ordinal (issue ordinals are `^[0-9]+$`; a provisional ordinal carries a reserved non-numeric form) and never appears in `specs.log`/`issues.log`, the `next-id`/`next-num` high-water, or `peek`. For issues, only the *ordinal* is deferred — the durable `YYYYMMDD-slug` identity is computed offline (`alloc_durable_issue_id` needs no origin).
- **Why:** AC 2 collision-proof: provisionals stay local, so they cannot inflate a real allocation and a real allocation cannot collide with them. Refinement 1: issue reconcile is a light ordinal fill-in, not a rename.
- **Rejected:** Storing provisionals in the registry with a flag — puts unpublished, local state on the shared branch and pollutes the high-water.

### 5. Unique-by-construction resume model (the AC-6 fork)

- **Chosen:** The consumer contract (AC 11) **requires the consumer to supply a globally-unique provisional identity** (e.g. a clone/random component in the offline id). Reconcile keys realization on that unique id: a registry `allocate` record already carrying it ⇒ *already realized* (skip, idempotent); absent ⇒ allocate a real id from the high-water and stage the record. No reconcile-time durable-id suffixing.
- **Why:** Makes AC 6 (resumable, no double-allocation across a crash between CAS and consumer rewrite) trivially correct and cross-clone-safe, while staying inside `platform/007`'s frozen grammar and letting the marker travel with the branch (G5). Chosen by the developer at plan time over auto-suffix (ambiguous on resume) and halt-and-report (softens the guarantee).
- **Rejected:** Auto-suffix on collision (spec Insight 1's note — *superseded here*) needs a durable provisional→real link the frozen grammar cannot carry, or local state that breaks G5. Halt-and-report cannot distinguish "my realized record" from "another clone's collision" without the same unique key.
- **Note:** This is a plan-level realization of AC 11's "defined and frozen contract"; it does not change any spec AC. `#115` still ships no real consumer — the uniqueness guarantee is a *requirement the contract places on* the #111 consumer, exercised here by a fixture consumer.

### 6. Reconcile is an explicit verb, preview-then-apply

- **Chosen:** `reconcile` (bare) previews (prints the provisional→real mapping and any stop condition, mutates nothing); `reconcile --apply` publishes. Reachable origin required; still-unreachable is a clean no-op (rc 0, "still offline", nothing changed) — distinct from the allocation-time hard-fail.
- **Why:** AC 9 + jim's migration doctrine (seed, `migrate.sh`); an explicit verb matches the real "run it deliberately on the host / at PR review" workflow (Insight 4). Auto-on-allocate couples concerns and no-ops every offline call.
- **Rejected:** Automatic reconcile on the next `allocate` — silent, and fires uselessly whenever offline.

### 7. Consumer contract: discovery and rewrite delegated; mechanism tested via fixture

- **Chosen:** Reconcile receives the pending set (the unique provisional identities) from the consumer and emits the realized provisional→real mapping; *discovery* (scanning the genuine artifact set) and *rewrite* (applying the mapping through the issue emitter) are the consumer's (#111). The mechanism is tested with a fixture consumer over the `JIMALLOC_REGISTRY_DIR` seam + `alloc_new_clone` helpers.
- **Why:** AC 11 + security Finding 3 (discovery scoped to the genuine artifact set, not an arbitrary tree walk) + the issue single-emitter invariant (no in-place `num` editor exists today, so the rewrite must ride with #111). Keeps `#115` kind-agnostic and shippable/testable alone.
- **Rejected:** Reconcile scans issue files and rewrites `num` itself — reaches into issue-group territory and violates the single-emitter invariant.

## Constitution Check

**ARCHITECTURE.md status:** Present — constraints noted below.

| Constraint from ARCHITECTURE.md | Honored? | Notes |
| :--- | :--- | :--- |
| Bash-vs-Prompt: deterministic logic in a bash script | Yes | Provisional issuance + reconcile realization are deterministic (same registry + pending set → same mapping, verifiable by string compare) → `jimalloc.sh`; the preview/reconcile-trigger judgment stays in the consumer skill. |
| Scripting Layer: `set -uo pipefail`, `export LC_ALL=C`, `GIT_TERMINAL_PROMPT=0`, Bash+POSIX only, no third-party deps | Yes | Inherited — new code lives inside `jimalloc.sh`'s existing preamble; parsing is grep/sed/awk. |
| Never `source`/`eval` untrusted content | Yes | Registry and pending markers parsed as data (AC 13); DD 4/7. |
| Single `is_valid_id` boundary (no fourth copy) | Yes | Every provisional/pending/subject token → `alloc_valid_token` → `jimfile.sh valid-id`; DD 7. |
| Operational-git discipline (`--end-of-options`, `--`, valid-id option-injection foreclosure, never `git add -A`) | Yes | Reuses 007's plumbing publish; the shared batch-publish stays plumbing-only. |
| `id_coordination_*` config read from the current branch | Yes | `provisional` is the reserved `id_coordination_unreachable` value 007 registered; no new key. |

**New capability note (not a violation):** provisional issuance touches *less* network than 007 (it is strictly local); reconcile reuses 007/008's shared-ref CAS — no net-new git surface class. `ARCHITECTURE.md`'s Scripting-Layer entry and the platform `000-blueprint` are refreshed by the `/jim:build` completion `/jim:arch` and `/jim:blueprint` gates (see Out of Scope), not hand-edited here.

## File Manifest

| Component | File Path | Action | Notes |
| :--- | :--- | :--- | :--- |
| Allocator | `skills/file/scripts/jimalloc.sh` | Update | Shared `alloc_publish` (folds #122); `alloc_preflight` accepts `provisional`; provisional-mode `allocate` branch + grammar; `reconcile` verb (realize logic, batch publish, preview/apply, still-offline no-op); boundary revalidation on the new path. |
| Allocator tests | `tests/jimalloc.sh` | Update | Flip the provisional-not-implemented case; seed-eroded-history hard-fail (post-consolidation); provisional issuance (local/no-network, grammar-distinct, peek/next-id unaffected, fail-mode byte-identical); reconcile realize (mapping, idempotent/resumable, marker→ordinal independence); reconcile publish (two-clone concurrency, still-offline no-op, resume no-double-allocate, atomicity); preview-then-apply; adversarial tokens. |

## Interface Contracts

```text
# ── Provisional allocation (mode of `allocate`; unreachable + provisional) ─────
jimalloc.sh allocate issue <subject>
  origin reachable          -> "<full-id>\t<num>"          # real, post-CAS (007)
  unreachable + fail        -> rc 1 hard-fail              # 007, byte-identical
  unreachable + provisional -> "<full-id>\t<PROV>"         # local: date-slug real,
                                                           #   ordinal deferred (PROV
                                                           #   is grammar-distinct,
                                                           #   never ^[0-9]+$)
jimalloc.sh allocate spec <group> <subject>
  unreachable + provisional -> "<PROV-id>"                 # whole identity provisional;
                                                           #   grammar defined, SPEC
                                                           #   reconcile deferred (#112/#113)
# Provisional identifiers NEVER enter specs.log/issues.log, next-id/next-num, or peek.
# Issuance performs NO ls-remote/fetch/push and no CAS.

# ── Reconcile (explicit verb; preview-then-apply; reachable origin required) ───
jimalloc.sh reconcile issue                 # PREVIEW: print "<prov-id>\t<real>" mapping
                                            #   + any stop condition; mutate nothing
jimalloc.sh reconcile issue --apply         # publish new reals in ONE CAS batch; print mapping
#   pending set: the consumer's unique provisional identities (contract; fixture in tests)
#   still-unreachable  -> rc 0, "still offline", nothing changed (NOT the alloc hard-fail)
#   realize(prov-id):  registry has allocate record keyed by prov-id's unique id?
#                        yes -> already realized (idempotent) ; no -> allocate high-water+1
#   realized ordinal derived SOLELY from the shared high-water under CAS — never from any
#     field of the provisional marker (AC 2/AC 8)
#   publish: shared alloc_publish (tier-select + in-loop erosion re-check + N-record commit
#     + CAS + baseline-arm); all-or-none; mapping durable before the consumer rewrite

# ── Config (unchanged key; new accepted value) ────────────────────────────────
id_coordination_unreachable = "provisional"  # opt-in; default stays "fail"
```

## Data Flow

```mermaid
sequenceDiagram
    participant C as consumer (fixture / #111)
    participant A as jimalloc.sh
    participant O as origin (coordination branch)
    Note over C,O: allocate, origin unreachable, mode=provisional
    C->>A: allocate issue <subject>
    A->>A: preflight accepts provisional; reachability check → unreachable
    A-->>C: "<date-slug>\t<PROV>"  (local; no network, no CAS)
    Note over C,O: later, origin reachable
    C->>A: reconcile issue --apply  (pending = unique prov ids)
    loop bounded retry (shared alloc_publish)
        A->>O: fetch tip; in-loop erosion re-check
        A->>A: realize: keyed find-or-allocate (idempotent); high-water only
        A->>O: CAS publish N reals (one commit, all-or-none)
        alt still unreachable
            O-->>A: rc 0 no-op ("still offline")
        else committed
            O-->>A: durable → arm baseline
        end
    end
    A-->>C: provisional→real mapping  (consumer applies rewrite)
```

## Task Breakdown

1. [x] **Consolidate the publish step (Tidy First; closes #122).** Factor `alloc_publish` (tier-select + in-loop erosion re-check + `alloc_seed_commit` N-record builder + origin/local CAS + baseline-arm + bounded retry) and fold the seed's current inline publish (`jimalloc.sh:1021-1081`) into it, so seed's realization gains the erosion re-check. Keep `alloc_cas_append` (allocate) as-is. Add a fixture: after a seed, a rewritten coordination history is detected on the next seeding path; all prior seed/allocate cases stay green.
   **Verify:** `bash tests/jimalloc.sh`

2. [x] **Accept `provisional` in preflight.** `alloc_preflight` admits `id_coordination_unreachable = provisional` (still rejects `service` mechanism and unknown values). Flip `case_..._unreachable_provisional_not_implemented` to assert acceptance; keep `mechanism=service` rejected. Depends on nothing.
   **Verify:** `bash tests/jimalloc.sh`

3. [x] **Provisional grammar + provisional-mode `allocate`.** When mode=`provisional` and origin is unreachable, `allocate` returns a grammar-distinct provisional identifier locally — no `ls-remote`/`fetch`/`push`, no CAS; the issue durable date-slug is computed offline, the ordinal deferred. Fixtures: provisional issuance touches no network and writes no registry; `peek`/`next-id`/`next-num` are unaffected by pending provisionals; `fail` mode stays byte-identical; a crafted subject is rejected at `alloc_valid_token`. Depends on task 2.
   **Verify:** `bash tests/jimalloc.sh`

4. [x] **Reconcile realize logic (pure; no git).** Given a pending set of unique provisional identities, compute the realized mapping: keyed find-or-allocate (already-realized ⇒ same mapping, no new allocation; new ⇒ high-water+1), the realized ordinal derived solely from the high-water (marker→ordinal independence). **Halt-and-report on a duplicate provisional identity within the pending batch** (defense-in-depth against a buggy or hostile consumer — security Finding 4), rather than silently collapsing two provisionals onto one ordinal; cross-batch uniqueness stays the consumer's AC 11 obligation. Fixtures over a fixture registry: mapping correctness, idempotency/resumability (re-run yields the same mapping, no second id), determinism, a within-batch duplicate identity halts, and a crafted pending identity rejected at the boundary. Depends on task 3.
   **Verify:** `bash tests/jimalloc.sh`

5. [x] **Reconcile publish + tiers (AC 4/5/6/7/8).** Publish the new reals via the shared `alloc_publish` (task 1) — one CAS batch, all-or-none, erosion-guarded, baseline-armed; reachable origin required, still-unreachable is a clean rc-0 no-op. Fixtures (two-clone bare-remote, `alloc_new_clone`): reals are published durably; two clones reconciling concurrently realize distinct reals; a simulated crash between CAS and rewrite re-runs with no double-allocation; still-offline changes nothing. Depends on tasks 1, 4.
   **Verify:** `bash tests/jimalloc.sh`

6. [x] **Reconcile preview-then-apply (AC 9).** Bare `reconcile` prints the mapping + any stop condition and mutates nothing; `--apply` publishes. Fixture: preview leaves the registry byte-identical; apply publishes the same mapping it previewed. Depends on task 5.
   **Verify:** `bash tests/jimalloc.sh`

7. [x] **Full-suite green.** Run the aggregate runner; no regression across platform scripts.
   **Verify:** `bash skills/meta-test/scripts/run.sh`

## Requirements Coverage Summary

| Spec Acceptance Criterion | Addressed In Task(s) |
| :--- | :--- |
| AC 1 — `provisional` mode returns a usable id instead of hard-failing; `fail`/local tier unchanged; config-governed | 2, 3 |
| AC 2 — grammar disjoint from ordinals; never in registry/next-id/preview; marker→ordinal independence | 3, 4 |
| AC 3 — issuance is local, origin-free, no CAS | 3 |
| AC 4 — reconcile realizes via the same guarded CAS path (no weaker write path) | 1, 5 |
| AC 5 — reconcile pass is atomic, all-or-none | 5 |
| AC 6 — resumable and idempotent | 4, 5 |
| AC 7 — still-unreachable is a clean no-op, not a hard fail | 5 |
| AC 8 — deterministic under concurrency + clock skew; ordinal from high-water only | 4, 5 |
| AC 9 — preview-then-apply | 6 |
| AC 10 — abandoned provisional → permanent gap, never an error | 4, 5 |
| AC 11 — consumer contract defined + frozen (unique-identity requirement; scoped discovery) | 4 (DD 5, 7) |
| AC 12 — every provisional/pending/subject token revalidated before git/ref/fs use | 3, 4, 5 |
| AC 13 — bash conventions; parse as data; no third-party deps | 1–7 (constitutionally) |
| Security Finding 1 (erosion re-check in the shared publish) | 1, 5 |
| Security Finding 4 (within-batch duplicate-identity guard) | 4 |

## Out of Scope

- **`ARCHITECTURE.md` Scripting-Layer entry + platform `000-blueprint` refresh** — pipeline-owned (the `/jim:build` completion `/jim:arch` and `/jim:blueprint` gates), not a task, not a deferral.
- **The issue consumer (#111)** — provisional marker storage/rendering, the `num` rewrite through the issue emitter, scoped discovery over the issue collection, and wiring issue filing onto `allocate`. This spec ships the mechanism + contract; the fixture consumer stands in for tests.
- **Spec-side provisional reconcile** — realizing a provisional *spec* renames its directory and rewrites references (rename/redirect churn owned by #112/#113). Reconcile's mechanism is consumer-agnostic; the spec consumer composes with those.
- **A productized maintainer PR-review reconcile command/UX** — the mechanism supports the fork-workflow (G5) by construction; a maintainer-facing flow is not built here.
- **Folding the single-record allocate path (`alloc_cas_append`) into the shared publish** — deferred as a lower-value cleanup (it is already erosion-guarded); this plan consolidates only seed + reconcile.
- All `platform/007` non-goals (service backend, opaque reservation, audit/authorization semantics) — unchanged.

## Open Questions

- [x] ~~Reconcile resumability vs. cross-clone durable-id collision (AC 6)~~ → unique-by-construction: the contract requires a globally-unique provisional identity reconcile keys on (DD 5).
- [x] ~~Consolidate the publish step, or add a third inline copy?~~ → consolidate seed + reconcile onto one erosion-guarded `alloc_publish`, folding #122 (DD 2; security Finding 1).
- [x] ~~Reconcile trigger~~ → explicit verb, preview-then-apply (DD 6).
- [ ] The concrete provisional-token shape (the reserved prefix / uniqueness source) is the coder's within DD 4/5 — grammar-distinct, non-numeric in the ordinal slot, unique by construction. Not blocking; resolved during TDD of task 3.
