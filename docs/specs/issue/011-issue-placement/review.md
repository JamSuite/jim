---
spec: "issue/011"
type: feature
date: "2026-08-07"
alignment: major-drift
plan_deviations: 4
security_regressions: 5
findings: 25
invariant_violations: 1
contract_violations: ""
artifacts_present: [spec, research, security, plan, ledger]
commits: 15
commits_feat: 11
commits_fix: 0
commits_test: 0
commits_refactor: 0
files_changed: 19
insertions: 2905
deletions: 32
spec_duration_seconds: 6385
research_duration_seconds: 1062
plan_duration_seconds: 34395
sec_duration_seconds: 37569
build_duration_seconds: 13717
review_runs: 1
review_interruptions: 1
undelegated: 0
---

# Review — issue/011 Issue placement

## Summary

**`major-drift`.** The design is sound and the hard parts landed: the
materialize-and-plumb engine works, the Critical containment gate is real and
proven non-vacuous, the graft rule is correct across all eight base/upstream/ours
combinations, and routing behind the emitter genuinely carries placement to all
eight surfacing skills with no per-skill change.

The drift is not in the architecture. It is that **four defects reachable by
ordinary use silently corrupt or discard user data**, and each was reproduced at
a shell rather than argued from the code:

1. An issue title containing `{}` has a temp path substituted into it — and into
   the durable id, which is then written to the append-only registry.
2. A mutation made while the remote is unreachable is committed locally, then
   discarded by the next reachable write. No message at any point.
3. `begin --read` in direct mode returns a token that publishes, so the
   read-only insights flow can commit a developer's uncommitted edits.
4. An offline read in a clone that has only ever read serves an **empty**
   collection while announcing "serving the last-seen state".

Three of the four are in code paths the test suite exercises adjacently but
never end-to-end, which is why 1262 green tests did not catch them.

Coverage: 14 investigators dispatched at `thorough` depth against a cap of 10
(the developer authorized exceeding it); 0 undelegated; all 14 returned. The
verdict was assigned after eleven and did not change; the last three added F23,
F24, F25 and the test-quality section, and **corrected one of my own AC
verdicts** — I had recorded AC #13 as satisfied-as-prose, and the sweep showed
the rule is inherited by nobody. The blueprint liveness check was run: `issue` is
live in `BLUEPRINT.md`.

The ledger's advisory line records `findings=22`, the count at the moment the
verdict was assigned; this file is authoritative at 25. The verdict is unchanged.

## Alignment vs spec

| AC | Verdict | Note |
| :--- | :--- | :--- |
| 1 — one key, `branch` sentinel | satisfied | gate verified; `branch` returns before the coordination-branch lookup, so default projects are untouched by a junk `id_coordination_branch` |
| 2 — default behavior unchanged | satisfied | control run stores `title: "Fix the {} placeholder"` verbatim; every defect below is placement-only. Cost: +27ms per read verb (measured) |
| 3 — every write lands at the destination | **partial** | `reconcile.sh -c <cfg>` silently skips routing (F10); `place_direct_publish` pushes the whole checked-out branch, not just the mutation |
| 4 — one commit per mutation | satisfied | verified on both tiers; no empty commit on a no-op |
| 5 — reads serve the destination | **partial** | `list`/`stats`/`show` route correctly; offline in a read-only clone serves empty (F4); `insights` half-routes (F23) |
| 6 — freshness, loud degrade | **partial** | the degrade message is emitted, but what it serves is not the last-seen state (F4) |
| 7 — writes never silently lost | **violated** | F2, reproduced |
| 8 — orphan bootstrap | satisfied | parentless commit, collection alone |
| 9 — coordination branch refused | satisfied | follows the configured name, not the default spelling |
| 10 — junk value refused | **partial** | refuses on every path a skill takes; an explicit dir argument bypasses it |
| 11 — dangling origin tolerated | **partial** | rc 0 and nothing blocked, but the test never exercises a dangling origin, and the real behavior is published cross-branch index churn (F25) |
| 12 — rewrite detected | **partial** | works on the plumbing path; absent from direct mode and the retry-loop re-fetch; false positives from F12/F13 |
| 13 — auto-file keeps a scrub moment | **violated** | the rule is stated in §7a and pinned by an invariant, but no inheritor executes it (F24) |

## Alignment vs plan

Three deviations, all disclosed during the build and two explicitly approved:

- **`place.sh mode` verb** (approved) — holds the gate and token comparison in
  one place rather than six copies. Not in the plan's interface contract.
- **`JIM_PLACE_ACTIVE` not set** (disclosed) — the plan's contract names it
  alongside the token, but a boolean that also suppresses routing reinstates
  security Finding 10. Only the token pair is set.
- **Index regeneration on every write** (undisclosed at the time) — DD 5 asserts
  it and task 7 requires it, so this follows the plan; but it was implemented by
  `touch`ing the index after materialization, which is what weakens
  `staleness-gated-reads` (F7).

## Alignment vs architecture

Conventions hold: `set -uo pipefail` + `LC_ALL=C` preamble, no third-party deps,
BASH_SOURCE-relative composition, no spec IDs in script comments (swept clean),
trusted-enum commit subjects, `--literal-pathspecs` on every pathspec call.

Provenance is clean in every line the build wrote — `place.sh` and all six
routing blocks carry no spec id, AC, Finding, DD, or issue number.

Four convention gaps:

- `place_direct_publish` is the **only** staging site in the repo that does not
  resolve its `git add` target against `git rev-parse --show-toplevel` (F14).
- **`place.sh` raises the corpus bash floor from 4.0 to 4.3** by being the first
  script to use namerefs (`local -n`), and introduces three new non-POSIX
  constructs (`grep -m1`, `find -mindepth`, `find -print0`). Each is GNU+BSD and
  the floor was already above stock macOS bash 3.2 via `declare -A`, but nothing
  documents the new floor.
- `place_shown` diverges from the house control-byte sanitizer
  (`tr -d '\000-\037\177' | cut -c1-512`, used in four scripts) by dropping the
  length cap, so an uncapped branch-supplied filename can flood a terminal.
- The three-clause verb-scoped `allowed-tools` grant is the **security-correct**
  choice — `place.sh run` is an arbitrary-command executor, so a script-level
  grant would be a de facto `Bash(*)` — but it diverges from the documented rule
  ("a skill that needs several of a script's verbs keeps the script-level
  clause"), and my `ARCHITECTURE.md` refresh did not record the new precedent or
  the exception it establishes.

Header inaccuracies in `place.sh`: it claims the commit is built with `mktree`
(the code uses a scratch `GIT_INDEX_FILE`; `ARCHITECTURE.md` describes it
correctly, so the header is the copy that drifted); its `CLI SUMMARY` omits
`begin`/`commit`/`abort` — the only three verbs with `allowed-tools` clauses;
`cmd_mode`'s comment calls itself "the only place the config gate is evaluated"
when three other functions call it; and "parses with grep/sed only" omits `awk`,
`tr`, and `read`.

## Findings

### F1 — `{}` in any untrusted scalar is substituted, corrupting the durable id

**Critical.** `place_substitute` (`skills/issue/scripts/place.sh:167-176`) does an
unconditional `${a//\{\}/$dir}` over *every* forwarded argument. `new.sh` is the
only entry script forwarding free-form user text, so a title, label, or origin
containing `{}` or `{token}` is silently rewritten.

Reproduced:

```
--title 'Fix the {} placeholder in output'
  → title: "Fix the /tmp/tmp.P6mm4tbCV4/collection placeholder in output"
  → slug:  20260807-fix-the-tmp-tmp-p6mm4tbcv4-collection-placeholder-in-output
--labels 'a{}b'  → labels: [a-tmp-tmp-9ocdwewkkd-collectionb]
--origin 'docs/{token}/x.md' → origin: docs/tmp.9OCdWeWkkd/x.md
```

The slug is the **durable id**. It is written to `issues.log` on the coordination
branch, which is append-only — the corruption cannot be corrected by any later
append. The injected value is a fresh `mktemp` basename each run, so the same
title filed twice yields two unrelated ids and the allocator's dedup scan can
never match. `jimfile.sh slug` truncates at 64 characters, so the real tail of
the title is evicted.

`{}` in a developer-tool issue title is ordinary: `interface{}`,
`map[string]interface{}`, an empty JSON literal, a template snippet.

Every current caller passes `{}` as a whole argument, so restricting
substitution to arguments that are *exactly* the placeholder is a contained fix.
The better shape is to stop putting placeholders in argv at all and pass the dir
and token as explicit options.

### F2 — a deferred mutation is discarded, silently

**Critical.** Reproduced end to end:

```
offline:   place.sh commit <tok> --verb close --id 20260101-a
           → rc 0, local commit made, no stderr disclosure
           → local head: "closed"
reconnect, one read, then any write:
           → remote:  [open]
           → local:   [open]
```

Three mechanisms compound. Nothing implements "propagation completes later" —
the only pushes send a commit built *this run* on the *remote* tip. `place_land`
(`:813`) syncs the local ref with **no old-value**, force-resetting over the
deferred commit. And the one warning that would fire is consumed by any
intervening read, which advances the bookmark.

`cmd_run` at least prints a deferral notice; `cmd_commit` prints nothing at all,
so the two-phase edit flow is fully silent. AC #7 states "No mutation is ever
silently dropped."

Note the `new.sh` path is *safe*: the allocator hard-fails offline before
anything is written. The exposure is exactly the `begin`/`commit` flow — the one
with no allocator gate.

### F3 — a read-only handle can publish in direct mode

**Critical (security).** Reproduced:

```
$ place.sh begin --read                 →  direct	docs/issues
$ place.sh commit direct --verb close   →  rc 0
  HEAD now: HALF-FINISHED PRIVATE NOTE
```

`cmd_begin`'s direct arm returns the fixed literal `direct`, which carries no
read flag; the read-only refusal in `cmd_commit` reads handle state and so covers
plumbing handles only. `--read` also skips the dirty guard. The result is that
the insights flow's own token is a publish capability that stages whatever
uncommitted edits are sitting in the collection.

`skills/issue/SKILL.md` states "A read handle cannot publish: `commit` refuses
it." That is false in direct mode. This is security Finding 9's exact harm,
reached through the path documented as safe.

### F4 — offline reads serve an empty collection, announced as last-seen state

**High.** Reproduced: clone B reads the shared collection online (sees the
issue), goes offline, reads again — gets "serving the last-seen state of
'jim/issues'" and **no issues at all**.

`place_local_tip` reads `refs/heads/<dest>`, which only a successful
`place_land` ever creates. A clone that has only ever *read* has no such ref, so
`tip` is empty and materialization returns an empty collection. The bookmark ref
holds exactly the right sha and is never consulted.

The test fixture hides this: `place_seed_collection` ends in `git update-ref
refs/heads/<branch>` in the same repo, so the degrade case always has a local
branch a real clone would not.

### F5 — `cmd_begin` returns rc 0 when the containment gate refuses

**High.** `place.sh:509-513` uses `if ! place_materialize …; then local mrc=$?`.
Inside the body of `if !`, `$?` is the status of the *negated* pipeline, i.e.
always 0. Reproduced: against a crafted traversal tree, `run` correctly exits 2
while `begin` exits **0 with empty stdout**.

An agent keying on the exit code believes it holds a handle; the SKILL.md
contract yields empty token and empty dir. The refusal reaches stderr and the
handle is removed, so nothing escapes — but the Critical gate's refusal is
invisible to the caller. This is the only `if ! cmd; then x=$?` in the repo.

### F6 — `cmd_commit direct` re-resolves config and never re-checks HEAD

**High.** The direct arm resolves `dest`/`prefix` fresh from config and calls
`place_direct_publish`, with no `symbolic-ref` re-check, no dirty guard, and no
`branch`-sentinel refusal. `direct` is a fixed literal, callable at any time with
no proof a `begin` happened.

Switch branches between `begin` and `commit` and the collection is committed onto
the *feature* branch, then `git push HEAD:refs/heads/main` publishes the entire
feature branch to the shared issues branch — succeeding silently whenever the
feature descends from main. If `issue_placement` is absent at commit time, `dest`
is the literal string `branch` and a junk remote branch named `branch` is created.

The handle arm is drift-immune by design (it reads recorded state); only the two
sentinel arms re-resolve. That asymmetry is undocumented and untested.

### F7 — `staleness-gated-reads` weakened

**High (invariant violation, in-change).** `place_materialize` ends by
`touch`ing `INDEX.md` so it is the newest entry, which makes `render.sh`'s
mtime gate always report fresh. That is sound only while the premise "every
write publishes a current index" holds — true for anything routed through
`place_reindex`, false for content arriving any other way.

A teammate committing an issue file onto the destination without regenerating the
index, or a merge of two branches, leaves every clone serving a view that omits
it — permanently, until some write happens to trigger a regen. Before placement,
the same drift bumped the directory mtime and forced a rescan.

The cheap correction is to regenerate unconditionally inside the read-only
materialized dir (which is discarded, so a read still commits nothing) rather
than asserting freshness by `touch`.

### F8 — every push failure is reported as contention

**Medium.** `place_land` maps *any* origin-tier push failure to rc 3. A developer
with read access but no push rights — the exact case the spec's user story
anticipates — gets five attempts and then "'jim/issues' kept moving; the mutation
was not published after 5 attempts. It is unpublished, not lost — re-run to apply
it." The diagnosis is false, the advice will fail identically forever, and on the
`cmd_run` path the temp state was already removed by the cleanup trap. Direct
mode has the same conflation, reporting "has diverged from" for an unreachable
network or an auth failure.

The loop re-reads the tip one line later and could compare it against the old tip
to tell contention from a hard failure.

### F9 — the emitter's stdout contract is printed before publication is known

**Medium.** `new.sh` prints `<slug>\t<path>` inside the wrapped command; the
publish happens afterward and can fail (rc 3 conflict, rc 1 build failure). The
caller then holds a line naming a destination path where nothing landed, and the
ordinal is already burned in the append-only registry. Reproduced incidentally
under a misconfigured `issues_path`:

```
20260807-alpha	./docs/issues/20260807-alpha.md
place.sh: could not build the destination tree
write rc=1
```

The candidate-batch flows do check rc, so they skip the row rather than record a
phantom. `new.sh`'s own EXIT CODES header still documents only 0/1/2 while the
`exec` now propagates rc 3.

### F10 — `reconcile.sh -c <cfg>` is mistaken for the issues dir

**Medium.** `reconcile.sh`'s routing loop has no `skip_next`, unlike its sibling
`migrate.sh`. `-c` matches `-*` and is ignored; the config path then matches `*)`
and becomes `dir`, so routing returns before `place.sh mode` is ever called and
the realization rewrites the **working tree** collection. Latent — `-c` is a
documented test seam — but it also means reconcile's routing can never be
exercised through the `-c` fixture path. One line mirroring migrate fixes it.

### F11 — `render.sh show` with no id loses its usage error

**Medium.** `dir_given` requires two args for `show`, so a zero-arg `show`
routes; `{}` then lands in the *id* slot, `dir` stays empty, and the fallback
resolves the working-tree dir, creating an untracked `docs/issues/INDEX.md` and
printing ``no issue matched `/tmp/tmp.XXXX/collection` `` at rc 0. It used to be
a clean rc 2. The temp path leaks into user-visible output.

### F12 / F13 — the bookmark produces false rewrite alarms

**Medium.** Two paths corrupt the freshness signal AC #12 rests on:

- `place_direct_publish` advances the bookmark *before* the push and does not
  roll back on rejection, so the bookmark names a commit that exists only in this
  clone. The next plumbing read reports "was rewritten" on a repo where nothing
  was.
- `place_check_rewrite` runs on the local tier too, where no fetch happened, and
  compares against `refs/heads/<dest>` — which an online read never advances. So
  read-online-then-work-offline manufactures a two-SHA tamper alarm, **and**
  rewinds the bookmark, after which a genuine force-push building on the older
  tip passes the ancestry check silently.

The suite's own comment says the disclosure "has to stay rare enough to mean
something."

### F14 — the worktree-top containment gate is absent

**Medium (security).** `place_direct_publish` stages a config-derived path
without resolving it against `git rev-parse --show-toplevel`. Every other staging
site in the repo does — `jimledger.sh` ×6, `jimpartition.sh` ×2,
`spec/reconcile.sh`, `jimalloc.sh` — and jimledger's own comment explains why:
it backstops `valid-relpath` and git's symlink refusal against a shape-valid path
that symlinks out of the worktree. DD 6 names `commit-*` as the precedent; only
half of it was carried over.

### F15 — the issue group's blueprint is stale

**Medium.** `docs/specs/issue/000-blueprint/spec.md` contains zero occurrences of
`place`/`placement`. Its Requires face records the `platform.jimconf-cli` contract
as "the `issue_list_*` and `issue_id_*` key contract" — now missing
`issue_placement*` and missing `place.sh` as a consumer, including its new
dependency on the platform key `id_coordination_branch`. Its Structure section
says "six scripts". This is the blueprint-update step's business, not a build
miss.

### F16 — SKILL.md §6's read-back breaks under placement

**Medium.** §6 step 4 tells the agent to read the written file's `num:` back from
the printed path. Under placement that path is on the destination branch and is
not in the working tree. Worse after the documented flip-migration: a leftover
working-tree copy would be read instead, silently reporting the wrong ordinal.
§6a got a placement arm; §6 did not.

### F23 — `insights` half-routes: the analyst reads the wrong collection

**High.** `SKILL.md` step 8 was updated to resolve the directory via
`place.sh begin --read` and hand `<dir>` to the analyst. `agents/issue-analyst.md`
was **not**. Its method still says, literally:

```
3. **Bodies last, selectively.** Read the individual `docs/issues/*.md` bodies
```

So under placement the analyst takes the roster and graph facts from the
**destination** (steps 1–2 use `<dir>`) and the bodies from the **branch-local
`docs/issues/`** — silently analysing two different collections. Where the
working tree has no collection at all, the body reads simply fail and
convergence degrades to metadata-only with no disclosure.

Secondary: `<dir>` now points inside `.git/`, which the analyst's Read-only grant
must reach; and `SKILL.md` asks the main agent to count `*.md` in `<dir>` while
`/jim:issue`'s `allowed-tools` grants no `Glob`/`LS` (pre-existing, but harder to
work around now that `<dir>` is an opaque absolute path).

### F24 — AC #13's degrade is inherited by nobody

**High (security).** Verified by sweep:

```
skills/ files mentioning issue_placement:  issue/SKILL.md, place.sh, jimconf.sh
surfacing skills reading auto_issue_file:  9
surfacing skills reading issue_placement:  NONE
```

DD 9 placed the scrub rule in §7a on the reasoning that the eight surfacing
skills cite §7a, so "one edit, eight inheritors." That reasoning is wrong for a
*behavioral branch*. Each surfacing skill carries its own local restatement —
`IF auto_issue_file == "true" THEN apply the AUTO-FILE PATH` — which is what the
agent executes; §7a lives in a skill file that is not loaded during `/jim:build`.
A pointer inherits a rule to consult, not a branch to take, when the local text
already spells the branch out unconditionally.

Concretely: a project with `auto_issue_file = "true"` and
`issue_placement = "jim/issues"` finishes a build and publishes every candidate —
including text drawn from tool output and fetched pages — to the shared branch
with no review. Security Finding 2's mitigation is present as documentation and
absent as behavior on all nine consuming skills.

This is a **plan defect, not a build slip**: task 11 scoped the edit to
`skills/issue/SKILL.md` alone and the AC-13 coverage row cites only tasks 1 and
11. My own `docsurfaces` invariant made it worse by certifying the rule was
"stated" — which it is, and which turns out not to be the property that matters.

### F25 — placement converts a per-branch origin lint into published churn

**Medium.** `index.sh`'s origin lint resolves `origin:` paths against the
*invoking* CWD, and `place.sh` deliberately never `cd`s. So the lint runs against
whichever developer's checkout happened to trigger the reindex, while writing
into the **destination's** `INDEX.md`.

Developer A on `feat/x` files an issue with `origin: docs/brainstorms/x.md`.
Developer B, on `main`, closes any issue; B's reindex cannot resolve that path
and appends an integrity warning naming A's issue to the published index — which
`render.sh stats` then shows every reader. The warning set is a function of which
branch the last mutator stood on, so it flips on and off, and each flip is a real
`INDEX.md` diff. Nothing is blocked and rc stays 0, so AC #11's letter holds; the
mechanical fact is new cross-branch churn.

The AC #11 test does not catch this because it creates the origin file in the
working tree before filing, so the path resolves and no warning fires.

### F17–F22 — lower severity

- **F17** `place_shown` is applied at only one of three sites that print a
  tree-supplied name; the graft conflict message and the snapshot refusal print
  it raw, so an ANSI escape in a branch-controlled filename reaches the terminal.
- **F18** `jim/registry` now has three production spellings (jimconf's
  `default_for`, plus dead-code fallbacks in `jimalloc.sh` and `place.sh`).
- **F19** `place_handle_dir` inlines the id-charset regex instead of calling
  `jimfile.sh valid-id`, which `place.sh` already invokes twice — a fourth
  spelling of the boundary that the triplicate-identical fixture cannot see.
- **F20** `place_valid_branch` and `place_handle_root`'s containment check are
  deliberate duplicates of `alloc_valid_branch` / `alloc_write_contained`, shipped
  without the `SYNC:` comment plus byte-agreement fixture the repo's own
  `is_valid_id` precedent defines.
- **F21** `place_prefix` normalization: `issues_path = "./"` yields prefix `.`
  (the repo root becomes the collection, failing closed on a confusing message);
  `"././docs/issues"` strips only one `./`, so reads work and writes fail opaquely.
- **F22** `place_conf` discards jimconf's exit status, so an unreachable resolver
  falls through to `branch` — a fail-*open* on the infrastructure path, in a
  function whose neighbouring comment promises no silent fallback.

**One claim tested and refuted.** Two investigators disagreed on whether a
newline in a tree entry name causes silent deletion of an untouched file at the
destination. I built the fixture: the victim survived. The forged snapshot key
always names a file that is also in the `after` snapshot, so the skip fires. The
residual is a spurious rc 3 conflict on a path the user never touched — integrity
churn, not data loss.

## Test quality

The suite is mostly honest — the fixtures build what they claim, the four race
cases genuinely race (deterministically, by publishing from inside the wrapped
command rather than by timing), and there is no `{}` hazard in the tests
themselves. `case_place_graft_does_not_reallocate_on_retry` is the strongest case
in the build: it counts registry records and fails at both 2 and 0.

But the audit found problems in my own tests:

- **One case cannot fail.** `case_place_cleans_up_its_temp_directory` discards
  rc, inspects no output, and asserts only that a temp dir is absent. **It passes
  if `place.sh` is deleted entirely.** One added landing assertion fixes it.
- **Three pass for the wrong reason.** `case_issues_placement_read_publishes_nothing`
  and `..._preview_publishes_nothing` assert "tip unmoved" in scenarios where the
  tip cannot move whether or not routing is read-only — `place_changed` guarantees
  it. `case_issues_placement_tolerates_a_branch_only_origin` creates the origin
  file in the working tree, so the origin is present, not dangling (F25).
- **Three cases use `rev-parse` without `--verify`**, so a silently failed
  fixture would compare two identical error strings.
- **`place_seed_collection` checks none of its own exit statuses.**

Worst coverage holes, ranked: the entire **`direct`-token branch of
`begin`/`commit`/`abort`** has zero tests — which is exactly where F3 and F6
live, and exactly what `docsurfaces` tells agents to use "unconditionally";
**`place_prefix`'s unsafe-path refusal**, the one security gate in the script
with no coverage at all; `--id` validation at both call sites; and the entire
**local-tier retry path** (all four race cases use the origin tier, so a
regression dropping the CAS old-value would be invisible).

## Security regressions

Five, all placement-only: F1 (untrusted scalars rewritten into a permanent
identifier), F3 (read handle publishes; documented guarantee false), F24
(Finding 2's mitigation inherited by nobody), F14 (missing containment gate),
F22 (fail-open config resolution). F5 degrades the Critical containment gate's
*reporting* without weakening the gate itself.

The gate itself is sound and I verified it is not vacuous: with the three
per-entry checks removed, a crafted tree writes `PWNED` outside the collection
directory from a *read* verb. With them in place, rc 2 and nothing escapes.

## Living intent

The `issue` group blueprint exists, so the sensor applies. One in-change
invariant violation: **`staleness-gated-reads`** (medium) — F7. The mtime signal
the invariant rests on is destroyed by construction in the materialized dir.

`single-emitter`, `untrusted-body-never-shell`, `id-gate-before-path` and
`atomic-index-write` all hold. `place.sh` never composes issue-file content — it
moves bytes the emitter produced, reading blobs by object name rather than tree
path. The body still travels only as a `--body-file` path, `cat`-copied
file→file, and cannot be reached by the F1 substitution. Note that
`untrusted-body-never-shell`'s scalar half is degraded in spirit by F1: the
encoder is unchanged and still correct, but it is no longer guaranteed to be
encoding what the caller passed.

`invariant_violations: 1`. F15 (a stale Requires face) is a blueprint-currency
gap, not an invariant violation.

## Metrics

15 commits (11 feat, 4 docs/chore), 19 files, +2905/−32. Suite 1262 green in
7m36s. Stage durations: spec 1h46m, research 18m, plan 9h33m, sec 10h26m, build
3h49m.

Measured cost of the routing check on the default path: `place.sh mode` is 27ms
against a 280ms `render.sh list` — about 10%, accepted during the build rather
than reclaimed by duplicating the sentinel check across six scripts.

## Deviations & feedback

The suite's 1262 green tests did not catch four reproducible data defects. The
pattern is worth naming: every one of them lives at a **seam between two states**
the fixtures never put together — online-then-offline (F2, F4), begin-then-switch
(F6), read-token-then-commit (F3). The fixtures test each state in isolation and
each transition's happy path. `place_seed_collection` creating a local branch in
the same repo is the clearest instance: it makes the offline-degrade case
unrepresentable.

The `{}` defect (F1) is a different lesson. It came from choosing a substitution
mechanism (textual replace over all argv) whose blast radius is wider than the
thing it was chosen for (two known placeholder arguments). Nothing about the
design required that width.

Both classes were reachable by reading the code adversarially, which is what the
fan-out did. Neither was reachable by running the suite.
