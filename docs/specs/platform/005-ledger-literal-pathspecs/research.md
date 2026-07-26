---
spec: "spec.md"
status: Needs PM Review
date: "2026-07-26"
---

# Research: Neutralize pathspec magic in the ledger git-mv primitives

## Anchors

**Fix targets** — `skills/ledger/scripts/jimledger.sh`:
- `cmd_rename_tracked` — `:304` `git ls-files -- "$old"` (the live magic sink) and `:310` `git mv -- "$old" "$new"`. Guards before git: `valid-relpath` (277/280), sibling-dir + slug-basename (285-291), realpath worktree containment (299-303). `$old` is valid-relpath-gated but **not** full-slug-gated, so a leading `:` (pathspec magic) survives to git.
- `cmd_move_spec_dir` — `:602` `git ls-files -- "$src"` and `:611` `git mv -- "$src" "$dst"`. More tightly gated (both groups slug-checked, basenames shape-checked, specs-subtree containment 594-601) but still assembled from operator input.

**Convention to mirror** — `skills/ledger/scripts/jimledger.sh:127-139` (`resolve_ref`, line 134): `git rev-parse --verify --end-of-options "$ref^{commit}"` is the existing "neutralize git's interpretation of an untrusted token" precedent, there for **refs**. This fix adds the **pathspec** analogue (`--literal-pathspecs` / `GIT_LITERAL_PATHSPECS`) — the symmetric directive.

**Shape gate (does not neutralize magic)** — `skills/file/scripts/jimfile.sh:227-244` (`cmd_valid_relpath`): exit 0 iff non-empty, not absolute, no `..` *segment*. Existence and pathspec-magic are deliberately out of its contract.

**Blueprint to restore** — `docs/specs/platform/000-blueprint/spec.md:88-109`: the Invariants table (88-98) plus the fail-closed note (104-109) that currently withholds `relpath-validation`. The row returns to the table; the note drops the `relpath-validation` clause (keeping the script-preamble clause, issue #99).

**Test anchors** — `tests/jimledger.sh`:
- Fixtures: `rename_git_fixture` (`:1147-1159`, tracked group spec dir + territory, prints repo root) and `move_git_fixture` (`:1391-1402`) — the scratch repos the two primitives' cases already use.
- Invoker: `run_jimledger_in <dir> <args>` (`:1137-1143`) runs the CWD-repo git verbs against the fixture.
- Existing cases to sit beside: rename-tracked `:1133-1315` (e.g. `case_jimledger_rename_tracked_refuses_untracked` `:1175-1181`, an rc-1 refusal template); move-spec-dir `:1387-1478`.
- Conventions: `skills/meta-test/scripts/testlib.sh` — name-discovered `case_*` fns; `assert_exit`, `assert_match` on `OUT/ERR/RC`.

## Local Patterns

- **Regression test shape:** mirror the `refuses_untracked` cases — feed each primitive a magic-bearing path (`:(glob)…/*`) that *would* spuriously match under magic, and assert it now refuses with rc 1 and the "not tracked" message. Use `rename_git_fixture` / `move_git_fixture` + `run_jimledger_in`; assert via `assert_exit`/`assert_match`. No new fixture machinery needed.
- **Neutralization is per-call, not global.** Follow `resolve_ref`'s inline style — the directive rides the specific git invocation, never a repo-wide `git config` or exported env (see guardrail below).

## Security & Performance

Empirically verified in-session (git 2.54.0):
- `git ls-files -- ':(glob)foo/*'` **spuriously matches** `foo/`'s tracked file; `GIT_LITERAL_PATHSPECS=1` returns nothing (magic neutralized). This is the live defect.
- `git mv` **already rejects** magic sources (`fatal: bad source`, rc 128) — so neutralizing the two `git mv` calls is belt-and-suspenders for the invariant's letter, not a live-sink fix. (Confirmed scope decision: neutralize both `ls-files` and `mv` uniformly.)
- Literal-pathspec semantics do **not** regress legitimate use: the tracked-**directory** check (`git ls-files -- 'docs/specs/grp/oldslug'`) and directory `git mv` both still succeed (rc 0) — AC #3 grounded.

**Guardrail for the coder:** apply the neutralizer to the two primitives' untrusted-path git calls **only**. Do **not** set a global `git config` or a repo-wide `GIT_LITERAL_PATHSPECS` export — `scripts/jim-deps-refs.sh:55,72,81,88,99,108,117` relies on **intentional literal-glob pathspecs** (e.g. `git ls-files -- 'skills/*/SKILL.md'`) that blanket neutralization would silently stop matching.

## Recommendations

*Options/trade-offs for the architect — not decisions.*

1. **Form (already deflected to spec Handoff Insight 1):** `GIT_LITERAL_PATHSPECS=1 git …` (env — wraps one command tidily) vs `git --literal-pathspecs <cmd>` (flag — explicit at each call site, parallels `resolve_ref`'s inline `--end-of-options`). Both verified equivalent; slight lean to the flag form for self-documentation and symmetry.
2. **Coverage:** all four calls (2 primitives × {`ls-files`, `mv`}), per the confirmed uniform-scope decision.
3. **Tests:** one refusal case per primitive (rc 1 + "not tracked" on a magic path), placed beside the existing rename-tracked / move-spec-dir sections.
4. **Invariant rewording:** state the outcome ("every untrusted path is handed to git only under literal-pathspec semantics"), superseding the recorded "enumerate `git ls-files` without a pathspec and filter in bash" mechanism — `--literal-pathspecs` achieves the same guarantee more simply and is the git-native analogue of the ref rule.

**Alignment:** aligns with VISION (executable institutional memory — a verifiable invariant returns to the blueprint) and ARCHITECTURE (bash + POSIX, no third-party dep; `--literal-pathspecs` is native git; mirrors the existing `--end-of-options` ref-safety convention). No divergence from a locked constraint.

## Peer Feedback

**For PM (spec scope) — Needs PM Review.** The `relpath-validation` rule's intent is project-wide ("an untrusted path is never handed to git as a pathspec"), but the ledger primitives are **not** the only sites. `skills/partition/scripts/jimpartition.sh` (blueprint group) has two siblings with the same class of exposure — an untrusted, valid-relpath-gated-but-not-slug-gated path handed to `git ls-files` as a pathspec:
- `cmd_rewrite_identity` — `:1694` `git ls-files -- "$f"`
- `cmd_rewrite_refs` — `:1850` `git ls-files -- "$f"`

(Both are `ls-files`-only tracked-checks — the actual edits go through awk, not git, so there is no `git mv` there.)

This spec deliberately stays **in the platform group** and fixes only the ledger primitives. The decision for you: **(a)** restore the invariant to the platform blueprint noting its project-wide applicability, and file a **blueprint-group** follow-on to neutralize the two partition sites (recommended — preserves group boundaries; a candidate issue is queued in this run's batch), or **(b)** treat the partition fix as a blocking dependency of this spec. Recommend (a). Either way, the spec's Out of Scope should explicitly name the two partition sites so the boundary is unambiguous.
