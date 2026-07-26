---
title: "Neutralize pathspec magic in the ledger git-mv primitives"
type: bug
group: "platform"
id: "005"
status: approved
origin:
  - "docs/issues/20260725-judge-or-fix-rename-tracked-pathspec-use-against-relpath-validat.md"
  - "docs/specs/platform/000-blueprint/spec.md"
---

# 005 Neutralize pathspec magic in the ledger git-mv primitives

## Overview
`jimledger.sh`'s git-mv primitives hand a `valid-relpath`'d — but not
pathspec-neutralized — path to git, diverging from the platform blueprint's
`relpath-validation` invariant; treat those paths literally and restore the
invariant to the blueprint.

## Defect Profile
- **Steps to Reproduce:**
  1. In a repo whose `foo/` directory holds a tracked file, call
     `cmd_rename_tracked` with an old path that carries git pathspec magic yet
     survives the shape / sibling / containment guards — e.g.
     `old=":(glob)foo/*"`, `new=":(glob)foo/renamed"` (shared dirname
     `:(glob)foo`, slug basename `renamed`, both resolve under the worktree via
     `realpath -m`).
  2. Observe the tracked-file check `git ls-files -- "$old"`.
- **Actual Behavior:** git interprets the `:(glob)` magic, so
  `git ls-files -- ":(glob)foo/*"` matches `foo/`'s tracked file and the
  "old path is not tracked" guard *passes* on a path that does not exist as a
  literal tracked entry. An untrusted path is handed to git as an interpretable
  pathspec, contrary to the `relpath-validation` invariant's letter. (Verified
  on git 2.54.0: `git ls-files -- ':(glob)foo/*'` returns `foo/realfile.txt`;
  `GIT_LITERAL_PATHSPECS=1` returns nothing.)
- **Expected Behavior:** every untrusted path handed to git in both primitives
  is treated as a literal filesystem path — pathspec magic is never
  interpreted — so the tracked-file check reflects the literal path's status,
  and the `relpath-validation` invariant is recorded in the platform blueprint
  rather than withheld.
- **Environment:** bash + POSIX scripts, `skills/ledger/scripts/jimledger.sh`
  (`cmd_rename_tracked`, `cmd_move_spec_dir`); git (verified 2.54.0); platform
  group.

## Acceptance Criteria
- [ ] A pathspec-magic-bearing old/source path (e.g. `:(glob)…`, `:/…`,
      `:(exclude)…`, `:!…`) presented to `cmd_rename_tracked` or
      `cmd_move_spec_dir` is treated as a literal path by the tracked-file
      check: a magic string with no matching literal tracked entry yields the
      "not tracked" guard refusal, never a spurious match.
- [ ] Every git invocation in both primitives that receives an untrusted path —
      the tracked-file `git ls-files` check and the `git mv` move — treats that
      path literally, so no untrusted path is handed to git as an interpretable
      pathspec.
- [ ] A legitimate literal sibling rename / spec-dir move (valid slug paths,
      no magic) still succeeds unchanged — neutralization does not regress the
      primitives' normal behavior.
- [ ] The platform group blueprint's Invariants table records the
      `relpath-validation` row, reworded to describe literal-pathspec
      neutralization of every git path argument (superseding the recorded
      "enumerate `git ls-files` without a pathspec and filter in bash"
      mechanism) and noting the rule's project-wide intent, and the fail-closed
      note below the table no longer lists `relpath-validation` among the
      withheld rules.
- [ ] Regression test covers the reported scenario

## Out of Scope
- The **script-preamble rule** (the other invariant withheld in the same
  fail-closed note, tracked separately) stays withheld — this spec removes only
  the `relpath-validation` clause from that note.
- The two sibling untrusted-path→`git ls-files` sites in
  `skills/partition/scripts/jimpartition.sh` (`cmd_rewrite_identity:1694`,
  `cmd_rewrite_refs:1850`) are **blueprint-group** territory and are fixed
  separately (issue #107). This spec restores `relpath-validation` to the
  platform blueprint noting its project-wide intent; the partition sites are
  the outstanding blueprint-group conformance gap.
- `cmd_valid_relpath`'s own shape logic (non-empty / not-absolute / no `..`
  segment) is unchanged — it remains a shape gate, not a pathspec neutralizer.
- The other guards in both primitives (sibling constraint, slug basename,
  `realpath` containment, specs-subtree containment, `[[ -e new ]]`) are
  unchanged.
- The `ref-validation` invariant's `--end-of-options` handling for untrusted
  refs is untouched.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point to
evaluate, not a directive.*

### Insight 1: literal-pathspec neutralization mechanism

- **Relates to AC:** *"every untrusted path handed to git is treated literally"*
  (AC #2)
- **Surfaced as:** the developer directed the fix to use `--literal-pathspecs`
  rather than the invariant's recorded "enumerate `git ls-files` without a
  pathspec and filter in bash" mechanism.
- **Levelled-up requirement (already in the ACs):** the functional need is that
  git never interprets pathspec magic in an untrusted path; the ACs state that
  outcome, not the flag.
- **Deflection reason:** Delegation — the exact form is the architect's/plan's
  call.
- **Architect note:** git exposes two equivalent forms — the top-level option
  `git --literal-pathspecs <cmd>` and the `GIT_LITERAL_PATHSPECS=1` environment
  variable. The env form wraps a single command tidily; the flag form is
  explicit at each call site. Both neutralize all magic (`:(glob)`, `:(top)`,
  `:(exclude)`, `:(attr)`, `:/`, `:!`), verified on git 2.54.0. Note `git mv`
  already rejects magic sources with `fatal: bad source`, so neutralizing it is
  belt-and-suspenders for the invariant's letter rather than a live-sink fix;
  the developer chose uniform coverage across both `git ls-files` and `git mv`.
  The choice is symmetric with the `ref-validation` invariant's use of
  `--end-of-options` for untrusted refs — both are git's own "treat this
  literally" directives.
- **Routing hint:** Architect to decide flag-vs-env form during plan;
  developer-directed mechanism (`--literal-pathspecs` semantics) is settled.

## Open Questions
None
