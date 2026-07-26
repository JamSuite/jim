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
