# Post-build review — B″, the id-coordination residue cluster

**Written:** 2026-08-05 · **Branch:** `feat/id-coordination` · **Range reviewed:**
`a9feede..da3ff7b`, **19 commits**, +2178/−187 over 49 files · tree clean · suite
**1182/1182** (re-run independently, exit 0)

**Verdict: major-drift.**

Judged contract by contract the build is strong: seventeen of the twenty-one
closes are fully satisfied under execution, and the *declined* proposed actions
are the best work in the pass — every one records its reason both in the issue
and at the site a future editor would re-add the code. But two things outweigh
that, and both are things a per-contract reading cannot see.

**The flagship critical item is not closed.** #229's rule — the registry never
reissues a vacated ordinal — still fails, through `/jim:partition`'s own verb
sequence, and the failure now also manufactures the registry-internal
contradiction the issue's Resolution claimed it had left untouched.

**The build introduced a new silent-corruption path.** `merge-map` now fabricates
map rows for specs that do not exist, at rc 0, into the id arithmetic its own
docstring says the human gate presents verbatim.

The verdict is not a judgment on care. This was a careful pass. It is a judgment
that the method it adopted — enumerate the rule's doors, not the issue's — was
applied one level too shallow, and that the thing it was built to prevent
happened again, in the guards written to prevent it.

---

## 1. Why this is a note and not a `review.md`

B″ is a build, not a spec. There is no spec directory whose `review.md` this
could be, and pointing `/jim:review` at `blueprint/025` would review the wrong
range and overwrite the `origin:` of thirteen tracked issues. So this is the
skill's *method* — triage the diff spine, fan investigators over the high-stakes
set, judge each ground truth on evidence — with the twenty-one closed issues'
*Proposed action* sections as the acceptance criteria. Same shape as B′'s review.

## 2. Coverage

`review_depth=thorough`, `review_model=inherit`, `review_fanout_cap=10`. The cap
was raised to **16 investigators** under explicit operator authorization, stated
before the phase that needed it. **There is no un-investigated remainder.** Nine
contract investigators over the twenty-one contracts, seven cross-cutting sweeps:
corpus-blindness, security, resolution-truth, conventions, omission class, doc
surfaces, verify folds, process arithmetic.

Four ran in isolated git worktrees so they could mutation-test and plant
violations. **Two of the four reported their worktree was provisioned 1164
commits stale** and reset to `b56fda2` before working; all four confirmed their
baseline in-report. Any result that did not confirm its baseline was not used.

Every investigator was told to execute rather than read, and to treat every
Resolution, commit message and handoff claim as a claim. That is what produced
the findings below: the two most serious were reproduced end-to-end by me
personally after the investigator reported them, and the security agent measured
a 500× fork amplification rather than reasoning about one.

All sixteen returned. One is worth recording as method: the fixture investigator
reported a GREEN row, then caught that its own test filter had excluded thirteen
cases, re-ran, and got RED. It reported the correction rather than the first
answer. That is the lesson of section 6 being applied to the review itself, and it
is why a GREEN row here means "planted and not caught", not "not looked for".

## 3. Per-contract disposition

Against each issue's *Proposed action*, not its Description.

| Item | Verdict | Note |
| :--- | :--- | :--- |
| #208 | **partial** | truncation note fixed at one site, traded a false positive at the other; the item-vs-character disagreement its own review raised is neither fixed nor mentioned |
| #211 | **overclaimed** | ten of eleven sites fixed; `ARCHITECTURE.md:396` is not, and the Resolution says all eleven are |
| #215 | satisfied | six mutations red |
| #216 | satisfied | rolls up onto #220 |
| #220 | satisfied | header rewritten; its new "no other function touches git" claim independently verified over lines 76–1382 |
| #221 | satisfied | sweep lands; the declined `REPO_ROOT` anchoring is reasoned in the issue *and* in-source at both sites |
| #222 | **overclaimed** | "five of six blind mutations now fail, and the sixth with them" — one still passes, and it is the house spelling |
| #223 | satisfied | all four ordinal mints enumerated independently; no unenumerated sibling |
| #224 | satisfied | six mutations red |
| #225 | satisfied *as scoped* | the five named guards discriminate; the scope was one arm wide (finding 10) |
| #226 | satisfied | both halves separately pinned |
| #227 | satisfied | all three sites pinned; the sweep that generalizes them is porous (finding 14) |
| #228 | satisfied | 4- and 15-digit ordinals bind end to end; 16 refuses loudly at non-zero rc |
| #229 | **not satisfied** | see finding 1 |
| #230 | satisfied | understated, if anything — a third instance was fixed and not claimed |
| #231 | **partial** | its own table's row 1 is the site still stale |
| #232 | satisfied *as scoped* | all six sites routed; the corpus was one file of sixteen (finding 8) |
| #233 | satisfied *as scoped* | the narrowing is real; the class survives it (finding 6) |
| #234 | satisfied *as scoped* | both verbs warm; six others do not (finding 6) |
| P- *renamed-away group* | satisfied | reproduced end to end |
| P- *lift's spent set* | satisfied | and the issue's "not presently exploitable" framing was wrong — it was reachable through ordinary verbs |

## 4. Findings

Ranked by impact × reachability. **in-change** means this build caused it;
**pre-existing** means the build made it legible without causing it.

### Critical

**1. #229's never-reissue rule still fails, one group rename out.** *(in-change —
the contract is unmet)*

The high-water fold applies the group alias (`jimalloc.sh:958`,
`g="${alias[$g]:-$g}"`). The spent set does not: the group-rename arm at
`:1669-1671` re-spells only *live* claims into `src_only`, so an ordinal already
spent by an earlier **spec** rename keeps its retired spelling. After
`spec rename ui/001 ui/044` then `group rename ui parts`, `src_only` holds
`ui/001` while the live spelling is `parts/001` — so a tree directory at
`parts/001` classifies `MISSING`, not `SPENT-TREE`.

Reproduced independently of the investigator that found it:

```
peek spec parts   → parts/045              registry says ordinal 1 is consumed
sweep             → missing-record spec parts/001            rc=3
catch-up --apply  → appended: spec allocate parts/001        rc=0   ← reissued
sweep             → rc=0                                            ← reads clean
resolve ui/001    → parts/044
resolve parts/001 → parts/001                                       ← two answers
realize           → error: duplicate spec claim … refusing          ← wedged
```

This is #229's failure shape verbatim, and worse in one respect: the appended
record manufactures a `duplicate-realize-key` — the registry-internal
contradiction whose repair needs a corrective-write primitive the grammar does
not have. #229's Resolution states "#200's scope is untouched." It is now
reachable from `catch-up`.

The same skew defeats `partition-batch`'s by-name spent refusal on both doors and
demotes the lift's new by-name check to its neighbour's gate — the lift still
refuses, but by `destination-not-established`, which is precisely the condition
the lift's own new comment declares insufficient ("a refusal that holds only
while its neighbour stays put is not enforcement").

**The door matrix that closes this**: every path reading the alias-folded
high-water is safe; every path reading the un-aliased spent set is not.

### High

**2. `merge-map` fabricates map rows from a directory basename.** *(in-change —
a regression)*

`2690614` replaced a per-directory `basename` with a numeric-sort round-trip
(`jimpartition.sh:1585-1615`): basenames are collected, re-serialized through
`printf '%s\n' | sort`, and re-read line-oriented. A basename containing a
newline splits into multiple rows. Reproduced:

```
on disk:   docs/specs/src/001-real
           docs/specs/src/"notes\n004-fabricated-a\n005-fabricated-b"

merge-map → MAP src/001 tgt/001
            MAP src/004 tgt/002      ← src/004 does not exist
            MAP src/005 tgt/003      ← nor does src/005
            rc=0
```

The verb's own docstring calls its output "the deterministic id arithmetic the
gate presents verbatim (no LLM arithmetic)". The ids bind at Close through
`partition-batch spec`, into an append-only registry that never reissues an
ordinal. So a planted directory permanently burns ordinals, writes rename records
for specs that do not exist, and shifts every real spec's assignment — with the
human gate reviewing a map that is arithmetically self-consistent and wrong. A
merely odd directory name misnumbers a real spec the same way.

Impact is critical; reachability requires a newline in a directory name, which is
why it ranks below finding 1. The fix is NUL-delimited iteration plus an outright
refusal of newline-bearing basenames.

**3. `partition-batch spec` writes a state its own classifier calls
unrepairable.** *(pre-existing)*

The builder emits `spec allocate <new>` then `spec rename <old> <new>`; the
replay calls a rename onto an already-live destination a `DUP`. So the emitter's
documented output is `duplicate-ordinal` drift, which `catch-up` puts in
`CU_BLOCKED` as "an operator decides which side is right" — and no operator can,
because the grammar has seven encoders and zero tombstone. Verified:

```
partition-batch spec 20260802   → jim/001 platform/001   rc=0
sweep                           → duplicate-ordinal spec platform/001   rc=3
catch-up --apply                → cannot repair (an operator decides…)  rc=3
```

`jimconf.toml:17` wires `registry-tree-consistency` (high) to that sweep, so on
any project that runs `/jim:partition`'s renumber, that invariant fails
permanently from first use. jim's own registry is clean only because it was built
by `lift`, which writes the rename alone. The replay's own header claims the
integrity report and the emission refusals "must not be able to disagree about
what 'already claimed' means." They do.

**4. `reconcile spec` and `reconcile issue` hand back vacated ordinals as
`have`.** *(pre-existing — the cell is absent from the build's matrix)*

`alloc_spec_claim_keys` folds claim keys from raw `allocate` records with no
replay, so a claim a rename moved away still owns its key. `resolve` says the
identity lives at `other/001`; `reconcile` tells the consumer to rename the
provisional directory onto `core/001` — manufacturing exactly the
`tree-on-vacated-ordinal` class this build shipped, from the allocator itself, at
rc 0. Same shape on the issue side.

**5. The discovery-root write refusal is defeated by a symlink, its test measures
one of four cells, and the suite writes into the production tree.** *(in-change)*

Found independently by three investigators.

`metatest.sh:76-82` tests bash's *logical* `$PWD`. `cd` through a symlink leaves
the logical path free of `/skills/`, so the refusal never fires:

```
cd $R/skills/demo   → Error: refusing to write under …      rc=1
cd /tmp/link        → Scaffolded tests/widget.sh            rc=0
                      wrote $R/skills/demo/tests/widget.sh        ← bypassed
```

`case_metatest_write_verbs_refuse_a_discovery_root` stays green under two of the
five mutations that break it: it invokes `add` without ever creating
`tests/widget.sh`, so `add` hits the *file-does-not-exist* branch, which also
exits 1 with stderr — both assertions pass whether or not the refusal exists, and
the `add` arm has no "no test file written" assertion at all. The `agents/` arm is
exercised only through `add`, so dropping `*/agents/*` from the pattern also
survives. Only `scaffold` × `skills/` is measured.

And `tests/metatest.sh:58` symlinks the sandbox's `skills` to `$REPO_ROOT/skills`,
so `mkdir -p "$sb/skills/demo"` writes into the repo. **`skills/demo/` is in your
working tree now, timestamped Aug 5 12:39** — created during the build session,
invisible to `git status` only because git does not track empty directories. With
the refusal mutated out, a real file lands there. This violates the standing rule
that tests use temporary directories, never production paths.

`pwd -P` closes the symlink route; the test needs its other three cells.

**6. The fork-amplification class survives the memo fix.** *(in-change)*

The vulnerability was real and worse than filed — measured on pre-fix code:
**606 forks / 39 s** for 600 crafted records, **3006 forks / 288 s** for 1000.

The fix narrows by *record kind*. The exploitable property is *readability*. A
right-kind, right-log, malformed record is still one boundary crossing per record
for a token no consumer ever reads:

```
600 × "spec allocate notanid evilslug… " in specs.log
  HEAD          : 607 forks, 101.5 s        ← 30× amplification
  warm stripped :  20 forks,   5.9 s
  tokens actually read by any consumer: 0
```

0.165 s per crafted record on a push-writable branch inside a read-only verb;
~27 minutes per `sweep`, per clone, for a 400 KB push. #233's Resolution — "a
record whose kind cannot live in the log it sits in is never crossed" — is true.
It is not the same statement as "the amplification is closed", which is how the
commit message reads.

Relatedly: the warming rule is applied at 3 of 9 verbs; six unwarmed ones show
72–91% repeat waste. The investigator tested the obvious fix and found it *wrong*
— warming `resolve` made it slower on jim's own registry shape (53→70 forks).
The structural fix is the 13 sites that call `alloc_canon_specid` inside a command
substitution and discard the memo write. And #233's "an unrecognised scope …
fails loudly" is inaccurate: it returns 1 silently, and none of the five call
sites checks the return value.

**7. `catch-up` claims total coverage while silently withholding.** *(in-change)*

`alloc_catchup_compute:3144-3146` unsets `want_spec` entries under a retired
group. The withheld ids are removed from the append set and never added to
`CU_BLOCKED`, so `:3249` then prints:

```
sweep     → missing-record spec dashboard/002 beta        ← named as drift
catch-up  → "nothing to append — every tree identity already has a record"
            (dashboard/002 appears nowhere in the output)
```

This is the shape #229's own Resolution invokes to *reject* one of its proposed
actions: "a repair verb that quietly skips what it could not fix, which is the
shape the cluster's own practice 6 exists to forbid." The build rejected a silent
filter for `SPENT-TREE` and shipped one for `GROUP-RETIRED`. The test it wrote
asserts nothing is appended and never asserts the operator is told what was
withheld.

`catch-up` is also the only verb in the derive-from-tree family that does not
disclose what its derivation passed over — `seed` and `sweep` both do.

**8. The output-sanitization corpus was one file of sixteen.** *(in-change
omission)*

The named fix is correct and proven: ANSI, OSC title-set, CR/BS overwrite and
newline injection all reproduced pre-fix and neutralized post-fix at all six
sites. But **12 live injection sites in 6 other scripts were proven by
execution**, including:

- `skills/issue/scripts/reconcile.sh:117` — the exact twin of the fixed site, one
  directory over: same message shape, same untrusted frontmatter source, and the
  file has no sanitizer at all;
- `jimledger.sh:600,603,631` — three raw siblings 55 lines from the single
  sanitized call this build *added to that file*;
- `jimfile.sh:208,236,528` — the shared id boundary every other script routes
  through, with newline forging still live at HEAD;
- `jimalloc.sh:1035,2400,2458,642` — the identical message sanitized at one site
  and raw at three, in one file.

Two further shapes: `catch-up`'s blocked-row renderer prints registry-controlled
fields raw while `sweep`'s renderer sanitizes the same row; and `jimpartition.sh`
gained a *new* raw site at `:1602` in commit `2690614`, after `a882ef6` declared
the class closed.

The severity is higher than the issue rated it. These scripts are invoked bare
from `skills/spec/SKILL.md` and `skills/issue/SKILL.md`, so their stderr is tool
output an agent reads. A forged `error: registry corrupt, run with --force` line
is injection into the agent's decision context, not terminal cosmetics.

The class sweep that was supposed to generalize the fix fires only if a new echo
uses `echo` (not `printf`), names one of three variables, lives in
`spec/reconcile.sh`, and shares no line with another sanitized call.

**9. The verify record drops the contract-edge counters.** *(in-change)*

`caf741d` records `checked=11;holds=7;violated=3;failed=1;unconfigured=0;skipped=0;undelegated=0`
— no `edges_checked=`/`edge_violations=`, although the contract graph names
`platform` as provider on 12 edges and the build touched provides-side code in
`jimalloc.sh`, `jimledger.sh` and the meta-test framework. The immediately prior
run carried `edges_checked=4;edge_violations=3`. The record cannot distinguish
"the phase did not run" from "it ran and its counters were dropped" — the exact
failure mode `undelegated=` was added to foreclose one rung over. Nothing
mechanically guards the edge counters, which is why it landed silently.

`undelegated=0` is good news and was corroborated rather than trusted: the three
judge findings are real and reproducible from `a9feede`.

**10. The lift's guard corpus is one arm wide.** *(in-change omission)*

#225 counted nine guards and named five. Independent enumeration finds **28**, of
which **11 survive the entire suite**. The shape:

| refusal class | realize | spec | group |
| :--- | :--- | :--- | :--- |
| `destination-conflict` | pinned | pinned | pinned ← *the class this build fixed* |
| `destination-not-established` | **blind** | pinned | **blind** |
| `source-conflict` | **blind** | pinned | **blind** |
| `source-claimed` | — | pinned | **blind** |
| `unrepresentable` (src) | **blind** | pinned | **blind** |
| `self-rename` | — | **blind** | **blind** |

Every refusal class is asserted on the spec arm and no other. The build closed the
arm asymmetry for one class and left the identical asymmetry open in five. Each
blind guard was proven load-bearing by deletion: dropping the group or realize
`destination-not-established` guard makes a lift mint a registry record pointing
at a destination the registry never established, from ledger content anyone who
can commit can write. Dropping the source-token validators puts an
`EVIL/../x`-shaped token into an appended record.

Two further test-corpus holes in the same family: no fixture exercises a
*live-and-spent* destination, so a mutant restoring exactly the pre-fix semantics
passes all 323 cases; and the entire issue-side vacated-ordinal arm has no test —
the shipped code is correct, nothing pins it.

**11. `tests/docsurfaces.sh`, new this build, has a corpus and a derivation
hole.** *(in-change)*

Its `doc_corpus` visits 50 files and omits 23 hand-authored surfaces, including
**every agent body** and every `skills/*/assets/` template. Planted a retired
symbol in `agents/coder.md` and a dead anchor in `agents/reviewer.md`: both green.
Five omitted files invoke the very scripts whose verbs get retired. Its sibling
in the same suite, `tests/fanoutdisclosure.sh:46-49`, already defines a corpus
that includes both roots.

Its registry-verb check hard-codes `verbs=('sweep' 'catch-up' 'lift')` while its
*adjacent* ledger-verb check derives the list from the dispatch table. Adding a
fourth registry verb passes; adding a fourth ledger verb fails. The comment above
the hard-coded one asserts the property it does not have.

And its retirement half is presently vacuous: every live occurrence of all four
retired symbols sits in a file the corpus deliberately excludes. It has real value
against future reintroduction and zero coverage of where they live now — and the
one file exempted for being "regenerated by `/jim:arch` rather than hand-edited"
is the file this build hand-edited, and the file where finding 13 lives.

### Medium

**12. Both single-source guards in `tests/jimfile.sh` miss what they were built to
catch — and one of them shows the other how.** *(in-change)*

The ordinal-width guard is blind to the spellings that caused the drift.
Its variable-name class is `[a-z_]+` and its operator set is narrow,
so these pass: `(( ${#1} > 15 ))` — which is the house spelling, used by
`alloc_valid_ord` itself — plus `${#SEQ}`, `length(myVar)`, a bare `999`,
`${bn:0:3}`, `[0-9]{3,}`, and `[0-9][0-9][0-9]`. The first is the exact fifth
mutation #222's Resolution says now fails. `999` and `${bn:0:3}` are the two
gates the build itself called "the dangerous ones". The guard keys on *naming the
bound*, so it catches conformant restatements and misses non-conformant caps —
asymmetric in the wrong direction for the omission class it exists to close. The
new `scripts/` root has no enumeration guard, unlike its sibling.

Its neighbour, the provisional-grammar pin (#215/#224), has the opposite problem
and the same root. Every assertion it makes discriminates — all six drifts #224
named go red, as do all three branches of #226's disjunction, so those two
Resolutions are accurate rather than overclaimed. But its corpus is three
hardcoded paths with no sweep: giving `jimpartition.sh` a fourth `PROV_PREFIX`,
its own `prov_id_boundary` and a loosened `is_prov_token` passes **1182/1182**.
Both its patterns are `^`-anchored, so an *indented* copy is invisible to the
fail-closed count as well as to the value assertion — which contradicts commit
`2beee89`'s own claim that "a line that is missed cannot read as clean." A second
grammar spelling at `spec/reconcile.sh:722` restates the whole rule inline and is
unpinned; widening its date class leaves all 73 specreconcile cases green.

These two cases sit in the same file. The width guard closes the omission class
with a `grep -r` sweep over both production roots and comments on why; the
provisional guard, twenty lines away, does not. That is the whole finding of
section 6 in miniature.

**13. Four Resolutions assert fixes or mechanisms that did not exist when they
were written.** *(in-change)*

`ARCHITECTURE.md:396` is still stale. It still documents `merge-map`'s `<start>` as "taken
verbatim from `next-id`" — a verb that now refuses spec ordinals outright
(`error: 'next-id' answers for issues only`, rc 2) — plus a second false clause
("never re-minting a vacated id"). `0620603` edited that line, fixing the
`renumber-map` clause in the same sentence. The document's own `:284` carries the
correct wording. #231's Resolution says "regenerated through `/jim:arch`" and
#211's says "all eleven are already fixed"; what landed was six targeted
hand-edits. The commit message was honest about this; the Resolutions are not, and
the substitution is why the site survived — `:395` was on the list the
regeneration was meant to sweep.

The other two are sharper, because they are what the judges caught. #227's
Resolution says `scripts/` need not be swept for the locale rule "which the
existing case already requires"; #221's says the stray sweep "sweeps `skills/`
and `agents/`". Both were written at 12:00:42, and at that moment the locale case
looped `skills/*/scripts/*.sh` only and `agents/` was absent from the stray
enumeration at any depth. Both became true at 12:58:09. **Two of the three
judge-found defects are exactly the two those Resolutions had already declared
closed** — the closing sentence outran the measurement, and the fan-out is what
noticed. Neither issue was amended afterward. Of the six inline fixes, two have
no artifact anywhere at all.

**14. The hygiene sweeps' depth and locale rules are porous.** *(in-change)* In
one file, the stray sweep recurses at any depth while the preamble, locale and
read-target sweeps stay depth-1 globs — a script one directory deeper with
`set -e`, no locale export and an undeclared `read` target passes all three. The
locale sweep uses `grep -c` (lines, not occurrences), so a pinned and an unpinned
`sort -u` on one line cancel to zero; it matches only the literal `sort -u`
spelling, missing `sort --unique` and `sort -nu`; and it excludes its own file
wholesale. Two of the three sites #227 was filed about are re-unpinnable with the
suite green. The stray sweep's roots are unenforced — deleting two of three leaves
it green, because `skills/` alone over-satisfies the `n >= 10` floor.

Blind spots proven by planting: `tests/nested/`, `tests/*.bash`, repo root,
`docs/`, symlinked files and directories, unreadable files. Scaffolding from
inside `tests/` writes `tests/tests/widget.sh`, reports success, and the file is
never run and never flagged.

**15. The practice-10 disposition table fails practice 10.** *(in-change)* The
step-7 table reads "Twelve findings, twelve dispositions, no remainder" over rows
summing **14**. Three findings occupy six rows — the three folded invariants
(`script-preamble`, `ordinal-single-source`, `tests-under-tests`) are the
blueprint-text half of three defects also counted under "fixed inline" — so
distinct findings are **11**. No decomposition yields 12. And the gate issue's own
rule is "Each finding carries exactly one disposition: fixed, filed, or left";
the table's first row is titled "filed + fixed", and at least 5 of 11 findings
carry two. The paragraph demonstrating the newly adopted arithmetic gate does not
survive it.

The B′ control recounts exactly, so this is B″'s own slippage, not a house
pattern.

**16. Three commits carry work their type denies.** *(in-change)* `d8e8a4e`
(`docs`) changes `jimpartition.sh` behavior; `2beee89` (`test`) adds a load-bearing
fourth arm to `alloc_group_has_records` and fixes a real variable clobber in
`render.sh`; `0620603` (`docs(arch)`) contains **all three verify-driven sweep
fixes**. Each bundles two logical changes, against the rule the commit convention
states most explicitly — and the third one is consequential for readers: it is why
the response to the verify run is invisible to anyone reconciling the timeline.

**17. `metrics` reports a span, not a duration.** *(pre-existing)* `<stage>_duration_seconds`
takes the first `started` and the last `finished`, so on the blueprint ledger —
the one `/jim:verify` and `/jim:blueprint` write repeatedly —
`verify_duration_seconds=920816` against a true sum of 6816 s. 135× overstated.
Correct on a one-run-per-stage spec ledger; wrong on every blueprint ledger.

### Low

**18.** Recount errors: "20 commits" (**19**); "suite 1148 → 1182" (the baseline
is **1140**; +42 not +34, and the missing 8 are the ones the build's own first fix
commit added); the exit handoff's claim that the cluster note names the four
provisional issues by slug (**zero** occurrences — it names them by prose).

**19.** The verify record's `failed=1` has no recoverable reason — the reason
lives only in the non-durable VERIFY-OUTCOME block and the ledger grammar has no
reason field — and no note in the repo mentions it. `registry-tree-consistency` is
the coherent candidate by the `--since` adapter's own rule, but that is inference.
Both notes describe the run as having "found three real defects", silent on the
one invariant that could not be checked.

**20.** #221 and #227 still say the blueprint sentence "rides the docs pass" after
the docs pass rewrote both; only #222 got a fold record. Two closed provisional
issues are untraceable from history — no commit trailer cites either.

**21.** Doc drift beyond finding 13: "3-digit ordinal" is false at five sites
(3 is the floor, not the width); "per-script test files only" is false on two
surfaces and the build added a seventh counterexample; the project-structure tree
omits 8 test files including the one this build added, 8 skill directories and 2
agents; 9 of 12 line-range claims are wrong. `README.md:214` says catch-up
"appends exactly what the sweep classifies as `missing-record`" — finding 7 makes
that false. The two new drift classes this build shipped appear on no operator
surface. And the "stage list re-spelled instead of named" inline fix corrected the
comment in `jimledger.sh` and left the same re-spelling live in two consumed
surfaces — `skills/review/assets/review-template.md:144-146`, whose three metrics
rows are structurally unable to show `blueprint_*` or `verify_*`, and
`docs/features/review.md:85`. Nothing in `tests/` references `LEDGER_STAGES`, so
that fix has no regression test.

**22.** A third verbatim copy of `display_field` was created with no
byte-identical pin, in a repo that has an established convention for exactly that
(`extract_fn`, used for `is_prov_token` across three scripts).

**23.** Dead code shipped: `alloc_class_label`'s new `RENAME-SRC → vacated-ordinal`
arm is unreachable from either caller.

**24.** One of the six cases added to close the fixture-blindness batch
discriminates nothing — no mutation in a 30-mutation sweep turns only it red. Its
assertion is an alternation of which only one branch ever fires. It is
documentation shaped like a test, in the batch whose purpose was eliminating
those.

**25.** `metatest.sh run` sources PWD-relative `tests/*.sh` under the skill's own
tool grant, and `run_action` calls no guard — the two write verbs got a refusal,
the read verb got nothing. Reachable only by invoking jim from inside an untrusted
checkout, but it is `source` of user-supplied data, which `CLAUDE.md` names as a
security boundary.

## 5. What the build got right

Stating this precisely matters, because the verdict is severe and the work is not
bad.

- **The declined proposed actions are the strongest part of the pass.** #229's two
  proposed actions were *both* wrong and the build proved it rather than
  implementing them; #221's `REPO_ROOT` anchoring was tried both ways and reverted
  with the reasoning left in-source at both sites; #225's arm-symmetry check would
  have been dead code beside `spent`, verified by execution; #232's alteration
  disclosure and #228's shared validator likewise. **No declined action's reason
  exists only in a handoff note** — every one is in the issue and, where a future
  editor would re-add the code, at the site.
- **#223 is complete.** All four ordinal mints enumerated independently, every
  other record-writer draws from a gated mint, group records carry no ordinal.
  No unenumerated sibling. Both new fixtures discriminate, each catching only its
  own site.
- **The width single-sourcing guard is well built** — the constant is extracted,
  bound per-file, fails closed, excludes by path, and three separate mutations go
  red. Its blind spots (finding 12) are in the spelling class, not the design.
- **#228 binds end to end.** A 4-digit ordinal survives `peek` →
  `merge-map` → `partition-batch` → `resolve`; 15 digits accepted, 16 refused
  loudly at non-zero rc; mixed-width sort is numerically correct.
- **The blueprint writes went through their surfaces**, with matching ledger event
  pairs and byte-identical commit subjects. The rewritten `ordinal-single-source`
  sentence is *honest* about `tests/` being outside the guard's reach, rather than
  claiming "any script" — verified by mutation.
- **The judges ran.** `undelegated=0`, corroborated independently.
- **Conventions are clean**: shebangs 160/160, EOF newlines 49/49,
  `set -uo pipefail` 31/31, zero third-party deps, zero `eval`, all 20 `Issue:`
  trailers resolving to real files with matching `num:` and INDEX rows. **The build
  added zero new artifact citations** while that backlog issue is open.
- **Every spot-checked commit is green on its own**, `INDEX.md` is byte-reproducible,
  and 1182/1182 holds at HEAD.
- **`docsurfaces.sh`'s design insight is sound** — retirement and introduction fail
  in opposite directions, so they must be separate checks. Its introduction half
  does real work. The corpus is the problem, not the idea.

## 6. The lesson

B″'s own lesson was: mutation testing proves an assertion *discriminates*; it
cannot tell you the *corpus was too small*. That is right, and this review is its
strongest confirmation — but the corollary is sharper than the pass recorded.

**The corpus question recurred inside every guard written to answer it.** The
sanitizer sweep looks at one file of sixteen. The width guard misses the two
spellings that caused the drift it exists to catch. The stray detector cannot see
`tests/` — the directory in its own name. The doc sweep omits every agent body.
The lift's mutation audit covered one arm of six. In each case a *correct* pattern
was available in the same file at authoring time — `ledger_verbs()` derives from
the dispatch table eight lines from the hard-coded `registry_verbs`; the stray
sweep recurses three functions from the depth-1 preamble sweep — and was not
generalized.

So the practice to add is not "check the corpus". It is: **when you write a guard,
name the set it must cover before you write the enumeration that covers it, and
make the enumeration derive from that name.** A hard-coded list is the failure;
`ledger_verbs()` is the pattern.

And the second-order lesson, which is finding 15's real content: the pass drew a
door matrix of **verb × entity** and enumerated it faithfully. The defects live in
**verb × rule**. Framing #229 as a classifier intersection kept the search inside
the classifier's consumers and out of the two verbs that read the log without it —
which is B′'s systematic under-reach, one level up. The matrix was right; its axes
were not.

## 7. Practice 10 applied to this review

Twenty-five findings. Twenty-five dispositions, one each, no remainder:

| Disposition | Count | Which |
| :--- | ---: | :--- |
| **file** | 16 | findings 1–14, 17, 25 |
| **left — recorded here, no issue** | 9 | findings 15, 16, 18–24 |

The nine "left" items are corrections to the record and one practice: the
recounts (18), the disposition table (15), the unexplained `failed=1` (19), the
two stale issue residuals (20), the doc drift inventory (21), the unpinned copy
(22), the dead arm (23), and the vacuous test case (24). Each is named above with
its location; none needs a tracking issue to be actionable, and filing nine
bookkeeping issues would repeat the accounting inflation finding 15 is about.

Finding 16 (commit typing) is left deliberately for a different reason: the
commits have landed, and correcting them means rewriting history rather than
amending. The forward-looking half — a behavioral change never ships under a
`docs` or `test` type — belongs with this cluster's adopted practices, not in the
issue collection.

## 8. What to do next

In order:

1. **Finding 1** — the alias fold on the spent set. It is the cluster's stated
   purpose and it is unmet. It should block D.
2. **Finding 2** — one-line fix, silent corruption, introduced this pass.
3. **Findings 3 and 4** — the two pre-existing registry paths that manufacture the
   drift this cluster exists to prevent. These are what step 8's sdlc pass will be
   sitting on top of.
4. **Finding 5** — `pwd -P`, plus the three missing test cells, plus stop the
   suite writing into `skills/`. `rmdir skills/demo` clears the artifact already
   in the tree.
5. **Findings 8, 10, 11, 12, 14** — the corpus class, as one pass with the
   derive-from-the-name rule above as its acceptance criterion.

**Step 8 remains the right next move after the above.** #161–#167, #52 and #53 are
still the highest-criticality open work, still untouched through seven builds.
This review adds to that queue rather than displacing it — but findings 1 and 2
should land first, because both are in the machinery every later step uses.
