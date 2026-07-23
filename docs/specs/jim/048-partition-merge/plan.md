---
title: "Partition merge"
spec: "docs/specs/jim/048-partition-merge/spec.md"
type: feature
status: approved
---

# Partition merge — Plan

## Overview

Build merge as sibling verbs on the shipped 043/046/047 substrate — three new
`jimpartition.sh` verbs, one new `jimledger.sh` commit arm, two one-line filter
widenings — plus prose arms (methodology § Merge protocol, migrate-arms
`--merge`, gatherer merge role, partition `## Merge runs`), with both
at-capacity SKILL.md files funded by explicit compression tasks before any
merge prose lands.

## Design Decisions

### 1. Sibling verbs, not flags on split's verbs

- **Chosen:** New `merge-preflight`, `merge-map`, `merge-edges-diff` verbs;
  `renumber-map` / `split-preflight` / `edges-diff` untouched.
- **Why:** `renumber-map` hard-codes per-child seeding (`seq=0`,
  `jimpartition.sh:1202`) and a single-source MAP prefix (`:1213`); in-place
  generalization risks the shipped split contract. Rename/split set the
  sibling-verb precedent.
- **Rejected:** Mode flags on existing verbs — flag-conditional behavior in a
  frozen verb is harder to test and regresses the shipped surface.

### 2. The renumber start is caller-passed, verbatim

- **Chosen:** `merge-map` takes an explicit `<start>` argument — the first id
  to assign — which the orchestrator passes **verbatim** from
  `jimfile.sh next-id <target>` stdout (absorption) or as `001` (fresh
  target). The verb assigns start, start+1, …; it refuses a non-numeric start
  and any result exceeding 999.
- **Why:** Keeps the verb pure and unit-testable (spec Insight 2); `next-id`
  already computes `max(dir-max, vacated-max)` — the exact floored semantic AC
  9 requires — and passing its output unmodified means the model copies a
  script value and never computes one (security Finding 6: no LLM arithmetic
  on the value that guards vacated-id re-minting).
- **Rejected:** A "highest occupied id" seed (`next-id − 1`) — puts a model
  subtraction on the floor value. Cross-script composition inside `merge-map`
  — a hidden dependency duplicating `next-id`'s tested logic.

### 3. `merge-edges-diff` as a sibling, not an `edges-diff` flag

- **Chosen:** `merge-edges-diff <before> <after> <target> <src>...` — rewrites
  every source slug → target on the before side, drops consumer==provider
  rows, then the same multiset diff and rc semantics.
- **Why:** `edges-diff`'s positional grammar (`<before> <after> <old> <new>`)
  has no clean slot for N sources; the self-edge elision is merge-specific
  (safe because a pre-merge graph cannot contain self-edges — the requires
  face is cross-group by template).
- **Rejected:** `edges-diff --merge` flag — this script's verbs are
  positional; a flag arm doubles the parse paths in a shipped verb.

### 4. Preflight emits the facts; the skill renders the judgment surface

- **Chosen:** `merge-preflight` emits `ARM`, per-slug `EFFECTIVE` rows with
  provenance (`listed`/`implicit`), per-source `CHECK` rows, `COLLAPSE\tfull`
  when the effective set covers every mapped group, `TERRITORY-IDENTITY`, and
  `DIRT`. The skill composes the gate's disposition header and the
  full-collapse advisory from these rows.
- **Why:** Mechanical-first (043 doctrine); the gate's disposition header (AC
  8) and advisory (AC 4) become script-grounded facts, which also anchors the
  event-provenance requirement (AC 14 / security Finding 1).
- **Rejected:** Skill-side arm/collapse detection — LLM re-derivation of facts
  the script can emit is the exact failure 045 removed.

### 5. Collision detection is a skill-level join over existing verbs

- **Chosen:** The orchestrator collects per-source invariant ids via
  `jimverify.sh parse` and provides-surface names via `jimverify.sh faces`,
  then computes set intersections and identical-text auto-unification itself;
  only differing-text / homonym residue reaches the interview.
- **Why:** Both verbs already emit the needed normalized TSV; the comparison
  is a join like the 034 reconcile (skill-level over script-emitted facts). No
  new verb, no LLM arithmetic on *counts* (nothing here feeds a ledger
  counter).
- **Rejected:** A new `merge-collisions` script verb — it would re-parse what
  two shipped verbs already normalize, for a set comparison the skill can do
  over their output.

### 6. The 500-line cap: authorized overage, within reason

- **Chosen:** Write `## Merge runs` and the blueprint routing at natural
  fidelity, exceeding the 500-line cap where needed — the developer authorized
  going over within reason for this spec (the cap is expected to rise soon).
  Sanity ceilings anchor "within reason" in the verifies: partition SKILL
  ≤ 560, blueprint SKILL ≤ 520. Light dedup of `## Split runs` toward
  methodology § Split protocol happens only where it genuinely reads better,
  preserving every load-bearing directive (security Finding 8's checklist) —
  no cap gymnastics, no fidelity loss.
- **Why:** Both files sit at exactly 500/500; forced compression risked
  dropping load-bearing prose (Finding 8) to satisfy a limit about to move.
  The overage trips the `000-blueprint` `skill-budget` invariant
  (criticality medium) — resolution rides the post-build blueprint-update
  violation fork as a fold-intent, the pipeline-native path.
- **Rejected:** Mandatory pre-compression to stay ≤ 500 (this DD's original
  form) — gymnastics against a moving limit. A new reference file for
  partition run-modes — a third home for protocol text when methodology is
  canonical.

### 7. `commit-merge` is parallel code to `commit-split`

- **Chosen:** Mirror `commit-split`'s shape — validate slugs, take the
  explicit `"$@"` path list as the complete docs stage set, subject
  `docs(specs): merge <s1>,<s2> into <target>` composed only from
  slug-validated values.
- **Why:** ~40 lines of parallel code keeps each commit arm independently
  auditable (research rec 4); the ledger-commit-discipline posture (literal
  paths, `--` guard, never `git add -A`) copies over.
- **Rejected:** A shared helper between commit-split/commit-merge —
  abstraction over two security-audited functions saves little and couples
  their review surfaces.

### 8. Event grammar: `old=` carries the effective set

- **Chosen:** `op=merge old=<effective sources incl. an absorbed target>
  new=<target>`; retirement rule everywhere = old-tokens ∉ new-tokens. The
  orchestrator composes values only from `merge-preflight`'s EFFECTIVE rows
  and `merge-map`'s MAP rows (AC 14's provenance clause).
- **Why:** `identity-check` and `vacated-max` extend by widening one op filter
  each with zero new parse logic; rename (old ∉ new trivially), split
  (remainder exempt), merge (surviving target exempt) share one rule.
- **Rejected:** `old=` = retired set only — reads more literally but forks the
  retirement rule per op.

### 9. Untrusted-content delimiter token

- **Chosen:** `<untrusted-merge-evidence>` for interview/gate quoting of
  blueprint/spec/gatherer content — mirroring 031's
  `<untrusted-change-evidence>` naming.
- **Why:** AC 5's delimiter requirement (security Finding 2) needs one named
  token the methodology, SKILL, and gatherer prose all cite.
- **Rejected:** Reusing `<untrusted-face-content>` — merge quotes more than
  faces (invariant texts, prose drafts); a mislabeled delimiter misleads.

### 10. Test fixture: a `merge_repo()` sibling of `split_repo()`

- **Chosen:** New helper in `tests/jimpartition.sh` building a three-group
  repo (`cart`, `orders`, `wishlist` + map + contract graph), following
  `split_repo()`'s pattern (`tests/jimpartition.sh:248-306`); jimledger/jimfile
  cases build inline fixtures as their siblings do.
- **Why:** Merge cases need ≥3 groups (multi-source + a bystander for
  re-point/full-collapse-negative cases); mutating `split_repo` would touch
  123 shipped cases' substrate.
- **Rejected:** Parameterizing `split_repo` — churn in a widely-consumed
  fixture for one consumer's needs.

## Constitution Check

**ARCHITECTURE.md status:** Present — constraints noted below.

| Constraint from ARCHITECTURE.md | Honored? | Notes |
| :--- | :--- | :--- |
| Single-writer: map/blueprints written only via the blueprint surface | Yes | Doc fusion only through the `--merge` arm (task 9); partition composes, never writes these artifacts |
| No skill gains a git grant; script-owned git primitives | Yes | `commit-merge` + reused `move-spec-dir`; no `allowed-tools` git clause anywhere |
| Permission Conventions: exact-script clauses; verb-scoping when consuming few verbs | Yes | **Zero `allowed-tools` delta**: partition already holds script-level clauses for `jimpartition.sh` / `jimledger.sh` / `jimfile.sh` / `jimverify.sh` (multi-verb consumer keeps the script-level clause); blueprint arm runs under the existing `Skill(jim:blueprint)` — resolves security Finding 5 |
| Counters-only ledger; display-data-only values; fixed stage allowlist | Yes | `op=merge` kv mirrors split's shapes; no new metric keys; consumers stay fail-closed (filter-widening only) |
| Bash-vs-Prompt: deterministic → script, judgment → prompt | Yes | Remap/preflight/edge-diff/floor in verbs; interview, fusion prose, collision resolution in skill |
| Gate Presentation rule at every hard gate | Yes | The merge gate cites `gate-presentation.md`; `tests/gatepresentation.sh` count updated with the new gate site (task 12) |
| Progressive disclosure: SKILL ≤ 500 lines, agent ≤ 800 tokens | Authorized exception | Developer-approved overage within reason (cap expected to rise); sanity ceilings 560/520 in the verifies (DD 6); the `skill-budget` invariant fold rides the post-build blueprint update. Gatherer stays in budget (task 11) |
| Content is data; secrets redacted; delimited untrusted quoting | Yes | `<untrusted-merge-evidence>` (DD 9); location-only evidence conventions carried |
| No standing verdict | Yes | Durable record = artifacts + issues + counter events; no report artifact |
| Identifier ratchet | Yes | Re-points touch dotted group-halves only; a homonym re-key is gate-presented and recorded in the commit body (AC 6) |
| Identity modes (046 doctrine) | Yes | `rewrite-identity` / `rewrite-refs` reused per source; `immutable` = no moves, no `moved=` |

## File Manifest

*No new files — every change lands in existing scripts, prose surfaces, and
test files.*

| Component | File Path | Action | Notes |
| :--- | :--- | :--- | :--- |
| Partition script | `skills/partition/scripts/jimpartition.sh` | Update | `merge-preflight`, `merge-map`, `merge-edges-diff`; `identity-check` op=merge + stale header comment; dispatch table + usage |
| Ledger script | `skills/review/scripts/jimledger.sh` | Update | `vacated-max` op=merge filter; new `commit-merge`; usage |
| File script | `skills/file/scripts/jimfile.sh` | Update | `next-id` floor comment names both ops (behavior unchanged) |
| Partition skill | `skills/partition/SKILL.md` | Update | `## Split runs` compression; new `## Merge runs`; argument-hint |
| Partition methodology | `skills/partition/references/partition-methodology.md` | Update | New § Merge protocol; supersede Merge-duality note (:544-550); § Health retired-slug wording |
| Migrate arms | `skills/blueprint/references/migrate-arms.md` | Update | New `--merge` arm (7 steps) |
| Blueprint skill | `skills/blueprint/SKILL.md` | Update | `--merge` routing row + argument-hint + § Migrate modes mention; funded by tightening |
| Gatherer agent | `agents/gatherer.md` | Update | Merge dispatch role beside the split role (:30-42) |
| Partition tests | `tests/jimpartition.sh` | Update | `merge_repo()` fixture + cases for the three verbs + identity-check |
| Ledger tests | `tests/jimledger.sh` | Update | vacated-max op=merge + tamper/multi-chunk; commit-merge |
| File tests | `tests/jimfile.sh` | Update | next-id floors from an `op=merge` event (retired-source re-mint) |
| Gate-presentation test | `tests/gatepresentation.sh` | Update | Expected per-file reference count rises with the merge gate site |

## Interface Contracts

```text
# jimpartition.sh — new verbs (read-only, stdout-only, san-field discipline)

merge-preflight <map> <specs-dir> <target> <src>...
  ARM\t(absorption|fresh-target)        # absorption iff <target> is a mapped group
  EFFECTIVE\t<slug>\t(listed|implicit)  # one row per effective source; implicit = sugar-promoted target
  CHECK\t<name>\t(pass|fail)\t<detail>  # map-exists · source-mapped:<s> · blueprint-exists:<s>
                                        # · sources-arity (effective ≥ 2; fail detail names rename for the 1→1 case)
                                        # · sources-dup · target-slug-valid · target-collision (fresh target vs
                                        #   existing dir/unmapped dir; skipped when target mapped) · tree-clean
  COLLAPSE\tfull                        # emitted iff effective set == all mapped groups
  TERRITORY-IDENTITY\t<src>\t<path>     # per source, slug-token-matched territories
  DIRT\t(affected|unrelated)\t<path>    # dirty-tree rows across every source
  rc: 0 clean · 1 structural fail · 2 usage/malformed

merge-map <specs-dir> <target> <start> <src>...
  MAP\t<src>/<onum>\t<target>/<nnum>    # absorbed sources only, CLI order, ascending onum;
                                        # absorption target emits no rows; wip dirs ride in sequence
  start: the first id to assign — passed VERBATIM from `next-id <target>`
         stdout (001 for a fresh target); the model copies, never computes
  rc: 0 · 1 (result would exceed 999) · 2 usage/bad start

merge-edges-diff <before> <after> <target> <src>...
  expected-after = before with each <src> → <target> on consumer/provider columns,
  then consumer==provider rows dropped (dissolved internals)
  MISSING\t... / EXTRA\t... rows on divergence
  rc: 0 identical-modulo-merge · 1 divergent · 2 usage

# jimledger.sh

vacated-max <specs-dir> <group>         # filter accepts ;op=split; OR ;op=merge; — parse unchanged
commit-merge <specs-dir> <target> <sources-csv> [--rekey <old:new,...>] <path>...
  # explicit path list = the docs stage set; subject "docs(specs): merge <s1>,<s2> into <target>";
  # slug-validated inputs; literal paths, -- guard, never git add -A
  # --rekey: optional invariant-id lineage pairs, each token charset-gated to
  #   [a-z0-9-] halves around one colon; rendered into the commit BODY
  #   in-script (AC 6's durable re-key record); absent → subject-only, unchanged

# op=merge close event (values only from EFFECTIVE + MAP rows — AC 14)
partition finished tier=project op=merge old=<effective-sources,csv> new=<target>
  [moved=<og/onum:ng/nnum>[,...]]       # rewrite/forward only; split's chunking (≤256B) + charset
  identity=<mode> frozen=<n> outcome=(merged|blocked|declined)
# retirement rule (identity-check, all three ops): retired = old-tokens ∉ new-tokens

# delimiter token for interview/gate quoting: <untrusted-merge-evidence>
```

## Data Flow

```mermaid
sequenceDiagram
    participant D as Developer
    participant P as /jim:partition (merge)
    participant S as jimpartition.sh
    participant G as gatherer ×N
    participant B as blueprint --merge arm
    participant L as jimledger.sh
    D->>P: merge <src>... into <target>
    P->>S: merge-preflight → ARM/EFFECTIVE/CHECK/COLLAPSE
    P->>G: one dispatch per source (evidence, collision candidates)
    P->>D: interview — fused draft + judgment residue
    P->>S: merge-map (seed = next-id − 1) → remap
    P->>D: single hard gate (dispositions, remap, edges, diffs)
    D-->>P: approve all
    P->>L: move-spec-dir per absorbed spec; rewrite-identity/refs
    P->>B: approved change-set → fusion, retirements, graph rewrite
    P->>L: commit-merge (docs) → commit-map (map + op=merge event)
    P->>S: merge-edges-diff + reconcile-to-clean
    P->>D: candidate batch (consolidation, code-clash, misalignments)
```

## Task Breakdown

1. [x] `jimledger.sh vacated-max`: accept `;op=merge;` alongside `;op=split;`
   (one filter clause; comment widens to both ops). Tests: floors from an
   op=merge event, malformed element inert, floor monotonic under crafted
   events, multi-chunk `moved=`.
   **Verify:** `bash tests/jimledger.sh vacated`

2. [x] `jimfile.sh next-id`: floor-comment names both ops; test that a
   retired-source re-mint floors past an `op=merge` event's `moved=` max.
   Depends on task 1.
   **Verify:** `bash tests/jimfile.sh next_id`

3. [x] `jimledger.sh commit-merge` per Interface Contracts (mirror of
   commit-split, plus the `--rekey` body channel). Tests: scoped staging, slug
   validation, subject shape, charset-gated rekey body composition, malformed
   rekey-token reject.
   **Verify:** `bash tests/jimledger.sh commit_merge`

4. [x] `tests/jimpartition.sh`: add `merge_repo()` three-group fixture (DD 10).
   **Verify:** `bash -n tests/jimpartition.sh && grep -q '^merge_repo()' tests/jimpartition.sh`

5. [x] `jimpartition.sh merge-preflight` per Interface Contracts + dispatch/
   usage rows. Tests: absorption vs fresh-target ARM, EFFECTIVE provenance,
   degenerate 1→1 reject naming rename, dup sources, target-collision,
   COLLAPSE row, territory-identity + dirt iteration over every source.
   Depends on task 4.
   **Verify:** `bash tests/jimpartition.sh merge_preflight`

6. [x] `jimpartition.sh merge-map` per Interface Contracts. Tests: the first
   absorbed spec receives exactly the passed `<start>` (pinning the
   verbatim-from-`next-id` convention), fresh-target from `001`, CLI argument
   order across sources, ascending ids within a source, wip riding, the
   floored re-mint guard (start=010 over a dir-max of 5), >999 refusal.
   **Verify:** `bash tests/jimpartition.sh merge_map`

7. [x] `jimpartition.sh merge-edges-diff` per Interface Contracts. Tests:
   clean collapse (dissolve + re-point) passes, third-party re-point rewrite,
   self-edge elision, divergence rc 1.
   **Verify:** `bash tests/jimpartition.sh merge_edges`

8. [x] `jimpartition.sh identity-check`: accept `;op=merge;` under the uniform
   retirement rule; fix the stale header comment (rename-only → all three
   ops). Tests: absorbed source flagged retired, surviving absorption target
   exempt, live-slug-in-old tamper case bounded.
   **Verify:** `bash tests/jimpartition.sh identity_check`

9. [x] `partition-methodology.md`: new § Merge protocol (grammar/effective
   sources/arms; preflight; gatherer dispatch; interview agenda + delimiter
   token + never-interviewed list; gate presentation incl. disposition header,
   full-collapse advisory, ratchet-break commit-body record; materialization
   order per identity mode; event grammar + provenance; edges-diff
   done-condition; territory residue + consolidation-issue rule; collision
   resolution). Supersede the Merge-duality paragraph (:544-550) with a
   pointer + the corrected invariant-id statement; fix § Health's "retired
   rename slug" wording to name all three ops.
   **Verify:** `grep -c '^## § Merge protocol' skills/partition/references/partition-methodology.md | grep -qx 1 && ! grep -q 'id collision dissolves' skills/partition/references/partition-methodology.md`

10. [x] `migrate-arms.md`: new `--merge` arm — 7 steps mirroring `--split`
    (re-validate against the `--sources` whitelist; map fusion N→1; fused
    target blueprint in-place/fresh; retire non-continuing sources without the
    standalone prompt; Contract Graph collapse + re-point; defer commits;
    return touched files). `blueprint SKILL.md`: `--merge` routing row +
    argument-hint + § Migrate modes mention at natural fidelity (DD 6
    ceiling).
    **Verify:** `grep -qc '^## .*--merge' skills/blueprint/references/migrate-arms.md && grep -q '\-\-merge' skills/blueprint/SKILL.md && [ "$(wc -l < skills/blueprint/SKILL.md)" -le 520 ]`

11. [x] `agents/gatherer.md`: merge dispatch role — one source group per
    dispatch, per-source evidence with collision candidates flagged (the dual
    of spanning cases), evidence-only framing. Keep within the agent budget.
    **Verify:** `grep -qi 'merge' agents/gatherer.md && [ "$(wc -l < agents/gatherer.md)" -le 140 ]`

12. [x] `skills/partition/SKILL.md`: new `## Merge runs` at natural fidelity
    (grammar; preflight → gatherer → interview → gate → materialize → verify
    flow; event recording with the provenance clause; gate-presentation
    reference; candidate batch) + argument-hint extension. Light dedup of
    `## Split runs` toward methodology § Split protocol only where it reads
    better — enumerate and preserve every load-bearing directive first (event
    recording, `RETIRES` row, commit ordering; security Finding 8).
    `tests/gatepresentation.sh`: raise the partition SKILL expected count for
    the new gate site. Depends on tasks 9, 10.
    **Verify:** `grep -q '^## Merge runs' skills/partition/SKILL.md && [ "$(wc -l < skills/partition/SKILL.md)" -le 560 ] && bash tests/gatepresentation.sh`

13. [x] Full suite green.
    **Verify:** `bash skills/meta-test/scripts/run.sh`

## Requirements Coverage Summary

| Spec Acceptance Criterion | Addressed In Task(s) |
| :--- | :--- |
| 1 Grammar & arms (effective sources, absorption/fresh-target, dedupe) | 5, 12 |
| 2 Degenerate 1→1 reject → rename pointer | 5 |
| 3 merge-preflight rows + rc convention | 5 |
| 4 Full collapse allowed, advisory row | 5 (COLLAPSE fact), 9, 12 |
| 5 Interview always; agenda; delimiters; mechanical never interviewed | 9, 12 |
| 6 Collision detect/auto-unify/interview; ratchet-break commit-body record; code-clash → issue | 3 (rekey channel), 9 (protocol; DD 5), 11, 12 |
| 7 Edge dissolve/re-point; default disposition; confirmable rows | 7, 9, 10 |
| 8 Single hard gate; disposition header; 040 presentation | 9, 12 |
| 9 Deterministic renumber-append; CLI order; floored start; wip | 6 |
| 10 Identity modes per 046; mode from config/developer only | 9, 12 (rewrite-identity/refs reused — no code change) |
| 11 Reference sweep; remap-as-whitelist; freeze-on-doubt | 9, 12 (rewrite-refs reused as-is) |
| 12 Blueprint --merge arm; single-writer; born-truthful graph | 10 |
| 13 Territory union; multi-root residue; consolidation-issue rule; no code moves | 9, 10, 12 |
| 14 op=merge event shape + value provenance | 9, 12 |
| 15 vacated-max/next-id/identity-check widenings, uniform rule | 1, 2, 8 |
| 16 edges-diff merge form done-condition | 7 |
| 17 commit-merge + commit-map choreography; no git grant | 3, 12 |
| 18 Reconcile-to-clean + graph health together | 12 |
| 19 Misalignments through candidate batch | 12 |
| 20 Gatherer merge dispatch role | 11 |
| 21 Bash tests over multi-group fixtures; prose by checklist | 1–8, 13 |

No `[NEEDS CLARIFICATION]` items.

## Out of Scope

- Detector-side merge signal and #72 straddle sensing (filed:
  `docs/issues/20260722-define-the-merge-signal-interpretive-rule-for-partition-health.md`).
- Consolidate-now code moves (spec Out of Scope; signed-off deferral).
- Split retrofit to the interview shape (filed:
  `docs/issues/20260722-align-partition-split-flow-to-interview-plus-gate-shape.md`).
- Issue #79 (rename re-mint floor) — rename's own; the widened machinery makes
  its fix drop-in later.
- *Handled by later gates, not deferrals:* the `000-blueprint`
  `ledger-commit-discipline` invariant row gaining `commit-merge` and the
  `skill-budget` invariant fold for the authorized cap overage (both via the
  build's blueprint-update phase), and the ARCHITECTURE.md refresh (the
  `/jim:build` completion gate via `/jim:arch`).

## Open Questions

None.

- [x] ~~Verb naming~~ → `merge-preflight` / `merge-map` / `merge-edges-diff`
  (DD 1, 3).
- [x] ~~Start passing~~ → caller-passed verbatim from `next-id` output,
  pinned by tests (DD 2; security Finding 6).
- [x] ~~500-line cap~~ → authorized overage within reason; sanity ceilings
  560/520 (DD 6).
- [x] ~~Fixture approach~~ → new `merge_repo()` sibling; `split_repo`
  untouched (DD 10).
- [x] ~~allowed-tools delta~~ → none; script-level clauses cover the new
  verbs (Constitution Check).
