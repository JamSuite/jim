#!/usr/bin/env bash
#
# skills/file/scripts/jimalloc.sh — jim's ID-coordination allocator.
#
# PURPOSE
#   Hand out jim's IDs (spec ordinals, issue ordinals + durable issue ids, and
#   group names) through a shared, append-only registry so separate users on
#   separate clones never claim the same ID. Allocation appends a
#   compare-and-swap (CAS)-guarded record to a per-kind log on a dedicated
#   coordination branch, using git plumbing so the developer's working tree is
#   never disturbed mid-flow.
#
#   This is jim's first script to fetch/push and write a shared ref. The
#   coordination branch is writable by anyone who can push it, so every value
#   read back from the registry or from config is revalidated through
#   jimfile.sh's id/slug/path boundary before it reaches a git command, a ref,
#   or a filesystem path (the single security boundary — no fourth copy).
#
# CLI SUMMARY
#   bash jimalloc.sh allocate spec  <group> <subject>   → "<group>/<NNN>"
#   bash jimalloc.sh allocate issue <subject>           → "<full-id>\t<num>"
#   bash jimalloc.sh peek     spec  <group>             → advisory "<group>/<NNN>"
#   bash jimalloc.sh peek     issue                     → advisory "<num>"
#   bash jimalloc.sh resolve  spec  <group>/<NNN>       → current "<group>/<NNN>"
#   bash jimalloc.sh resolve  issue <num|full-id>       → current id
#   bash jimalloc.sh -c <path> <subcmd>                 use <path> as jimconf.toml
#
# EXIT CODES
#   0  Success.
#   1  Hard failure (unreachable coordination point / erosion detected /
#      retries exhausted / a rejected registry or config token).
#   2  Malformed invocation (missing argument, unknown subcommand).
#

set -uo pipefail
# LC_ALL=C — locale-independent text handling (matches jimfile.sh / jimconf.sh).
export LC_ALL=C
# Non-interactive git: a mid-flow credential prompt must never hang a consumer;
# an unreachable coordination point surfaces as a failed command, not a stall.
export GIT_TERMINAL_PROMPT=0

# ─── Section: Globals ────────────────────────────────────────────────────────

# Sibling platform CLIs, resolved BASH_SOURCE-relative so the composition
# travels with the plugin tree regardless of install scope. jimfile.sh is the
# id/slug/date/path boundary; jimconf.sh resolves the id_coordination_* keys.
JIMFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/jimfile.sh"
JIMCONF="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../conf/scripts" && pwd)/jimconf.sh"

# Optional -c <path> override for jimconf.toml. Empty when not supplied;
# production consumers never pass it (tests and ad-hoc inspection do).
CONFIG_FILE=""

# ─── Section: Record layer (pure — operates on a log, no git) ────────────────
#
# The registry is one append-only, space-separated, newline-delimited log per
# kind, file-order authoritative. It is writable by anyone who can push the
# coordination branch, so it is untrusted data: every id/group/slug token read
# back is revalidated through jimfile.sh's boundary before use, and a malformed
# record is degraded and skipped — never executed (parsed as data; never sourced).
#
# Record grammar (fields after `<kind> <verb>`):
#   spec  allocate <group>/<NNN> <slug> <date> <who>
#   group allocate <group> <date> <who>
#   issue allocate <NNN> <full-id> <date> <who>
#   spec  rename   <group>/<NNN> <newgroup>/<newNNN> <date>
#   group rename   <old-group> <new-group> <date>
#   issue rename   <NNN> <newNNN> <date>
# Only allocate records are emitted by this build; rename/group-rename are parsed
# and resolved (format frozen) so a later spec can begin emitting them unchanged.

# alloc_log_file <kind> — the log file name for <kind>. Group records ride the
# spec log so resolving a spec id replays a single file.
alloc_log_file() {
  case "$1" in
    spec|group) printf 'specs.log' ;;
    issue)      printf 'issues.log' ;;
    *) return 1 ;;
  esac
}

# alloc_read_log <kind> — print the current registry log for <kind> to stdout
# (empty if none). Source precedence:
#   1. $JIMALLOC_REGISTRY_DIR (offline/local staging + test seam), if set.
#   2. the coordination branch via git plumbing (wired in a later task).
alloc_read_log() {
  local kind="$1" file
  file="$(alloc_log_file "$kind")" || { echo "error: no log for kind '$kind'" >&2; return 1; }
  if [[ -n "${JIMALLOC_REGISTRY_DIR:-}" ]]; then
    local p="$JIMALLOC_REGISTRY_DIR/$file"
    [[ -f "$p" ]] && cat -- "$p"
    return 0
  fi
  # Read the local coordination-branch ref (kept in sync by allocate on both
  # tiers). peek refreshes it from the remote first; resolve reads as-is.
  local branch
  branch="$(alloc_coord_branch)" || return 1
  git cat-file -p "refs/heads/$branch:$file" 2>/dev/null || true
  return 0
}

# alloc_valid_token <tok> — exit 0 iff <tok> passes jimfile.sh's id boundary
# (is_valid_id). THE single security boundary — no fourth copy. Forecloses
# option-injection (leading '-'), path traversal ('..'), and ref metacharacters,
# all of which fall outside the ^[A-Za-z0-9][A-Za-z0-9._-]*$ allowlist.
alloc_valid_token() {
  bash "$JIMFILE" valid-id "$1" >/dev/null 2>&1
}

# alloc_valid_specid <id> — exit 0 iff <id> is "<group>/<NNN>": exactly one '/',
# a boundary-valid group, and an all-digits ordinal.
alloc_valid_specid() {
  local id="$1" grp num
  [[ "$id" == */* ]] || return 1
  grp="${id%/*}"; num="${id##*/}"
  [[ "$grp" == *"/"* ]] && return 1
  [[ "$num" =~ ^[0-9]+$ ]] || return 1
  alloc_valid_token "$grp"
}

# alloc_sanitize_who <raw> — reduce a free-text provenance value to a single safe
# token: every character outside [A-Za-z0-9._@-] (space, tab, NEWLINE, CR, and
# ref/shell metacharacters) becomes '-', runs collapse, ends trim, cap 64. A
# newline here would otherwise forge a second record on a plain grep/replay; it
# is advisory provenance only, so lossy normalization is acceptable (DD 7 / F8).
alloc_sanitize_who() {
  printf '%s' "${1:-}" \
    | tr -c 'A-Za-z0-9._@-' '-' \
    | sed 's/-\+/-/g; s/^-//; s/-$//' \
    | cut -c1-64
}

# alloc_encode_allocate_spec  <specid> <slug> <date> <who>
# alloc_encode_allocate_group <group> <date> <who>
# alloc_encode_allocate_issue <num> <full-id> <date> <who>
#   Build exactly one record line. Fixed fields are pre-validated single tokens
#   supplied by the allocate path; the trailing free-text <who> is sanitized
#   here (write-side complement to read-side revalidation).
alloc_encode_allocate_spec() {
  printf 'spec allocate %s %s %s %s\n' "$1" "$2" "$3" "$(alloc_sanitize_who "${4:-}")"
}
alloc_encode_allocate_group() {
  printf 'group allocate %s %s %s\n' "$1" "$2" "$(alloc_sanitize_who "${3:-}")"
}
alloc_encode_allocate_issue() {
  printf 'issue allocate %s %s %s %s\n' "$1" "$2" "$3" "$(alloc_sanitize_who "${4:-}")"
}

# alloc_resolve_spec <queried>  (log on stdin)
#   Forward-replay a spec id to its current name. Replay is anchored at the
#   queried id's own (last) allocate record so a string later reused does not
#   inherit an earlier referent's rename history; if the queried id has no
#   allocate record of its own (it may be the current name a rename produced),
#   replay runs from the top. Each record applies at most once in file order,
#   so a reverted rename cycle terminates. rc 1 if the id is invalid or never
#   appears in the registry (as an allocate id, a rename target, or a member of
#   a renamed-into group).
alloc_resolve_spec() {
  local queried="$1"
  alloc_valid_specid "$queried" || { echo "error: invalid spec id '$queried'" >&2; return 1; }
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 c5 c6
  local qgroup="${queried%/*}"
  local anchor=-1 known=0
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    if [[ "$c1" == spec && "$c2" == allocate ]]; then
      alloc_valid_specid "$c3" || continue
      [[ "$c3" == "$queried" ]] && { anchor=$i; known=1; }
    elif [[ "$c1" == spec && "$c2" == rename ]]; then
      alloc_valid_specid "$c3" && alloc_valid_specid "$c4" || continue
      [[ "$c4" == "$queried" ]] && known=1
    elif [[ "$c1" == group && "$c2" == rename ]]; then
      alloc_valid_token "$c3" && alloc_valid_token "$c4" || continue
      [[ "$c4" == "$qgroup" ]] && known=1
    fi
  done
  local current="$queried"
  for ((i=0; i<n; i++)); do
    (( anchor >= 0 && i <= anchor )) && continue
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    if [[ "$c1" == spec && "$c2" == rename ]]; then
      alloc_valid_specid "$c3" && alloc_valid_specid "$c4" || continue
      [[ "$c3" == "$current" ]] && current="$c4"
    elif [[ "$c1" == group && "$c2" == rename ]]; then
      alloc_valid_token "$c3" && alloc_valid_token "$c4" || continue
      [[ "$current" == "$c3"/* ]] && current="$c4/${current#*/}"
    fi
  done
  (( known )) || { echo "error: spec id '$queried' not allocated" >&2; return 1; }
  printf '%s\n' "$current"
}

# alloc_resolve_issue <queried>  (log on stdin)
#   Resolve an issue citation (an ordinal or a durable full-id) to its current
#   ordinal, following issue-rename records. A full-id is first mapped to its
#   ordinal via its allocate record. Same anchoring / cycle-safety discipline
#   as the spec resolver; issues have no group dimension.
alloc_resolve_issue() {
  local queried="$1"
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 c5 c6
  local target=""
  if [[ "$queried" =~ ^[0-9]+$ ]]; then
    target="$queried"
  else
    alloc_valid_token "$queried" || { echo "error: invalid issue id '$queried'" >&2; return 1; }
    for ((i=0; i<n; i++)); do
      read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
      [[ "$c1" == issue && "$c2" == allocate ]] || continue
      [[ "$c3" =~ ^[0-9]+$ ]] || continue
      alloc_valid_token "$c4" || continue
      [[ "$c4" == "$queried" ]] && target="$c3"
    done
    [[ -n "$target" ]] || { echo "error: issue id '$queried' not allocated" >&2; return 1; }
  fi
  local anchor=-1 known=0
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    if [[ "$c1" == issue && "$c2" == allocate ]]; then
      [[ "$c3" =~ ^[0-9]+$ ]] || continue
      [[ "$c3" == "$target" ]] && { anchor=$i; known=1; }
    elif [[ "$c1" == issue && "$c2" == rename ]]; then
      [[ "$c3" =~ ^[0-9]+$ && "$c4" =~ ^[0-9]+$ ]] || continue
      [[ "$c4" == "$target" ]] && known=1
    fi
  done
  local current="$target"
  for ((i=0; i<n; i++)); do
    (( anchor >= 0 && i <= anchor )) && continue
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    [[ "$c1" == issue && "$c2" == rename ]] || continue
    [[ "$c3" =~ ^[0-9]+$ && "$c4" =~ ^[0-9]+$ ]] || continue
    [[ "$c3" == "$current" ]] && current="$c4"
  done
  (( known )) || { echo "error: issue '$queried' not allocated" >&2; return 1; }
  printf '%s\n' "$current"
}

# alloc_next_id_spec <group>  (log on stdin)
#   The next spec id for <group>: max ordinal + 1 (zero-padded to 3), counting
#   every allocate id and rename destination in the group. Because ids are never
#   reused, this is a high-water mark — an ordinal vacated by a rename is still
#   counted via its own allocate record, so it is never reclaimed (permanent
#   gap). Group-rename aliasing of the group namespace is deferred to the spec
#   that begins emitting rename records; allocate-only logs need no aliasing.
alloc_next_id_spec() {
  local group="$1"
  alloc_valid_token "$group" || { echo "error: invalid group '$group'" >&2; return 1; }
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 c5 c6 max=0 g num
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    if [[ "$c1" == spec && "$c2" == allocate ]]; then
      alloc_valid_specid "$c3" || continue
      g="${c3%/*}"; num="${c3##*/}"
    elif [[ "$c1" == spec && "$c2" == rename ]]; then
      alloc_valid_specid "$c4" || continue
      g="${c4%/*}"; num="${c4##*/}"
    else
      continue
    fi
    [[ "$g" == "$group" ]] || continue
    num=$((10#$num))          # base-10 — never octal on leading zeros
    (( num > max )) && max=$num
  done
  printf '%s/%03d\n' "$group" $((max + 1))
}

# alloc_next_num_issue  (log on stdin)
#   The next issue display ordinal: max + 1 over allocate ids and rename
#   destinations, unpadded (issue ordinals render as #N). Empty registry → 1.
alloc_next_num_issue() {
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 c5 c6 max=0 cand
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    if [[ "$c1" == issue && "$c2" == allocate ]]; then
      cand="$c3"
    elif [[ "$c1" == issue && "$c2" == rename ]]; then
      cand="$c4"
    else
      continue
    fi
    [[ "$cand" =~ ^[0-9]+$ ]] || continue
    cand=$((10#$cand))
    (( cand > max )) && max=$cand
  done
  printf '%s\n' $((max + 1))
}

# alloc_durable_issue_id <subject>  (issues log on stdin)
#   Compute the durable issue id (today's date + slug via jimfile.sh) and
#   disambiguate it with a -2 / -3 … suffix when the computed form already
#   appears as a full-id in the registry (G9 collision guard). The ordinal and
#   the durable form are guarded by the same append-only registry.
alloc_durable_issue_id() {
  local subject="$1" date slug base
  date="$(bash "$JIMFILE" date)" || return 1
  slug="$(bash "$JIMFILE" slug "$subject")" || return 1
  base="${date}-${slug}"
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 c5 c6
  local candidate="$base" suffix=1 taken
  while :; do
    taken=0
    for ((i=0; i<n; i++)); do
      read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
      [[ "$c1" == issue && "$c2" == allocate ]] || continue
      [[ "$c4" == "$candidate" ]] && { taken=1; break; }
    done
    (( taken )) || break
    suffix=$((suffix + 1))
    candidate="${base}-${suffix}"
  done
  printf '%s\n' "$candidate"
}

# ─── Section: Coordination point + CAS (git plumbing) ────────────────────────

# alloc_in_repo — exit 0 iff CWD is inside a git repository.
alloc_in_repo() {
  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "error: not inside a git repository" >&2
    return 1
  }
}

# alloc_config <cli-key> — resolve a config key via jimconf.sh, forwarding any
# -c override. The id_coordination_* family is read from the current branch, so
# a team's coordination scheme is versioned with the repo.
alloc_config() {
  if [[ -n "$CONFIG_FILE" ]]; then
    bash "$JIMCONF" -c "$CONFIG_FILE" get "$1"
  else
    bash "$JIMCONF" get "$1"
  fi
}

# alloc_preflight — validate the config-governed mechanism and unreachable mode
# before any allocation. Only the git mechanism and the fail unreachable-mode
# are implemented in this build; a reserved value ('service' / 'provisional')
# fails loudly rather than silently misbehaving.
alloc_preflight() {
  local mech unreachable
  mech="$(alloc_config id_coordination_mechanism)"; [[ -n "$mech" ]] || mech="git"
  if [[ "$mech" != "git" ]]; then
    echo "error: id_coordination_mechanism '$mech' is not implemented (only 'git' is supported)" >&2
    return 1
  fi
  unreachable="$(alloc_config id_coordination_unreachable)"; [[ -n "$unreachable" ]] || unreachable="fail"
  if [[ "$unreachable" != "fail" ]]; then
    echo "error: id_coordination_unreachable '$unreachable' is not implemented (only 'fail' is supported)" >&2
    return 1
  fi
  return 0
}

# alloc_backoff <attempt> — sleep a short, rising, jittered interval between CAS
# retries so racing allocations de-synchronize instead of colliding in lockstep
# (F6). Bounded well under a second; jitter comes from $RANDOM.
alloc_backoff() {
  local n="$1" ms
  ms=$(( n * 40 + RANDOM % 50 ))
  sleep "0.$(printf '%03d' "$ms")" 2>/dev/null || true
}

# alloc_valid_branch <branch> — exit 0 iff <branch> is a safe branch name for
# refs/heads/<branch>: no leading '-' (option injection) and accepted by git's
# own ref-name policy (rejects '..', control chars, ~^:?*[, .lock, etc.). The
# coordination branch is config-supplied, so it is validated before it ever
# reaches a git command (F1b).
alloc_valid_branch() {
  local b="${1:-}"
  [[ -n "$b" ]] || return 1
  case "$b" in -*) return 1 ;; esac
  git check-ref-format "refs/heads/$b" >/dev/null 2>&1
}

# alloc_coord_branch — resolve the coordination branch from config (default
# jim/registry), validated as a git branch name. Prints the branch; rc 1 if the
# configured value is not a valid branch name.
alloc_coord_branch() {
  local b
  b="$(alloc_config id_coordination_branch)"
  [[ -n "$b" ]] || b="jim/registry"
  if ! alloc_valid_branch "$b"; then
    echo "error: id_coordination_branch '$b' is not a valid git branch name" >&2
    return 1
  fi
  printf '%s' "$b"
}

# alloc_coord_remote — print a usable coordination remote (prefer 'origin',
# else the first configured remote), or nothing when the clone has no remote.
# An empty result selects the local tier; a non-empty one selects the origin
# tier (the guarantee follows reachability).
alloc_coord_remote() {
  local r
  if git remote 2>/dev/null | grep -qx origin; then
    r=origin
  else
    r="$(git remote 2>/dev/null | head -n1)"
  fi
  [[ -n "$r" ]] && printf '%s' "$r"
}

# alloc_origin_tip <remote> <branch>  — print the coordination branch's tip sha
# on <remote> (empty when the branch does not exist yet), having fetched its
# objects locally so the log can be read and a commit built atop it. rc 1 if the
# remote is unreachable — the origin tier hard-fails rather than silently
# falling back to an unpublished local allocation.
alloc_origin_tip() {
  local remote="$1" branch="$2" line tip
  if ! line="$(git ls-remote --heads "$remote" "$branch" 2>/dev/null)"; then
    echo "error: coordination remote '$remote' is unreachable" >&2
    return 1
  fi
  tip="$(printf '%s' "$line" | awk 'NR==1{print $1}')"
  if [[ -n "$tip" ]]; then
    if ! git fetch --quiet "$remote" "$branch" 2>/dev/null; then
      echo "error: failed to fetch '$branch' from '$remote'" >&2
      return 1
    fi
  fi
  printf '%s' "$tip"
}

# ── Erosion guard (G3): a local, per-clone baseline of the last-seen registry.
# It lives under the git dir — never on any branch, never fetched or pushed — so
# an attacker who force-pushes a rewritten history cannot also rewrite the
# baseline. The append-only log may only grow, so the baseline must remain a
# byte-prefix of the current content; if it does not, the history was truncated
# or rewritten and the next allocation must hard-fail rather than reissue an
# already-consumed id (DD 8 / F9). A first-time clone has no baseline and cannot
# detect erosion that predates its first fetch — denying force-push on the
# coordination branch is the primary control; this is defense-in-depth.

# alloc_baseline_dir — the local baseline directory (under the git dir).
alloc_baseline_dir() {
  local gd
  gd="$(git rev-parse --git-dir 2>/dev/null)" || return 1
  printf '%s/jimalloc' "$gd"
}

# alloc_baseline_file <logfile> — path to the last-seen baseline for <logfile>.
alloc_baseline_file() {
  local d
  d="$(alloc_baseline_dir)" || return 1
  printf '%s/seen-%s' "$d" "$1"
}

# alloc_check_erosion <logfile> <current_raw> — rc 0 if the stored baseline is a
# byte-prefix of <current_raw> (clean growth) or no baseline exists yet; rc 1 if
# the baseline is no longer a prefix (erosion).
alloc_check_erosion() {
  local logfile="$1" current="$2" base seen
  base="$(alloc_baseline_file "$logfile")" || return 0
  [[ -f "$base" ]] || return 0
  seen="$(cat -- "$base"; printf X)"; seen="${seen%X}"
  [[ -z "$seen" ]] && return 0
  [[ "$current" == "$seen"* ]] && return 0
  return 1
}

# alloc_update_baseline <logfile>   (content on stdin) — record the content just
# committed as the new last-seen baseline for <logfile>. Best-effort: a failure
# to persist the baseline never fails an allocation that already committed.
alloc_update_baseline() {
  local logfile="$1" d base
  d="$(alloc_baseline_dir)" || { cat >/dev/null; return 0; }
  mkdir -p "$d" 2>/dev/null || { cat >/dev/null; return 0; }
  base="$(alloc_baseline_file "$logfile")" || { cat >/dev/null; return 0; }
  cat > "$base" 2>/dev/null || true
}

# alloc_write_contained — verify the allocator's only local write target (the
# erosion baseline dir, under the git dir) resolves inside the git dir, refusing
# a symlink that escapes it. Runs before any git object write or ref update so a
# rejected target leaves no side effect (F5). The git dir is the right anchor
# rather than the working-tree top: the baseline is untracked local state, and
# in a worktree the git dir legitimately sits outside the working tree. The
# allocator writes no other filesystem artifact — record content flows through
# pipes, never a temp file — so this is the complete write surface.
alloc_write_contained() {
  local gd gd_real b_real
  gd="$(git rev-parse --git-dir 2>/dev/null)" || {
    echo "error: not inside a git repository" >&2
    return 1
  }
  gd_real="$(realpath -m -- "$gd" 2>/dev/null)" || return 1
  b_real="$(realpath -m -- "$gd/jimalloc" 2>/dev/null)" || return 1
  if [[ "$b_real" != "$gd_real" && "$b_real" != "$gd_real"/* ]]; then
    echo "error: refusing to write the erosion baseline outside the git dir" \
         "(symlink escape): $gd/jimalloc" >&2
    return 1
  fi
  return 0
}

# alloc_group_present <group>  (log on stdin) — exit 0 iff a valid
# `group allocate <group>` record already exists.
alloc_group_present() {
  local group="$1" line c1 c2 c3
  while IFS= read -r line; do
    read -r c1 c2 c3 _ <<< "$line"
    [[ "$c1" == group && "$c2" == allocate ]] || continue
    alloc_valid_token "$c3" || continue
    [[ "$c3" == "$group" ]] && return 0
  done
  return 1
}

# alloc_build_commit <parent_sha> <logfile> <who> <email>   (content on stdin)
#   Build — with git plumbing only, so the working tree is never touched — a
#   commit that sets <logfile> to the piped content atop <parent_sha> (empty =
#   root commit), preserving every sibling log entry, and print the new commit
#   sha. The identity is passed per-invocation (already sanitized) so a hostile
#   user.name cannot corrupt the commit object.
alloc_build_commit() {
  local parent="$1" logfile="$2" who="$3" email="$4"
  local blob tree
  blob="$(git hash-object -w --stdin)" || return 1
  if [[ -n "$parent" ]]; then
    tree="$( { git ls-tree "$parent^{tree}" | awk -F'\t' -v f="$logfile" '$2 != f'; \
               printf '100644 blob %s\t%s\n' "$blob" "$logfile"; } | git mktree )" || return 1
    git -c "user.name=$who" -c "user.email=$email" \
        commit-tree "$tree" -p "$parent" -m "jim: append $logfile"
  else
    tree="$( printf '100644 blob %s\t%s\n' "$blob" "$logfile" | git mktree )" || return 1
    git -c "user.name=$who" -c "user.email=$email" \
        commit-tree "$tree" -m "jim: create $logfile"
  fi
}

# alloc_local_cas <ref> <old_sha> <logfile> <who> <email>   (content on stdin)
#   Local tier: build the commit and land it with an old-value compare-and-swap
#   (git update-ref; old_sha="" ⇒ the ref must not yet exist). Non-zero if the
#   CAS is rejected (a concurrent session advanced the ref) or a step fails.
alloc_local_cas() {
  local ref="$1" old_sha="$2" logfile="$3" who="$4" email="$5" commit
  commit="$(alloc_build_commit "$old_sha" "$logfile" "$who" "$email")" || return 1
  git update-ref "$ref" "$commit" "$old_sha" 2>/dev/null
}

# alloc_origin_cas <remote> <ref> <parent> <logfile> <who> <email>  (content on stdin)
#   Origin tier: build the commit atop the fetched remote tip <parent>, then
#   push it. The default non-fast-forward rejection is the compare-and-swap —
#   the push lands only if the remote branch is still at <parent>; if a
#   concurrent allocation advanced it, the push is rejected and the caller
#   refetches and retries. On success the local ref is synced so reads see it.
alloc_origin_cas() {
  local remote="$1" ref="$2" parent="$3" logfile="$4" who="$5" email="$6" commit
  commit="$(alloc_build_commit "$parent" "$logfile" "$who" "$email")" || return 1
  if git push --quiet "$remote" "$commit:$ref" 2>/dev/null; then
    git update-ref "$ref" "$commit" 2>/dev/null || true
    return 0
  fi
  return 1
}

# alloc_cas_append <logfile> <builder_fn> <builder_args...>
#   The allocation retry loop. Each attempt re-reads the coordination branch tip
#   and its log, invokes <builder_fn> "<current_log>" <args...> <who> to compute
#   the id to return (its first output line) and the record line(s) to append
#   (the rest), then attempts the CAS. A rejected CAS (a concurrent allocation
#   advanced the ref) re-reads and retries; exhausting the attempts hard-fails
#   loudly rather than issuing a duplicate. <who>/<email> are read once from
#   git config, sanitized, and used for both the record and the commit identity.
alloc_cas_append() {
  local logfile="$1"; shift
  local builder="$1"; shift
  alloc_preflight || return 1
  alloc_write_contained || return 1
  local branch ref remote
  branch="$(alloc_coord_branch)" || return 1
  ref="refs/heads/$branch"
  remote="$(alloc_coord_remote)"   # empty ⇒ local tier; set ⇒ origin tier
  local who email
  who="$(alloc_sanitize_who "$(git config user.name 2>/dev/null || printf '')")"
  email="$(alloc_sanitize_who "$(git config user.email 2>/dev/null || printf '')")"
  [[ -n "$who" ]]   || who="jim-allocator"
  [[ -n "$email" ]] || email="jim-allocator@localhost"
  local attempts=5 attempt tip current_log current_raw return_id
  local -a cur=() built=() records=() all=()
  for ((attempt=1; attempt<=attempts; attempt++)); do
    # Current tip of the coordination branch for this tier (origin fetches it).
    if [[ -n "$remote" ]]; then
      tip="$(alloc_origin_tip "$remote" "$branch")" || return 1
    else
      tip="$(git rev-parse --verify --quiet --end-of-options "$ref" 2>/dev/null || true)"
    fi
    # Erosion guard: the seen-baseline must remain a byte-prefix of the current
    # registry, else the history was truncated or rewritten — hard-fail loudly.
    # The trailing-X trick preserves the blob's final newline through capture so
    # the byte-prefix check is line-boundary precise.
    if [[ -n "$tip" ]]; then
      current_raw="$(git cat-file -p "$tip:$logfile" 2>/dev/null; printf X)"
      current_raw="${current_raw%X}"
    else
      current_raw=""
    fi
    if ! alloc_check_erosion "$logfile" "$current_raw"; then
      echo "error: coordination branch '$branch' shows registry erosion for $logfile" \
           "(history truncated or rewritten); refusing to allocate" >&2
      return 1
    fi
    cur=()
    [[ -n "$tip" ]] && mapfile -t cur < <(git cat-file -p "$tip:$logfile" 2>/dev/null)
    if (( ${#cur[@]} > 0 )); then
      current_log="$(printf '%s\n' "${cur[@]}")"
    else
      current_log=""
    fi
    mapfile -t built < <("$builder" "$current_log" "$@" "$who")
    if (( ${#built[@]} < 2 )); then
      echo "error: allocator failed to compute a record" >&2
      return 1
    fi
    return_id="${built[0]}"
    records=( "${built[@]:1}" )
    all=( "${cur[@]}" "${records[@]}" )
    # Attempt the tier's compare-and-swap; a rejection re-reads and retries.
    if [[ -n "$remote" ]]; then
      if printf '%s\n' "${all[@]}" \
           | alloc_origin_cas "$remote" "$ref" "$tip" "$logfile" "$who" "$email"; then
        printf '%s\n' "${all[@]}" | alloc_update_baseline "$logfile"
        printf '%s\n' "$return_id"
        return 0
      fi
    else
      if printf '%s\n' "${all[@]}" \
           | alloc_local_cas "$ref" "$tip" "$logfile" "$who" "$email"; then
        printf '%s\n' "${all[@]}" | alloc_update_baseline "$logfile"
        printf '%s\n' "$return_id"
        return 0
      fi
    fi
    # CAS lost — back off (jittered) before refetching and retrying.
    (( attempt < attempts )) && alloc_backoff "$attempt"
  done
  echo "error: allocation failed after $attempts attempts (contention on $branch)" >&2
  return 1
}

# alloc_build_spec <current_log> <group> <subject> <who>
#   Emit (stdout) the id to return, then the record line(s) to append: a
#   group-allocate record when this allocation first claims the group, followed
#   by the spec-allocate record. The slug and date are derived through jimfile.sh.
alloc_build_spec() {
  local current_log="$1" group="$2" subject="$3" who="$4"
  local id slug date
  id="$(printf '%s' "$current_log" | alloc_next_id_spec "$group")" || return 1
  slug="$(bash "$JIMFILE" slug "$subject")" || return 1
  date="$(bash "$JIMFILE" date)" || return 1
  printf '%s\n' "$id"
  if ! printf '%s' "$current_log" | alloc_group_present "$group"; then
    alloc_encode_allocate_group "$group" "$date" "$who"
  fi
  alloc_encode_allocate_spec "$id" "$slug" "$date" "$who"
}

# alloc_build_issue <current_log> <subject> <who>
#   Emit (stdout) the return value "<full-id><TAB><num>", then the issue-allocate
#   record. The ordinal and the durable id are computed from the same log.
alloc_build_issue() {
  local current_log="$1" subject="$2" who="$3"
  local num fullid date
  num="$(printf '%s' "$current_log" | alloc_next_num_issue)" || return 1
  fullid="$(printf '%s' "$current_log" | alloc_durable_issue_id "$subject")" || return 1
  date="$(bash "$JIMFILE" date)" || return 1
  printf '%s\t%s\n' "$fullid" "$num"
  alloc_encode_allocate_issue "$num" "$fullid" "$date" "$who"
}

# ─── Section: Subcommand handlers ────────────────────────────────────────────

alloc_allocate_spec() {
  local group="${1:-}" subject="${2:-}"
  if [[ -z "$group" || -z "$subject" ]]; then
    echo "error: 'allocate spec' requires <group> <subject>" >&2
    return 2
  fi
  alloc_valid_token "$group" || { echo "error: invalid group '$group'" >&2; return 1; }
  alloc_in_repo || return 1
  alloc_cas_append "specs.log" alloc_build_spec "$group" "$subject"
}

alloc_allocate_issue() {
  local subject="${1:-}"
  if [[ -z "$subject" ]]; then
    echo "error: 'allocate issue' requires <subject>" >&2
    return 2
  fi
  alloc_in_repo || return 1
  alloc_cas_append "issues.log" alloc_build_issue "$subject"
}

cmd_allocate() {
  local kind="${1:-}"
  shift || true
  case "$kind" in
    spec)  alloc_allocate_spec  "$@" ;;
    issue) alloc_allocate_issue "$@" ;;
    *)
      echo "error: allocate kind must be 'spec' or 'issue'" >&2
      return 2
      ;;
  esac
}

# alloc_peek_refresh — best-effort fast-forward of the local coordination ref
# from the remote so peek previews the latest state. Non-fatal by design: an
# unreachable remote or a refused update is ignored — peek degrades to the
# last-seen local state, never binds, and never mutates the registry.
alloc_peek_refresh() {
  local remote branch
  remote="$(alloc_coord_remote)"
  [[ -n "$remote" ]] || return 0
  branch="$(alloc_coord_branch)" || return 0
  git fetch --quiet "$remote" "$branch:refs/heads/$branch" 2>/dev/null || true
  return 0
}

cmd_peek() {
  local kind="${1:-}"
  case "$kind" in
    spec)
      local group="${2:-}"
      if [[ -z "$group" ]]; then
        echo "error: 'peek spec' requires <group>" >&2
        return 2
      fi
      alloc_valid_token "$group" || { echo "error: invalid group '$group'" >&2; return 1; }
      alloc_peek_refresh
      alloc_read_log spec | alloc_next_id_spec "$group"
      ;;
    issue)
      alloc_peek_refresh
      alloc_read_log issue | alloc_next_num_issue
      ;;
    *)
      echo "error: peek kind must be 'spec' or 'issue'" >&2
      return 2
      ;;
  esac
}

cmd_resolve() {
  local kind="${1:-}" queried="${2:-}"
  if [[ -z "$kind" || -z "$queried" ]]; then
    echo "error: 'resolve' requires <kind> and <id>" >&2
    return 2
  fi
  case "$kind" in
    spec)  alloc_read_log spec  | alloc_resolve_spec  "$queried" ;;
    issue) alloc_read_log issue | alloc_resolve_issue "$queried" ;;
    *)
      echo "error: resolve kind must be 'spec' or 'issue'" >&2
      return 2
      ;;
  esac
}

# ─── Section: Argument dispatch ──────────────────────────────────────────────

usage() {
  cat >&2 <<'USAGE'
usage:
  jimalloc.sh allocate spec  <group> <subject>   allocate a spec id
  jimalloc.sh allocate issue <subject>           allocate an issue id
  jimalloc.sh peek     spec  <group>             advisory next spec id (no commit)
  jimalloc.sh peek     issue                     advisory next issue num (no commit)
  jimalloc.sh resolve  spec  <group>/<NNN>       resolve a spec id to its current name
  jimalloc.sh resolve  issue <num|full-id>       resolve an issue id to its current name
  jimalloc.sh -c <path> <subcmd>                 use <path> instead of ./jimconf.toml
USAGE
}

main() {
  if [[ "${1:-}" == "-c" ]]; then
    if [[ -z "${2:-}" ]]; then
      echo "error: -c requires a path argument" >&2
      return 2
    fi
    CONFIG_FILE="$2"
    shift 2
  fi
  local subcmd="${1:-}"
  if [[ -z "$subcmd" ]]; then
    usage
    return 2
  fi
  shift
  case "$subcmd" in
    allocate) cmd_allocate "$@" ;;
    peek)     cmd_peek     "$@" ;;
    resolve)  cmd_resolve  "$@" ;;
    *)
      echo "error: unknown subcommand '$subcmd'" >&2
      usage
      return 2
      ;;
  esac
}

# Guarded so the pure record-layer functions can be sourced and unit-tested
# without executing the CLI (BASH_SOURCE[0] != $0 when sourced).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
