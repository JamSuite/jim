#!/usr/bin/env bash
#
# skills/review/scripts/jimledger.sh — jim ledger for the /jim:review phase.
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
#   files   <spec-dir>                         list changed file paths over base..head
#   diff    <spec-dir>                         emit the diff (function-context) over base..head
#   diff-range <base> [head]                   emit the diff over a validated CWD-repo range
#   commit-review <spec-dir> [verdict]         commit review.md + ledger.md (path-scoped)
#   commit-blueprint <blueprint-dir> [create|update]  commit spec.md + ledger.md (path-scoped)
#   updates-since <blueprint-dir> <iso>       count blueprint finished events after <iso>
#
# Ledger line format (TAB-separated): <epoch>\t<iso8601>\t<phase>\t<event>\t<kv>
#
# Security: commit/diff/ledger content is untrusted — never sourced or eval'd.
# SHAs read from the ledger are validated via jimfile.sh `valid-id` before any
# git range use (forecloses option injection). The script commits in exactly one
# place — `commit-review`, a path-scoped commit of review.md + ledger.md with a
# `--` guard and no `git add -A` (028 AC #10); `/jim:build` commits ledger.md at
# start/finish itself.

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
  metrics <spec-dir>                          emit key=value metrics to stdout
  files   <spec-dir>                          list changed files over the build range
  diff    <spec-dir>                          emit the diff (function-context) over the build range
  diff-range <base> [head]                    emit the diff over a validated CWD-repo range
  commit-review <spec-dir> [verdict]          commit review.md + ledger.md (path-scoped)
  commit-blueprint <blueprint-dir> [create|update]  commit spec.md + ledger.md
  updates-since <blueprint-dir> <iso>         count blueprint finished events after <iso>
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
#   injection (sec 030 Finding 5). Rev expressions (HEAD~3, a^, a:b) are
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
#   step (028 AC #8/#10). Literal paths with a `--` guard, never `git add -A`; the
#   message carries only the trusted-origin verdict enum (DD #4). Any git failure
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
#   commit-review's discipline (literal paths, `--` guard, never `git add -A`;
#   sec 030 Finding 2). The blueprint lives in <group>/000-blueprint/, a
#   different dir than the reviewed spec, so it gets its own path-scoped commit
#   rather than riding commit-review. Any git failure returns non-zero so the
#   caller degrades.
cmd_commit_blueprint() {
  local dir="${1:-}" mode="${2:-update}"
  if [[ -z "$dir" ]]; then echo "jimledger commit-blueprint: need <blueprint-dir>" >&2; return 2; fi
  if [[ ! -d "$dir" ]]; then echo "jimledger: blueprint-dir not found: $dir" >&2; return 2; fi
  # Whitelist the mode to create|update; anything else (or absent) maps to
  # update so the commit subject stays well-formed and non-injectable (sec 032
  # Finding 2). A first-time create (the U2 fallthrough) passes 'create'.
  [[ "$mode" == "create" ]] || mode="update"
  git -C "$dir" add -- spec.md ledger.md || return 2
  git -C "$dir" commit -q -m "docs(blueprint): $mode 000-blueprint" -- spec.md ledger.md || return 2
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
#   ref cannot inject a git option or pathspec (sec 030 Finding 5). Untrusted
#   output. Unlike the range verbs, this operates on CWD's repo, not a spec-dir.
cmd_diff_range() {
  local base_ref="${1:-}" head_ref="${2:-HEAD}"
  if [[ -z "$base_ref" ]]; then echo "jimledger diff-range: need <base> [head]" >&2; return 2; fi
  local base head
  base="$(resolve_ref "$base_ref")" || return 1
  head="$(resolve_ref "$head_ref")" || return 1
  git diff --function-context "$base..$head" --
}

# Stages whose started/finished boundaries the ledger may carry. The metrics
# loop iterates THIS fixed list — key names are literals, never derived from
# ledger text — so a tampered ledger cannot inject spurious metric keys
# (sec Finding 7: the key set is fixed; values are counts/SHAs or the
# shape-validated verdict, never free-form ledger text).
LEDGER_STAGES="spec research plan sec build review blueprint"

# phase_event_metrics <ledger> — emit per-stage process metrics:
#   <stage>_runs, <stage>_interruptions, and (when both bounds exist)
#   <stage>_duration_seconds. runs = max(started, finished); interruptions =
#   started - finished, so a stage restarted after an abandoned attempt counts
#   each run and surfaces the gap. spec is instrumented like the rest: it opens
#   its `started` event in a `<id>-wip` dir that `mv-spec` renames into the
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
#   most a bounded, well-formed value — never arbitrary text (sec 028 Finding 1).
#   review.md, not this channel, is the authoritative verdict (028 AC #9).
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
#   values, never free-form ledger text (DD #9).
cmd_metrics() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then echo "jimledger metrics: need <spec-dir>" >&2; return 2; fi
  local ledger="$dir/ledger.md"
  if [[ ! -f "$ledger" ]]; then echo "jimledger: no ledger at $ledger" >&2; return 2; fi

  # Git-derived metrics — emitted ONLY when a build range resolves. The
  # ledger-only metrics below (per-stage process + the review verdict) emit even
  # with no build baseline, so review stays self-measurable over an
  # un-instrumented build (028 DD #6). A no-baseline / malformed-sha range simply
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
  # never derived from ledger text (sec Finding 7).
  phase_event_metrics "$ledger"
  review_verdict_metrics "$ledger"
  return 0
}

# cmd_updates_since <blueprint-dir> <watermark-iso> — print the count of
#   `blueprint finished` events strictly after <watermark-iso> and at/before now,
#   for the regen-cadence signal (spec 032). The watermark is validated to the
#   fixed iso format (rc 2 on malformed/empty) so the count can safely gate an
#   unattended regen; the `<= now` upper bound stops a planted future-dated ledger
#   event from inflating the count (sec 032 Finding 1). Untrusted ledger — parsed
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

main() {
  local sub="${1:-}"
  case "$sub" in
    start)   shift; cmd_start "$@" ;;
    metrics) shift; cmd_metrics "$@" ;;
    files)   shift; cmd_files "$@" ;;
    diff)    shift; cmd_diff "$@" ;;
    diff-range) shift; cmd_diff_range "$@" ;;
    finish)  shift; cmd_finish "$@" ;;
    event)   shift; cmd_event "$@" ;;
    commit-review) shift; cmd_commit_review "$@" ;;
    commit-blueprint) shift; cmd_commit_blueprint "$@" ;;
    updates-since) shift; cmd_updates_since "$@" ;;
    *) usage; return 2 ;;
  esac
}

main "$@"
exit $?
