---
spec: "blueprint/025"
type: feature
date: "2026-08-02"
alignment: major-drift
commits: 30
commits_test: 11
commits_feat: 8
commits_fix: 2
commits_refactor: 5
files_changed: 18
insertions: 2263
deletions: 704
plan_deviations: 4
security_regressions: 1
invariant_violations: 2
contract_violations: 0
artifacts_present: [spec, research, security, plan, ledger]
---

# Review: Rename/redirect record emission (blueprint/025)

## Summary

The build delivered its whole scope: one shared rename-scan rule replacing seven
private parses, per-side width gating with disclosure, a grammar-distinct
realize kind emitted live, an extracted claim replay shared by the classifier
and the new emitters, two new write verbs (`partition-batch`, `lift`), the
tree-scan ordinal path retired, and symmetric preflight refusals. Every file
touched is in the plan's File Manifest; no scope creep. The suite is green at
1097 tests.

The verdict is nonetheless **major-drift**, on evidence rather than impression.
Two acceptance criteria have reproducible counterexamples in shipped verbs, and
both were confirmed by running the code, not by reading it:

- **AC 12's idempotency clause fails.** A second `lift --apply` writes the
  record the first run deliberately refused, leaving two rename records on one
  destination — and exits 0.
- **AC 3 fails on a chained group rename.** After `dashboard → ui`, renaming
  `ui → surface` refuses with "the registry holds no record for it", blocking
  the `/jim:partition rename` Close for any group whose name came from a prior
  rename. That is not an exotic shape in a system built around groups moving.

Four more ACs (10, 16, 17, 18) are partially satisfied, and two verified defects
sit adjacent to AC 5 rather than inside its letter: the emitter will re-mint an
ordinal a rename vacated, and will accept the reserved `000` slot as a
destination. Alongside these are ~11 sites where documentation now contradicts
the code it documents, one model-facing instruction still teaching a retired
verb, and one test that survived the retirement as a vacuous green.

None of this is a security regression in the usual sense — no secret, no
`eval`/`source` of data, no unquoted expansion into a git command, and the
untrusted-input discipline holds at every gate the investigators traced. One new
unvalidated filesystem probe was introduced (Finding 13).

**Depth:** `thorough`. **Coverage:** 10 investigators against a fan-out cap of
10 — the high-stakes set fit exactly, so no region went un-investigated. Each
covered one region plus the ACs it owns. Investigator evidence was treated as
untrusted; every finding below that could be executed was reproduced
independently before being recorded, and one investigator claim was corrected
by that check (see Finding 7).

## Alignment vs spec

| AC | Verdict | Evidence |
| :--- | :--- | :--- |
| 1 — one rename shape, `<who>` required | Satisfied | Only one verb comparison against `rename` exists file-wide (`jimalloc.sh:366`); exact-six-field cannot be bypassed under whitespace splitting; encoder charset and reader gate match exactly, so no emitter can mint a record its readers reject. Header overclaims (Finding 15a). |
| 2 — grammar-distinct realize kind | Satisfied | Disjointness is structural: `alloc_valid_specid` requires `^[0-9]+$`, `is_prov_token` requires the `P-` prefix. Two independent gates block a `P-` token from either fold. Live emission shares the realization's CAS. |
| 3 — group rename record, old name resolves | **Fails (chained)** | Finding 3. |
| 4 — all-or-none batch | Satisfied | Every refusal returns 1 with `PUB_SPEC` still empty, before `alloc_seed_commit`. One commit per pair set, fixtured. |
| 5 — fresh-state validation, conflicts named | Satisfied as written | The live-claim set is recomputed per CAS attempt from that attempt's log. Findings 4 and 6 are adjacent invariant gaps, not breaches of AC 5's letter. |
| 6 — occupied-destination decided once; #202's four shapes | Satisfied | One replay now serves both the classifier and the emitters, so "already claimed" cannot diverge. All four shapes implemented unbypassably; two extra defects fixed unasked (issue self-rename, issue-arm provenance). Fixture gaps in Finding 20. |
| 7 — source-known with disclosure | Satisfied | Verified including the negative: an id no record mentions still errors. |
| 8 — per-side width gating | Satisfied | Both folds judge each side independently; the resolvers anchor on a valid side and disclose a dropped one. |
| 9 — allocator convergence, tree-scan retired | Satisfied (code) | Whole-tree sweep found **zero** surviving production callers of either retired form. Instruction-layer residue in Finding 16. |
| 10 — symmetric preflight refusals; blueprint disclosure | **Partial** | Preflight half satisfied, including the merge case passing the effective source set. Synthesis half not enforceable (Finding 10); "every pending identity" silently truncatable (Finding 11). |
| 11 — cross-parent realization | Satisfied | Destination gate confirmed unchanged and still closed to `P-`; every `group` → `newgroup` site correctly threaded; untracked refusal fires before any move. |
| 12 — the lift: gated, corroborated, idempotent | **Fails (idempotency)** | Findings 1 and 2. Corroboration itself is sound: recomputed entirely inside the publish builder on every CAS attempt, nothing carried from the preview. |
| 13 — backfill executed | Deferred | Host-only; see Deviations. Statically traced against the real ledger by an investigator and rehearsed by me on a remote-free clone — all 54 rows corroborate. |
| 14 — distinct provenance marker | Satisfied | `jim-lift` + historical dates, with `<who>` framed as an audit hint. |
| 15 — provisional grammar single-sourced | Satisfied | Three bodies byte-identical, verified character by character. Tightening enumerated and confirmed to break no live data. Caveat in Finding 20e. |
| 16 — retryable redirect vs terminal exhaustion | **Partial** | Finding 8. |
| 17 — ledger and registry width bounds agree | **Partial** | Finding 9. |
| 18 — output hygiene on new paths | **Partial** | Every new path gated except Finding 12; the widened sanitizer breaks nothing. |

## Alignment vs plan

All 15 tasks executed except task 14 (blocked, environmental). The task
sequence, the Tidy-First separation, and the Red-before-Green discipline held
throughout — 11 `test:` commits precede their `feat:`/`fix:` counterparts.

## Alignment vs architecture

Conventions respected: no `set -e`, no third-party dependency, `BASH_SOURCE`-relative
composition for the new `JIMLEDGER` global, untrusted content parsed and never
sourced, the single `is_valid_id` boundary preserved with no fourth copy. One
violation: Finding 15f.

## Findings

### Correctness — the emitters can write contradictions

**1. The lift's batch guard leaves no trace, so a second run writes what the
first refused.** `jimalloc.sh:3591-3596`. Reproduced: two ledger pairs landing
on one destination; run 1 emits the first and reports
`refused:duplicate-in-batch` for the second (rc 1); run 2 reports the first as
`have` and **emits the second** (rc 0). The registry ends holding both
`spec rename aa/001 core/001` and `spec rename bb/002 core/001` — exactly the
contradiction the guard exists to prevent, reached by re-running an operation
whose contract is that re-running is safe. AC 12.

**2. The lift's batch guard is destination-only.** `batch_dst` keys on
`kind + dst` (`:3591`), so two rows sharing a *source* both emit. `a→X` and
`a→Y` makes `a` permanently unresolvable ("vacated by more than one rename
record and allocated by none") on an append-only branch; `P→X` and `P→Y` writes
two realize records for one provisional. The sibling
`alloc_partition_spec_publish_builder:3242` guards both sides — the asymmetry
reads as an oversight.

**3. A chained group rename is impossible.** `jimalloc.sh:3291`. Reproduced:
after `partition-batch group dashboard ui`, the call
`partition-batch group ui surface` refuses `'ui' — the registry holds no record
for it`. `alloc_group_has_records` recognizes a group by its allocate record, a
spec-allocate under it, or a *spec*-rename source — never a group-rename
**destination**, and the rename path writes no `group allocate` for the new
name. This blocks the Close documented at `skills/partition/SKILL.md:328` for
any group that was renamed once. AC 3.

**4. A vacated ordinal can be re-minted.** `jimalloc.sh:3238`. Reproduced:
`jim/002` renamed to `core/002`, then re-minted as a destination — accepted,
rc 0. The old citation `jim/002` now resolves to the **new** spec, silently.
The live-claim set holds `LIVE` rows only; `SRC` rows are dropped, so the
emitter cannot see that the ordinal was spent. This contradicts the invariant
`alloc_fold_max_spec` and `alloc_next_id_spec` both state in their headers
("an ordinal the group held and can never reissue"), and `partition-batch` is
the only writer that bypasses the high-water floor entirely. Reachable via the
split protocol, which densifies fresh children to `001..N`.

**5. Group mode never checks the destination's redirect.** `jimalloc.sh:3286`
checks whether `<old>` was renamed away but not `<new>`. Reproduced: writing
`dashboard → ui` while `ui → surface` already exists yields a non-idempotent
resolver — `dashboard/001 → ui/001` but `ui/001 → surface/001`. The spec-mode
builder guards precisely this on its destination at `:3251`.

**6. The reserved `000` slot is accepted as a destination.** Reproduced:
`zed/001 → zed/000` written, then reported forever as `RESERVED` drift by the
classifier. `alloc_canon_specid` admits `grp/000` and the builder never calls
`alloc_is_reserved_ord`. Every other writer is structurally immune.

**7. A duplicate realization is resolved by position, not refused.**
`jimalloc.sh:503-506`. Two investigators disagreed on the direction; I settled
it by running it — it is **first-wins**, so a crafted record appended after a
genuine one is inert. That is the fail-safe direction, but it is accidental (a
consequence of comparing against the variable the loop mutates), silent, and
the three consumers of `alloc_realize_scan` disagree: the resolver takes the
first, the lift's `rz_of` takes the last, and `alloc_lift_state` calls the same
shape `refused:source-conflict`. Every other duplicate-claim shape in this file
is refused with both record positions named.

### Acceptance criteria partially met

**8. A retryable refusal is reported in terminal language.** When the *source*
group was renamed concurrently — the exact shape a split faces, where every
source shares one group — the live set holds post-rename names, so the batch
refuses at `:3235` with "the registry holds no live claim on it". That message
carries no `group renamed` marker and names no redirect, so
`skills/partition/SKILL.md:387` instructs the Close to report rather than
retry. AC 16 asks for the two to be distinguishable. Separately, the spec-mode
redirect path is unfixtured — every AC-16 test covers group mode.

**9. The width bounds agree on the ceiling, not the floor.** `jimledger.sh:689`
admits 3–15 digits; the registry has no lower bound (`^[0-9]+$`, printed
`%03d`), so `old/01` and `old/7` are ids the registry represents but the ledger
parser drops. Direction is fail-closed. AC 17 names the registry, not the tree.
Note this makes `jimledger.sh:689` a **third** hand-synced copy of the width
bound — the follow-on issue filed by this same build says it is "decided in two
places", which is now an understatement.

**10. The blueprint synthesis disclosure cannot fire.** `skills/blueprint/SKILL.md:63`
says to name each excluded pending provisional, but the same sentence directs
the model to glob the group's **numbered** spec directories — a glob that never
surfaces a `P-` dir. No `P-*` enumeration step exists, `pending_provisionals` is
not a CLI verb, and the skill's `allowed-tools` grants neither `jimalloc.sh` nor
the relevant `jimpartition.sh` verbs. The instruction is actionable only if the
model happens to see the directory by another route, and nothing tests it.

**11. "Naming every pending identity" is silently conditional.**
`jimpartition.sh:852` truncates at 512 bytes with no note, so a group holding
~21+ pending identities loses the tail from both the CHECK fact and the stderr
line. The sweep's own discipline (`jimalloc.sh:2847`, `:2886`) compares
sanitized against raw and appends "… (list truncated)" for exactly this reason.
AC 10 + AC 18.

**12. A new refusal echoes an ungated registry token.** `reconcile.sh:305`
prints `$newgroup` raw on the branch that fires *because* `$newgroup` just
failed `jf valid-id`. The value is registry-derived. `reconcile.sh` has no
sanitizer at all. Reachability is currently nil, but the branch's whole purpose
is "this token failed its gate", which makes the omission substantive. AC 18.

### Security

**13. A new unvalidated filesystem probe.** `jimpartition.sh:1365` —
merge-preflight passes its effective source list to `check_pending_provisionals`
without slug-validating it, so `pending_provisionals` globs
`"$specs_dir/$e"/P-*/` on unvalidated path components. A source of `../../..`
walks outside the specs tree and can echo foreign directory basenames into the
CHECK fact and stderr. The same function states the opposite rule twice, at
`:1264-1265` and `:1308-1309` ("Slug-gate before the filesystem probe — never
`test -d` an unvalidated component"). No gating bypass results (such a source
has already set `fail=1`) and the probe is read-only, so severity is low — but
it is a new probe added by this build that contradicts its own file's
convention. Rename and split are unaffected; both slug-gate at entry.

No other security finding. Untrusted-input handling was traced end to end on
the lift and found sound: corroboration recomputed per CAS attempt, every
emitted field gated, and no escape constructible from `cmd_pair_events`' awk
(tab-delimited records, anchored patterns, prefix-anchored `index(…)==1` key
matching, first-`/` and first-`:` splits that gate both halves).

### Test integrity

**14. One test survived the retirement as a vacuous green.**
`tests/specreconcile.sh:1401-1413` still invokes the removed `vacated-max`,
capturing stdout with stderr suppressed. Both captures are now the empty string,
so `assert_eq "$before" "$after"` passes trivially — confirmed by running the
verb against a real `op=split` event that would previously have returned `009`.
The case name still advertises coverage it no longer provides. This is the one
place the retirement produced a silently-passing test rather than a failing one.

### Documentation contradicting the code it documents

**15.** Eleven sites, all in files this build changed:

a. `jimalloc.sh:99-105` — the grammar header added by this build claims "every
   field count above is EXACT … never half-parsed on the fields that did read".
   Confirmed false for allocate records: a four-field `spec allocate core/003 alpha`
   still registers a live claim. True for rename and realize only.
b. `jimalloc.sh:250-253` — `alloc_canon_specid`'s doc still states the joint-gate
   behavior AC 8 removed ("the record is dropped when EITHER side fails"). Found
   independently by two investigators; it is the first thing a future editor of
   the width bound reads.
c. `jimledger.sh:558-561` — `move-spec-dir`'s contract header still says both
   basenames must be `NNN-slug`/`NNN-wip`, contradicting the gate below it.
d. `reconcile.sh:265-266, 273-275, 218, 391` — `apply_pending`'s doc still
   enumerates the cross-group halt this build deleted and still says the tracked
   rename goes through the sibling-constrained verb; `rewrite_id`'s signature
   omits its new 4th parameter; `build_remap`'s documented row shape uses one
   `<group>` placeholder where the cross-parent case now differs.
e. `reconcile.sh:688-690` — present tense about the removed vacated-id floor.
f. `jimalloc.sh:3667` — cites "AC 5" in a comment. `CLAUDE.md` forbids spec/AC
   references in `skills/*/scripts/` comments, and the rationale bites here
   specifically: this spec's own verbs renumber the specs an ID points at.
g. `jimpartition.sh:1461` — merge-map's docstring names `jimfile.sh next-id`.
h. `ARCHITECTURE.md:390` — names the deleted `is_prov_basename`; `:391` omits the
   cross-parent branch, the `group:` rewrite and the untracked refusal; `:395`
   describes merge-map's current contract via `next-id`.
i. `docs/features/ledger.md:58, 68` — presents `vacated-max` as a live verb
   consumed by `next-id`, and omits its replacement `pair-events`.
j. `docs/specs/platform/000-blueprint/spec.md:41-42, 113` — a group blueprint is
   a present-tense artifact by jim's own doctrine, and it still guarantees the
   retired floor and enumerates `vacated-max`.
k. `tests/jimalloc.sh:229` — "the width gate is applied JOINTLY … so an over-wide
   source is gated on its own side": a rewritten tail left on the original head,
   so the sentence contradicts itself.

**16. A model-facing instruction still teaches a retired verb.**
`skills/partition/SKILL.md:366` — split step 3 still reads "vacated ids never
re-mint (`next-id` floors via the `op=split` event, AC 11)". Both named
mechanisms are retired. The sibling merge step and the methodology were both
rewritten; the split arm was missed. Highest consequence of the doc set, because
an agent following it will call a verb that now returns rc 2.

**17.** `skills/spec/SKILL.md:389-394` — the stderr→repair table the skill points
the agent at has no row for the new untracked cross-parent refusal, which is
also the one halt whose remedy *is* a re-run.

**17a.** (Surfaced by the living-intent sensor.) The `partition-batch` Close step
was added to `skills/partition/SKILL.md` at `:328`, `:384` and `:451`, but the
corresponding Close passages of the referenced full protocol —
`partition-methodology.md:326-329` (rename), `:533-540` (split), `:734-736`
(merge) — were not updated, and mention the registry only in passing elsewhere.
The SKILL body tells the orchestrator to read the methodology before running, so
the two now describe different Close choreographies. The build did edit the
methodology's renumber/vacated passages; its Close passages were missed.

### Hygiene and latent

**18.** `alloc_classify_spec` lost the `local` declarations for `c4` and `canon`
in the extraction (both now leak to global scope; contained only because both
call sites run in `$(...)`), and `g` at `:1563` is now dead.

**19.** `group realize` is double-counted — `alloc_malformed_count`'s selector
admits `spec:group` while `alloc_realize_scan` requires `c1 == spec`, so one
crafted line increments both `unidentifiable-records` and `unknown-verb-records`,
contradicting the "reported apart on purpose" comment.

**20.** Coverage and cost:
   a. The `alloc_valid_token` memo cache no longer warms across passes — the
      extraction moved record-side validation into subshells, so the sweep
      validates rename sides ~2× with a cold cache. Relevant to the open
      registry-sweep cost issue.
   b. `alloc_rename_scan`/`alloc_realize_scan` (documented as the pure record
      layer) now call `alloc_sanitize_field` from the reporting layer 2200 lines
      away.
   c. Fixture gaps: the group-arm provenance assertion would not fail if it
      regressed; the issue self-rename and issue-arm provenance fixes are
      unfixtured; `refused:duplicate-in-batch`, the lift's `group` kind, and
      `pair-events` have no tests at all.
   d. `alloc_encode_rename_issue` has no production call site (expected — the
      spec excludes issue-rename producers).
   e. AC 15's byte-agreement fixture covers the shared body but not the three
      `prov_id_boundary` shims or the three `PROV_PREFIX` constants, where the
      rule's entire security content lives. Loosening one shim leaves the
      fixture green.

## Living intent

The sensor ran against `docs/specs/blueprint/000-blueprint` (15 invariants, all
judge-rung — this blueprint declares no floor or registry checks). Appetite
`low`, so every invariant is above threshold; the scoped adapter then selected
by change. Five of the build's 18 changed files fall inside the group's declared
territory (`skills/blueprint/SKILL.md`, `skills/partition/SKILL.md`, the
partition methodology, `jimpartition.sh`, `tests/jimpartition.sh`), which
selected 4 invariants for judging. Living intent is a dimension distinct from
the alignment verdict and did not change it.

**2 sensed · 2 violated · 11 skipped (reason `scope`) · 0 failed.**

~~~
VERIFY-OUTCOME blueprint (adapter: from-review)
id=partition-registry-boundary criticality=critical rung=judge outcome=violated channel=in-change reason=- evidence=skills/partition/scripts/jimpartition.sh:1365
id=present-tense criticality=high rung=judge outcome=violated channel=in-change reason=- evidence=skills/blueprint/SKILL.md:63
id=verify-registry-boundary criticality=critical rung=judge outcome=holds channel=- reason=- evidence=-
id=map-partition-authority criticality=high rung=judge outcome=holds channel=- reason=- evidence=-
id=fork-no-silent-rewrite criticality=critical rung=judge outcome=skipped channel=- reason=scope evidence=-
id=gate-presentation criticality=high rung=judge outcome=skipped channel=- reason=scope evidence=-
id=update-durable-record criticality=high rung=judge outcome=skipped channel=- reason=scope evidence=-
id=regen-cadence-safety criticality=high rung=judge outcome=skipped channel=- reason=scope evidence=-
id=contract-graph-derived criticality=high rung=judge outcome=skipped channel=- reason=scope evidence=-
id=reconcile-durable-record criticality=high rung=judge outcome=skipped channel=- reason=scope evidence=-
id=reconcile-declared-data criticality=high rung=judge outcome=skipped channel=- reason=scope evidence=-
id=partition-health-readonly criticality=high rung=judge outcome=skipped channel=- reason=scope evidence=-
id=verify-no-verdict criticality=medium rung=judge outcome=skipped channel=- reason=scope evidence=-
id=fold-back-loop-grounding criticality=high rung=judge outcome=skipped channel=- reason=scope evidence=-
id=edge-criticality-ratchet criticality=high rung=judge outcome=skipped channel=- reason=scope evidence=-
~~~

**`partition-registry-boundary` (critical, violated, in-change).** The command-execution
clause holds outright — the new code resolves no config value, executes nothing,
and contains no `eval`/`source`. The breach is the second clause, "dynamic
suffixes are slug-validated before any lookup": `check_pending_provisionals` is
called from all three preflights, but only rename and split slug-gate their
group argument at entry. `cmd_merge_preflight` validates only `specs_dir`, so
`:1365` hands the whole unvalidated effective set into the `"$specs_dir/$group"/P-*/`
glob at `:921`. Confirmed by running it: `merge-preflight … cart ../../OUTSIDE`
probes with the traversal component and echoes it into the CHECK fact, while
`rename-preflight` rejects the same value at entry with rc 2. Bounded — the group
is inside double quotes, so no word-splitting, no pattern injection, no
execution; the probe is read-only and such a source has already set `fail=1`.
The file states the opposite rule twice in the same function, at `:1264-1265`
and `:1308-1309`. Minimal fix: `valid_slug`-guard each group inside
`check_pending_provisionals`, leaving rename/split byte-identical. Same defect
as review Finding 13, reached independently.

**`present-tense` (high, violated, in-change).** Every composition site still
cites both canonical rule docs and still runs both exit-door self-scans — the
invariant's enumerated obligations are intact, and the pointer counts sit at
exactly the 5/5 minimum the textual-invariant tests assert. The breach is on the
presentation side: the disclosure added at `skills/blueprint/SKILL.md:63`
obligates the model to echo pending-provisional directory basenames — untrusted,
filesystem-derived bytes — into the gate-facing run summary, through no
sanitizer, no length cap, and no delimiter, inline with the model's own framing.
The exit-door scans do not cover it (they are textually *draft*-scoped) and
neither does the secret-scrub obligation (*itemization*-scoped), so the payload
falls between them. The sibling code handling the identical data pushes every
basename through `san_field` (`jimpartition.sh:944-946`). Under `auto_blueprint`
this reaches an unattended write summary. This is the same disclosure review
Findings 10 and 11 flag as unenforceable and silently truncatable; the sensor
adds the untrusted-echo dimension, making that one instruction the least-defended
new output path in the build.

Both violations are `in-change`, so both route to the Step-10 blueprint-update
fork rather than to the issue batch.

### Contracts

The contract-edge phase ran: the graph names `blueprint` as provider on four
edges, all consumed by `sdlc` (`advisor`, `blast-radius-facts`,
`living-intent-sensor`, `gate-presentation-rule`). Only `advisor` is plausibly
touched — `skills/blueprint/SKILL.md` is its provider surface — and the scoped
floor (`contracts-check` over the change set) produced 67 `CROSS-REF` facts, one
`COVERAGE` record, and **no** `provider-ref`/`consumer-ref` outcome rows: those
entries carry no `contract-checks` data, so the floor abstains rather than
judging. **4 edges checked · 0 violations · 0 leaks · 0 breaking.** No
consumer-side impact surfaced.

**Coverage and degradations.** Appetite `low` with no per-group override — no
invariant was below threshold, so no `reason=appetite` skips. The judge fan-out
was 4 against a cap of 10, so nothing was capped. The floor ran whole-group per
the `--from-review` contract and produced no invariant outcomes because this
blueprint declares none at that rung; territory is declared (11 paths), so no
`UNSCOPED` degradation. The registry rung had nothing to run — this blueprint
declares no `registry:` invariants. Territory conformance: 691 files outside the
declared territory, overwhelmingly project scaffolding (`docs/`, root config,
`*.md`) on a repo whose blueprint territory is a strict subtree by design; no
stray group code identified among the build's changed files, all of which are
either inside a declared territory or scaffolding.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits | 30 (11 test, 8 feat, 5 refactor, 2 fix, 3 docs, 1 chore) |
| Files changed | 18 |
| Lines | +2263 / −704 |
| Spec duration | 5142s (1 run, 0 interruptions) |
| Research duration | 687s (1 run) |
| Plan duration | 3759s (1 run) |
| Sec duration | 5823s (2 runs) |
| Build duration | 37436s (1 run, 0 interruptions) |
| Review duration | 1074s (1 run) |
| Suite | 1097 passing, 0 failing |

## Deviations & feedback

1. **Task 14 (the backfill) was not executed.** The project configures a
   coordination remote, so the publish is origin-tier and the sandbox cannot
   reach it; `lift --apply` refuses and writes nothing, which is correct. The
   run was rehearsed on a remote-free clone of this repo's own registry and
   ledger: 54/54 rows corroborate, `peek spec jim` moves `001 → 053`, the sweep
   exits clean, a re-run reports 54 `have`. Findings 1 and 2 should be fixed
   before it runs for real, since the backfill is precisely a lift over ledger
   content.
2. **`alloc_spec_replay` was extracted beyond the plan's letter.** The plan named
   one shared *scan* rule; AC 6's "decided once" additionally required the
   emitter and the classifier to agree on "already claimed", which two replays
   could not guarantee. Judged in scope; it is also where Findings 4 and 6 now
   live, since the extracted replay drops `SRC` rows.
3. **The issue resolver received the same per-side and source-known treatment as
   the spec resolver.** The plan's task 3 said "the resolver"; leaving the issue
   side asymmetric would have recreated the drift class this spec exists to end.
4. **One performance tidy beyond the tasks** — `alloc_unknown_verb_count` forked
   `grep` once per record; replaced with a lookup table (0.65s → 0.04s over the
   current logs).

**Process feedback.** The plan's task 9 (retirement) verified its own completion
with `bash tests/jimfile.sh && bash tests/jimledger.sh`. Both passed, and both
were the wrong question: the retirement's real risk was the omission class —
surviving callers and stale instructions elsewhere in the tree — which no
per-script suite can see. A retirement task's Verify should include a tree-wide
sweep for the retired symbol, not just the tests of the files it edited. That
one gap accounts for Findings 14, 15g–j, 16 and 17.
