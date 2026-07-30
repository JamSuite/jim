---
spec: "sdlc/017"
type: "feature"
base_sha: "f930730067bc42563a90a36e822235b5d0e036fa"
head_sha: "781d0b1251e93271ff7e36ff8f997eb514088646"
commits: "25"
commits_test: "11"
commits_feat: "11"
commits_fix: "1"
commits_refactor: "0"
files_changed: "10"
insertions: "2194"
deletions: "33"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "4441"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "1123"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1742"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "3153"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "6699"
review_runs: "2"
review_interruptions: "0"
review_duration_seconds: "167"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "3"
security_regressions: "2"
invariant_violations: "1"
contract_violations: ""
alignment: "major-drift"
date: "2026-07-30"
---

# Review: Coordinated spec identity

## Summary

**Alignment:** major-drift · **Depth:** thorough · **Findings:** 15 · **Plan deviations:** 3 · **Security regressions:** 2

Reviewed the full `sdlc/017` build (25 commits, `f930730..781d0b1`) against the spec's 15 acceptance criteria, the plan's 13 tasks, and `ARCHITECTURE.md`, with a ten-investigator fan-out over the high-stakes set. Every planned task landed with tests and the suite is green at 903 cases with no pre-existing fixture modified — but the implemented behaviour is not the whole contract, and the fan-out found defects the build's own tests could not: a silent duplicate-ordinal path that defeats the guarantee this spec exists to provide, an unvalidated path composition that can write `plan.md` and `research.md` into fabricated directories unattended, and a high-criticality invariant in the shipping group's own blueprint that the build contradicts and never folded.

This review supersedes an earlier pass that recorded `minor-drift` with 5 findings. That pass assessed the same regions without independent investigation and reached a verdict the evidence does not support; the ledger retains both lines so the trajectory stays visible. The earlier pass also stated that subagent dispatch was "unavailable" — that was wrong, and is corrected under Coverage.

## Alignment

### vs. Spec acceptance criteria

- AC 1 — met, prose-only. Reserved-before-write and write-nothing-on-refusal are asserted by `skills/spec/SKILL.md` Step 8; no executable check of flow order exists.
- AC 2 — met for the coordinated path (`case_jimalloc_origin_cross_clone_distinct`), but see Finding 5: on a reused-group-name log the shared fold hands out an ordinal that is already resolvable, so "never receive the same ordinal" has a reachable exception that predates this build.
- AC 3 — met. Both tiers exercised.
- AC 4 — met, prose-only for the ordering clause. `peek` provably mutates nothing and `mv-spec-id` absorbs the shift; nothing asserts a stale preview cannot reach the artifact.
- AC 5 — **drift.** Offline completion, registry exclusion and high-water exclusion hold. "The downstream stages run against it unchanged" does not: Finding 2.
- AC 6 — met weakly. The hard fail happens, but the skill never names the `fail` unreachable-mode and the message it would actually see (`coordination remote '<r>' is unreachable`) matches neither refusal the skill enumerates; "bounded retries" is asserted nowhere.
- AC 7 — **partial.** Preview-then-apply, idempotency and resumability hold. The residual same-identity clause does not: the fixture claiming to cover it pre-realizes *the same* directory, so it proves resume, not that two distinct specs sharing group/slug/date are surfaced rather than merged.
- AC 8 — met. `git` records an `R` for the committed case; the uncommitted case renames plainly.
- AC 9 — **partial.** The `moved=` record lands on the specs-root ledger and is proven inert to the vacated floor and to metrics. But Finding 7 shows a realized identity can be silently absent from that record, and the no-registry-rename half has no negative assertion (it holds structurally — no rename encoder exists in the file).
- AC 10 — met for classification; `allocate spec --follow-redirect` is never exercised end to end, and exhaustion-as-terminal has no test in any path.
- AC 11 — met.
- AC 12 — met. No `next-id` reference survives under `skills/spec/`; the verb keeps its partition caller.
- AC 13 — **divergence.** Every token is revalidated except one: the realized ordinal returned by the allocator (Finding 3), which reaches a path, a git argument and frontmatter unchecked.
- AC 14 — **divergence on both sides.** Realize side: Finding 3 bypasses the halt. Creation side: Finding 4 — the halt is delegated to a primitive that refuses only an exact-name collision, so the drift case AC 14 names proceeds silently.
- AC 15 — met. 903 cases pass; `git diff --numstat` over the range shows additions only in the three pre-existing test files (399/173/62 insertions, 0 deletions).

### vs. Plan tasks

- Tasks 1–5, 7–10, 12–13 — done as specified.
- Task 6 — deviation (justified). No source-basename gate exists on `rename-tracked`; the described change would have broken `/jim:partition`'s group- and territory-dir renames. Behaviour pinned instead, `jimledger.sh` untouched. The instruction traces to `move-spec-dir`, whose gate really is 3-digit-only — see Finding 12 for the consequence that was left unnamed.
- Task 11 — deviation (justified). DD 3's provisional rename was inexpressible in DD 4's verb; a three-argument form was added rather than putting raw `mv` in a skill body.
- Task 4 — deviation (justified). The plan's two contracts disagreed on the preview's field count; the unimplementable reading was discarded.
- No scope creep. Every changed file is in the File Manifest except `jimledger.sh`, which was not changed.

### vs. ARCHITECTURE.md

- Scripting Layer (bash + POSIX), `set -uo pipefail` + `LC_ALL=C`, `BASH_SOURCE` composition, operational-git discipline, `allowed-tools` exactness, tests-under-`tests/` — all respected.
- Single `is_valid_id` boundary — respected in letter, strained in spirit (Finding 10).
- No artifact IDs in code comments — respected.
- **Stale, and this build's responsibility:** `ARCHITECTURE.md:304,307` still declares `docs/specs/{group}/{NNN}-{name}/` and "IDs are 3-digit zero-padded", contradicting the same document's own updated Scripting Layer prose. The refresh performed at the build's completion gate updated one region and missed the Data Stores block (Finding 14). The fix belongs to `/jim:arch`, never a hand edit.

## Investigation

Ten investigators, the configured cap, highest-risk first. Every target below was deep-investigated; none was dropped.

### High-stakes regions investigated

#### `alloc_cas_append` builder-status change — satisfied
- locations: `jimalloc.sh:1129,1165-1176`; callers `:1344`, `:1358`
- evidence: array equivalence holds for 2-line, 3+-line, empty and no-trailing-newline output; the only divergent shape (trailing *blank* lines) is unreachable since every builder emits one `\n` per line, and would have written blank lines into the registry under the old form anyway. `builder_rc=$?` sits on its own line, so the `local x="$(...)"` masking pitfall is avoided. No consumer greps the removed generic string. Incidental gain: the old form ignored builder status entirely, so a builder failing *after* printing ≥2 lines would have had its records committed.

#### `alloc_reconcile_realize_spec` — partial (Findings 5, 6, 9)
- locations: `jimalloc.sh:658-712`, `:126-151`, `:674-688`
- evidence: key-field gating and token splitting are airtight — `P-`, `P-12345678`, `P-12345678-`, embedded newline/tab and any `/` in the slug all fail. No key component can contain `/`, so the `<group>/<slug>/<date>` key cannot be forged. Batch validation precedes emission for the boundary-invalid and duplicate halts. Three defects: double alias resolution (Finding 5), unpadded `have` ordinal (Finding 6), exhaustion halt inside the emit loop (Finding 9).

#### Registry write path — satisfied (AC 9's registry half proven)
- locations: `jimalloc.sh:1753-1784`; encoders `:182-190`
- evidence: exactly two record grammars are reachable and **no rename encoder exists anywhere in the file** — `spec rename` / `group rename` appear only in read-side parsers. `PUB_SPEC`/`PUB_ISSUE`/`PUB_PAYLOAD` are assigned, never re-declared `local`, so the shared publish's dynamic-scope readback works. Guard order is identical to the shipped issue path. Preview mutates nothing.
- two pre-existing latencies, neither a regression: `alloc_group_present` is fed via `printf '%s'` and so drops the log's final line (unreachable — every writer appends a `spec allocate` after a group record); and because the group passed to it is post-alias while it matches literal records, a crafted `group rename` yields a redundant second `group allocate`. Reviewer's note: the investigator called the latter unreachable "while no writer emits `group rename`", which does not hold — the registry is push-writable and the read path parses such records precisely because they can appear without jim emitting them. Consequence is a redundant record; the fold counts spec ordinals, not group records, so no ordinal decision changes. Identical shape exists in `alloc_build_spec` on the shipped path.

#### `mv-spec-id` and its basename gates — satisfied (Finding 13)
- locations: `jimfile.sh:445-474,505-549`
- evidence: all four elements gated before the first path composition and long before the single `mv`; same-parent is structural, not merely checked, since both basenames share the literal group-dir prefix and neither may contain `/`. `is_valid_id`'s extra latitude over `is_valid_slug` (uppercase, `.`) is inert as a path component. The clobber refusal immediately precedes the only `mv`. One narrow TOCTOU: `mv` omits `-T` (Finding 13).

#### Realizer scan and apply — partial (Findings 3, 8, 15)
- locations: `reconcile.sh:87,114-141,171,184,213-258,454-461`
- evidence: the pending set itself is clean — no `/`, tab, newline, glob or shell metacharacter can reach a path or the allocator. `failed` handling is correct: every error path continues, the status survives the command substitution, and a halted identity is absent from both sweep and ledger. Partially-staged directories route to the correct primitive. Three defects: the unvalidated ordinal (Finding 3), `rewrite_id`'s silent no-op (Finding 8), and the absolute-dir wart (Finding 15).

#### Citation sweep — partial (Findings 6b, 11, 12b)
- locations: `reconcile.sh:261-281,306-387`; precedent `jimpartition.sh:1782-1897`
- evidence: boundary matrix confirmed — `docs/specs/sdlc/P-…/spec.md` MATCH→path; `sdlc/P-…-alpha-2` NO-MATCH (the same-day sibling is safe, as required); `…alphax`, `xsdlc/…`, `SDLC/…` all NO-MATCH. Overlapping entries and multi-match are safe: `break` fires only inside the boundary-accepted branch, so the longer sibling wins regardless of remap order, and rewrites accumulate while the scan advances over the untouched original. The guard loop runs over every target before the first write. Location-only output is canaried. A control-character filename is C-quoted by `git ls-files` and dropped by the `.md` filter, so no forged record. Two defects: the fence toggle (Finding 6b) and the PATHED/TYPED pick (Finding 11).

#### `record_realized` and ledger interaction — satisfied (Finding 7 is at the caller)
- locations: `reconcile.sh:406-427`; `jimledger.sh:652,821-828`
- evidence: **both inertness claims proven.** `vacated-max` fails on fields 3/4 before any `moved=` split is reached, and no other consumer reads `moved=` at all. `cmd_metrics` pairs stage bounds on `$3==phase && $4=="started"/"finished"` — the *event* token — so `spec`/`realized` is matched by none of the four programs and the spec-stage counters are bit-identical with or without it. Field/line forgery is impossible: the read is line-oriented and tab-split, and both anchored regexes exclude space, tab, `;`, `,`, `:` and newline. Two empty guards make a degenerate event unreachable. A single element over 256 bytes is emitted **whole**, never truncated — correct per AC 9, though the plan's "chunked ≤256 bytes" reads as a hard bound and is optimistic for that input.

#### `skills/spec/SKILL.md` flow and grants — divergence (Findings 2, 4, 16)
- locations: `SKILL.md:10,86,92,189,198-199,212-232,358,395`
- evidence: grants are verb-scoped with no whole-CLI `jimalloc.sh *`, and every script the body invokes is covered. AC 10/AC 14's classification and drift prose are unambiguous. But four sections contradict the new flow (Finding 16), and the provisional write path is unfollowable (Finding 2).

#### Omission class, repo-wide — divergence (Findings 1, 2, 12, 14)
- locations: 14 sites across `jimfile.sh`, `skills/{plan,research,spec,blueprint,partition}`, `jimpartition.sh`, `jimledger.sh`, `ARCHITECTURE.md`, `WORKFLOW.md`, two `000-blueprint` files and two templates
- evidence: verified unaffected — `next-id`'s numeric gate (skips `P-`, desired), `glob specs` (unfiltered, correct), the seed skip, `rename-tracked`'s new-basename gate, `vacated-max`, `jimverify.sh`, the issue origin lint, `migrate.sh`, and `cmd_mv_spec` (3-digit-only but with no production caller left). The rest are Findings 1, 2, 12, 14.

#### Independent AC sweep — divergence (Finding 4)
- Defaulted all 15 ACs to unproven. Named the prose-only set, and found two tests weaker than the AC they cover (AC 7's residual case, AC 6's message assertion) plus AC 14's untested creation-side hole.

### Coverage

- Depth: thorough; `review_model: inherit`; fan-out 10 of 10 available slots used, no region left un-investigated.
- **Correction to the earlier pass.** It recorded that "subagent dispatch was unavailable this session". That was inaccurate: dispatch worked, and this session carried a standing instruction not to call the Agent tool unless the developer requested it. The developer then requested it explicitly, and this pass is the result. The distinction matters because the earlier phrasing implied a broken harness rather than a permission boundary — and because the un-run fan-out was the sole reason a `minor-drift` verdict looked defensible.
- **Reviewer independence:** the reviewer authored the build. Every finding here rests on an investigator's evidence or on a reproduction the reviewer ran directly (Finding 5's double-issue was reproduced end to end), not on the author's own recollection of intent.
- One investigator had no Bash tool, so AC 15's numstat check was completed by the reviewer directly rather than by that agent.
- Investigator conclusions were treated as untrusted: one claim was rejected on review (the `group rename` unreachability above) and one was found understated (`renumber-map` aborts the whole split rather than skipping — Finding 12).

## Living intent

**Sensed:** 1 invariant (by direct investigation, not by the engine) · **holds:** 0 · **violations:** 1 (in-change 1 · pre-existing 0 · unlocalized 0) · **skipped:** all others · **failed/unconfigured:** 1

### Violations

- **`spec-id-sequencing` — high criticality · violated · in-change · `docs/specs/sdlc/000-blueprint/spec.md:100` and `docs/specs/jim/000-blueprint/spec.md:233`.** The invariant reads "Spec IDs are 3-digit zero-padded and sequential within the group; … (the minting mechanism is the platform group's `next-id`)". This build contradicts **both** halves deliberately and by design — a provisional identity is `P-<date>-<slug>`, not three digits, and AC 12 strands `next-id` for spec creation — and folded neither declaration. See Finding 1.

### Coverage

- The `sdlc` group has a blueprint, so the sensor was in scope and should have run.
- **Engine not run.** The sensor's judge rung dispatches subagents, which the earlier pass was not authorized to do; this pass spent its authorized fan-out on the alignment investigation. The violation above was found by the omission sweep rather than by a whole-group sensor pass, so this section is **not** a clean bill of health for the group's other invariants — they are unmeasured, not sound. `invariant_violations: "1"` counts only what is evidenced.
- Running `/jim:verify --from-review docs/specs/sdlc/017-coordinated-spec-identity sdlc` would measure the remainder without re-running the build. Both blueprint declarations should be folded either way, and the `jim` group's copy is outside this review's group — it needs its own fold.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 25 (11/11/1/0) |
| Files changed · insertions · deletions | 10 · +2194 · -33 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·2 |
| Stage durations (spec·research·plan·sec·build·review) | 4441s·1123s·1742s·3153s·6699s·167s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

Two, both on surfaces this build introduced, both reachable through the crafted-record vector the spec's own security review accepted as in scope.

1. **Unvalidated realized ordinal → duplicate-ordinal directories, exit 0.** Finding 3. A crafted `spec allocate <group>/18 <slug> <date>` record drives a rename onto an ordinal the tree already holds as `018-…`, with no halt and no warning. The guarantee AC 14 exists to provide is defeated silently.
2. **Silent loss of the durable audit record.** Finding 7. On the same path, `record_realized`'s gate rejects the row and continues, so the identity is renamed and swept while its provisional→real mapping is absent from the ledger, with exit 0. The record AC 9 requires for later dereferencing is the thing that disappears.

Not regressions, recorded for completeness: `reconcile.sh` takes its specs root from configuration and globs it without a worktree-containment check, matching how `jimfile.sh` and siblings already treat developer-owned config paths.

## Findings

### 1. The build contradicts a high-criticality invariant in its own group's blueprint, unfolded

- **Priority:** critical
- **Description:** `spec-id-sequencing` (high criticality, judge rung) is declared in `docs/specs/sdlc/000-blueprint/spec.md:100` and again in `docs/specs/jim/000-blueprint/spec.md:233`: "Spec IDs are 3-digit zero-padded and sequential within the group; … (the minting mechanism is the platform group's `next-id`)". Both halves are now false by design. Nothing folded either declaration, and the mechanism that exists to catch precisely this — the review's living-intent sensor — did not run, so the contradiction is unrecorded. The next `/jim:verify` of either group must score every provisional spec a violation or silently reinterpret its own invariant.
- **Suggestion:** fold both declarations through the blueprint surface (`/jim:blueprint --from-review` for `sdlc`; the `jim` group needs its own pass), restating the invariant to cover both identity states and naming the allocator as the minting mechanism.
- **Relates to:** AC 5, AC 12, living intent

### 2. The path helper composes a fabricated directory for a provisional spec — at five call sites

- **Priority:** critical
- **Description:** `jimfile.sh:783-791` composes `<specs>/<group>/<id>-<name>/<kind>.md` with **no validation of `id` or `name`**, and requires all three arguments. A provisional directory's basename is the whole token, so `path plan sdlc P-20260728-alpha alpha` prints `docs/specs/sdlc/P-20260728-alpha-alpha/plan.md`, exit 0, a directory that does not exist. There is no correct way to call it on that branch — the caller must invent a `<name>`. Five sites do exactly this: `skills/plan/SKILL.md:120` (with `Bash(mkdir *)` and `Write` granted), `skills/research/SKILL.md:38` (auto-spawned by `/jim:plan` Step 3, so it fires **unattended**), `skills/spec/SKILL.md:231` (the provisional branch's own write path, so the spec file can land outside the directory Step 8 just created), plus `skills/plan/assets/plan-template.md:3`, which bakes `{id}-{name}` into a persisted machine-read back-reference.
- **Suggestion:** teach `cmd_path` a provisional form that takes the token as the whole basename — mirroring the three-argument `mv-spec-id` added for the same reason — and validate `id`/`name` there. Fix the template. Cover the provisional shape with a fixture; none exists anywhere.
- **Relates to:** AC 5, DD 2, Task 11

### 3. The drift halt is bypassable: the realized ordinal is never revalidated

- **Priority:** critical
- **Description:** `reconcile.sh:223` takes `ord="${real##*/}"` and uses it as a path component (`:226`), a glob (`:227`), a git argument (`:232`) and frontmatter (`:248`) with no numeric gate — the one tree/registry-derived token the script never revalidates. The allocator's `have` branch emits whatever digits a record carries (`^[0-9]+$`, not `%03d`), so a record `spec allocate sdlc/18 alpha 20260728` matching a pending `sdlc/P-20260728-alpha` yields `ord=18`. `ordinal_holder` matches the ordinal as a literal string, so it globs `18-*/` and `18/` and **misses the existing `018-alpha`** — no halt. On the committed branch `rename-tracked`'s basename gate (`^[a-z0-9][a-z0-9-]*$`) accepts `18-alpha`. Result: two directories on one numeric ordinal, `id: "18"`, exit 0. The untracked branch is safe only because `mv-spec-id` carries the digit gate — the two rename primitives enforce asymmetrically.
- **Suggestion:** gate `ord` with `^[0-9]{3,15}$` in `apply_pending` and halt otherwise; compare numerically (`10#$ord`) in `ordinal_holder` so padding variants collide; and normalize the allocator's `have` branch to `%03d` so it matches `new`. Fixture the padding-variant and bare-`<NNN>` occupant cases.
- **Relates to:** AC 13, AC 14, security regression 1

### 4. AC 14's creation-side halt detects only an exact-name collision

- **Priority:** high
- **Description:** `SKILL.md:218` delegates the drift halt to `mv-spec-id`, which refuses on `[[ -e "$target" ]]` — the exact composed name. With `001-bar` in the tree and absent from the registry, `allocate spec` issues `001`, the target `001-foo` does not exist, the rename succeeds and the spec is written. That is exactly the registry-vs-tree drift AC 14 requires to halt loudly. The realize path has ordinal-level detection (`ordinal_holder`); the creation path does not, so the two halves of one AC are enforced asymmetrically. No test covers it.
- **Suggestion:** give the creation path the same ordinal-level check — either in `mv-spec-id` (refuse when any sibling holds the target ordinal) or as an explicit step before the rename — and fixture it.
- **Relates to:** AC 14

### 5. The shared fold resolves group aliases twice, durably double-issuing an ordinal

- **Priority:** high
- **Description:** a caller resolves the group through the alias map and then passes the resolved name to `alloc_fold_max_spec`, which resolves it **again**, walking one hop too far and folding a retired namespace. Reproduced directly: with `spec allocate side/001 …`, `group rename core legacy`, `group rename side core`, the map is `side→core, core→legacy`; `fold(side)=1` but `fold(core)=0`; `alloc_next_id_spec side --follow-redirect` → `core/001` and `alloc_reconcile_realize_spec side/P-…` → `core/001`, while `alloc_resolve_spec side/001` → `core/001` shows that ordinal already taken. `--apply` publishes the duplicate record before the tree-side group-mismatch halt fires, so the registry double-issues durably. **This predates the build** — `alloc_next_id_spec` has the identical defect, and the new function inherits it precisely because it reuses the shared fold, which was the correct design decision. No test exercises a reused group name at the fold level; the existing alias tests cover only chains and the A→B/B→A cycle, the one shape where double resolution is harmless.
- **Suggestion:** resolve exactly once — either have the fold accept a pre-resolved group and skip its own resolution, or have callers pass the raw group and let the fold own it. Fixture the reused-name log against both `next-id` and realize.
- **Relates to:** AC 2, AC 15

### 6. Two sweep defects: a live fence-tracking bug, and an unpadded-ordinal echo

- **Priority:** high
- **Description:** (a) `reconcile.sh:349`'s fence toggle is char- and length-blind, where jim already ships two correct trackers (`migrate.sh:338-345`, `index.sh:219-245`) that record the marker and close only on a ≥-length run of the same character. A 4-backtick outer fence is closed by the first inner 3-backtick fence, so the inner block is rewritten as live — and that shape exists in the swept roots today (`docs/issues/20260531-wikilink-parser-skips-fenced-code-blocks.md`, `docs/specs/blueprint/009-verify-contracts/plan.md`, `docs/specs/blueprint/007-verify-engine/plan.md`, `docs/brainstorms/20260512-jim-howtos.md`). A `~~~` line inside a ``` block also toggles; an unclosed fence silently skips the rest of the file. (b) Separately, `jimalloc.sh:665` stores the `have` ordinal verbatim while `:711` canonicalizes `new` with `%03d` — the asymmetry feeding Finding 3.
- **Suggestion:** reuse one of the two existing fence trackers rather than a third implementation. Normalize the `have` ordinal.
- **Relates to:** AC 7, DD 5

### 7. A realized identity can be silently absent from the durable record

- **Priority:** high
- **Description:** `record_realized` re-gates each row on `^…/[0-9]{3,15}$` and `continue`s on failure. Reached with the Finding 3 ordinal, the identity is renamed and its citations swept, while its provisional→real mapping never enters the ledger — exit 0, no warning. AC 9's durable bridge, and the lift the rename-emitting follow-on depends on, is exactly what goes missing.
- **Suggestion:** make a rejected row loud — warn and set the failure status — rather than silently dropped. Ideally it becomes unreachable once Finding 3 gates the ordinal upstream.
- **Relates to:** AC 9, security regression 2

### 8. The frontmatter rewrite can silently no-op on a realized spec

- **Priority:** medium
- **Description:** `field_value` anchors on the whole file's first `^id:` while `rewrite_id` anchors inside the first `---` block. A `spec.md` with no frontmatter — or with CRLF `---\r` — whose *body* line `id: P-…` matches the directory passes the scan, gets renamed, and the awk rewrite does nothing: realized directory, file still claiming the provisional identity, exit 0. Rewrite success is never verified. The mirror case also holds: a no-frontmatter file with a body `---` sets the block counter mid-body, so a later `id:` line there *is* rewritten.
- **Suggestion:** require a real leading frontmatter block during the scan, and verify the rewrite changed the field before reporting success.
- **Relates to:** AC 7, AC 13

### 9. Exhaustion halts after emitting, contradicting the documented contract

- **Priority:** medium
- **Description:** the exhaustion guard sits inside the emit loop, so a batch prints earlier rows and then returns 1 — while the docstring claims it "halts (rc 1) before emitting anything". `alloc_next_id_spec` checks before printing. The consumer discards the mapping on non-zero rc, so nothing downstream acts on the partial output today, but the contract is false for any other consumer and the preview pipes realize straight to stdout. No test exercises exhaustion in any allocator path.
- **Suggestion:** compute the whole batch before emitting any row, or fix the docstring. Add an exhaustion fixture.
- **Relates to:** AC 10

### 10. The provisional grammar is written three times with nothing keeping them in lockstep

- **Priority:** medium
- **Description:** expressed in `jimalloc.sh` (`alloc_is_prov_form`, `alloc_valid_provid`), `jimfile.sh` (`is_prov_basename`, `is_spec_dir_basename`) and `reconcile.sh` (`is_prov_identity`). Each delegates the token check to `valid-id`, so the id boundary is single-sourced, but the grammar around it is triplicated across a trust boundary. Independently corroborated: `is_prov_basename` admits id-charset slugs, so a hand-typed `P-20260728-New.Widget` creates a directory the realize path later rejects. The repo's precedent for a knowingly-duplicated check carries a `SYNC:` note and a byte-identity fixture; these have neither.
- **Suggestion:** single-source it as a `jimfile.sh` verb, or adopt the `is_valid_id` discipline.
- **Relates to:** AC 13, ARCHITECTURE.md → Scripting Layer
- **Already filed:** `docs/issues/20260730-single-source-the-provisional-identity-grammar.md`

### 11. The path-vs-typed replacement choice drops the slug for a first-segment path

- **Priority:** medium
- **Description:** the pick keys on `before == "/"`. In the partition precedent that signal only *labels* the record — the replacement is identical either way and the `-slug` tail survives. Here the source token consumes the whole slug, so a path citation whose group is the first segment (`[x](sdlc/P-20260728-alpha/spec.md)`) picks the typed replacement and yields `sdlc/017/spec.md`, a dead link. Latent: every citation in the corpus today goes through `docs/specs/…`.
- **Suggestion:** decide by whether a `/` *follows* the token as well, or match the path form explicitly with its trailing separator.
- **Relates to:** DD 5

### 12. Partition and provisional specs interact badly, in three places

- **Priority:** medium
- **Description:** `jimpartition.sh:1362` gates each `renumber-map` assign row on `^[0-9]{3}(-wip)?$`, so a `P-` source **aborts the whole split remap** (rc 1, no output) — one pending spec blocks the split rather than being skipped, which is stronger than the earlier pass reported. `jimledger.sh:579-582`'s `move-spec-dir` refuses a `P-` basename outright — the gate Task 6 was actually reaching for. And `jimpartition.sh:1450` plus `partition-methodology.md:418` silently strand a pending spec in a retired group. Separately, `skills/blueprint/SKILL.md:63` globs "the group's **numbered** spec directories", so a pending provisional spec is excluded from blueprint synthesis with no note.
- **Suggestion:** settle it once — either refuse a partition while provisional specs are pending, or carry them (which needs the cross-parent move the group-rename issue also needs). Decide whether blueprint synthesis should see them.
- **Relates to:** AC 5
- **Partly filed:** `docs/issues/20260730-settle-what-a-partition-does-with-pending-provisional-specs.md`

### 13. `mv` without `-T` can nest instead of refusing

- **Priority:** low
- **Description:** both `cmd_mv_spec_id` and the shipped `cmd_mv_spec` omit `-T`/`--no-target-directory`. If the target appears as a directory between the `[[ -e ]]` check and the `mv`, the source is nested inside it and the verb still prints the target and exits 0 — a silent wrong move. Narrow single-developer race; pre-existing pattern, not introduced here.
- **Suggestion:** add `mv -T` to both.
- **Relates to:** AC 14

### 14. `ARCHITECTURE.md` contradicts itself after an incomplete refresh

- **Priority:** low
- **Description:** the completion-gate refresh updated the Scripting Layer prose but left `ARCHITECTURE.md:304,307` declaring `{NNN}-{name}` and "IDs are 3-digit zero-padded", so the document now disagrees with itself.
- **Suggestion:** complete it through `/jim:arch` — never a hand edit, per the group's own `arch-via-skill` invariant.
- **Relates to:** ARCHITECTURE.md

### 15. Smaller defects worth batching

- **Priority:** low
- **Description:** (a) an absolute spelling of the configured specs dir passes the `--apply` realpath guard, after which tracked identities fail loudly (`valid-relpath` rejects absolute) while untracked ones succeed. (b) `index.sh`'s regen discards rc and stderr, so a failed regen leaves a stale INDEX and the run still returns 0. (c) An untracked spec directory's own files are absent from `git ls-files`, so an uncommitted provisional spec's body self-citations stay stale with no warning — concrete, since `apply_pending` deliberately supports untracked directories. (d) `WORKFLOW.md`, `README.md` and `skills/spec/assets/spec-template.md:5` still imply a numeric id and document neither reconcile surface nor provisional mode. (e) Missing fixtures, named: padding-variant ordinal, bare `<NNN>` occupant, mixed-batch partial failure, partially-staged directory, group-rename halt, absolute-dir apply, exhaustion in either path, `allocate spec --follow-redirect` end to end, and AC 7's genuine two-spec residual case.
- **Suggestion:** batch (a)–(c) as hardening; (d) is the user-doc pass already in flight; (e) is the test debt this review exposes.
- **Relates to:** AC 6, AC 7, AC 8, AC 10

### 16. `skills/spec/SKILL.md` contradicts itself in four places

- **Priority:** medium
- **Description:** `:86` still says "for a new spec you'll assign the next id when you open the ledger below" — flatly contradicting `:92` ("The id is **not** assigned here") and `:189` ("never earlier"), and the one surviving tree-derivation cue. `:395`'s checklist still demands a 3-digit zero-padded sequential `id`, so a spec bound offline fails its own skill's presentation gate (and the item is narrower than the allocator's own `^[0-9]{3,15}$`). `:358`'s Step 13 "create a new increment → follow step 8 with a new ID" has no `<peek>-wip` placeholder, while Step 8's rename is mandatory and sourced from one, with no branch for its absence. And the `fail` unreachable-mode is never named: the refusal table lists only `group renamed` / `group exhausted`, while the actual hard-fail message matches neither. All four are prose the build's edits made inconsistent rather than prose it wrote.
- **Suggestion:** reconcile the four sections against the shipped flow in one pass, and add the `fail`-mode row with retry guidance.
- **Relates to:** AC 1, AC 4, AC 6, AC 12
- **Partly filed:** `docs/issues/20260730-fix-jim-spec-checklist-contradicting-its-provisional-branch.md`

## Deviations & feedback

- **The fan-out was the difference between two verdicts.** The same regions, reviewed by the author without independent investigation, produced `minor-drift` and five findings; investigated, they produced `major-drift`, three critical defects and fifteen findings. Nothing about the code changed in between. The lesson is not that the first pass was careless — it caught the path-helper gap and the checklist contradiction — but that an author reviewing their own build reliably under-weights what they were confident about while writing it. Two of the three criticals live in code the author had just written and re-read twice.
- **Green tests said nothing about any critical finding.** All 903 pass, and every critical here is either an omission (Findings 1, 2), a boundary the tests share an assumption with (Finding 3), or a defect in code the build reused on purpose (Finding 5). Test-passing and contract-satisfying diverged completely on this range.
- **Two of three plan deviations were plan defects of the same kind:** an instruction naming the right change in the wrong place. Task 6 pointed at `rename-tracked`'s non-existent gate when it meant `move-spec-dir`'s — and Finding 12 shows the consequence of leaving that unnamed, since `move-spec-dir` is exactly what a partition needs and refuses. A plan-phase check that each named verb has the property its task assumes would have caught both.
- **The security review's carve-out held up under adversarial reading, and the accepted residual is where the damage concentrated.** The crafted-record vector `security.md` Finding 7 accepted as detected-not-prevented is the same vector that drives Findings 3 and 7 — but there it is *not* detected, because the padding gate landed on one rename primitive and not the other. An accepted residual is only as good as the detection that justifies accepting it; that detection needs its own fixture.
- **The living-intent sensor's absence was itself the highest-cost omission.** Finding 1 — a high-criticality invariant contradicted in two blueprints — is precisely what the sensor exists to surface, and it went unrecorded because the sensor never ran. The fold-back loop's value is not the report it writes but the contradiction it refuses to let pass silently.
