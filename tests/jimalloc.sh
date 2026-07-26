#!/usr/bin/env bash
#
# tests/jimalloc.sh — Tests for skills/file/scripts/jimalloc.sh
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# WHAT THIS FILE TESTS
#   The jimalloc.sh ID-coordination allocator: subcommand dispatch/usage, the
#   pure record layer (grammar parse, emit-encode, forward-replay resolution),
#   next-id/next-num + durable-id guard, the two-tier compare-and-swap (local
#   update-ref, origin push non-fast-forward), the erosion growth guard,
#   config wiring + failure semantics, write-containment, and peek.
#
# HOW TO RUN
#   bash tests/jimalloc.sh                  # every case in this file
#   bash tests/jimalloc.sh usage            # only cases whose name contains "usage"
#   bash skills/meta-test/scripts/run.sh    # this file alongside every other tests/*.sh
#

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT_jimalloc="$REPO_ROOT/skills/file/scripts/jimalloc.sh"

# ─── Section: Per-script invoker ─────────────────────────────────────────────

# run_jimalloc <args...>
#   Invoke the allocator; capture stdout, stderr, and exit code into the
#   globals OUT, ERR, RC. Same shape as run/run_jimfile in sibling files.
run_jimalloc() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_jimalloc" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# ─── Section: Usage / dispatch ───────────────────────────────────────────────

# AC: no subcommand → usage error on stderr, rc 2, clean stdout.
case_jimalloc_no_args_usage() {
  run_jimalloc
  assert_exit     "no-arg rc"       2  "$RC"
  assert_eq       "stdout empty"    "" "$OUT"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: unknown subcommand → usage error on stderr, rc 2, clean stdout.
case_jimalloc_unknown_verb_usage() {
  run_jimalloc bogus-verb
  assert_exit     "unknown rc"      2  "$RC"
  assert_eq       "stdout empty"    "" "$OUT"
  assert_nonempty "stderr explains" "$ERR"
}

# run_jimalloc_reg <regdir> <args...>
#   Same as run_jimalloc but points the allocator at a fixture registry
#   directory (specs.log / issues.log) via JIMALLOC_REGISTRY_DIR — the seam
#   that lets the pure record layer be exercised over fixture logs before the
#   coordination-branch git wiring lands.
run_jimalloc_reg() {
  local regdir="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(JIMALLOC_REGISTRY_DIR="$regdir" bash "$SCRIPT_jimalloc" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# ─── Section: Record layer — emit-encoder (DD 7 / write-side boundary) ────────

# AC: a newline (or the field delimiter) in the free-text <who> value cannot
# forge a second record — the encoder collapses it to a single safe token, so
# a plain grep/replay sees exactly one allocate line (spec AC 13; security F8).
case_jimalloc_encode_who_newline_forgery() {
  local who out
  who="$(printf 'Jane\nspec allocate evil/999 x 20260726 attacker')"
  out="$(source "$SCRIPT_jimalloc"; alloc_encode_allocate_spec "core/001" "my-slug" "20260726" "$who")"
  assert_match "record prefix" '^spec allocate core/001 my-slug 20260726 ' "$out"
  if [[ "$out" == *$'\n'* ]]; then
    CURRENT_FAILED=1; echo "    [forgery] encoder emitted multiple lines: [$out]"
  fi
  if printf '%s' "$out" | grep -q 'evil/999'; then
    CURRENT_FAILED=1; echo "    [forgery] raw injected id survived: [$out]"
  fi
}

# ─── Section: Record layer — forward-replay resolution ───────────────────────

# AC: an id with only its own allocate record resolves to itself (idempotent).
case_jimalloc_resolve_spec_identity() {
  local dir; dir=$(empty_dir res_identity)
  printf '%s\n' 'spec allocate core/003 my-slug 20260726 jane' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_exit "rc"      0          "$RC"
  assert_eq   "current" "core/003" "$OUT"
}

# AC: a multi-hop rename (A→B→C) resolves the original citation to the current
# name; the current name resolves to itself.
case_jimalloc_resolve_spec_multihop_rename() {
  local dir; dir=$(empty_dir res_multihop)
  printf '%s\n' 'spec allocate core/003 s 20260726 jane
spec rename core/003 dashboard/001 20260727
spec rename dashboard/001 ui/002 20260728' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_eq "old→current" "ui/002" "$OUT"
  run_jimalloc_reg "$dir" resolve spec dashboard/001
  assert_eq "mid→current" "ui/002" "$OUT"
  run_jimalloc_reg "$dir" resolve spec ui/002
  assert_eq "current→self" "ui/002" "$OUT"
}

# AC: a group rename resolves every id in the group forward; the renamed-into
# name resolves to itself.
case_jimalloc_resolve_spec_group_rename() {
  local dir; dir=$(empty_dir res_group)
  printf '%s\n' 'spec allocate dashboard/001 s 20260726 jane
group rename dashboard ui 20260727' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec dashboard/001
  assert_eq "group old→current" "ui/001" "$OUT"
  run_jimalloc_reg "$dir" resolve spec ui/001
  assert_eq "group current→self" "ui/001" "$OUT"
}

# AC: a name renamed away and later reused does not inherit the earlier
# referent's rename history — replay is anchored at the queried id's own (last)
# allocate record (reused-name safety).
case_jimalloc_resolve_spec_reused_name() {
  local dir; dir=$(empty_dir res_reuse)
  printf '%s\n' 'spec allocate dashboard/001 first 20260726 jane
spec rename dashboard/001 core/009 20260727
spec allocate dashboard/001 second 20260728 kai' > "$dir/specs.log"
  # The moved original resolves forward…
  run_jimalloc_reg "$dir" resolve spec core/009
  assert_eq "moved original" "core/009" "$OUT"
  # …while the reused string resolves to the current (latest) referent, NOT the
  # earlier rename target.
  run_jimalloc_reg "$dir" resolve spec dashboard/001
  assert_eq "reused string" "dashboard/001" "$OUT"
}

# AC: a reverted rename (A→B→A) is cycle-safe — each record applies once in
# file order, so the id resolves back to itself and replay terminates.
case_jimalloc_resolve_spec_cycle_revert() {
  local dir; dir=$(empty_dir res_cycle)
  printf '%s\n' 'spec allocate core/003 s 20260726 jane
spec rename core/003 tmp/001 20260727
spec rename tmp/001 core/003 20260728' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_exit "rc"      0          "$RC"
  assert_eq   "reverted" "core/003" "$OUT"
}

# AC: a malformed record (option-injection id, '..'-bearing token, ref
# metacharacters) is degraded and skipped, never executed — a legit id in the
# same log still resolves, and the malformed token itself is not allocated.
case_jimalloc_resolve_spec_skips_malformed() {
  local dir; dir=$(empty_dir res_malformed)
  printf '%s\n' 'spec allocate --upload-pack=x s 20260726 jane
spec allocate ../../etc/passwd s 20260726 jane
spec allocate core/003 good 20260726 jane
spec rename core/003 he^ad~1:x 20260727' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_exit "legit rc"       0          "$RC"
  assert_eq   "legit resolves" "core/003" "$OUT"   # malformed rename dst skipped
  run_jimalloc_reg "$dir" resolve spec --upload-pack=x
  assert_exit "injection query rejected" 1 "$RC"
  assert_eq   "no injection stdout"      "" "$OUT"
}

# AC: an id that never appears in the registry is reported unallocated (rc 1).
case_jimalloc_resolve_spec_unknown() {
  local dir; dir=$(empty_dir res_unknown)
  printf '%s\n' 'spec allocate core/003 s 20260726 jane' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec zzz/999
  assert_exit     "rc"      1  "$RC"
  assert_eq       "stdout"  "" "$OUT"
  assert_nonempty "stderr"  "$ERR"
}

# AC: issue ordinals resolve across a multi-hop rename chain.
case_jimalloc_resolve_issue_multihop() {
  local dir; dir=$(empty_dir res_issue_hop)
  printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jane
issue rename 5 8 20260727
issue rename 8 12 20260728' > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 5
  assert_eq "issue old→current" "12" "$OUT"
}

# AC: an issue queried by its durable full-id resolves to the current ordinal.
case_jimalloc_resolve_issue_by_fullid() {
  local dir; dir=$(empty_dir res_issue_fid)
  printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jane
issue rename 5 8 20260727' > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 20260726-alpha
  assert_eq "fullid→current ordinal" "8" "$OUT"
}

# ─── Section: next-id / next-num / durable-id guard ──────────────────────────

# AC: next spec id in an empty group is <group>/001; otherwise max ordinal + 1,
# zero-padded, counting both allocate ids and rename destinations in the group
# (ids never reused → the high-water mark, never a reclaimed gap).
case_jimalloc_next_id_spec() {
  local out
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec dashboard <<< "")"
  assert_eq "empty group → 001" "dashboard/001" "$out"
  local log
  log=$(printf '%s\n' 'spec allocate dashboard/001 a 20260726 x' \
                      'spec allocate dashboard/002 b 20260726 x' \
                      'spec allocate other/007 c 20260726 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec dashboard <<< "$log")"
  assert_eq "max+1 in group" "dashboard/003" "$out"
  # a rename destination into the group counts toward the high-water mark
  log=$(printf '%s\n' 'spec allocate dashboard/001 a 20260726 x' \
                      'spec rename core/009 dashboard/005 20260727')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec dashboard <<< "$log")"
  assert_eq "rename dst counts" "dashboard/006" "$out"
}

# AC: leading-zero ordinals are read as base-10, never octal (008 → 8, not error).
case_jimalloc_next_id_spec_base10() {
  local log out
  log=$(printf '%s\n' 'spec allocate dashboard/008 a 20260726 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec dashboard <<< "$log")"
  assert_eq "008 → 009" "dashboard/009" "$out"
}

# AC: next issue ordinal is max+1 over allocate ids and rename destinations,
# unpadded; empty registry → 1.
case_jimalloc_next_num_issue() {
  local out log
  out="$(source "$SCRIPT_jimalloc"; alloc_next_num_issue <<< "")"
  assert_eq "empty → 1" "1" "$out"
  log=$(printf '%s\n' 'issue allocate 5 20260726-a 20260726 x' \
                      'issue rename 5 11 20260727')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_num_issue <<< "$log")"
  assert_eq "max+1" "12" "$out"
}

# AC: the durable issue id (date + slug) is disambiguated with a -2/-3 suffix
# when the computed form already exists in the registry (G9 collision guard).
case_jimalloc_durable_issue_id_collision() {
  local today base out log
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  base="${today}-my-subject"
  out="$(source "$SCRIPT_jimalloc"; alloc_durable_issue_id "My Subject" <<< "")"
  assert_eq "no collision → base" "$base" "$out"
  log=$(printf '%s\n' "issue allocate 1 $base 20260726 x")
  out="$(source "$SCRIPT_jimalloc"; alloc_durable_issue_id "My Subject" <<< "$log")"
  assert_eq "collision → -2" "${base}-2" "$out"
  log=$(printf '%s\n' "issue allocate 1 $base 20260726 x" \
                      "issue allocate 2 ${base}-2 20260726 x")
  out="$(source "$SCRIPT_jimalloc"; alloc_durable_issue_id "My Subject" <<< "$log")"
  assert_eq "collision → -3" "${base}-3" "$out"
}

# ─── Section: CAS helpers (real git repos) ───────────────────────────────────

# run_jimalloc_in <dir> <args...>
#   Invoke the allocator with CWD inside <dir> so its git plumbing operates on
#   that repo. Captures OUT/ERR/RC.
run_jimalloc_in() {
  local dir="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$dir" && bash "$SCRIPT_jimalloc" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# alloc_new_repo <name>
#   Create and print a fresh git repo with a committer identity set.
alloc_new_repo() {
  local repo; repo="$(empty_dir "$1")"
  git -C "$repo" init -q
  git -C "$repo" config user.name  "Test User"
  git -C "$repo" config user.email "test@example.com"
  printf '%s' "$repo"
}

# alloc_specs_log <repo> — print the specs.log on the coordination branch.
alloc_specs_log() { git -C "$1" cat-file -p refs/heads/jim/registry:specs.log 2>/dev/null; }
# alloc_issues_log <repo> — print the issues.log on the coordination branch.
alloc_issues_log() { git -C "$1" cat-file -p refs/heads/jim/registry:issues.log 2>/dev/null; }

# ─── Section: local-tier allocation (update-ref CAS) ─────────────────────────

# AC: sequential allocations in a no-remote repo yield distinct, durable ids;
# the log grows append-only (spec: at-most-once, never reused, permanent gap).
case_jimalloc_allocate_spec_local_distinct() {
  local repo log
  repo="$(alloc_new_repo alloc_spec_distinct)"
  run_jimalloc_in "$repo" allocate spec dashboard "First feature"
  assert_exit "first rc" 0              "$RC"
  assert_eq   "first id" "dashboard/001" "$OUT"
  run_jimalloc_in "$repo" allocate spec dashboard "Second feature"
  assert_exit "second rc" 0              "$RC"
  assert_eq   "second id" "dashboard/002" "$OUT"
  log="$(alloc_specs_log "$repo")"
  assert_match "first recorded"  '^spec allocate dashboard/001 first-feature '  "$log"
  assert_match "second recorded" '^spec allocate dashboard/002 second-feature ' "$log"
}

# AC: the first spec in a new group claims the group once (group allocate
# record); a later spec in the same group does not re-claim it (allocate-once).
case_jimalloc_allocate_spec_group_claimed_once() {
  local repo log count
  repo="$(alloc_new_repo alloc_group_once)"
  run_jimalloc_in "$repo" allocate spec platform "One"
  run_jimalloc_in "$repo" allocate spec platform "Two"
  log="$(alloc_specs_log "$repo")"
  count="$(printf '%s\n' "$log" | grep -c '^group allocate platform ')"
  assert_eq "group claimed exactly once" "1" "$count"
}

# AC: an issue allocation returns "<full-id><TAB><num>" and is durable;
# sequential allocations yield distinct ordinals.
case_jimalloc_allocate_issue_local() {
  local repo today num1 num2 fid1
  repo="$(alloc_new_repo alloc_issue_local)"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  run_jimalloc_in "$repo" allocate issue "Alpha bug"
  assert_exit "rc" 0 "$RC"
  fid1="${OUT%%$'\t'*}"; num1="${OUT##*$'\t'}"
  assert_eq "first num"  "1" "$num1"
  assert_eq "first fid"  "${today}-alpha-bug" "$fid1"
  run_jimalloc_in "$repo" allocate issue "Beta bug"
  num2="${OUT##*$'\t'}"
  assert_eq "second num" "2" "$num2"
}

# AC: a newline-bearing git config user.name cannot forge a second record —
# the encoder collapses it, so exactly one spec allocate line lands (F8).
case_jimalloc_allocate_who_no_forgery() {
  local repo log
  repo="$(alloc_new_repo alloc_who_forgery)"
  git -C "$repo" config user.name "$(printf 'evil\nspec allocate x/999 y 20200101 z')"
  run_jimalloc_in "$repo" allocate spec core "A feature"
  assert_exit "rc" 0 "$RC"
  log="$(alloc_specs_log "$repo")"
  assert_eq "exactly one spec allocate" "1" "$(printf '%s\n' "$log" | grep -c '^spec allocate ')"
  assert_match "legit id present" '^spec allocate core/001 a-feature ' "$log"
  if printf '%s\n' "$log" | grep -q 'x/999'; then
    CURRENT_FAILED=1; echo "    [forgery] injected x/999 landed in the log"
  fi
}

# AC: allocation never touches the working tree — the coordination branch is
# written by plumbing, HEAD and the index are untouched.
case_jimalloc_allocate_leaves_worktree_clean() {
  local repo status
  repo="$(alloc_new_repo alloc_clean_tree)"
  run_jimalloc_in "$repo" allocate spec ui "Widget"
  assert_exit "rc" 0 "$RC"
  status="$(git -C "$repo" status --porcelain)"
  assert_eq "worktree clean" "" "$status"
}

# ─── Section: origin-tier helpers (bare remote + clones) ─────────────────────

# alloc_new_bare <name> — init and print a bare coordination remote.
alloc_new_bare() {
  local d; d="$(empty_dir "$1")"
  git init -q --bare "$d/r.git"
  printf '%s' "$d/r.git"
}

# alloc_new_clone <bare> <name> — clone <bare> with an identity, print its path.
alloc_new_clone() {
  local bare="$1" name="$2" dir
  dir="$(empty_dir "$2")"
  git clone -q "$bare" "$dir"
  git -C "$dir" config user.name  "$name"
  git -C "$dir" config user.email "$name@example.com"
  printf '%s' "$dir"
}

# alloc_bare_specs <bare> — print specs.log on the bare remote's coordination branch.
alloc_bare_specs() { git -C "$1" cat-file -p refs/heads/jim/registry:specs.log 2>/dev/null; }

# ─── Section: origin-tier allocation (push non-fast-forward CAS) ─────────────

# AC: when a remote is reachable, allocations coordinate across clones — a
# second clone sees the first's allocation and gets a distinct id, both durable
# on the remote (spec: guarantee tier follows reachability).
case_jimalloc_origin_cross_clone_distinct() {
  local bare A B log
  bare="$(alloc_new_bare occ_bare)"
  A="$(alloc_new_clone "$bare" occ_A)"
  B="$(alloc_new_clone "$bare" occ_B)"
  run_jimalloc_in "$A" allocate spec dashboard "from A"
  assert_exit "A rc" 0              "$RC"
  assert_eq   "A id" "dashboard/001" "$OUT"
  run_jimalloc_in "$B" allocate spec dashboard "from B"
  assert_exit "B rc" 0              "$RC"
  assert_eq   "B id" "dashboard/002" "$OUT"
  log="$(alloc_bare_specs "$bare")"
  assert_match "A on remote" '^spec allocate dashboard/001 from-a ' "$log"
  assert_match "B on remote" '^spec allocate dashboard/002 from-b ' "$log"
}

# AC: the first allocation against a remote with no coordination branch creates
# it on the remote (branch-create case).
case_jimalloc_origin_first_allocation_creates_branch() {
  local bare A exists
  bare="$(alloc_new_bare ofa_bare)"
  A="$(alloc_new_clone "$bare" ofa_A)"
  run_jimalloc_in "$A" allocate spec ui "Widget"
  assert_exit "rc" 0 "$RC"
  exists="$(git -C "$bare" rev-parse --verify --quiet refs/heads/jim/registry || true)"
  assert_nonempty "branch created on remote" "$exists"
}

# AC: two allocations racing against the same remote never both succeed with the
# same id — the loser's push is rejected (non-fast-forward), it refetches and
# retries, so both land distinct ids (spec: racing allocations never both win).
case_jimalloc_origin_race_distinct() {
  local bare A B ra rb count
  bare="$(alloc_new_bare race_bare)"
  A="$(alloc_new_clone "$bare" race_A)"
  B="$(alloc_new_clone "$bare" race_B)"
  run_jimalloc_in "$A" allocate spec g "seed"      # seed so both racers fetch+append
  ( cd "$A" && bash "$SCRIPT_jimalloc" allocate spec g "a" ) > "$TMP_BASE/ra" 2>/dev/null &
  ( cd "$B" && bash "$SCRIPT_jimalloc" allocate spec g "b" ) > "$TMP_BASE/rb" 2>/dev/null &
  wait
  ra="$(cat "$TMP_BASE/ra")"; rb="$(cat "$TMP_BASE/rb")"
  assert_nonempty "A race id" "$ra"
  assert_nonempty "B race id" "$rb"
  if [[ "$ra" == "$rb" ]]; then
    CURRENT_FAILED=1; echo "    [race] both allocations returned the same id: $ra"
  fi
  count="$(alloc_bare_specs "$bare" | grep -c '^spec allocate ')"
  assert_eq "three specs on remote" "3" "$count"
}

# AC: after an allocation, resolve reads the registry from the coordination
# branch (not only the test seam) and returns the id.
case_jimalloc_resolve_reads_branch_after_allocate() {
  local repo
  repo="$(alloc_new_repo resolve_after)"
  run_jimalloc_in "$repo" allocate spec core "Alpha"
  assert_eq "allocated" "core/001" "$OUT"
  run_jimalloc_in "$repo" resolve spec core/001
  assert_exit "resolve rc"      0          "$RC"
  assert_eq   "resolve current" "core/001" "$OUT"
}

# ─── Section: G3 erosion guard ───────────────────────────────────────────────

# AC: if the coordination branch history is truncated or rewritten (force-push
# / revert), the next allocation detects the erosion relative to the locally
# seen baseline and hard-fails rather than reissuing an already-consumed id —
# even though the attacker controls the branch content, the local baseline
# (outside the branch) still catches it (spec AC 11 / DD 8 / F9).
case_jimalloc_allocate_detects_erosion() {
  local repo blob tree commit
  repo="$(alloc_new_repo alloc_erosion)"
  run_jimalloc_in "$repo" allocate spec g "one"
  assert_exit "first rc"  0 "$RC"
  run_jimalloc_in "$repo" allocate spec g "two"
  assert_exit "second rc" 0 "$RC"
  # Rewrite the coordination branch to a truncated history the baseline never saw.
  blob="$(printf 'spec allocate g/001 tampered 20200101 x\n' | git -C "$repo" hash-object -w --stdin)"
  tree="$(printf '100644 blob %s\tspecs.log\n' "$blob" | git -C "$repo" mktree)"
  commit="$(git -C "$repo" commit-tree "$tree" -m rewrite)"
  git -C "$repo" update-ref refs/heads/jim/registry "$commit"
  run_jimalloc_in "$repo" allocate spec g "three"
  assert_exit     "erosion hard-fail" 1  "$RC"
  assert_eq       "no id issued"      "" "$OUT"
  assert_nonempty "erosion message"   "$ERR"
}

# AC: clean append-only growth never false-triggers the erosion guard — the
# baseline is a byte-prefix of every later state (regression guard for the check).
case_jimalloc_allocate_growth_not_erosion() {
  local repo
  repo="$(alloc_new_repo alloc_growth)"
  run_jimalloc_in "$repo" allocate spec g "one"
  run_jimalloc_in "$repo" allocate spec g "two"
  run_jimalloc_in "$repo" allocate spec g "three"
  assert_exit "third rc"  0             "$RC"
  assert_eq   "third id"  "g/003"       "$OUT"
}

# ─── Section: config wiring + failure semantics ──────────────────────────────

# AC: the mechanism is config-governed; a reserved-but-unimplemented value
# ('service') fails loudly rather than silently misbehaving (spec: config
# governs mechanism; only git/local implemented here).
case_jimalloc_mechanism_service_not_implemented() {
  local repo
  repo="$(alloc_new_repo alloc_mech)"
  printf 'id_coordination_mechanism = "service"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate spec g "x"
  assert_exit     "rc"      1  "$RC"
  assert_eq       "no id"   "" "$OUT"
  assert_nonempty "message" "$ERR"
}

# AC: the unreachable-origin behavior is config-governed; the reserved
# 'provisional' mode is not shipped here and fails loudly (spec ships 'fail').
case_jimalloc_unreachable_provisional_not_implemented() {
  local repo
  repo="$(alloc_new_repo alloc_unreach_mode)"
  printf 'id_coordination_unreachable = "provisional"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate spec g "x"
  assert_exit     "rc"      1  "$RC"
  assert_nonempty "message" "$ERR"
}

# AC: a configured but unreachable remote hard-fails with a clear message and
# never silently falls back to an unpublished local allocation (AC 10 / F7).
case_jimalloc_unreachable_remote_hard_fails() {
  local repo localref
  repo="$(alloc_new_repo alloc_bad_remote)"
  git -C "$repo" remote add origin "$TMP_BASE/no-such-remote.git"
  run_jimalloc_in "$repo" allocate spec g "x"
  assert_exit     "rc"      1  "$RC"
  assert_eq       "no id"   "" "$OUT"
  assert_nonempty "message" "$ERR"
  localref="$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
  assert_eq "no local fallback branch" "" "$localref"
}

# AC: the coordination point is config-governed and read from the branch — a
# custom branch name routes the registry to that ref (spec: config governs the
# coordination point, per-branch).
case_jimalloc_custom_branch_from_config() {
  local repo
  repo="$(alloc_new_repo alloc_custom_branch)"
  printf 'id_coordination_branch = "jim/ids"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate spec g "x"
  assert_exit "rc" 0 "$RC"
  assert_eq   "id" "g/001" "$OUT"
  local log
  log="$(git -C "$repo" cat-file -p refs/heads/jim/ids:specs.log 2>/dev/null)"
  assert_match "recorded on custom branch" '^spec allocate g/001 x ' "$log"
}

# ─── Section: write-containment guard (F5) ───────────────────────────────────

# AC: the allocator refuses a local write target that a symlink escapes outside
# the git dir, before any git object write or ref update, leaving no side effect
# (spec AC 13 write-path revalidation / security F5).
case_jimalloc_refuses_symlink_escaping_baseline() {
  local repo outside
  repo="$(alloc_new_repo alloc_symlink)"
  outside="$(empty_dir alloc_symlink_outside)"
  ln -s "$outside" "$repo/.git/jimalloc"
  run_jimalloc_in "$repo" allocate spec g "x"
  assert_exit     "rc"      1  "$RC"
  assert_eq       "no id"   "" "$OUT"
  assert_nonempty "message" "$ERR"
  assert_eq "outside untouched" "" "$(ls -A "$outside" 2>/dev/null)"
  assert_eq "no coordination branch" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
#
# Dual-mode: direct invocation runs this file's cases; the aggregate runner
# sources it alongside every other tests/*.sh. See the testlib.sh header and
# the meta-test scaffold template for why the BASH_SOURCE guard is shaped this
# way — do not "tidy" it.
#
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_jimalloc" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_jimalloc — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
