# Post-build review — B′, the id-coordination hardening cluster

**Written:** 2026-08-05 · **Branch:** `feat/id-coordination` · **Range reviewed:**
`175047c..HEAD` (`68c2bdb`), 34 commits, +1654/−147 over 18 files · tree clean ·
suite **1137/1137** (re-run, exit 0)

**Verdict: minor-drift.**

Every one of the sixteen items was built, and against each issue's *Proposed
action* read strictly, eleven are fully satisfied. The code is correct wherever
it was measured, and the mechanisms are proven — not inspected. What this review
found is a build that is **systematically under-reaching**: it does precisely
what it was asked and stops at the boundary of the ask. Nine of the sixteen
contracts were satisfied at the site the issue named and left unapplied at a
sibling site the issue did not name.

**The verdict understates the severity of the findings, deliberately.** Alignment
measures build-against-contract, and by that measure the build is sound. The most
serious thing this review found is a *pre-existing* registry-corruption path in a
shipped verb — surfaced only because B′'s own new invariant makes it legible.
That is the review working as intended, not the build failing.

---

## 1. Why this is a note and not a `review.md`

`/jim:review` was run as a **method**, not as its artifact choreography. Pointing
the skill at `docs/specs/blueprint/025-…` was refused on two independent grounds,
the second of which the prior handoff had not found:

1. **Provenance.** The skill overwrites `review.md` on a re-run. That file is the
   `origin:` for **13** tracked issues — the #205–#219 cluster's primary source.
2. **Wrong range.** `025`'s ledger records `base_sha=8f1b6dd … head_sha=ad02fb4`,
   and `ad02fb4` is an **ancestor** of `175047c`. `jimledger.sh diff` would have
   handed the skill B's diff, not B′'s. Pointing it there would have reviewed the
   wrong code *and* destroyed the provenance.

So: the skill's method — triage the diff spine, fan investigators over the
high-stakes set, judge each ground truth on evidence — with the sixteen issues'
*Proposed action* sections as the acceptance criteria, filed here.

## 2. Coverage

`review_depth=thorough`, `review_model=inherit`, `review_fanout_cap=10`. The cap
was raised to **17 investigators** under explicit authorization; sixteen contracts
plus cross-cutting classes do not fit in ten. **There is no un-investigated
remainder.** Thirteen contract investigators plus four sweeps: security
regression, convention compliance, adversarial omission, and independent
verification of the prior session's closing claims.

Every investigator was told to execute rather than read, and to treat the
handoff's claims as claims. That paid: the two most serious findings were
reproduced end-to-end by two agents independently, and six fixture claims were
overturned by mutation testing the original session did not run.

## 3. Per-contract disposition

Judged against each issue's *Proposed action*, not its Description.

| Item | Contract | Note |
| :--- | :--- | :--- |
| **#205** slug gate | **satisfied** | 20-payload attack matrix; 54-comparison byte-identity proof for rename/split |
| **#206** AC-16/18 residuals | **satisfied** | all three bullets shipped; both remedies followed through to `rc=0` |
| **#207** lift batch guard | **satisfied** (behavior) · **partial** (fixture) | contract's "(or source)" cross-run closure survives deletion, 1137 green |
| **#208** disclosure | **partial** | bullet 2's sanitizing boundary absent; bullet 4's "consumers" is one consumer |
| **#209** emitter refusals | **satisfied** | all three contradictions refused, not over-broad, all 5 gates discriminating |
| **#209 fork** peek-fed starts | **satisfied** (mechanism) | 8 mutations, 7 discriminating; but see Finding 2 |
| **#210** fixture gaps | **satisfied** | **13 of 13** mutations red — the strongest fixture result in the cluster |
| **#211** doc retirement | **disposition disproven** | `blueprints.md` is not the only survivor; three more |
| **#212** ordinal width | **satisfied** | fixture scope met and exceeded; `>999` partition block was never diagnosed |
| **#213** group coverage | **satisfied** | reproduced on a true pre-fix checkout, then under single-hunk isolation |
| **#214** realize fold | **satisfied** | one decision site proven exhaustively; `rz_of` gone; fold mutation-proven |
| **#215** grammar fixture | **partial** | shims covered verbatim; the three `PROV_PREFIX` values are not |
| **#216** sanitizer layering | **partial** | the move shipped; the header it was filed about did not change |
| **#217** classifier locals | **satisfied** | leak check discriminates on each name independently |
| **#218** memo warming | **satisfied** | every claimed number reproduces exactly; but see Findings 1 and 6 |
| **#219** verb-aware counting | **satisfied** | exhaustive 7×3 known + 6 unknown matrix; exactly one row moved |

## 4. Findings

Ranked by severity. Every one was reproduced, not inferred.

### F1 — `catch-up --apply` silently reissues a vacated ordinal *(critical, pre-existing, untracked)*

`alloc_classify_spec:1714` emits `RENAME-SRC spec <id> "vacated by a rename"`.
`alloc_catchup_compute:3033-3035` harvests **only** `MISSING` into `want_spec`,
and `CU_BLOCKED:3039` greps `^(MISMATCH|DUP-ORD|DUP-ID|RESERVED|UNREADABLE)` —
`RENAME-SRC` is in neither. The classifier computes the fact, prints it, and
catch-up discards it.

Reproduced independently by two investigators, via a spec rename and via a group
rename:

```
$ jimalloc partition-batch group jim core   →  resolve spec jim/001 → core/001
$ jimalloc sweep                            →  rc 3, rename-source-ids 1
$ jimalloc catch-up --apply                 →  spec allocate jim/001 … jim-catchup
$ jimalloc resolve spec jim/001             →  jim/001     ← referent changed
$ jimalloc sweep                            →  rc 0, rename-source-ids 0   ← clean
```

Every frozen citation to the vacated id now dereferences to a different spec, and
the fresh live claim masks the spent marker so the registry **reports clean
afterwards**. Highly reachable — the rename record and the directory move are
separate steps, so an aborted reconcile, a reverted move, or a branch merge
restoring the old directory all produce the precondition.

This is a **living-intent divergence**, not merely a code gap.
`docs/specs/platform/000-blueprint/spec.md:91-92` asserts a vacated ordinal is
"permanently gapped **whatever shape the log takes**". That credits the fold, and
the fold does have the property — but `catch-up` writes around the fold entirely,
so the invariant states a system property the system does not have.

It is also verbatim the harm B′'s own new comment at `jimalloc.sh:3431-3433`
describes. The build installed that gate on the spec emitter and the group
emitter — and the handoff credits it for catching "the same invariant through the
sibling door, which the issue did not name." It found the principle and applied
it to one sibling of three. `catch-up` and `lift` both remain open.

### F2 — B′ shipped two items that contradict each other above ordinal 999 *(high, introduced)*

`#212` widened the canonical bound to `{3,15}` and closed the `>999` dead end in
the registry and ledger primitives. `#209 fork` — same range, `d872159` — wired
`skills/partition/SKILL.md:365-369`: a fresh child's start is "the ordinal part of
`jimalloc.sh peek spec <child>` stdout, **copied verbatim**", explicitly for the
case where "a previously retired name resumes above its high-water."

But `jimpartition.sh:1440` still refuses anything that is not three digits:
`start must be a 3-digit id 001-999`. A group past 999 peeks to `cart/1000`, and
following the skill's own instruction verbatim is refused. Neither issue could
have caught this alone — each is internally consistent.

Worse, `merge-map:1566` does not refuse a 4-digit spec at all: it **silently omits
it from the map at rc 0**, weaker than the loud refusal `move-spec-dir` used to
give. Nothing in `tests/jimpartition.sh` pins any 4-digit case.

### F3 — the memo warmer is a fork-amplification DoS *(medium, introduced)*

`alloc_warm_token_memo:190-208` applies the full *cross-kind* grammar case-list to
*both* logs, but `alloc_log_file:111-116` pins `spec|group → specs.log` and
`issue → issues.log`. A record whose kind does not belong to the log it sits in is
inert to every consumer — and the warmer still forks `bash jimfile.sh valid-id`
once per distinct token in it. The coordination branch is push-writable and the
file's own header at `:79-82` declares it untrusted.

Measured differentially against a `git archive 175047c` worktree, counting forks:

| input | pre (`175047c`) | HEAD |
| :--- | :--- | :--- |
| 600 legitimate spec rows | 1m56s · 2417 forks | 0m41s · 1217 forks — *the intended 2× win* |
| 600 `issue allocate` rows in `specs.log` | 2.3s · 17 forks | **17.2s · 617 forks** — 36× amplification |
| 2000 crafted rows | ~0.2s | **61s** |

Linear and unbounded, ~30 ms of serialized subprocess per crafted record, in the
sweep's own shell. The optimization made `sweep` 1.5× faster on honest input and
arbitrarily slower on hostile input. The docstring reasons only about the
*under*-coverage direction — "a missed field only costs speed, never correctness"
— and it is **over**-coverage that is exploitable. Fix: scope the case list to the
log being warmed.

### F4 — the fix added a sanitizer and applied it to one of five sibling sites *(medium)*

`display_field` (`reconcile.sh:117`) carries the docstring *"used on values whose
whole reason for being printed is that they just failed a gate."* It is called at
exactly one of the five sites matching that description in its own file.

| site | token | source | sanitized | reachable |
| :--- | :--- | :--- | :---: | :--- |
| `:317` | `$newgroup` | registry | yes | — |
| `:346` | `$held` | **directory basename** | no | **yes** |
| `:155` | `$group` | directory name | no | yes |
| `:162` | `$base` | directory name | no | yes |
| `:172` | `$id` | **spec.md frontmatter** | no | yes |
| `:327` | `$ord` | registry | no | no — defence-in-depth only |
| `jimledger.sh:649` | `$held` | directory basename | no | **yes** |

`spec_ordinal_holder` (`jimfile.sh:399-422`) constrains only the leading
`[0-9]{1,15}` token, so `001-<ESC>[1;31mEVIL` is a valid holder name returned
verbatim. `$id` at `:172` is controlled by anyone who can land a file in the repo.
Live terminal-escape bytes on stderr were demonstrated with `od -c`.

`:327` is listed for completeness and is **not** a live escape — the security
sweep could reach it through no real path, since every producer emits either
`printf '%s/%03d'` or `alloc_canon_specid` output.

### F5 — five of the lift's nine guards survive deletion with 1137 tests green *(medium)*

Mutation audit over the full suite:

| deleted guard | failing tests |
| :--- | ---: |
| `rn_dst[spec]` — cross-run destination closure | 1 |
| in-batch guard / `batch_src` / `batch_dst` | 4 / 2 / 1 |
| **`rn_src[spec]` — cross-run *source* closure** | **0 of 1137** |
| **`rz_dst` — realize destination closure, sub-claim (d) entire** | **0 of 1137** |
| **`rn_src[group]` · `rn_dst[group]`** | **0** |
| **first-recordable-wins ordering** | **0 of 18 lift cases** |

`refused:destination-conflict` is emitted from three sites and asserted **nowhere**
in the suite. The contract said "a destination **(or source)**"; the destination
half is pinned cross-run and the source half is not. The last row is sharpest:
invert the rule and the build records the *wrong* row of a duplicate pair, and
every lift fixture still passes.

### F6 — `catch-up` and `lift` never got the memo warm *(medium)*

| verb | `valid-id` forks | repeats |
| :--- | ---: | ---: |
| `sweep` (HEAD) | 291 | 0 |
| `catch-up` preview | 815 | 524 |
| `lift` preview | 564 | 492 (87% waste) |

`catch-up` re-runs the same classifiers over the same logs and pays the sweep's
entire pre-fix cost — **it is now slower than the sweep it exists to fix.** Third
appearance of `catch-up` as the neglected sibling.

The warmer's fixture pins **two of six** case arms: dropping the `'spec rename'`
arm passes the fixture while costing 105 of the 535 repeats, the single largest
saving. And `assert_nonempty "the boundary was consulted at all"` at
`tests/jimalloc.sh:2858` is **vacuous** — satisfied by one unrelated `date` fork,
so it never asserts a `valid-id` crossing happened.

### F7 — the tree-wide width guard has a live blind spot *(medium)*

`tests/jimfile.sh:1557` excludes by **basename**:
`grep -vE '(jimfile|jimledger|reconcile)\.sh$'`. There are two `reconcile.sh`
under `skills/` — `skills/spec/scripts/` (intended) and **`skills/issue/scripts/`
(silently exempted)**. Its own comment claims it catches "the one divergence none
of the per-file counts above would see."

15 mutations: M9 fires; **M10–M15 are blind** — a width literal in
`skills/issue/scripts/reconcile.sh`, any future file with one of the three
basenames, exactly-N literals, awk `length()` comparisons, and `${#x}` forms.

Consequently the restored invariant at
`docs/specs/platform/000-blueprint/spec.md:171` **overstates the code**: it claims
the fixture "fails when a new width literal appears in **any script**". The fold
understated the code; the restoration overshoots it. Same class, opposite sign.

### F8 — the provisional-grammar fixture pins the half that was mutation-tested *(medium)*

```bash
p="$(grep -h 'PROV_PREFIX="' <3 files> | sed 's/^readonly //' | sort -u)"
assert_eq "one prefix value across the three copies" 'PROV_PREFIX="P-"' "$p"
```

`sort -u` asserts *"the distinct values I managed to find agree"*, not *"there are
three, and each is `P-`"*. Delete a copy, or re-spell it `PROV_PREFIX='Q-'` — the
quote-literal grep does not match it, the survivor still reduces to
`PROV_PREFIX="P-"`, and the case passes with the constant genuinely drifted.

The handoff's claim — "mutation-tested: loosening a shim fails the case" — is
**true**. The shims are verbatim-pinned with per-site rationale stated in-file, and
A1–A3 all go red. The *constants* half was never mutation-tested, and that is the
half that is blind. Issue #215's own closing line — *"a fixture written for a sync
contract that has never been observed failing is a claim, not a measurement"* —
lands on its own fixture.

### F9 — `#211`'s stated disposition is false *(medium)*

`docs/features/blueprints.md` is **not** the only survivor.

- **`ARCHITECTURE.md:395`** — named by the issue and **claimed fixed**. The
  remediation commit `fd423e9` edited that line (appending a retirement marker)
  and left the stale `merge-map … taken verbatim from next-id` clause on it.
  `next-id spec platform` → rc 2, "answers for issues only".
- **`README.md:62`** — "Two registry-integrity verbs", a 2-row table with no
  `lift` row. Missed sibling of site 15, which *was* fixed at `:199-215`. The
  fixing commit also renamed the heading and left `:62`'s in-page anchor **dead**.
- **`ARCHITECTURE.md:393`** — present-tense `vacated-max`, the only unmarked one.

Beyond the issue's list: **`WORKFLOW.md` contains zero occurrences of `lift`.**
The issue cleared it with "carries no occurrence of any retired symbol" — a check
structurally incapable of noticing a *missing new* verb. `ARCHITECTURE.md` was not
regenerated in the range (`Last updated: 2026-08-03`), so `:282` and `:395` still
document a `renumber-map` invocation that now fails at arity.

### F10 — smaller, confirmed

- **`alloc_group_has_records:2702` is missing `local rdst rdok`.** `a21f55d`
  widened the read to five fields and did not extend the declaration — the sole
  outlier among ten sites in the file reading that tuple. Latent only because all
  three production call sites pipe into a subshell; the *tests* already call it in
  the leaky here-string form. Same class as #217, in the same change.
- **The same function's header is now wrong.** `:2696-2700` still describes two
  coverage arms; the body has four. `a21f55d` updated the body comment and left
  the header contract.
- **Issue-side ordinal mint has no width recheck.** Past the ceiling, every
  subsequent issue allocation mints the *same* ordinal forever, because
  `alloc_fold_max_issue` filters out the 16-digit record it just wrote. Reachable
  through the supported seed bootstrap from ordinary user-edited frontmatter — not
  a crafted record, as previously recorded.
- **Provisional acceptor asymmetry is reachable.** Via `mv-spec-id` and
  `path spec`, both of which `skills/spec/SKILL.md:224,:235` instruct the agent to
  call; the resulting directory is unrealizable on *all three* mover branches.
- **`#208`'s cut discloses *that* it cut, never *how many*** — and mis-reports a
  cut that did not happen, because `shown="$(san_field "$pend" | cut -c1-256)"` is
  compared against raw `"$pend"`. The comment cites "the sweep's truncation
  discipline"; the sweep it names emits `%d` beside the list precisely so a count
  and a shorter list cannot silently disagree.
- **The leak check is name-pinned, not a file invariant.** It asserts
  `declare -p c4 canon` in one function; removing `tag ra rb rc` from the same
  function leaves it green. It could not have caught the `alloc_live_claim_set`
  two-array trap, nor the `alloc_group_has_records` miss above. A file-wide check
  would need an allowlist for `rn` / `live` / `spent`, which are deliberate
  out-params.
- **`group allocate` lands in *zero* counters** (pre-existing, out of #219's
  scope). A degraded `group allocate` record is invisible to the sweep's
  reconciliation — `unid=0 unk=0`, rc 0. `spec allocate` and `issue allocate`
  short-forms surface as `UNREADABLE` drift; only the group arm is silent. Same
  "the numbers do not reconcile against a record count" class #219 fixed, on a
  different verb.
- **The lift never reads `spent`.** `alloc_lift_states:3673` declares it (it must —
  `alloc_live_claim_set` fills it) and `alloc_lift_state` never consults it. Both
  partition emitters do, at `:3356` and `:3434`. Separately, the **spec** arm omits
  the `rn_src[spec\t$dst]` check — "a destination that itself renamed away" — that
  the **group** arm has at `:3648`, and whose rule the group arm's own comment
  states. Safe today only via the `live[$dst]` gate: the identical
  "safe by the `destination-not-established` side effect" pattern that #209
  identified and fixed one line below.

### F11 — `#216` left standing the exact header its issue was filed about *(medium)*

The issue's *Proposed action* is two clauses joined by "then": move the sanitizer,
**"then make the section header state what is true. A header that describes a
purity the code does not have is worse than no header, because it is what the next
editor reasons from."**

Clause one shipped, and shipped well — `alloc_sanitize_field:158` is a genuine
record-layer primitive calling only `printf`/`tr`/`cut`, all 18 call sites strictly
downward, upward dependencies in the section reduced from three to two, and
behavior byte-identical across 16 hostile inputs. Clause two was never done.
`jimalloc.sh:76` still reads:

```
# ─── Section: Record layer (pure — operates on a log, no git) ────
```

`alloc_read_log:123` forks git — `git cat-file -p` at `:135`, demonstrated with a
PATH shim — and the section's own comment at `:122` says "the coordination branch
via git plumbing", contradicting its header 46 lines above. The issue about a
header that overclaims left the header overclaiming.

Nothing pins the layering either: `60df938` touched no test file, and moving the
block verbatim back beside `alloc_display_field` leaves `tests/jimalloc.sh` at
305/305.

### F12 — convention compliance

The bash-script hard contract is **clean**: all 130 added comment lines carry no
spec/AC/Finding/DD/issue ID, no cross-file line range, and no change-log
narration; shebangs, trailing newlines, `set -uo pipefail`, dependency inventory,
and `BASH_SOURCE` composition all verified. Breaches are metadata:

- `8c904c2` puts `AC 16/18` in a **commit header** — IDs belong in trailers.
- `7e5dd00` is the one hand-authored commit with no `Issue:` trailer.
- Six subjects exceed 50 characters.
- `tests/jimpartition.sh:1726` uses non-POSIX `seq`.
- 39 new `case_*` functions; one carries the canonical `# AC:` header.

## 5. Corrections to the record

1. **#205's severity was understated by its own reproduction.** The repro block
   showed a directory-existence oracle. With a directory present at the traversal
   target, the pre-fix code **enumerated and reflected basenames from arbitrary
   paths inside and outside the repo**, on stdout and stderr.
2. **#211's stated disposition is false** (F9).
3. **The width-table correction was itself under-counted.** The handoff revised
   nine sites to ten. The measured count is **eleven runtime gates across four
   files**, plus six more in `jimpartition.sh` that no count has ever included.
   This cluster has now mis-stated the same scope in three successive passes — the
   third time its own practice 7 has paid out.
4. **`--since 175047c platform` has no durable record.** No `verify started` /
   `verify finished` pair on the platform ledger for 2026-08-04, though
   `skills/verify/SKILL.md:89` requires it and both the 08-01 and 08-03 passes
   recorded one. The restoration is real and its fixtures pass; its stated
   grounding is unproven. Note the ledger records it as `folded=2; fixed=0` — the
   same metric key as the 08-03 understatement, so "weakened the invariant" and
   "restored the invariant" are indistinguishable from the ledger alone.
5. **`blueprint-slot-reserved` is not uniformly stronger than pre-fold.** It gates
   two of the four write paths the fold explicitly named and drops the disclosure
   of the other two — the generic path composer and `move-spec-dir`, both confirmed
   still accepting `000` at HEAD.
6. **The commit range is 34, not 32.** `175047c..HEAD` is 34; `7e5dd00..HEAD` is 33.
7. **Two stale stamps.** `docs/specs/platform/000-blueprint/spec.md` frontmatter
   reads `updated: "2026-08-02"` after a 2026-08-04 content edit; `BLUEPRINT.md:7`
   reads `Last updated: 2026-08-02`.

## 6. Confirmed clean

Recorded so the next reader does not re-derive them:

- **Suite 1137/1137**, exit 0, re-run. Arithmetic reconciles independently:
  1099 + 39 − 1 = 1137.
- **Registry clean** — 65/65 specs, 219/219 issues, zero hazard classes, zero
  drift rows. (The coordination remote is unreachable, so this is the last-seen
  local ref; `reserved-slots 5` and `rename-source-ids 52` are named omissions,
  not drift.)
- **The contract-edge phase reproduces exactly** — 310 CROSS-REF facts, coverage
  4/4, all facts landing on one of the 9 declared pairs, `edges=14` reconciling as
  distinct surface strings (23 graph rows, 9 group pairs). The 18-side remainder
  was disclosed as a first-class `skipped=18` key on the durable ledger event, not
  dropped.
- **Commit discipline clean** — `e5be48d`, `fb78fea`, `093bda7` each path-scoped
  correctly; zero deleted lines across both ledgers in the range (pure appends).
- **The two-array trap is clean** — all three `alloc_live_claim_set` callers
  declare `local -A live=() spent=()`. Confirmed four times independently. A
  missing declaration would also fail *loudly* (unbound variable under `set -u`),
  not silently.
- **The memo cannot corrupt an answer by omission** — cold and warm outputs
  byte-identical across every consumer; `is_valid_id` is pure. (A *wrong* entry
  **is** authoritative and never re-derived — see F3's neighbour finding.)
- **No injection, traversal, or escape regressions.** Zero `eval`/`source`/
  indirect expansion; all associative-array subscripts proven inert; exactly two
  word-position unquoted expansions, both proven unreachable with metacharacters;
  `move-spec-dir` refused all 12 hostile destination shapes; ReDoS ruled out on
  200 KB adversarial inputs; the `{3}`→`{3,15}` widening admits only more digits.
  The one boundary *move* in the range is a tightening (#205's slug gate).

## 7. What this cluster should learn

The pattern is not carelessness — every contract was met and most were met
thoroughly. It is that **a contract names a site, and a site is not a class.**

Three of the ten most serious findings are the same shape: an invariant was
decided correctly, implemented correctly at the named door, and left unapplied at
a door nobody enumerated. `catch-up` alone appears three times — missing #209's
refusals, missing #218's warm, and absent from every door matrix anyone drew.

The mechanical form of the lesson: **when a fix establishes a rule, enumerate the
rule's doors before closing the issue** — not the issue's doors. Two of the four
sweeps in this review did exactly that and found what thirteen contract-scoped
investigators could not.

The second lesson is about fixtures. Six fixture claims in this cluster were
overturned by mutation testing that the original session did not run — and in
every case the tested half worked while the untested half was blind. #215's own
words are the rule: *a fixture written for a contract that has never been observed
failing is a claim, not a measurement.* It applies per-assertion, not per-fixture.
