---
spec: "platform/007"
type: "feature"
base_sha: "00c41c98d81d5aca7fb27a3ab7063da998ff77b4"
head_sha: "8c683cfb2efb94904623bba6e2447e8c461de9b7"
commits: "15"
commits_test: "0"
commits_feat: "10"
commits_fix: "0"
commits_refactor: "1"
files_changed: "7"
insertions: "1491"
deletions: "20"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "4783"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "860"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "2317"
sec_runs: "4"
sec_interruptions: "0"
sec_duration_seconds: "4231"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "3662"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "498"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "0"
contract_violations: "0"
alignment: "minor-drift"
date: "2026-07-26"
---

<!-- Findings record references, counts, and locations — no raw secrets. -->

# Review: ID coordination allocator (foundation)

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 4 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the `platform/007` build (`00c41c9..8c683cf`, 7 files, +1491/−20) — a new git-backed compare-and-swap ID allocator (`jimalloc.sh`) plus three additive config keys — against 15 spec ACs, 11 plan tasks, and ARCHITECTURE.md. Six read-only investigators covered the security boundary, both CAS tiers, never-reuse, resolution, the erosion guard, and the reachability tiers. Fourteen of fifteen ACs are fully satisfied for the shipped (allocate-only) behavior; the verdict is **minor-drift** on one latent gap in the *frozen-for-future* resolution semantics (AC 5 × AC 7) that no current code path can trigger, plus two advisories.

## Alignment

### vs. Spec acceptance criteria
- AC 1 (at-most-once, durable-before-return) — met. An id prints only inside a CAS-success branch; no path returns an id without a durable commit/push.
- AC 2 (racing allocations never both win; bounded retry then loud fail) — met. Both tiers' CAS (`update-ref` old-value; `push` non-fast-forward) close the TOCTOU window; retries bounded at 5, exhaustion returns non-zero with a message.
- AC 3 (never reused; permanent gap) — met. `next-id`/`next-num` are high-water marks over allocate + rename-destination; an abandoned/vacated ordinal stays counted via its allocate record and is never reclaimed.
- AC 4 (deterministic under clock skew) — met. Resolution/next-id iterate strictly in file order; the `<date>` field is written but never read for ordering.
- **AC 5 (renamed / reused / reverted resolves correctly) — drift.** Reuse-via-**allocate**, multi-hop, group-rename, and revert all resolve correctly. But reuse-via-**rename-in** (a name renamed away, then a *different* spec renamed onto the freed name) is not anchored — it resolves to the *old* referent, not the current one. Latent: this build emits no rename records and there is no `resolve` consumer yet, so no current path reaches it; but AC 7 freezes resolution semantics, so it must be closed before rename emission lands. See Finding 1.
- AC 6 (read-only preview; advisory, never binds) — met. `peek` computes next-id without committing; unreachable is non-fatal.
- AC 7 (grammar covers allocate/rename/group-rename; emit allocate only) — met (format parsed + resolved), with the AC-5 caveat above on the frozen resolution.
- AC 8 (group names allocate-once) — met. The first spec in a group emits a single `group allocate`; the CAS serializes concurrent claims.
- AC 9 (guarantee tier follows reachability) — met. A configured remote selects the origin tier; no remote selects the local tier.
- AC 10 (unreachable → bounded retry → hard-fail; no silent local fallback) — met on the security-critical property (no fallback), with a minor nuance: the *unreachability-detection* path is not retried before failing (Finding 3).
- AC 11 (erosion detected vs locally-seen; no reissue) — met. Byte-prefix guard over a per-clone baseline outside the branch; line-boundary precise; first-clone caveat honored.
- AC 12 (durable-id collision disambiguated) — met. A colliding durable issue id gets a `-2`/`-3` suffix from the same registry.
- AC 13 (replayed/config tokens revalidated before git/ref/fs use) — met. Every registry token → `valid-id`; the config branch → `check-ref-format`; the sole fs write → containment guard. Option-injection, traversal, ref-metachar, and who-forgery all foreclosed.
- AC 14 (config governs mechanism/point/unreachable, per-branch) — met. All three keys resolve from the current branch; a custom branch routes the registry.
- AC 15 (bash conventions; parsed as data, no third-party deps) — met. `set -uo pipefail; export LC_ALL=C`; no `source`/`eval`; grep/sed/awk only.

### vs. Plan tasks
- Tasks 1–11 — all done, each via Red-Green-Refactor with a `**Verify:**` gate. No scope creep; the group-allocate-on-first-use emission is within the plan's Interface Contract. Task 6 was split into a `refactor:` (extract `alloc_build_commit`) then a `feat:` per Tidy First.
- Implementation note (not a deviation): the `resolve` algorithm elaborates the plan's literal "rc 1 if no allocate record" with a `known`-check so rename/group-rename *targets* resolve idempotently — strictly more correct, and the source of the AC-5 edge in Finding 1.

### vs. ARCHITECTURE.md
- Bash-vs-Prompt placement, `set -uo pipefail`/`LC_ALL=C`, BASH_SOURCE-relative composition, the single `is_valid_id` boundary (no fourth copy), operational-git discipline — all respected. The completion-gate `/jim:arch` refresh documented the new script and config family.

## Investigation

### High-stakes regions investigated

#### AC 13 / AC 15 — security & injection boundary
- locations examined: `skills/file/scripts/jimalloc.sh:86-147, 158-317, 368-427, 456-560`; `skills/file/scripts/jimfile.sh:181-244`
- callers/consumers traced: every git/fs sink vs. its validating gate (cat-file/ls-remote/fetch/update-ref/push/commit-tree ← validated branch, sanitized `<who>`, `--`-guarded seam)
- tests checked: `tests/jimalloc.sh:75-86, 158-170, 336-348, 547-559`
- verdict: satisfied — no unvalidated token reaches git/fs; no `source`/`eval`; leading-dash, `..`, ref-metachar, and newline-forgery all rejected.

#### AC 1 / AC 2 — CAS at-most-once & race
- locations examined: `skills/file/scripts/jimalloc.sh:562-644` (retry loop), `:536-560` (both tiers), `:514-534` (plumbing)
- callers/consumers traced: `cmd_allocate` → `alloc_allocate_spec`/`_issue` → `alloc_cas_append` (sole id emitter)
- tests checked: `tests/jimalloc.sh:292-304, 388-436` (incl. concurrent race), `:457-473, 515-525`
- verdict: satisfied — id printed only in a CAS-success branch; each retry re-reads the tip and recomputes; bounded 5 then loud non-zero; TOCTOU closed by update-ref old-value + push non-ff.

#### AC 3 / AC 4 — never-reuse & file-order determinism
- locations examined: `skills/file/scripts/jimalloc.sh:247-290` (next-id/next-num), `:158-238` (resolve), `:292-317`
- tests checked: `tests/jimalloc.sh:206-241` (high-water incl. rename-dst; 008→009 base-10)
- verdict: satisfied — high-water mark, base-10 parse, date informational-only. Latent note surfaced (Finding 2).

#### AC 5 / AC 7 — resolution correctness
- locations examined: `skills/file/scripts/jimalloc.sh:149-238`
- tests checked: `tests/jimalloc.sh:88-199` (identity, multihop, group, reuse-via-allocate, cycle, malformed-skip, unknown, issue)
- verdict: partial — the six required behaviors hold on well-formed logs; the reuse-via-rename-in path is unanchored (Finding 1).

#### AC 11 — erosion guard
- locations examined: `skills/file/scripts/jimalloc.sh:429-499, 570-644`
- tests checked: `tests/jimalloc.sh:450-485, 542-559`
- verdict: satisfied — local off-branch baseline, byte-prefix with line-boundary precision (the trailing-newline capture bug is correctly handled), updates only post-commit, first-clone skip, guard runs before issuing an id.

#### AC 9 / AC 10 — reachability tier & unreachable hard-fail
- locations examined: `skills/file/scripts/jimalloc.sh:344-357, 394-427, 536-644, 712-747`
- tests checked: `tests/jimalloc.sh:487-525, 597-606`
- verdict: satisfied — tier by reachability; unreachable hard-fails with no silent local fallback; reserved modes fail loudly; `GIT_TERMINAL_PROMPT=0`. One nuance (Finding 3).

### Coverage

- Depth: thorough; review_model: inherit (session model).
- Full high-stakes set investigated (6 investigators, well under the fan-out cap of 10). The lower-risk ACs (6, 7-emit, 8, 12, 14, 15) were assessed from the diff spine, the 36 passing tests, and the mechanical hygiene test.

## Living intent

**Sensed:** 9 invariants · **holds:** 7 · **violations:** 1 (in-change 1 · pre-existing 0 · unlocalized 0) · **skipped:** 2 · **failed/unconfigured:** 0

The platform `000-blueprint` sensor ran in `--from-review` scoped mode over the whole-group floor + change-selected judges (appetite `low`). All script-rule invariants the change touches hold for the new `jimalloc.sh`; the one violation is a territory-declaration drift, not an invariant breach.

### Violations
- Territory conformance — `tests/jimalloc.sh` is outside platform's declared territory · in-change · `BLUEPRINT.md:85`. Platform's territory cell enumerates test files individually (`tests/jimconf.sh`, `tests/jimfile.sh`, …); the new test file was not added. Mirrors existing issue #110. Routed to the Findings/issue batch (a map-territory edit, not a `000-blueprint` fold). See Finding 4.

### Coverage
- appetite in force: low (judge everything the change touches).
- Whole-group floor ran (territory declared; not UNSCOPED).
- judges: change-selected, all within cap. The two critical prose invariants (`no-source-eval`, `ref-validation`) were confirmed from this session's independent read-only investigator evidence rather than re-dispatched — a cost-conscious reuse of fresh, on-point judgment; the mechanical invariants (`script-preamble`, `bash-source-relative`, `tests-under-tests`) were grep/hygiene-test confirmed.
- skipped by scope: 2 (`ledger-commit-discipline`, `blueprint-slot-reserved` — `jimalloc.sh` touches neither surface) · skipped by appetite: 0.
- registry: 0 configured for platform.

### Contracts

**Edges checked:** 3 · **holds:** 3 · **violations:** 0 (provider-side 0 · consumer-side 0)

- None — every checked edge holds. Platform is a provider (jimconf-cli/jimfile-cli/jimledger-cli/testlib); the change touched the `jimconf-cli` provider entry, but the three consumer edges (sdlc/blueprint/issue → jimconf-cli) are unaffected — the config change is purely additive (three new keys + a new dispatch arm), removing/altering no consumed surface.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 15 (0/10/0/1) |
| Files changed · insertions · deletions | 7 · +1491 · −20 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·4·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 4783s·860s·2317s·4231s·3662s·498s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The build adds jim's first network + shared-ref-write git surface, but with full discipline: every replayed/config token revalidated through the single boundary, the free-text `<who>` sanitized on write, a write-containment guard on the sole fs write, an erosion guard on a local baseline, and non-interactive git. No secrets are handled or committed; `<who>` derives from `git config user.name` (not sensitive).

## Findings

### 1. Resolution not anchored for reuse-via-rename-in (frozen semantics)

- **Priority:** medium
- **Description:** `alloc_resolve_spec`/`alloc_resolve_issue` set the replay anchor only on an `allocate` match, not when the queried id is a rename *destination*. A name renamed away and later reused by renaming a different spec onto it resolves to the old referent, not the current one — the "mis-resolve to the wrong referent" AC 5 forbids. No current path triggers it (this build emits no rename records; there is no `resolve` consumer yet), but AC 7 freezes resolution semantics, so it must be closed before the rename-emitting follow-on (#113) begins emitting rename/group-rename records.
- **Suggestion:** When rename emission lands (#113), extend the anchor to also fix on the last rename whose destination equals the queried id, and add fixture cases for reuse-via-rename-in (spec and issue). Track as a note on #113.
- **Relates to:** AC 5, AC 7; `skills/file/scripts/jimalloc.sh:169,172,222,225`

### 2. next-id counts rename destinations but not sources

- **Priority:** medium
- **Description:** The high-water `next-id`/`next-num` fold in allocate ids and rename destinations but not rename sources. The permanent-gap guarantee therefore rests on the invariant that every rename source has its own prior `allocate` record. In a well-formed, allocate-only log (this build) it always holds; but once rename emission lands (or via a hostile push to the untrusted branch), a rename record whose source lacks an allocate could let a vacated ordinal be reclaimed. Same follow-on family as Finding 1.
- **Suggestion:** When rename emission lands (#113), either count rename sources in the high-water fold or assert the source-has-allocate invariant; add a fixture seeding a same-group rename source.
- **Relates to:** AC 3, AC 7; `skills/file/scripts/jimalloc.sh:247-266`

### 3. Unreachable-detection path is not retried; exhaustion message says "contention"

- **Priority:** low
- **Description:** In the origin tier, a `git ls-remote`/`fetch` failure (`alloc_origin_tip`) hard-fails on attempt 1 with zero retries; only push-rejection re-enters the bounded loop. AC 10 says allocation "performs bounded retries and then hard-fails" for the unreachable case — a transient network blip fails immediately rather than retrying. The security-critical property (no silent local fallback) is intact and "bounded" is trivially satisfied (0 ≤ 5). Separately, the exhaustion message always attributes failure to "contention," which would misdescribe a repeated push-policy denial.
- **Suggestion:** Consider retrying the reachability-detection path with the same jittered backoff for transient blips, and generalize the exhaustion message beyond "contention." Low priority — behavior is safe as-is.
- **Relates to:** AC 10; `skills/file/scripts/jimalloc.sh:413-424, 642`

### 4. New test file outside platform's declared territory

- **Priority:** low
- **Description:** The build added `tests/jimalloc.sh`, which falls outside platform's map territory (`BLUEPRINT.md:85`) because that cell enumerates test files individually and the new one was not added. The living-intent sensor flagged it as an in-change territory violation. Directly parallels open issue #110 (`tests/scripthygiene.sh`).
- **Suggestion:** Add `tests/jimalloc.sh` to platform's territory in `BLUEPRINT.md` (a map reconcile / partition update, not a code change) — or fold it into the batch alongside #110.
- **Relates to:** AC 5 (territory conformance); `BLUEPRINT.md:85`

## Deviations & feedback

- The build ran clean: 0 interruptions across every stage, 11 TDD tasks each Red-Green-verified, full suite 745/745 green. The one mid-build bug (erosion baseline trailing-newline stripping through command substitution) was caught and fixed within the task, then confirmed by an independent investigator — evidence that the Red-Green discipline plus the review fan-out both earned their keep.
- Findings 1 and 2 are the same shape: correct-for-now behavior whose *frozen* contract has a rename-era edge. They are best carried as notes on the rename-emission follow-on (#113) rather than standalone work, since that spec is the one that will first exercise them.
