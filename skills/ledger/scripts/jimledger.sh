#!/usr/bin/env bash
#
# skills/ledger/scripts/jimledger.sh — jim ledger for the /jim:review phase.
#
# Records the build's boundary and process events to <spec-dir>/ledger.md (an
# append-only, line-oriented log) and derives metrics from git + the ledger for
# the reviewer. This is the only jim script that reads git operationally.
#
# Subcommands:
#   start   <spec-dir>                         append a build-started event (base_sha)
#   finish  <spec-dir>                         append a build-finished event (head_sha)
#   event   <spec-dir> <phase> <event> [k=v…]  append a generic event
#   metrics <spec-dir>                         emit git + per-stage ledger key=value lines
#   events  <spec-dir>                         print recorded events (read-only view)
#   files   <spec-dir>                         list changed file paths over base..head
#   diff    <spec-dir>                         emit the diff (function-context) over base..head
#   diff-range <base> [head]                   emit the diff over a validated CWD-repo range
#   files-range <base> [head]                  list changed paths over a validated CWD-repo range
#   commit-review <spec-dir> [verdict]         commit review.md + ledger.md (path-scoped)
#   commit-blueprint <blueprint-dir> [create|update]  commit spec.md + ledger.md (path-scoped)
#   commit-map <map-path> <specs-dir> [create|update]  commit project map + specs-root ledger
#   commit-verify <blueprint-dir> [verify|health]  commit ledger.md only (verify/health self-commit)
#   updates-since <blueprint-dir> <iso>       count blueprint finished events after <iso>
#   reconcile-series <specs-dir>              full reconcile event series → EVENT/EXCLUDED
#
# Ledger line format (TAB-separated): <epoch>\t<iso8601>\t<phase>\t<event>\t<kv>
#
# Security: commit/diff/ledger content is untrusted — never sourced or eval'd.
# SHAs read from the ledger are validated via jimfile.sh `valid-id` before any
# git range use (forecloses option injection). The script commits in exactly
# seven path-scoped places — `commit-review` (review.md + ledger.md),
# `commit-blueprint` (a group's spec.md + ledger.md), `commit-map` (the
# project map + the specs-root ledger.md), `commit-verify` (a group's ledger.md
# alone), `commit-rename` (a rename's explicit stage set), `commit-split`
# (a split's explicit docs stage set), and `commit-merge` (a merge's explicit
# docs stage set) — each with literal paths, a `--` guard, and no `git add -A`;
# `/jim:build` commits ledger.md at start/finish itself. `rename-tracked`
# (sibling) and `move-spec-dir` (cross-parent) additionally do a guarded
# `git mv` — staging but not committing.

set -uo pipefail
export LC_ALL=C

# jimfile.sh provides the single is_valid_id boundary (via `valid-id`). Resolved
# BASH_SOURCE-relative so it travels with the plugin tree.
JIMFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../file/scripts" 2>/dev/null && pwd)/jimfile.sh"

usage() {
  cat >&2 <<'USAGE'
usage: jimledger.sh <subcommand> <spec-dir> [args]
  start   <spec-dir>                          record build start (base_sha)
  finish  <spec-dir>                          record build finish (head_sha)
  event   <spec-dir> <phase> <event> [k=v …]  append a generic event
  rename-tracked <old-path> <new-path>        sibling-constrained git mv
  move-spec-dir <specs-dir> <og> <src-base> <ng> <dst-base>  cross-parent spec-dir git mv
  vacated-max <specs-dir> <group>             highest split-vacated id for <group>
  pair-events <specs-dir>                     durable identity-pair events, normalized
  metrics <spec-dir>                          emit key=value metrics to stdout
  events  <spec-dir>                          print recorded events (read-only view)
  files   <spec-dir>                          list changed files over the build range
  diff    <spec-dir>                          emit the diff (function-context) over the build range
  diff-range <base> [head]                    emit the diff over a validated CWD-repo range
  files-range <base> [head]                   list changed paths over a validated CWD-repo range
  commit-review <spec-dir> [verdict]          commit review.md + ledger.md (path-scoped)
  commit-blueprint <blueprint-dir> [create|update]  commit spec.md + ledger.md
  commit-map <map-path> <specs-dir> [create|update]  commit project map + specs-root ledger
  commit-verify <blueprint-dir> [verify|health]  commit ledger.md only (verify/health self-commit)
  commit-rename <specs-dir> <old> <new> <docs|code> <path...>  commit a rename stage set
  commit-split <specs-dir> <old> <targets-csv> <path...>  commit a split stage set
  commit-merge <specs-dir> <target> <sources-csv> [--rekey <o:n,...>] <path...>  commit a merge stage set
  updates-since <blueprint-dir> <iso>         count blueprint finished events after <iso>
  last-reconcile <specs-dir>                  prior reconcile event: iso + documented counters
  reconcile-series <specs-dir>                full reconcile event series → EVENT/EXCLUDED
USAGE
}

# append_line <spec-dir> <phase> <event> <kv>
#   Append one TAB-separated event to <spec-dir>/ledger.md.
append_line() {
  local dir="$1" phase="$2" event="$3" kv="$4"
  if [[ ! -d "$dir" ]]; then
    echo "jimledger: spec-dir not found: $dir" >&2
    return 2
  fi
  local epoch iso
  epoch="$(date -u +%s)"
  iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "$iso" "$phase" "$event" "$kv" >> "$dir/ledger.md"
}

# validate_sha <sha> — return 0 iff <sha> passes jimfile.sh's is_valid_id.
validate_sha() {
  bash "$JIMFILE" valid-id "$1" >/dev/null 2>&1
}

# resolve_head <spec-dir> — echo the validated HEAD sha of the repo containing
#   <spec-dir>, or return 2 (not a repo / no HEAD / invalid sha).
resolve_head() {
  local dir="$1" sha
  sha="$(git -C "$dir" rev-parse HEAD 2>/dev/null)" || {
    echo "jimledger: not a git repo or no HEAD: $dir" >&2
    return 2
  }
  if ! validate_sha "$sha"; then
    echo "jimledger: refusing malformed sha: $sha" >&2
    return 2
  fi
  printf '%s' "$sha"
}

# valid_git_ref <ref> — return 0 iff <ref> is safe to hand to git as a rev:
#   non-empty, no leading '-' (option injection), only ref-name-safe bytes
#   (letters, digits, / . _ -), no '..', no leading/trailing '/'. Accepts
#   branch/tag/SHA refs including '/'-bearing ones (origin/main) — which
#   is_valid_id would wrongly reject — while foreclosing option/metacharacter
#   injection. Rev expressions (HEAD~3, a^, a:b) are
#   intentionally rejected; pass a plain ref or SHA.
valid_git_ref() {
  local ref="$1"
  [[ -n "$ref" ]] || return 1
  [[ "$ref" == -* ]] && return 1
  [[ "$ref" =~ ^[A-Za-z0-9._/-]+$ ]] || return 1
  [[ "$ref" == *".."* ]] && return 1
  [[ "$ref" == /* || "$ref" == */ ]] && return 1
  return 0
}

# resolve_ref <ref> — validate <ref> and resolve it to a commit SHA in the repo
#   at CWD, or return 1. `git rev-parse --verify --end-of-options` guarantees the
#   ref can never be parsed as an option; the resulting SHA is re-validated
#   through the single is_valid_id boundary before a caller ranges on it.
resolve_ref() {
  local ref="$1" sha
  if ! valid_git_ref "$ref"; then echo "jimledger: invalid git ref: $ref" >&2; return 1; fi
  sha="$(git rev-parse --verify --end-of-options "$ref^{commit}" 2>/dev/null)" || {
    echo "jimledger: unresolvable git ref: $ref" >&2; return 1;
  }
  if ! validate_sha "$sha"; then echo "jimledger: refusing malformed sha: $sha" >&2; return 1; fi
  printf '%s' "$sha"
}

# cmd_start <spec-dir> — record the build baseline.
cmd_start() {
  local dir="${1:-}" sha
  if [[ -z "$dir" ]]; then echo "jimledger start: need <spec-dir>" >&2; return 2; fi
  sha="$(resolve_head "$dir")" || return 2
  append_line "$dir" build started "base_sha=$sha"
}

# cmd_finish <spec-dir> — record the build head.
cmd_finish() {
  local dir="${1:-}" sha
  if [[ -z "$dir" ]]; then echo "jimledger finish: need <spec-dir>" >&2; return 2; fi
  sha="$(resolve_head "$dir")" || return 2
  append_line "$dir" build finished "head_sha=$sha"
}

# cmd_commit_review <spec-dir> [verdict] — the single audited git-write site:
#   commit review.md + ledger.md together in one path-scoped commit so a
#   completed review's verdict and metrics are durably recorded without a manual
#   step. Literal paths with a `--` guard, never `git add -A`; the
#   message carries only the trusted-origin verdict enum. Any git failure
#   returns non-zero so the caller degrades with review.md left intact.
cmd_commit_review() {
  local dir="${1:-}" verdict="${2:-}"
  if [[ -z "$dir" ]]; then echo "jimledger commit-review: need <spec-dir>" >&2; return 2; fi
  if [[ ! -d "$dir" ]]; then echo "jimledger: spec-dir not found: $dir" >&2; return 2; fi
  local msg="chore(review): record review"
  case "$verdict" in
    aligned|minor-drift|major-drift) msg="chore(review): record review ($verdict)" ;;
  esac
  git -C "$dir" add -- review.md ledger.md || return 2
  git -C "$dir" commit -q -m "$msg" -- review.md ledger.md || return 2
}

# cmd_commit_blueprint <blueprint-dir> — path-scoped commit of the refreshed
#   blueprint: spec.md + ledger.md inside <blueprint-dir>, mirroring
#   commit-review's discipline (literal paths, `--` guard, never `git add -A`).
#   The blueprint lives in <group>/000-blueprint/, a
#   different dir than the reviewed spec, so it gets its own path-scoped commit
#   rather than riding commit-review. Any git failure returns non-zero so the
#   caller degrades.
cmd_commit_blueprint() {
  local dir="${1:-}" mode="${2:-update}"
  if [[ -z "$dir" ]]; then echo "jimledger commit-blueprint: need <blueprint-dir>" >&2; return 2; fi
  if [[ ! -d "$dir" ]]; then echo "jimledger: blueprint-dir not found: $dir" >&2; return 2; fi
  # Whitelist the mode to create|update; anything else (or absent) maps to
  # update so the commit subject stays well-formed and non-injectable. A
  # first-time create (the U2 fallthrough) passes 'create'.
  [[ "$mode" == "create" ]] || mode="update"
  git -C "$dir" add -- spec.md ledger.md || return 2
  git -C "$dir" commit -q -m "docs(blueprint): $mode 000-blueprint" -- spec.md ledger.md || return 2
}

# cmd_commit_map <map-path> <specs-dir> [create|update] — path-scoped commit of
#   the project-tier context map: <map-path> + <specs-dir>/ledger.md in the repo
#   at CWD. BOTH path arguments are config-derived
#   (blueprint_path / specs_path) and clear two containment gates before git
#   runs: the jimfile `valid-relpath` boundary (relative, no
#   '..' segment), then a literal check that each git-add target resolves inside
#   `git rev-parse --show-toplevel` — backstopping valid-relpath and git's own
#   symlink refusal against a shape-valid path that symlinks out of the worktree.
#   Literal paths, `--` guard, never `git add -A`; mode whitelisted like
#   commit-blueprint. Any git failure returns non-zero so the caller degrades
#   with the map left intact on disk.
cmd_commit_map() {
  local map="${1:-}" specs_dir="${2:-}" mode="${3:-update}"
  if [[ -z "$map" || -z "$specs_dir" ]]; then
    echo "jimledger commit-map: need <map-path> <specs-dir> [create|update]" >&2
    return 2
  fi
  if ! bash "$JIMFILE" valid-relpath "$map" >/dev/null 2>&1; then
    echo "jimledger commit-map: unsafe map path rejected" >&2
    return 2
  fi
  if ! bash "$JIMFILE" valid-relpath "$specs_dir" >/dev/null 2>&1; then
    echo "jimledger commit-map: unsafe specs dir rejected" >&2
    return 2
  fi
  local top
  if ! top="$(git rev-parse --show-toplevel 2>/dev/null)" || [[ -z "$top" ]]; then
    echo "jimledger commit-map: not in a git repo" >&2
    return 2
  fi
  [[ "$mode" == "create" ]] || mode="update"
  local ledger="${specs_dir%/}/ledger.md"
  # Containment: each git-add target must resolve inside the worktree top,
  # rejecting a shape-valid path that symlinks out of the tree before git runs.
  local target resolved
  for target in "$map" "$ledger"; do
    if ! resolved="$(realpath -m -- "$target" 2>/dev/null)" || [[ "$resolved" != "$top"/* ]]; then
      echo "jimledger commit-map: path escapes worktree: $target" >&2
      return 2
    fi
  done
  git add -- "$map" "$ledger" || return 2
  git commit -q -m "docs(blueprint): $mode project map" -- "$map" "$ledger" || return 2
}

# cmd_commit_verify <blueprint-dir> [verify|health] — path-scoped commit of a
#   read-only run's self-recorded ledger event: ledger.md alone inside
#   <blueprint-dir>. A verify run and a partition-health run
#   both write NO artifact and are on-demand with no approval gesture to ride, so
#   each self-commits its own ledger record, modeled on commit-blueprint's
#   fix-only path (ledger.md alone falls out of pathspec staging for free). The
#   optional mode selects the subject from a two-entry whitelist (default
#   `verify`); an unrecognized mode is rejected rc 2 so no untrusted input ever
#   reaches the commit message. Literal path, `--` guard, never `git add -A`. Any
#   git failure returns non-zero so the caller degrades with the ledger intact.
cmd_commit_verify() {
  local dir="${1:-}" mode="${2:-verify}"
  if [[ -z "$dir" ]]; then echo "jimledger commit-verify: need <blueprint-dir> [verify|health]" >&2; return 2; fi
  if [[ ! -d "$dir" ]]; then echo "jimledger: blueprint-dir not found: $dir" >&2; return 2; fi
  local subject
  case "$mode" in
    verify) subject="chore(verify): record verification run" ;;
    health) subject="chore(health): record partition-health run" ;;
    *) echo "jimledger commit-verify: mode must be verify or health: $mode" >&2; return 2 ;;
  esac
  git -C "$dir" add -- ledger.md || return 2
  git -C "$dir" commit -q -m "$subject" -- ledger.md || return 2
}

# cmd_rename_tracked <old-path> <new-path> — history-continuous `git mv` of a
#   tracked path, constrained to a SIBLING rename so it can never relocate an
#   arbitrary repo file. Guards, all before git runs:
#   both paths clear the jimfile valid-relpath boundary; dirname(old) ==
#   dirname(new) with basename(new) a valid group slug (the sibling constraint);
#   both resolve inside `git rev-parse --show-toplevel` (containment, backstopping
#   valid-relpath against a symlink escape); <old> is tracked; <new> does not yet
#   exist. Operates on the repo at CWD. rc 0 renamed · rc 1 guard refusal (named)
#   · rc 2 usage.
cmd_rename_tracked() {
  local old="${1:-}" new="${2:-}"
  if [[ -z "$old" || -z "$new" ]]; then
    echo "jimledger rename-tracked: need <old-path> <new-path>" >&2; return 2
  fi
  if ! bash "$JIMFILE" valid-relpath "$old" >/dev/null 2>&1; then
    echo "jimledger rename-tracked: unsafe old path rejected: $old" >&2; return 1
  fi
  if ! bash "$JIMFILE" valid-relpath "$new" >/dev/null 2>&1; then
    echo "jimledger rename-tracked: unsafe new path rejected: $new" >&2; return 1
  fi
  # Sibling-rename constraint: same parent directory, new basename a valid slug.
  local old_dir new_dir new_base
  old_dir="$(dirname -- "$old")"; new_dir="$(dirname -- "$new")"; new_base="$(basename -- "$new")"
  if [[ "$old_dir" != "$new_dir" ]]; then
    echo "jimledger rename-tracked: not a sibling rename ($old_dir != $new_dir)" >&2; return 1
  fi
  if [[ ! "$new_base" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "jimledger rename-tracked: new basename not a valid slug: $new_base" >&2; return 1
  fi
  local top
  if ! top="$(git rev-parse --show-toplevel 2>/dev/null)" || [[ -z "$top" ]]; then
    echo "jimledger rename-tracked: not in a git repo" >&2; return 1
  fi
  # Containment: each path resolves inside the worktree top (rejects a shape-valid
  # path that symlinks out of the tree before git runs).
  local rp resolved
  for rp in "$old" "$new"; do
    if ! resolved="$(realpath -m -- "$rp" 2>/dev/null)" || [[ "$resolved" != "$top"/* ]]; then
      echo "jimledger rename-tracked: path escapes worktree: $rp" >&2; return 1
    fi
  done
  # Hand every path to git only literally: valid-relpath does not neutralize
  # pathspec magic, so --literal-pathspecs keeps a magic-bearing path from being
  # interpreted as a pathspec at the tracked-check or the move.
  if [[ -z "$(git --literal-pathspecs ls-files -- "$old" 2>/dev/null)" ]]; then
    echo "jimledger rename-tracked: old path is not tracked: $old" >&2; return 1
  fi
  if [[ -e "$new" ]]; then
    echo "jimledger rename-tracked: new path already exists: $new" >&2; return 1
  fi
  git --literal-pathspecs mv -- "$old" "$new" || {
    echo "jimledger rename-tracked: git mv failed: $old -> $new" >&2; return 1
  }
}

# cmd_commit_rename <specs-dir> <old> <new> <docs|code> <path...> — the fifth
#   path-scoped commit site: land one atomic commit of a rename's stage set,
#   composed from explicit literal paths only (no globs), so an
#   uncommitted change outside the set can never ride it. The `docs` stage
#   auto-includes the moved spec-dir PAIR (<specs-dir>/<old> deleted +
#   <specs-dir>/<new> added, both already staged by rename-tracked) so the rename
#   commits atomically; the explicit args are the touched blueprint files. The
#   `code` stage takes its complete set (the moved territory pair + each
#   import-fixed file) as explicit args. `git add` runs only on paths that still
#   exist (a gone old path is already staged; adding it would error); the commit
#   pathspec covers the whole set so the staged deletion lands with it. Subjects
#   are composed in-script from the slug-validated <old>/<new> only. rc 0
#   committed · rc 1 nothing staged / guard refusal · rc 2 usage.
cmd_commit_rename() {
  local specs_dir="${1:-}" old="${2:-}" new="${3:-}" stage="${4:-}"
  if [[ -z "$specs_dir" || -z "$old" || -z "$new" || -z "$stage" ]]; then
    echo "jimledger commit-rename: need <specs-dir> <old> <new> <docs|code> <path...>" >&2; return 2
  fi
  shift 4
  case "$stage" in docs|code) ;; *) echo "jimledger commit-rename: stage must be docs or code: $stage" >&2; return 2 ;; esac
  if [[ ! "$old" =~ ^[a-z0-9][a-z0-9-]*$ || ! "$new" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "jimledger commit-rename: old/new must be valid group slugs" >&2; return 2
  fi
  if [[ "$stage" == "code" && $# -eq 0 ]]; then
    echo "jimledger commit-rename: code stage needs explicit <path...>" >&2; return 2
  fi
  if ! bash "$JIMFILE" valid-relpath "$specs_dir" >/dev/null 2>&1; then
    echo "jimledger commit-rename: unsafe specs-dir rejected: $specs_dir" >&2; return 1
  fi
  local -a paths=()
  [[ "$stage" == "docs" ]] && paths+=("${specs_dir%/}/$old" "${specs_dir%/}/$new")
  paths+=("$@")
  local top
  if ! top="$(git rev-parse --show-toplevel 2>/dev/null)" || [[ -z "$top" ]]; then
    echo "jimledger commit-rename: not in a git repo" >&2; return 1
  fi
  local p resolved
  for p in "${paths[@]}"; do
    if ! bash "$JIMFILE" valid-relpath "$p" >/dev/null 2>&1; then
      echo "jimledger commit-rename: unsafe path rejected: $p" >&2; return 1
    fi
    if ! resolved="$(realpath -m -- "$p" 2>/dev/null)" || [[ "$resolved" != "$top"/* ]]; then
      echo "jimledger commit-rename: path escapes worktree: $p" >&2; return 1
    fi
  done
  # Stage only paths that still exist — a git-mv'd old path is already staged and
  # `git add` on a vanished path errors. Never a blanket add.
  for p in "${paths[@]}"; do
    [[ -e "$p" ]] || continue
    git add -- "$p" || { echo "jimledger commit-rename: git add failed: $p" >&2; return 1; }
  done
  if git diff --cached --quiet -- "${paths[@]}"; then
    echo "jimledger commit-rename: nothing staged for the given paths" >&2; return 1
  fi
  local subject
  if [[ "$stage" == "docs" ]]; then subject="docs(specs): rename group $old to $new"
  else                              subject="refactor($new): rename territory $old to $new"; fi
  git commit -q -m "$subject" -- "${paths[@]}" || { echo "jimledger commit-rename: commit failed" >&2; return 1; }
}

# cmd_commit_split <specs-dir> <old> <targets-csv> <path>... — the split's docs
#   commit: one atomic commit of the fission's COMPLETE stage set,
#   composed from explicit literal paths only. Unlike commit-rename's docs arm, a
#   split has no single old→new pair to auto-derive — N spec dirs move across N
#   children — so the orchestrator passes the whole set: every moved spec-dir's
#   old AND new path, the touched child / remainder / retired blueprints, the
#   reference-edit files, and the issue INDEX.md (the map + specs-root ledger
#   commit separately via commit-map). Guards mirror commit-rename: <old> and each
#   target are valid group slugs; the target set has the split arity (≥2); every
#   path clears valid-relpath and resolves inside the worktree top. `git add` runs
#   only on paths that still exist (a moved old dir is already staged as a deletion
#   by move-spec-dir; re-adding a vanished path errors) while the commit pathspec
#   covers the whole set so the staged deletions land. Subject is composed
#   in-script from the slug-validated <old> + targets only, never from path text.
#   Operates on the repo at CWD. rc 0 committed · rc 1 nothing staged / guard · rc 2 usage.
cmd_commit_split() {
  local specs_dir="${1:-}" old="${2:-}" targets_csv="${3:-}"
  if [[ -z "$specs_dir" || -z "$old" || -z "$targets_csv" ]]; then
    echo "jimledger commit-split: need <specs-dir> <old> <targets-csv> <path...>" >&2; return 2
  fi
  shift 3
  if [[ $# -eq 0 ]]; then
    echo "jimledger commit-split: need explicit <path...>" >&2; return 2
  fi
  if [[ ! "$old" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "jimledger commit-split: old must be a valid group slug" >&2; return 2
  fi
  # Parse + validate the target set; compose the ", "-joined display list from the
  # slug-validated tokens only (never from any path or ledger text).
  local -a targets=()
  local tlist="" t
  IFS=',' read -r -a targets <<< "$targets_csv"
  if [[ ${#targets[@]} -lt 2 ]]; then
    echo "jimledger commit-split: need >=2 targets" >&2; return 2
  fi
  for t in "${targets[@]}"; do
    if [[ ! "$t" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      echo "jimledger commit-split: invalid target slug: $t" >&2; return 2
    fi
    tlist="${tlist:+$tlist, }$t"
  done
  if ! bash "$JIMFILE" valid-relpath "$specs_dir" >/dev/null 2>&1; then
    echo "jimledger commit-split: unsafe specs-dir rejected: $specs_dir" >&2; return 1
  fi
  local top
  if ! top="$(git rev-parse --show-toplevel 2>/dev/null)" || [[ -z "$top" ]]; then
    echo "jimledger commit-split: not in a git repo" >&2; return 1
  fi
  local -a paths=("$@")
  local p resolved
  for p in "${paths[@]}"; do
    if ! bash "$JIMFILE" valid-relpath "$p" >/dev/null 2>&1; then
      echo "jimledger commit-split: unsafe path rejected: $p" >&2; return 1
    fi
    if ! resolved="$(realpath -m -- "$p" 2>/dev/null)" || [[ "$resolved" != "$top"/* ]]; then
      echo "jimledger commit-split: path escapes worktree: $p" >&2; return 1
    fi
  done
  for p in "${paths[@]}"; do
    [[ -e "$p" ]] || continue
    git add -- "$p" || { echo "jimledger commit-split: git add failed: $p" >&2; return 1; }
  done
  if git diff --cached --quiet -- "${paths[@]}"; then
    echo "jimledger commit-split: nothing staged for the given paths" >&2; return 1
  fi
  git commit -q -m "docs(specs): split group $old into $tlist" -- "${paths[@]}" || {
    echo "jimledger commit-split: commit failed" >&2; return 1
  }
}

# cmd_commit_merge <specs-dir> <target> <sources-csv> [--rekey <old:new,...>] <path>...
#   — the merge's docs commit: one atomic commit of the collapse's COMPLETE docs
#   stage set, composed from explicit literal paths only, the N->1 sibling of
#   commit-split. Where commit-split fissions one group into N children,
#   commit-merge collapses N sources into one <target>, so the orchestrator passes
#   the whole set: every absorbed spec-dir's old AND new path, the fused / retired
#   blueprints, the reference-edit files, and the issue INDEX.md (the map +
#   specs-root ledger commit separately via commit-map). Guards mirror
#   commit-split: <target> and each source are valid group slugs; every path
#   clears valid-relpath and resolves inside the worktree top. The optional
#   --rekey channel carries invariant-id lineage pairs (each half charset-gated to
#   a slug around exactly one colon) rendered into the commit BODY in-script — the
#   durable ratchet-break record; absent leaves a subject-only commit. `git add`
#   runs only on paths that still exist (a moved old dir is already staged as a
#   deletion by move-spec-dir) while the commit pathspec covers the whole set so
#   the staged deletions land. Subject and body are composed in-script from the
#   slug-validated <target> / sources and the charset-gated rekey pairs only,
#   never from path text. Operates on the repo at CWD. rc 0 committed · rc 1
#   nothing staged / guard refusal · rc 2 usage / malformed rekey.
cmd_commit_merge() {
  local specs_dir="${1:-}" target="${2:-}" sources_csv="${3:-}"
  if [[ -z "$specs_dir" || -z "$target" || -z "$sources_csv" ]]; then
    echo "jimledger commit-merge: need <specs-dir> <target> <sources-csv> [--rekey <old:new,...>] <path...>" >&2; return 2
  fi
  shift 3
  # Optional --rekey <csv> sits between the positional trio and the path list.
  local rekey_csv=""
  if [[ "${1:-}" == "--rekey" ]]; then
    if [[ $# -lt 2 ]]; then
      echo "jimledger commit-merge: --rekey needs <old:new,...>" >&2; return 2
    fi
    rekey_csv="$2"; shift 2
  fi
  if [[ $# -eq 0 ]]; then
    echo "jimledger commit-merge: need explicit <path...>" >&2; return 2
  fi
  if [[ ! "$target" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "jimledger commit-merge: target must be a valid group slug" >&2; return 2
  fi
  # Parse + validate the source set; compose the comma-joined display list from
  # the slug-validated tokens only (never from any path or ledger text).
  local -a sources=()
  local slist="" s
  IFS=',' read -r -a sources <<< "$sources_csv"
  if [[ ${#sources[@]} -lt 1 ]]; then
    echo "jimledger commit-merge: need >=1 source" >&2; return 2
  fi
  for s in "${sources[@]}"; do
    if [[ ! "$s" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      echo "jimledger commit-merge: invalid source slug: $s" >&2; return 2
    fi
    slist="${slist:+$slist,}$s"
  done
  # Compose the optional re-key body from charset-gated pairs BEFORE any git work,
  # so a malformed token fails rc 2 with nothing committed. Each pair is
  # <old>:<new>, both halves invariant-id slugs around exactly one colon.
  local body=""
  if [[ -n "$rekey_csv" ]]; then
    local -a rekeys=()
    IFS=',' read -r -a rekeys <<< "$rekey_csv"
    local pair oid nid
    body="Invariant-id re-keys (ratchet break):"
    for pair in "${rekeys[@]}"; do
      if [[ ! "$pair" =~ ^[a-z0-9][a-z0-9-]*:[a-z0-9][a-z0-9-]*$ ]]; then
        echo "jimledger commit-merge: invalid rekey token: $pair" >&2; return 2
      fi
      oid="${pair%%:*}"; nid="${pair#*:}"
      body="${body}"$'\n'"  ${oid} -> ${nid}"
    done
  fi
  if ! bash "$JIMFILE" valid-relpath "$specs_dir" >/dev/null 2>&1; then
    echo "jimledger commit-merge: unsafe specs-dir rejected: $specs_dir" >&2; return 1
  fi
  local top
  if ! top="$(git rev-parse --show-toplevel 2>/dev/null)" || [[ -z "$top" ]]; then
    echo "jimledger commit-merge: not in a git repo" >&2; return 1
  fi
  local -a paths=("$@")
  local p resolved
  for p in "${paths[@]}"; do
    if ! bash "$JIMFILE" valid-relpath "$p" >/dev/null 2>&1; then
      echo "jimledger commit-merge: unsafe path rejected: $p" >&2; return 1
    fi
    if ! resolved="$(realpath -m -- "$p" 2>/dev/null)" || [[ "$resolved" != "$top"/* ]]; then
      echo "jimledger commit-merge: path escapes worktree: $p" >&2; return 1
    fi
  done
  for p in "${paths[@]}"; do
    [[ -e "$p" ]] || continue
    git add -- "$p" || { echo "jimledger commit-merge: git add failed: $p" >&2; return 1; }
  done
  if git diff --cached --quiet -- "${paths[@]}"; then
    echo "jimledger commit-merge: nothing staged for the given paths" >&2; return 1
  fi
  if [[ -n "$body" ]]; then
    git commit -q -m "docs(specs): merge $slist into $target" -m "$body" -- "${paths[@]}" || {
      echo "jimledger commit-merge: commit failed" >&2; return 1
    }
  else
    git commit -q -m "docs(specs): merge $slist into $target" -- "${paths[@]}" || {
      echo "jimledger commit-merge: commit failed" >&2; return 1
    }
  fi
}

# cmd_move_spec_dir <specs-dir> <old-group> <src-basename> <new-group> <dst-basename>
#   — cross-parent, history-continuous `git mv` of one spec directory: the move +
#   renumber primitive split needs. Where rename-tracked is a
#   SIBLING-only rename, this deliberately crosses parents, so its bound set is
#   NARROWER instead of wider: both endpoints must resolve
#   under <specs-dir> — never an arbitrary repo file — and each basename must be a
#   spec-dir shape (NNN-slug or NNN-wip). Guards, all before git runs: 5 args;
#   specs-dir clears the jimfile valid-relpath boundary; both groups are valid
#   slugs; both basenames match the spec-dir shape; the specs anchor and both
#   endpoints resolve inside `git rev-parse --show-toplevel` AND inside the specs
#   subtree (realpath -m, so a symlinked group dir cannot slip an endpoint out of
#   either); <src> is tracked; <dst> does not yet exist (its parent is created).
#   Operates on the repo at CWD. rc 0 moved+staged · rc 1 named guard refusal ·
#   rc 2 usage.
cmd_move_spec_dir() {
  local specs_dir="${1:-}" og="${2:-}" src_base="${3:-}" ng="${4:-}" dst_base="${5:-}"
  if [[ -z "$specs_dir" || -z "$og" || -z "$src_base" || -z "$ng" || -z "$dst_base" ]]; then
    echo "jimledger move-spec-dir: need <specs-dir> <old-group> <src-basename> <new-group> <dst-basename>" >&2
    return 2
  fi
  if ! bash "$JIMFILE" valid-relpath "$specs_dir" >/dev/null 2>&1; then
    echo "jimledger move-spec-dir: unsafe specs-dir rejected: $specs_dir" >&2; return 1
  fi
  if [[ ! "$og" =~ ^[a-z0-9][a-z0-9-]*$ || ! "$ng" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "jimledger move-spec-dir: old/new group must be valid slugs" >&2; return 1
  fi
  local shape='^[0-9]{3}(-[a-z0-9][a-z0-9-]*|-wip)$'
  if [[ ! "$src_base" =~ $shape || ! "$dst_base" =~ $shape ]]; then
    echo "jimledger move-spec-dir: basenames must be NNN-slug or NNN-wip: $src_base / $dst_base" >&2; return 1
  fi
  local sd="${specs_dir%/}" src dst
  src="$sd/$og/$src_base"; dst="$sd/$ng/$dst_base"
  local top
  if ! top="$(git rev-parse --show-toplevel 2>/dev/null)" || [[ -z "$top" ]]; then
    echo "jimledger move-spec-dir: not in a git repo" >&2; return 1
  fi
  # Containment: the specs anchor and both endpoints resolve inside the worktree
  # top AND inside the specs subtree (rejecting a shape-valid path that symlinks
  # out of either before git runs). realpath -m so a not-yet-existing dst resolves.
  local specs_abs
  if ! specs_abs="$(realpath -m -- "$sd" 2>/dev/null)" || { [[ "$specs_abs" != "$top" && "$specs_abs" != "$top"/* ]]; }; then
    echo "jimledger move-spec-dir: specs-dir escapes worktree: $specs_dir" >&2; return 1
  fi
  local rp resolved
  for rp in "$src" "$dst"; do
    if ! resolved="$(realpath -m -- "$rp" 2>/dev/null)" || [[ "$resolved" != "$top"/* ]]; then
      echo "jimledger move-spec-dir: path escapes worktree: $rp" >&2; return 1
    fi
    if [[ "$resolved" != "$specs_abs"/* ]]; then
      echo "jimledger move-spec-dir: path escapes specs subtree: $rp" >&2; return 1
    fi
  done
  # Hand every path to git only literally (as in rename-tracked):
  # --literal-pathspecs keeps a magic-bearing path from being interpreted as a
  # pathspec at the tracked-check or the move.
  if [[ -z "$(git --literal-pathspecs ls-files -- "$src" 2>/dev/null)" ]]; then
    echo "jimledger move-spec-dir: source not tracked: $src" >&2; return 1
  fi
  if [[ -e "$dst" ]]; then
    echo "jimledger move-spec-dir: destination already exists: $dst" >&2; return 1
  fi
  # An exact-path check does not decide occupancy: a spec ordinal is path
  # identity, so landing 018-beta beside an existing 018-alpha is two directories
  # on one ordinal even though neither path collides. Decided through the SAME
  # predicate the rename and realize paths enforce, over the specs dir this verb
  # was handed, so a renumber cannot do what those paths refuse. The source
  # excludes itself, since a within-group renumber onto its own ordinal is not a
  # collision.
  local dst_ord held held_rc
  dst_ord="${dst_base%%-*}"
  # The exclusion answers "the source already sits on this ordinal", which can
  # only be true when the move stays inside one group — the predicate matches it
  # against the DESTINATION group's siblings. Carrying it across parents skips a
  # genuine holder there that happens to share the source's basename, and the
  # exact-path check cannot see that collision because the slugs differ.
  if [[ "$og" == "$ng" ]]; then
    held="$(bash "$JIMFILE" spec-ordinal-holder "$ng" "$dst_ord" \
              --root "$sd" --exclude "$src_base" 2>/dev/null)"
  else
    held="$(bash "$JIMFILE" spec-ordinal-holder "$ng" "$dst_ord" --root "$sd" 2>/dev/null)"
  fi
  held_rc=$?
  if (( held_rc == 0 )); then
    echo "jimledger move-spec-dir: ordinal $dst_ord already held in $ng by '$held'; nothing moved" >&2
    return 1
  fi
  if (( held_rc != 1 )); then
    echo "jimledger move-spec-dir: could not decide occupancy of ordinal '$dst_ord' in $ng" >&2
    return 1
  fi
  mkdir -p -- "$(dirname -- "$dst")" || {
    echo "jimledger move-spec-dir: cannot create destination parent" >&2; return 1
  }
  git --literal-pathspecs mv -- "$src" "$dst" || {
    echo "jimledger move-spec-dir: git mv failed: $src -> $dst" >&2; return 1
  }
}

# cmd_vacated_max <specs-dir> <group> — the vacated-id floor source consumed by
#   jimfile.sh next-id. Scans <specs-dir>/ledger.md for
#   partition-finished op=split and op=merge events and prints the highest OLD
#   number any split or merge ever vacated FROM <group> (zero-padded 3-digit),
#   so next-id can floor past it and never re-mint a moved spec's id. Both ops
#   share one vacated-id grammar (grammar stays with the ledger). Fail-closed:
#   the event is gated on ;op=split; or ;op=merge;, EVERY moved= pair is
#   iterated, and each element is charset-gated (og/onum:ng/nnum, onum exactly 3
#   digits) — an element that fails the gate is inert, never fatal, so a tampered
#   ledger element can at worst be ignored and the floor only ever raises.
#   Untrusted ledger, parsed only (no source/eval). rc 0 (prints the max or
#   nothing) · rc 1 no ledger file · rc 2 usage / bad slug.
cmd_vacated_max() {
  local dir="${1:-}" group="${2:-}"
  if [[ -z "$dir" || -z "$group" ]]; then
    echo "jimledger vacated-max: need <specs-dir> <group>" >&2; return 2
  fi
  if [[ ! "$group" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "jimledger vacated-max: invalid group slug: $group" >&2; return 2
  fi
  local ledger="${dir%/}/ledger.md"
  if [[ ! -f "$ledger" ]]; then return 1; fi
  awk -F'\t' -v GROUP="$group" '
    function consider(elem,   a, b) {
      # og/onum:ng/nnum — onum/nnum exactly 3 digits (interval-free for portability)
      if (elem !~ /^[a-z0-9][a-z0-9-]*\/[0-9][0-9][0-9]:[a-z0-9][a-z0-9-]*\/[0-9][0-9][0-9]$/) return
      split(elem, a, ":"); split(a[1], b, "/")
      if (b[1] != GROUP) return
      if (b[2]+0 > max) { max = b[2]+0; have = 1 }
    }
    $3=="partition" && $4=="finished" {
      if (index(";" $5 ";", ";op=split;") == 0 && index(";" $5 ";", ";op=merge;") == 0) next
      n = split($5, pairs, ";")
      for (i = 1; i <= n; i++) {
        if (index(pairs[i], "moved=") != 1) continue
        m = split(substr(pairs[i], 7), elems, ",")
        for (j = 1; j <= m; j++) consider(elems[j])
      }
    }
    END { if (have) printf "%03d\n", max }
  ' "$ledger"
}

# cmd_pair_events <specs-dir>
#   Print every durable identity-pair event the specs-root ledger holds, one
#   normalized TAB-separated row each:
#     realize <group>/P-<date>-<slug>  <group>/<NNN>  <YYYYMMDD>
#     spec    <old-group>/<NNN>        <new-group>/<NNN>  <YYYYMMDD>
#     group   <old-group>              <new-group>        <YYYYMMDD>
#   Realizations come from `spec realized moved=` events, renumber pairs from
#   `partition finished` events carrying op=split or op=merge, and group renames
#   from op=rename's old=/new= (which carries no pair list — the group name is
#   the whole event).
#
#   <YYYYMMDD> is the EVENT's own day, not today's: these rows describe things
#   that already happened, and a consumer recording them wants the date the
#   identity actually moved.
#
#   Fail-closed like vacated-max: the ledger is ordinary branch content anyone
#   who can commit can write, so every element is charset-gated and an element
#   that fails its gate is inert rather than fatal. Ordinals are admitted at
#   3–15 digits — the width the registry itself can represent — so no
#   representable pair is silently unliftable. Parsed only; never sourced.
#   rc 0 (rows, possibly none) · rc 1 no ledger file · rc 2 usage.
cmd_pair_events() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then
    echo "jimledger pair-events: need <specs-dir>" >&2; return 2
  fi
  local ledger="${dir%/}/ledger.md"
  if [[ ! -f "$ledger" ]]; then return 1; fi
  awk -F'\t' '
    function isord(s) { return s ~ /^[0-9]+$/ && length(s) >= 3 && length(s) <= 15 }
    function isgrp(s) { return s ~ /^[a-z0-9][a-z0-9-]*$/ }
    function isprovtok(s,   b) {
      if (substr(s, 1, 2) != "P-") return 0
      b = substr(s, 3)
      if (length(b) < 10) return 0
      if (substr(b, 1, 8) !~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/) return 0
      if (substr(b, 9, 1) != "-") return 0
      return substr(b, 10) ~ /^[a-z0-9][a-z0-9-]*$/
    }
    function specid_ok(s,   p) {
      p = index(s, "/"); if (p == 0) return 0
      return isgrp(substr(s, 1, p - 1)) && isord(substr(s, p + 1))
    }
    function provid_ok(s,   p) {
      p = index(s, "/"); if (p == 0) return 0
      return isgrp(substr(s, 1, p - 1)) && isprovtok(substr(s, p + 1))
    }
    function day(iso,   t) { t = iso; gsub(/-/, "", t); return substr(t, 1, 8) }
    function kv(field, key,   c, parts, i) {
      c = split(field, parts, ";")
      for (i = 1; i <= c; i++)
        if (index(parts[i], key "=") == 1) return substr(parts[i], length(key) + 2)
      return ""
    }
    function emit_pairs(field, kind, when,   c, parts, i, m, elems, j, p, src, dst) {
      c = split(field, parts, ";")
      for (i = 1; i <= c; i++) {
        if (index(parts[i], "moved=") != 1) continue
        m = split(substr(parts[i], 7), elems, ",")
        for (j = 1; j <= m; j++) {
          p = index(elems[j], ":")
          if (p == 0) continue
          src = substr(elems[j], 1, p - 1); dst = substr(elems[j], p + 1)
          if (kind == "realize") { if (!provid_ok(src) || !specid_ok(dst)) continue }
          else                   { if (!specid_ok(src) || !specid_ok(dst)) continue }
          printf "%s\t%s\t%s\t%s\n", kind, src, dst, when
        }
      }
    }
    $3 == "spec" && $4 == "realized" { emit_pairs($5, "realize", day($2)); next }
    $3 == "partition" && $4 == "finished" {
      op = kv($5, "op")
      if (op == "split" || op == "merge") { emit_pairs($5, "spec", day($2)); next }
      if (op == "rename") {
        old = kv($5, "old"); new = kv($5, "new")
        if (isgrp(old) && isgrp(new)) printf "group\t%s\t%s\t%s\n", old, new, day($2)
      }
    }
  ' "$ledger"
}

# cmd_event <spec-dir> <phase> <event> [k=v ...]
cmd_event() {
  local dir="${1:-}" phase="${2:-}" event="${3:-}"
  if [[ -z "$dir" || -z "$phase" || -z "$event" ]]; then
    echo "jimledger event: need <spec-dir> <phase> <event> [k=v ...]" >&2
    return 2
  fi
  shift 3
  local kv="" tok
  for tok in "$@"; do
    kv="${kv:+$kv;}$tok"
  done
  append_line "$dir" "$phase" "$event" "$kv"
}

# cmd_events <spec-dir> — READ-ONLY. Print every event recorded in
#   <spec-dir>/ledger.md, one per line, reordered to "<phase>\t<event>\t<iso>\t<kv>"
#   in recorded order (the trailing <kv> omitted when empty). The read view
#   backing /jim:ledger's stage-events surface: reads ledger.md only, writes
#   nothing, and invokes no git. The ledger is a hand-editable, untrusted file —
#   parsed only via awk (no source/eval), each field re-emitted as data. Guards
#   mirror the sibling read verbs: rc 2 on a missing <spec-dir> (the append_line
#   spec-dir guard) or a dir carrying no ledger.md (the metrics no-ledger guard).
#   rc 0 on success.
cmd_events() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then echo "jimledger events: need <spec-dir>" >&2; return 2; fi
  if [[ ! -d "$dir" ]]; then echo "jimledger: spec-dir not found: $dir" >&2; return 2; fi
  local ledger="$dir/ledger.md"
  if [[ ! -f "$ledger" ]]; then echo "jimledger: no ledger at $ledger" >&2; return 2; fi
  awk -F'\t' '{
    line = $3 "\t" $4 "\t" $2
    if ($5 != "") line = line "\t" $5
    print line
  }' "$ledger"
}

# ledger_kv <ledger> <phase> <event> <key> <which:first|last>
#   Extract a kv value from the first/last line whose phase AND event fields
#   match and whose kv field carries <key>=. Empty if none. Scoping by phase
#   keeps a same-named event from another phase out of the build range.
#   Untrusted input — parsed only.
ledger_kv() {
  local ledger="$1" phase="$2" event="$3" key="$4" which="$5"
  awk -F'\t' -v ph="$phase" -v ev="$event" -v k="$key" -v which="$which" '
    $3==ph && $4==ev {
      n=split($5, a, ";")
      for (i=1; i<=n; i++) {
        if (index(a[i], k"=")==1) {
          val=substr(a[i], length(k)+2)
          if (which=="first") { print val; exit }
        }
      }
    }
    END { if (which=="last" && val!="") print val }
  ' "$ledger"
}

# resolve_range <spec-dir> — print "<base> <head>" for the build range, or
#   return 2 (no ledger / no baseline / malformed sha). SHAs are validated here
#   so callers can interpolate them into git ranges safely.
resolve_range() {
  local dir="$1" ledger="$dir/ledger.md"
  if [[ ! -f "$ledger" ]]; then echo "jimledger: no ledger at $ledger" >&2; return 2; fi
  local base head
  base="$(ledger_kv "$ledger" build started base_sha first)"
  head="$(ledger_kv "$ledger" build finished head_sha last)"
  if [[ -z "$base" ]]; then echo "jimledger: no build baseline in ledger" >&2; return 2; fi
  if [[ -z "$head" ]]; then head="$(git -C "$dir" rev-parse HEAD 2>/dev/null)"; fi
  if ! validate_sha "$base" || ! validate_sha "$head"; then
    echo "jimledger: refusing malformed sha in ledger" >&2
    return 2
  fi
  printf '%s %s' "$base" "$head"
}

# cmd_files <spec-dir> — list changed paths over the build range (untrusted).
cmd_files() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then echo "jimledger files: need <spec-dir>" >&2; return 2; fi
  local rr base head
  rr="$(resolve_range "$dir")" || return 2
  base="${rr% *}"; head="${rr#* }"
  git -C "$dir" diff --name-only "$base..$head" --
}

# cmd_diff <spec-dir> — emit the diff over the build range with --function-context
#   so each hunk carries its enclosing function (untrusted output). Mirrors
#   cmd_files: SHAs validated by resolve_range, `--` end-of-options guard.
cmd_diff() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then echo "jimledger diff: need <spec-dir>" >&2; return 2; fi
  local rr base head
  rr="$(resolve_range "$dir")" || return 2
  base="${rr% *}"; head="${rr#* }"
  git -C "$dir" diff --function-context "$base..$head" --
}

# cmd_diff_range <base> [<head>] — emit the --function-context diff over the
#   <base>..<head> range in the repo at CWD (head defaults to HEAD). The ad-hoc
#   blueprint update's diff source: both endpoints are ref-safety-gated and
#   resolved to SHAs (resolve_ref) before any git interpolation, so a crafted
#   ref cannot inject a git option or pathspec. Untrusted
#   output. Unlike the range verbs, this operates on CWD's repo, not a spec-dir.
cmd_diff_range() {
  local base_ref="${1:-}" head_ref="${2:-HEAD}"
  if [[ -z "$base_ref" ]]; then echo "jimledger diff-range: need <base> [head]" >&2; return 2; fi
  local base head
  base="$(resolve_ref "$base_ref")" || return 1
  head="$(resolve_ref "$head_ref")" || return 1
  git diff --function-context "$base..$head" --
}

# cmd_files_range <base> [<head>] — list changed paths over the <base>..<head>
#   range in the repo at CWD (head defaults to HEAD), one repo-relative path per
#   line via `git diff --name-only`. The --name-only sibling of cmd_diff_range:
#   both endpoints are ref-safety-gated and resolved to SHAs (resolve_ref) before
#   any git interpolation, so a crafted ref cannot inject a git option or
#   pathspec. Returns rc 2 on an invalid/unresolvable ref or a
#   missing base — the files-family degrade code the review sensor and the ad-hoc
#   --since caller key on (not diff-range's rc 1) — and rc 0 + empty on an empty
#   range. Untrusted output: paths with unusual bytes arrive git-C-quoted
#   (double-quoted, octal-escaped), while a plain-space path is emitted verbatim,
#   so consumers must re-gate each line. Operates on
#   CWD's repo, not a spec-dir — the ad-hoc --since adapter runs at root.
cmd_files_range() {
  local base_ref="${1:-}" head_ref="${2:-HEAD}"
  if [[ -z "$base_ref" ]]; then echo "jimledger files-range: need <base> [head]" >&2; return 2; fi
  local base head
  base="$(resolve_ref "$base_ref")" || return 2
  head="$(resolve_ref "$head_ref")" || return 2
  git diff --name-only "$base..$head" --
}

# Stages whose started/finished boundaries the ledger may carry. The metrics
# loop iterates THIS fixed list — key names are literals, never derived from
# ledger text — so a tampered ledger cannot inject spurious metric keys
# (the key set is fixed; values are counts/SHAs or the
# shape-validated verdict, never free-form ledger text).
LEDGER_STAGES="spec research plan sec build review blueprint verify"

# phase_event_metrics <ledger> — emit per-stage process metrics:
#   <stage>_runs, <stage>_interruptions, and (when both bounds exist)
#   <stage>_duration_seconds. runs = max(started, finished); interruptions =
#   started - finished, so a stage restarted after an abandoned attempt counts
#   each run and surfaces the gap. spec is instrumented like the rest: it opens
#   its `started` event in a `<id>-wip` dir that `mv-spec-id` renames into the
#   final spec dir, then records `finished` at approval — so a completed spec
#   carries both bounds and emits all three metrics. A stage with only
#   `finished` (e.g. an older checkout that skipped the wip open) still counts
#   one run but emits no duration. Stages with no events are omitted (absent
#   key = stage not instrumented), matching the reviewer's graceful-degradation
#   contract.
phase_event_metrics() {
  local ledger="$1" ph s f runs inter se fe
  for ph in $LEDGER_STAGES; do
    s="$(awk -F'\t' -v p="$ph" '$3==p && $4=="started"{n++}  END{print n+0}' "$ledger")"
    f="$(awk -F'\t' -v p="$ph" '$3==p && $4=="finished"{n++} END{print n+0}' "$ledger")"
    if (( s == 0 && f == 0 )); then continue; fi
    if (( s > f )); then runs=$s; inter=$(( s - f )); else runs=$f; inter=0; fi
    printf '%s_runs=%s\n' "$ph" "$runs"
    printf '%s_interruptions=%s\n' "$ph" "$inter"
    se="$(awk -F'\t' -v p="$ph" '$3==p && $4=="started"{print $1; exit}' "$ledger")"
    fe="$(awk -F'\t' -v p="$ph" '$3==p && $4=="finished"{e=$1} END{print e}' "$ledger")"
    if [[ "$se" =~ ^[0-9]+$ && "$fe" =~ ^[0-9]+$ ]]; then
      printf '%s_duration_seconds=%s\n' "$ph" "$(( fe - se ))"
    fi
  done
}

# review_verdict_metrics <ledger> — surface the latest review verdict under the
#   fixed, code-literal keys review_alignment / review_findings. The value is
#   shape-validated on the way out (alignment against the known vocabulary,
#   findings against a non-negative integer) so a tampered ledger surfaces at
#   most a bounded, well-formed value — never arbitrary text.
#   review.md, not this channel, is the authoritative verdict.
review_verdict_metrics() {
  local ledger="$1" ra rf
  ra="$(ledger_kv "$ledger" review finished alignment last)"
  case "$ra" in
    aligned|minor-drift|major-drift) printf 'review_alignment=%s\n' "$ra" ;;
  esac
  rf="$(ledger_kv "$ledger" review finished findings last)"
  if [[ "$rf" =~ ^[0-9]+$ ]]; then printf 'review_findings=%s\n' "$rf"; fi
}

# cmd_metrics <spec-dir> — emit key=value metrics: fixed keys, shape-validated
#   values, never free-form ledger text.
cmd_metrics() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then echo "jimledger metrics: need <spec-dir>" >&2; return 2; fi
  local ledger="$dir/ledger.md"
  if [[ ! -f "$ledger" ]]; then echo "jimledger: no ledger at $ledger" >&2; return 2; fi

  # Git-derived metrics — emitted ONLY when a build range resolves. The
  # ledger-only metrics below (per-stage process + the review verdict) emit even
  # with no build baseline, so review stays self-measurable over an
  # un-instrumented build. A no-baseline / malformed-sha range simply
  # skips this block — the stage metrics still land.
  local rr base head
  if rr="$(resolve_range "$dir" 2>/dev/null)"; then
    base="${rr% *}"; head="${rr#* }"
    local range="$base..$head"
    local commits ct cf cx cr stat fc ins del
    commits="$(git -C "$dir" rev-list --count "$range" 2>/dev/null || echo 0)"
    ct="$(git -C "$dir" log --format=%s "$range" 2>/dev/null | grep -cE '^test(\([^)]+\))?!?:')"
    cf="$(git -C "$dir" log --format=%s "$range" 2>/dev/null | grep -cE '^feat(\([^)]+\))?!?:')"
    cx="$(git -C "$dir" log --format=%s "$range" 2>/dev/null | grep -cE '^fix(\([^)]+\))?!?:')"
    cr="$(git -C "$dir" log --format=%s "$range" 2>/dev/null | grep -cE '^refactor(\([^)]+\))?!?:')"
    stat="$(git -C "$dir" diff --shortstat "$range" -- 2>/dev/null)"
    fc="$(printf '%s' "$stat"  | grep -oE '[0-9]+ files? changed' | grep -oE '[0-9]+' || true)"
    ins="$(printf '%s' "$stat" | grep -oE '[0-9]+ insertion'      | grep -oE '[0-9]+' || true)"
    del="$(printf '%s' "$stat" | grep -oE '[0-9]+ deletion'       | grep -oE '[0-9]+' || true)"
    : "${fc:=0}" "${ins:=0}" "${del:=0}"

    printf 'base_sha=%s\n' "$base"
    printf 'head_sha=%s\n' "$head"
    printf 'commits=%s\n' "$commits"
    printf 'commits_test=%s\n' "$ct"
    printf 'commits_feat=%s\n' "$cf"
    printf 'commits_fix=%s\n' "$cx"
    printf 'commits_refactor=%s\n' "$cr"
    printf 'files_changed=%s\n' "$fc"
    printf 'insertions=%s\n' "$ins"
    printf 'deletions=%s\n' "$del"
  fi

  # Per-stage process metrics (spec/research/plan/sec/build/review/blueprint) plus the
  # latest review verdict — ledger-only, so they survive an un-instrumented
  # build. Iterates a fixed allowlist (LEDGER_STAGES); key names are literals,
  # never derived from ledger text.
  phase_event_metrics "$ledger"
  review_verdict_metrics "$ledger"
  return 0
}

# cmd_updates_since <blueprint-dir> <watermark-iso> — print the count of
#   `blueprint finished` events strictly after <watermark-iso> and at/before now,
#   for the regen-cadence signal. The watermark is validated to the
#   fixed iso format (rc 2 on malformed/empty) so the count can safely gate an
#   unattended regen; the `<= now` upper bound stops a planted future-dated ledger
#   event from inflating the count. Untrusted ledger — parsed
#   only via awk -v (no source/eval), mirroring phase_event_metrics.
cmd_updates_since() {
  local dir="${1:-}" wm="${2:-}"
  if [[ -z "$dir" ]]; then echo "jimledger updates-since: need <blueprint-dir> <watermark-iso>" >&2; return 2; fi
  local ledger="$dir/ledger.md"
  if [[ ! -f "$ledger" ]]; then echo "jimledger: no ledger at $ledger" >&2; return 2; fi
  if [[ ! "$wm" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    echo "jimledger: invalid watermark: $wm" >&2; return 2
  fi
  local now; now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  awk -F'\t' -v w="$wm" -v now="$now" '
    $3=="blueprint" && $4=="finished" && $2>w && $2<=now { n++ }
    END { print n+0 }' "$ledger"
}

# Shared reconcile-counter contract (15 keys). `last-reconcile`
# and `reconcile-series` validate the `op=reconcile` finished event against ONE
# whitelist, so the injection-proof key set — the only channel from the
# hand-editable ledger into the health report — lives in a single place. Three
# value classes: INT (non-negative integer — the 7 finding counters plus
# faces/faces_max), NA (integer or the literal `na` = not-computable, the
# coverage carve-out), SLUG (sorted comma-joined group slugs, ≤256 bytes, each
# element slug-valid — the faces_max_group / fanin_group attribution keys,
# present only when the metric > 0, display data never consumed by threshold
# predicates). ORDER is the canonical print order both verbs emit.
RECONCILE_INT_KEYS="edges leaks breaking dead unresolved undeclared stale faces faces_max"
RECONCILE_NA_KEYS="groups cycles fanin uncovered"
RECONCILE_SLUG_KEYS="faces_max_group fanin_group"
RECONCILE_KEY_ORDER="edges leaks breaking dead unresolved undeclared stale groups cycles fanin uncovered faces faces_max faces_max_group fanin_group"

# RECONCILE_AWK — the shared validator/emitter, parameterized by -v MODE and the
# four -v key lists above. Untrusted ledger, parsed only (no source/eval).
#   MODE=series → one EVENT\t<iso>\t<k=v>… line per valid reconcile event
#                 (file order = oldest→newest), and EXCLUDED\t<line>\t<reason>
#                 for a malformed one (the named series-grain degradation);
#                 END exits 1 iff no valid EVENT was emitted.
#   MODE=last   → the LAST reconcile event's iso + counters; END exits 1 on no
#                 prior event, 2 on a malformed one.
# validate() fills the global vals[] and returns the first bad key ("" = clean).
IFS= read -r -d '' RECONCILE_AWK <<'AWK' || true
function valid_sluglist(s,   m, parts, i) {
  if (length(s) == 0 || length(s) > 256) return 0
  m = split(s, parts, ",")
  for (i = 1; i <= m; i++) if (parts[i] !~ /^[a-z0-9][a-z0-9-]*$/) return 0
  return 1
}
function validate(kv,   n, pairs, j, p, eq, key, val, t) {
  split("", vals)
  n = split(kv, pairs, ";")
  for (j = 1; j <= n; j++) {
    p = pairs[j]
    if (p == "") continue
    eq = index(p, "=")
    if (eq == 0) continue
    key = substr(p, 1, eq - 1)
    val = substr(p, eq + 1)
    if (!(key in doc)) continue                 # whitelist: drop unknown/op/tier
    t = typ[key]
    if (t == "int")       { if (val ~ /^[0-9]+$/)               { vals[key] = val; continue } }
    else if (t == "na")   { if (val ~ /^[0-9]+$/ || val == "na") { vals[key] = val; continue } }
    else if (t == "slug") { if (valid_sluglist(val))            { vals[key] = val; continue } }
    return key                                   # documented key, bad value
  }
  return ""
}
BEGIN {
  ni = split(INTKEYS, IK, " ");  for (i = 1; i <= ni; i++) { doc[IK[i]] = 1; typ[IK[i]] = "int" }
  nn = split(NAKEYS, NK, " ");   for (i = 1; i <= nn; i++) { doc[NK[i]] = 1; typ[NK[i]] = "na" }
  ns = split(SLUGKEYS, SK, " "); for (i = 1; i <= ns; i++) { doc[SK[i]] = 1; typ[SK[i]] = "slug" }
  nord = split(ORDER, ORD, " ")
  any = 0; found = 0
}
$3 == "blueprint" && $4 == "finished" {
  if (index(";" $5 ";", ";op=reconcile;") == 0) next
  if (MODE == "series") {
    bad = validate($5)
    if (bad != "") { print "EXCLUDED\t" NR "\tbad-value:" bad; next }
    line = "EVENT\t" $2
    for (idx = 1; idx <= nord; idx++) if (ORD[idx] in vals) line = line "\t" ORD[idx] "=" vals[ORD[idx]]
    print line
    any = 1
  } else {
    found = 1; last_iso = $2; last_kv = $5
  }
}
END {
  if (MODE == "series") { if (!any) exit 1; exit 0 }
  if (!found) exit 1
  bad = validate(last_kv)
  if (bad != "") exit 2
  print last_iso
  for (idx = 1; idx <= nord; idx++) if (ORD[idx] in vals) print ORD[idx] "=" vals[ORD[idx]]
}
AWK

# cmd_reconcile_series <specs-dir> — emit the full op=reconcile finished event
#   series (oldest→newest) as EVENT/EXCLUDED records, the trend sensor's input.
#   Reuses the shared whitelist so a tampered ledger line can inject
#   no counter key. rc: 0 ≥1 valid EVENT · 1 no ledger / zero valid events ·
#   2 bad args.
cmd_reconcile_series() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then echo "jimledger reconcile-series: need <specs-dir>" >&2; return 2; fi
  local ledger="$dir/ledger.md"
  if [[ ! -f "$ledger" ]]; then return 1; fi
  awk -F'\t' -v MODE=series \
    -v INTKEYS="$RECONCILE_INT_KEYS" -v NAKEYS="$RECONCILE_NA_KEYS" \
    -v SLUGKEYS="$RECONCILE_SLUG_KEYS" -v ORDER="$RECONCILE_KEY_ORDER" \
    "$RECONCILE_AWK" "$ledger"
}

# cmd_last_reconcile <specs-dir> — print the immediately preceding reconcile
#   event's iso and its documented counters, for the health delta. The
#   prior is the LAST `blueprint finished` line whose kv carries `op=reconcile`.
#   Only the documented counter keys are printed — the seven finding counters
#   (edges/leaks/breaking/dead/unresolved/undeclared/stale) plus the four health
#   counters (groups/cycles/fanin/uncovered); every other kv token (op, tier, or
#   a hand-injected key) is dropped, never printed, so the ledger — a committed,
#   hand-editable file — has no injection channel into the report. Each
#   documented key present must be a non-negative integer; `na`
#   is additionally allowed on the four health keys (a not-computable coverage /
#   short-circuit measurement). A documented key carrying any other value is a
#   malformed prior → rc 2, so the caller degrades to baseline and names it.
#   Untrusted ledger — parsed only via awk (no source/eval).
#   rc: 0 found+valid · 1 no prior reconcile event (or no ledger) · 2 malformed.
cmd_last_reconcile() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then echo "jimledger last-reconcile: need <specs-dir>" >&2; return 2; fi
  local ledger="$dir/ledger.md"
  if [[ ! -f "$ledger" ]]; then return 1; fi
  awk -F'\t' -v MODE=last \
    -v INTKEYS="$RECONCILE_INT_KEYS" -v NAKEYS="$RECONCILE_NA_KEYS" \
    -v SLUGKEYS="$RECONCILE_SLUG_KEYS" -v ORDER="$RECONCILE_KEY_ORDER" \
    "$RECONCILE_AWK" "$ledger"
}

main() {
  local sub="${1:-}"
  case "$sub" in
    start)   shift; cmd_start "$@" ;;
    metrics) shift; cmd_metrics "$@" ;;
    events)  shift; cmd_events "$@" ;;
    files)   shift; cmd_files "$@" ;;
    diff)    shift; cmd_diff "$@" ;;
    diff-range) shift; cmd_diff_range "$@" ;;
    files-range) shift; cmd_files_range "$@" ;;
    finish)  shift; cmd_finish "$@" ;;
    event)   shift; cmd_event "$@" ;;
    rename-tracked) shift; cmd_rename_tracked "$@" ;;
    move-spec-dir) shift; cmd_move_spec_dir "$@" ;;
    vacated-max) shift; cmd_vacated_max "$@" ;;
    pair-events) shift; cmd_pair_events "$@" ;;
    commit-rename) shift; cmd_commit_rename "$@" ;;
    commit-split) shift; cmd_commit_split "$@" ;;
    commit-merge) shift; cmd_commit_merge "$@" ;;
    commit-review) shift; cmd_commit_review "$@" ;;
    commit-blueprint) shift; cmd_commit_blueprint "$@" ;;
    commit-map) shift; cmd_commit_map "$@" ;;
    commit-verify) shift; cmd_commit_verify "$@" ;;
    updates-since) shift; cmd_updates_since "$@" ;;
    last-reconcile) shift; cmd_last_reconcile "$@" ;;
    reconcile-series) shift; cmd_reconcile_series "$@" ;;
    *) usage; return 2 ;;
  esac
}

main "$@"
exit $?
