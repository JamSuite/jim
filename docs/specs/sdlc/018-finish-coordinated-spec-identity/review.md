---
spec: "sdlc/018"
type: "bug"
base_sha: "457d2ff47994a9ed84ddb1441b7b68b2abf4d225"
head_sha: "ff8853e1d0c981c2670c71ff6e34fd11d22190aa"
commits: "26"
commits_test: "2"
commits_feat: "2"
commits_fix: "13"
commits_refactor: "0"
files_changed: "30"
insertions: "2032"
deletions: "153"
spec_runs: "2"
spec_interruptions: "0"
spec_duration_seconds: "17500"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "892"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1558"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "1351"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "12607"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "668"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "7"
security_regressions: "0"
invariant_violations: "8"
contract_violations: ""
alignment: "major-drift"
date: "2026-07-31"
---

# Review: Finish coordinated spec identity

## Summary

**`major-drift`.** Sixteen of seventeen acceptance criteria are met, the suite is
954/954 green with 51 added fixtures and zero pre-existing fixtures modified, and
every defect `sdlc/017`'s review recorded is closed. The verdict is nonetheless
`major-drift`, and the reason is specific: **AC 12 — the criterion promising that
"the realize path cannot silently do the wrong thing where it currently can" —
shipped a new silent-wrong-thing in each of its three clauses.**

- The nesting guard built for its first clause false-positives on `mv`'s
  copy fallback and can strand a realization half-applied (Finding 1).
- The absolute-specs-dir canonicalization built for its second clause makes
  `--apply` from a subdirectory silently no-op at exit 0, contradicting its own
  preview (Finding 2) — and stopped one line short of the sweep's own roots,
  where the same absolute-spelling defect survives (Finding 3).
- The realizer hardening interacts with the index-regeneration fix to create a
  new path that skips regeneration entirely (Finding 4).

That is the same shape as the build being remediated: a green suite, a complete
task list, and correctness gaps that only a deep read surfaces. Recording it
plainly is more useful than a softer verdict — this is the second consecutive
spec in this lineage where test-passing and contract-satisfying diverged, and
the pattern is the finding that matters most.

Investigation: `thorough` depth, 8 investigators against a cap of 10, all on
consumer-tracing and omission-class questions. Two of the three highest-stakes
regions came back satisfied under scrutiny — the region-bounded frontmatter
parsing is correct *by construction* (proof by region), and the citation sweep's
fence tracker and either-side-slash pick withstood every constructed
counterexample.

## Alignment vs spec

Sixteen of seventeen ACs met. The evidence map from AC 1 — each of `sdlc/017`'s
fifteen criteria to the fixtures evidencing it — is in `build-notes.md` and is
not repeated here.

**AC 12 — not met.** Findings 1–4 below. Each of its three clauses shipped a
defect of the class the clause exists to remove.

**AC 4 — met, with an unplanned semantic change.** Two spellings of one ordinal
are now one identity at all three named sites, fixtured by a resume against an
unpadded record. But `alloc_canon_specid` also rejects ordinals wider than
`ALLOC_MAX_ORD_DIGITS`, where the guard it replaced accepted any digits — see
Finding 5.

**AC 9 — met in code, half-evidenced.** The scan and rewrite predicates were
verified to be the *same set* by region proof: no input exists where one matches
a field and the other does not. The AC's second half — "a rewrite that changed
nothing is reported as that identity's failure" — is implemented but has no
fixture (Finding 8).

**AC 13 — met as amended.** The invariant was restated through the blueprint
surface in `sdlc`, the fold was confirmed at a violation fork, and `/jim:verify
sdlc` scored both restated identity clauses holding. AC 13 was amended in place
after the build to scope the restatement to blueprints a live group's
verification consults; the reasoning, including that the amendment followed the
partial result, is recorded in `build-notes.md`.

**AC 17 — met, strongly.** 928 test insertions, 0 deletions: no pre-existing
fixture was modified, which is the strongest available form of the criterion.

## Alignment vs plan

Twenty of twenty-one tasks executed as written, in dependency order, with each
fix landing alongside its fixture. Deviations are enumerated in § Deviations.

No scope creep found: every code change traces to a numbered task. The one edit
beyond the plan's enumeration (a fifth numeric-id framing in
`skills/spec/SKILL.md`) sits inside a file the plan's File Manifest lists and
under AC 14's requirement, and is recorded.

## Alignment vs architecture

Conventions held. Specifically verified:

- **Bash + POSIX, no third-party deps.** `mv -T` was rejected on exactly this
  constraint; `ls -di` was confirmed POSIX and behaviourally identical on GNU and
  BSD for a directory operand, including symlink handling under `-d`.
- **Single `is_valid_id` boundary.** No fourth validator copy; new gates compose
  the existing ones.
- **`BASH_SOURCE`-relative composition**, `set -uo pipefail`, `export LC_ALL=C`
  preambles: unchanged.
- **No spec/issue IDs in code comments**: verified across all four touched
  scripts.
- **`allowed-tools` verb-scoped, no new grants** — the creation halt is inside
  the primitive, exactly as DD 1 intended.

One drift: `ARCHITECTURE.md:258` and `:390`, plus the `cmd_mv_spec` docstring and
one `jimledger.sh` comment, still describe `/jim:spec` renaming its placeholder
via `mv-spec`. It uses `mv-spec-id`; `mv-spec` now has **zero** production
callers. This survived the completion-gate `/jim:arch` refresh performed during
this build (Finding 13).

## Findings

### 1. The nesting guard false-positives on `mv`'s copy fallback and can strand a realization — critical

`undo_nested_rename`'s premise (`jimfile.sh:550-551`) is that "the rename landed
only if `<target>` IS the directory that was at `<src>`". `mv` guarantees the
contents arrive, not the inode. On `EXDEV`, `mv` recursively copies and deletes:
new inode, exit 0, rename correct on disk.

Not reachable via mount points — both paths share a parent, so that is `EBUSY`
and `mv` fails before the guard. It **is** reachable on overlayfs, where renaming
a lower or merged directory returns `EXDEV` by default absent `redirect_dir`, and
where the kernel documentation names `mv(1)` recursively copying as the expected
handling. That is the normal filesystem in containers and microVMs.

Sequence: inode mismatch fires the guard → `$target/$base` does not exist → the
`else` branch reports *"could not be restored — repair `<target>` by hand"* and
returns 1, while the tree is correct. Acting on that instruction is itself the
destructive step.

Downstream, `reconcile.sh:267-270` sets `failed=1; continue`, skipping the
frontmatter rewrite, the `REALIZED` emission, the citation sweep, and the
`moved=` ledger record — with the registry ordinal already durably published.
Retry cannot recover: the directory no longer wears its `P-` basename for the
pending scan to find.

Fix shape, small and detection-preserving: make `$target/$base` the primary tell;
treat "target inode differs AND `$target/$base` absent" as *landed*.

Two supporting defects in the same function: `[[ -n "$src_ino" ]] || return 0`
(`:562`) silently downgrades both verbs to an unguarded `mv` whenever `dir_inode`
yields empty — the check belongs before the move, where refusing is free; and the
restore's own `mv` is unverified, an asymmetry inside a function whose threat
model is a concurrent writer.

Neither guard test drives the code through `cmd_mv_spec`/`cmd_mv_spec_id` — both
call `undo_nested_rename` directly, so the `src_ino` capture and the `|| return 1`
wiring are untested end to end, and the Finding-1 shape has no fixture at all.

### 2. `--apply` from a subdirectory silently does nothing, contradicting its own preview — high

Nothing establishes that CWD equals the worktree top, but the new guard derives
`$dir` relative to `$top` (`reconcile.sh:568`) while every downstream consumer is
CWD-relative. Run `--apply` from `$top/sub`: containment passes, `dir` becomes
`sub/docs/specs`, `[[ -d "$dir" ]]` resolves to `$top/sub/sub/docs/specs`, fails,
and the run prints *"nothing to realize"* and **exits 0**.

The preview path does not rewrite (`:550` gates on `apply`), so from that same
directory the preview lists N pending identities and `--apply` immediately claims
there are none. For a step whose entire contract is preview-then-apply, that is
the wrong failure direction. Introduced by task 15.

Fix: derive the relative form against `$PWD`, or refuse outright when `$PWD` is
not the worktree top. (`realpath --relative-to` is GNU-only and unavailable here.)

### 3. The sweep's roots keep the absolute-spelling defect task 15 was fixing — high

`sweep_citations:352` still consumes all four content roots in their raw
configured spelling, stripping only a trailing `/` and a leading `./`. With an
absolute `issues_path`, `[[ "$f" == "$issues_root"/* ]]` (`:467`) can never match,
because `git ls-files` emits repo-relative paths. Issue citations are rewritten on
disk and `INDEX.md` is **never regenerated** — silently, at exit 0.

That is precisely the failure mode task 12 exists to prevent, in the same
defect class as the one task 15 fixed one line earlier. Normalizing the roots the
way `$dir` is now normalized closes it.

### 4. The issue realizer's new failure path skips index regeneration — high

Task 11 gave `rewrite_num` a non-zero exit when it replaces nothing. The issue
side handles it with `return 1` (`issue/reconcile.sh:182-186`), aborting the batch
**before** the `index.sh` call at `:229` — even though earlier files in the batch
were already rewritten. Stale index, the exact failure mode task 12 exists to
prevent, now reachable through the door task 11 opened.

The spec side handles the same rc asymmetrically (`failed=1; continue`), which
leaves a different residue: the directory is already renamed, so the identity is
omitted from `applied` and therefore from the remap — moved directory,
still-provisional frontmatter, un-swept citations, no ledger row, rc 1.

### 5. Canonicalization silently narrowed the ordinal width resolve accepts — notable

`alloc_canon_specid` rejects an ordinal wider than `ALLOC_MAX_ORD_DIGITS`; the
`alloc_valid_specid` guard it replaced accepted any `^[0-9]+$`. Three divergences
for inputs that previously resolved: an over-wide query now errors; a rename
record with an over-wide side no longer anchors, turning a resolvable id into
`not allocated` (rc 1); and a rename *to* an over-wide destination is not applied,
so resolve returns the pre-rename name silently at rc 0.

All are crafted-log-only — this build cannot mint such a record — and the change
is arguably correct hardening that brings resolve under the width policy the
constant already declares. But DD 2 specified padding, never width. It rode in
from reusing the helper as the guard, and **none of the three is fixtured**.

### 6. `cmd_path`'s new arity is absent from the script's own help — notable

`jimfile.sh`'s CLI SUMMARY (`:37-39`), the `cmd_path` docstring (`:920-923`), and
`usage()` (`:1145-1147`) all still show only the three-argument form, so `--help`
omits the provisional arity entirely. `ARCHITECTURE.md:390` documents it
correctly — the script that implements it does not. The sibling `mv-spec-id` has
the same gap in its `usage()` entry, so this is consistent drift across both
two-arity verbs.

### 7. Unchecked awk exit status can install a truncated file — notable

`sweep_citations` does not check awk's exit status (`:463`) before
`cat -- "$tmp_out" > "$f"` (`:465`). A mid-stream awk failure after at least one
`REWROTE` record would install a truncated `tmp_out` over a real tracked file.

### 8. A named plan fixture was never written — notable

Plan task 11 enumerates four fixtures; three exist. "Forced no-op rewrite fails
loudly" does not — no test asserts either realizer's `rewrite failed` message or
the rc-1 path. The behavior is implemented; the criterion is unevidenced, against
AC 1's requirement that each executable criterion carry at least one fixture. It
was judged unreachable from the CLI during the build (the two predicates are
provably the same set, so a bounded scan cannot find a field the bounded rewrite
misses) — but Finding 4 shows the rc-1 path *does* have reachable consequences
worth pinning.

Plan task 13's "unclosed fence does not skip the tail" is likewise unwritten, and
is not assertable as worded: under correct CommonMark semantics an unclosed fence
*does* extend to EOF. The clause described a symptom of the toggle bug, not a
target behavior.

### 9. The spec template now ships an `id:` line one slip from a silent skip — notable

`spec-template.md:5` was changed this build to
`id: "{id}"      # the bound identity: …`. An author who fills the value but
leaves the trailing comment produces a frontmatter `id` that does not equal the
directory basename, so the spec is silently treated as **not pending** — a
warning and a skip. Not a regression (the old parser behaved identically), but
this build is what put the comment into the shipped template.

### 10. A symlinked own-directory entry is written through, defeating root scoping — notable

`sweep_citations` applies two of the three guards from the `rewrite-identity`
precedent it cites: worktree containment and relpath shape, but not
tracked-ness — which `own_dirs` must drop to do its job. A symlink inside a
realized directory pointing at an in-worktree file passes containment, and `>`
writes through to the link target. Containment itself holds (the escape case is
refused and fixtured), but the four-content-roots scoping does not: a link can
reach `.github/`, `flake.nix`, `pre-commit.sh`. One `[[ -L "$entry" ]] && continue`
closes it at no cost — a symlink is never a spec's own body.

Related, lower: `:563`'s `realpath` result is unchecked, the one guard here whose
failure mode is *pass* rather than refuse.

### 11. The occupancy predicate's width skip contradicts `next-id`'s width count — advisory

`spec_ordinal_holder` skips a sibling token wider than 15 digits (deliberate,
fixtured), while `cmd_next_id` strips leading zeros and counts any width. A
19-digit-padded `…018-wide` therefore floors `next-id` to `019` while reading as
"018 is free" to the occupancy gate, permitting a padding twin. Hand-made only,
but a genuine hole in the invariant AC 3 and AC 4 assert.

### 12. The structural guarantee stops at the partition move primitives — advisory

`jimledger.sh move-spec-dir` and `rename-tracked` refuse only an exactly-existing
destination and never consult `spec_ordinal_holder`, so split/merge renumbering
can still land a padding-variant twin. DD 1's "structural, not discipline" claim
holds for the spec-creation and realize paths, and stops there.

### 13. `mv-spec` prose survived the completion-gate architecture refresh — advisory

See § Alignment vs architecture. `mv-spec` has zero production callers; four
documentation sites still name it as the placeholder-rename verb, including two
in `ARCHITECTURE.md` that this build's own `/jim:arch` pass did not catch.

## Living intent

The sensor did **not** re-run in this review. A full on-demand `/jim:verify sdlc`
was executed earlier in the same session (recorded on
`docs/specs/sdlc/000-blueprint/ledger.md`, committed `b4f7a16`), and no file the
sensor would judge changed between that run and this review — the only
subsequent commits touched `ARCHITECTURE.md`, `ledger.md`, and `spec.md`. Its
results are carried forward here rather than spending a second judge fan-out on
identical code.

**Named limitation:** an on-demand run produces no channel tags. The
`in-change` / `pre-existing` classification that routes findings between the
Step-9 batch and the Step-10 fork is therefore absent, and I have not
substituted my own judgment for the engine's classifier. Re-run
`/jim:verify --from-review docs/specs/sdlc/018-finish-coordinated-spec-identity sdlc`
if the routing distinction is needed.

Results (12 invariants; appetite `low`; territory declared; 0 registry commands
configured; judge fan-out 10 of 11, `arch-via-skill` the named remainder):

| invariant | criticality | outcome |
| :--- | :--- | :--- |
| plugin-name | critical | violated (partial) |
| allowed-tools-exact | critical | violated (partial) |
| injection-set-rhs | critical | violated (partial) |
| untrusted-content | critical | violated (partial) |
| sentinel-vocab | high | violated (partial) |
| sigil-discipline | high | violated (partial) |
| agent-boundaries | high | violated (partial) |
| spec-id-sequencing | high | violated (partial) |
| name-matches-path | high | holds |
| fold-back-sensor-obligations | high | holds |
| skill-budget | medium | unconfigured |
| arch-via-skill | medium | skipped (fan-out cap) |

Sensed 12 · holds 2 · violated 8 · unconfigured 1 · skipped 1. Territory
conformance: 0 strays, 611 files bucketed (all other groups' declared territory
or scaffolding).

**None of the eight was introduced by this build.** Seven were filed as
#161–#167; the eighth (`untrusted-content`) was already open as #53. The
`spec-id-sequencing` partial is clause 3 only — the two identity clauses this
spec restated both verified holding, which is the evidence AC 13 asks for.

The contract-edge phase did not run: the graph names `sdlc` as a provider only
for its persona bindings, and this build changed no agent definition.

## Metrics

26 commits over `457d2ff..ff8853e` — 13 `fix`, 2 `feat`, 2 `test`, 0 `refactor`
— 30 files, +2032/−153. Stage durations: spec 17500s over 2 runs (the second is
the post-build AC 13 amendment), research 892s, plan 1558s, sec 1351s over 2
runs, build 12607s, review 668s. Zero interruptions on every stage.

The `fix`-dominated commit profile matches a remediation spec. The 2 `test`
commits understate the test work: 51 fixtures landed, most inside the `fix`
commits alongside the defect each pins, which is the intended Red-Green pairing
rather than a metric anomaly.

**Coverage gap in this review's own range.** `head_sha` is the build's finish
SHA, so three later commits are outside the diff spine: the `/jim:arch` refresh
(`e5b21a6`), the ledger close (`6544ce2`), and the AC 13 amendment (`9726815`).
They were assessed directly rather than through the spine — Finding 13 is a
result of that assessment.

## Security regressions

**None.** The build's security-relevant changes strengthen the posture:

- The realized ordinal — the one registry-derived token that previously reached a
  path, a glob, a git argument, and frontmatter ungated — now crosses the id
  boundary before first use.
- The widened citation-sweep enumeration was verified to apply worktree
  containment to **every** added path before any file is opened for write; both
  refusal arms return with zero files written and the temp directory not yet
  created. Security review Finding 2 is genuinely satisfied, and the symlink
  escape is refused and fixtured.
- A crafted unpadded record can no longer split a resumed realization from its
  own prior record.

Two hardening opportunities, neither a regression: Finding 10's symlink
write-through (scoping, not containment) and Finding 1's fail-open when
`dir_inode` yields empty.

## Deviations and feedback

1. **Task 20 — the `jim` blueprint fold was declined.** Spec-aligned after the
   AC 13 amendment; still divergent from the plan's task-20 text and Verify
   command, which name the retired group. Task 20 left unchecked rather than
   marked against superseded text.
2. **Task 20 — `/jim:verify jim` skipped.** A retired group has no territory, so
   the run would degrade to `UNSCOPED` and score a superseded document repo-wide.
3. **Task 11 — a named fixture was never written** (Finding 8).
4. **Task 13 — a named fixture was never written** and is unassertable as worded
   (Finding 8).
5. **Task 15's fix is incomplete** (Finding 3).
6. **AC 14 — one site beyond the plan's enumeration was corrected**, inside a
   file the File Manifest lists.
7. **All fourteen issues this spec was scoped to close are still `status:
   open`** — #133, #134, #145–#151, #156–#160. The build fixed every one of them
   and closed none. No plan task covered closing them, so this is a gap in the
   plan rather than a build failure, but the collection now misrepresents the
   project's state.

### Feedback on the process

The two deep-read results worth carrying forward are the ones that came back
**satisfied**: the region-bounded frontmatter parsing is correct by construction
(the scan and rewrite predicates are provably the same set), and the citation
sweep withstood every constructed counterexample. Those are the two defects
`sdlc/017` shipped, and they are properly closed.

The failures cluster in code written to satisfy AC 12 — the criterion about
eliminating silent wrong behavior. Three of its three clauses shipped a new
silent-wrong-behavior path. The common factor is that each was a *new* guard
rather than a corrected one, and new guards had no prior fixture shape to
inherit. The nesting guard in particular was built against a race that cannot be
produced deterministically from the CLI, so its fixtures exercise the function
directly and never the wiring — which is exactly where Finding 1 lives.
