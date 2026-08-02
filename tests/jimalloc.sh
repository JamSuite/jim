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
#   config wiring + failure semantics, write-containment, peek, and the
#   integrity surface — tree-vs-registry classification, the read-only sweep,
#   and the catch-up repair verb.
#
# MUTATION AUDIT (the integrity surface)
#   Each guard below was neutered in turn and its fixture confirmed to FAIL,
#   then restored — 37 mutations, all discriminating. A fixture that still
#   passes while its guard is neutered is not testing that guard, so this is
#   what makes "discriminates" a measurement rather than a claim.
#
#   Audited: the origin-tip boundary and the empty-token guard in front of it;
#   the reserved-ordinal predicate; both resolver duplicate refusals and the
#   vacating clear that keeps them off the reuse path; both realize halts; the
#   claim rule for a record with an unusable sibling field, on both kinds;
#   every classifier class on BOTH kinds — MISSING, MISMATCH (ordinal-side and
#   durable-id-side), RESERVED, INFO-NO-TREE, DUP-ORD, DUP-ID, UNREADABLE and
#   rename liveness — plus record-token validation; the sweep's drift,
#   could-not-check and absent-tree-root exits, its listing cap,
#   uncovered-group naming, both pending counters, the rename-source counter,
#   the staleness header, and the field sanitizer; the derivation's
#   provisional-issue skip; and catch-up's marker, group-record rule, blocked
#   listing, empty-log refusal, partial-repair exit, at-the-tip recomputation,
#   and its inherited erosion refusal.
#
#   SCOPE, stated because a coverage claim is only as good as its bounds: the
#   first pass of this audit claimed "every classifier class" while measuring
#   per class rather than per kind×class, and three issue-side emit sites had
#   no discriminating fixture as a result. They do now. The audit measures the
#   guards named above and nothing else — a detection not in that list has not
#   been shown to be tested.
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

# AC: resolve treats two spellings of one ordinal as one identity — a query for
# the canonical form finds a record written unpadded, and a query written
# unpadded finds the canonical record. Either way the answer is canonical, so
# resolve and the fold cannot disagree about what an ordinal is.
case_jimalloc_resolve_spec_padding_is_one_identity() {
  local dir; dir=$(empty_dir res_padding)
  printf '%s\n' 'spec allocate core/18 my-slug 20260726 jane' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/018
  assert_exit "canonical query rc" 0         "$RC"
  assert_eq   "canonical answer"   "core/018" "$OUT"
  printf '%s\n' 'spec allocate core/018 my-slug 20260726 jane' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/18
  assert_exit "unpadded query rc" 0          "$RC"
  assert_eq   "canonical answer"  "core/018" "$OUT"
}

# AC: the padding-blind identity holds through replay too — a rename recorded
# against one spelling still moves a citation written in the other.
case_jimalloc_resolve_spec_padding_replay() {
  local dir; dir=$(empty_dir res_padding_replay)
  printf '%s\n' 'spec allocate core/003 s 20260726 jane
spec rename core/3 ui/7 20260727 x' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_exit "rc"                 0        "$RC"
  assert_eq   "renamed, canonical" "ui/007" "$OUT"
}

# AC: a multi-hop rename (A→B→C) resolves the original citation to the current
# name; the current name resolves to itself.
case_jimalloc_resolve_spec_multihop_rename() {
  local dir; dir=$(empty_dir res_multihop)
  printf '%s\n' 'spec allocate core/003 s 20260726 jane
spec rename core/003 dashboard/001 20260727 x
spec rename dashboard/001 ui/002 20260728 x' > "$dir/specs.log"
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
group rename dashboard ui 20260727 x' > "$dir/specs.log"
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
spec rename dashboard/001 core/009 20260727 x
spec allocate dashboard/001 second 20260728 kai' > "$dir/specs.log"
  # The moved original resolves forward…
  run_jimalloc_reg "$dir" resolve spec core/009
  assert_eq "moved original" "core/009" "$OUT"
  # …while the reused string resolves to the current (latest) referent, NOT the
  # earlier rename target.
  run_jimalloc_reg "$dir" resolve spec dashboard/001
  assert_eq "reused string" "dashboard/001" "$OUT"
}

# AC: a name vacated by a rename and later re-established by renaming a
# *different* spec onto it resolves to its current holder, not to the referent
# that left. The anchor is the latest establishing record of either kind, so a
# rename destination anchors replay exactly as an allocate record does.
case_jimalloc_resolve_spec_reuse_rename_in() {
  local dir; dir=$(empty_dir res_reuse_rename_in)
  printf '%s\n' 'spec allocate dashboard/001 first 20260726 jane
spec rename dashboard/001 core/009 20260727 x
spec allocate other/003 second 20260728 kai
spec rename other/003 dashboard/001 20260729 x' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec dashboard/001
  assert_exit "rc"              0               "$RC"
  assert_eq   "current holder"  "dashboard/001" "$OUT"
  # the departed referent still resolves forward to where it went
  run_jimalloc_reg "$dir" resolve spec core/009
  assert_eq   "departed referent" "core/009" "$OUT"
}

# AC: an ordinal wider than the registry could be rebuilt from is refused by
# `resolve`, and the message says so rather than reading as a malformed id. The
# width bound exists because recoverability was the requirement, so resolve must
# not hand back an id the seed could not reproduce.
case_jimalloc_resolve_spec_over_wide_ordinal_refused() {
  local dir; dir=$(empty_dir res_overwide_query)
  printf '%s\n' 'spec allocate core/003 alpha 20260726 jane' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/1234567890123456
  assert_exit  "rc"              1        "$RC"
  assert_match "names the width" 'width'  "$ERR"
}

# AC: the width gate is applied JOINTLY to a rename record, so an over-wide
# source is gated on its own side, so it no longer takes its destination's
# establishing claim down with it. Crafted-log-only: nothing in this build can
# mint such a record.
case_jimalloc_resolve_spec_over_wide_rename_source_keeps_dest_claim() {
  local dir; dir=$(empty_dir res_overwide_anchor)
  printf '%s\n' 'spec rename core/1234567890123456 core/003 20260727 x' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_exit "rc"                 0          "$RC"
  assert_eq   "destination stands" "core/003" "$OUT"
}

# AC 8: a rename TO a destination the registry cannot represent is not applied —
# resolve reports the pre-rename name, and DISCLOSES that the walk stopped there
# rather than answering as though the record said nothing.
case_jimalloc_resolve_spec_over_wide_rename_dest_disclosed() {
  local dir; dir=$(empty_dir res_overwide_replay)
  printf '%s\n' 'spec allocate core/003 alpha 20260726 jane
spec rename core/003 core/1234567890123456 20260727 x' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_exit  "rc"              0          "$RC"
  assert_eq    "pre-rename name" "core/003" "$OUT"
  assert_match "discloses the unrepresentable destination" "record 2" "$ERR"
}

# AC 7: an id whose only registry appearance is as a rename source resolves to
# its current referent, and the answer says so — the citation dereferences, and
# the reader is told the claim behind it was never allocated.
case_jimalloc_resolve_spec_source_known_discloses() {
  local dir; dir=$(empty_dir res_source_known)
  printf '%s\n' 'spec rename core/003 ui/007 20260727 x' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_exit  "rc"                0         "$RC"
  assert_eq    "current referent"  "ui/007"  "$OUT"
  assert_match "discloses the unallocated source" \
               "unallocated rename source .record 1." "$ERR"
}

# AC 7: an id no record mentions at all still errors — source-known widens what
# resolves, not what the registry claims to know.
case_jimalloc_resolve_spec_source_known_does_not_invent() {
  local dir; dir=$(empty_dir res_source_known_unknown)
  printf '%s\n' 'spec rename core/003 ui/007 20260727 x' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec other/001
  assert_exit "rc" 1 "$RC"
}

# AC 7: the incoherent shape stays loud — one unallocated source vacated by two
# records has no single referent, so it is refused with both records named
# rather than answered from whichever applied first.
case_jimalloc_resolve_spec_source_vacated_twice_refuses() {
  local dir; dir=$(empty_dir res_source_twice)
  printf '%s\n' 'spec rename core/003 ui/007 20260727 x
spec rename core/003 surface/009 20260728 x' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_exit  "rc"                 1               "$RC"
  assert_match "names both records" "records 1 and 2" "$ERR"
  assert_eq    "no answer on stdout" ""             "$OUT"
}

# AC 7/8: the issue side of both rules.
case_jimalloc_resolve_issue_source_known_discloses() {
  local dir; dir=$(empty_dir res_issue_source_known)
  printf '%s\n' 'issue rename 5 8 20260727 x' > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 5
  assert_exit  "rc"               0        "$RC"
  assert_eq    "current referent" "8"      "$OUT"
  assert_match "discloses the unallocated source" \
               "unallocated rename source .record 1." "$ERR"
}

case_jimalloc_resolve_issue_over_wide_source_keeps_dest_claim() {
  local dir; dir=$(empty_dir res_issue_overwide)
  printf '%s\n' 'issue rename 1234567890123456 5 20260727 x' > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 5
  assert_exit "rc"                 0   "$RC"
  assert_eq   "destination stands" "5" "$OUT"
}

# AC: the same reuse-via-rename-in shape over issue ordinals resolves to the
# ordinal's current holder.
case_jimalloc_resolve_issue_reuse_rename_in() {
  local dir; dir=$(empty_dir res_issue_reuse_rename_in)
  printf '%s\n' 'issue allocate 7 20260726-first 20260726 jane
issue rename 7 9 20260727 x
issue allocate 3 20260728-second 20260728 kai
issue rename 3 7 20260729 x' > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 7
  assert_exit "rc"             0   "$RC"
  assert_eq   "current holder" "7" "$OUT"
  run_jimalloc_reg "$dir" resolve issue 9
  assert_eq   "departed referent" "9" "$OUT"
}

# AC: a reverted rename (A→B→A) is cycle-safe — each record applies once in
# file order, so the id resolves back to itself and replay terminates.
case_jimalloc_resolve_spec_cycle_revert() {
  local dir; dir=$(empty_dir res_cycle)
  printf '%s\n' 'spec allocate core/003 s 20260726 jane
spec rename core/003 tmp/001 20260727 x
spec rename tmp/001 core/003 20260728 x' > "$dir/specs.log"
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
spec rename core/003 he^ad~1:x 20260727 x' > "$dir/specs.log"
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
issue rename 5 8 20260727 x
issue rename 8 12 20260728 x' > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 5
  assert_eq "issue old→current" "12" "$OUT"
}

# AC: an issue queried by its durable full-id resolves to the current ordinal.
case_jimalloc_resolve_issue_by_fullid() {
  local dir; dir=$(empty_dir res_issue_fid)
  printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jane
issue rename 5 8 20260727 x' > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 20260726-alpha
  assert_eq "fullid→current ordinal" "8" "$OUT"
}

# ─── Section: malformed records stay degraded-and-skipped ────────────────────

# AC 1: a record short a field is degraded and skipped, never fatal. The token
# cache indexes on the raw token, and an empty one is not a usable array
# subscript — so the read path has to reject it before the cache sees it, or one
# truncated line pushed to the branch breaks resolution for every clone.
case_jimalloc_truncated_record_is_skipped_not_fatal() {
  local dir; dir=$(empty_dir res_truncated)
  printf '%s\n' 'spec allocate core/001 alpha 20260726 jane
group rename core' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/001
  assert_exit "still resolves"     0          "$RC"
  assert_eq   "answers"            "core/001" "$OUT"
  assert_eq   "no interpreter noise on stderr" "0" \
    "$(printf '%s\n' "$ERR" | grep -c 'array subscript')"
}

# AC 1: the same shape on the issue side, and through a verb that walks every
# record rather than one identity.
case_jimalloc_truncated_issue_record_is_skipped() {
  local dir; dir=$(empty_dir res_truncated_issue)
  printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jane
issue allocate' > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 5
  assert_exit "still resolves" 0   "$RC"
  assert_eq   "answers"        "5" "$OUT"
  assert_eq   "no interpreter noise on stderr" "0" \
    "$(printf '%s\n' "$ERR" | grep -c 'array subscript')"
}

# ─── Section: duplicate-identity refusal on the read path (AC 11) ────────────
#
# The registry is push-writable and append-only, so two records can claim one
# identity. Answering from whichever appears last hands back a confidently wrong
# referent; these cases pin the contradiction being reported instead.

# AC 11: two allocate records claiming one spec ordinal make resolve refuse,
# naming both claiming record positions rather than answering from the later.
#
# Discriminating in both directions, verified by mutation: neutering the refusal
# fails this case, and neutering the vacating clear that keeps it off the reuse
# path fails the vacated-reuse case below.
case_jimalloc_resolve_spec_duplicate_ordinal_refused() {
  local dir; dir=$(empty_dir res_dup_spec)
  printf '%s\n' 'spec allocate core/007 alpha 20260726 jane
spec allocate other/001 x 20260726 jane
spec allocate core/007 beta 20260727 mallory' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/007
  assert_exit     "refused"         1         "$RC"
  assert_eq       "no answer"       ""        "$OUT"
  assert_match    "names the identity" 'core/007' "$ERR"
  assert_match    "names both claimants" '1 and 3' "$ERR"
}

# AC 11: the duplicate check reads ordinals as numbers, so a claim spelled
# unpadded is the same identity as its padded twin — the contradiction cannot be
# hidden behind a spelling difference.
case_jimalloc_resolve_spec_duplicate_across_paddings_refused() {
  local dir; dir=$(empty_dir res_dup_spec_pad)
  printf '%s\n' 'spec allocate core/7 alpha 20260726 jane
spec allocate core/007 beta 20260727 mallory' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/007
  assert_exit  "refused"           1         "$RC"
  assert_eq    "no answer"         ""        "$OUT"
  assert_match "names the identity" 'core/007' "$ERR"
}

# AC 11: a single claim still resolves — the refusal is a contradiction check,
# not a ban on re-reading a log that holds many records for many identities.
case_jimalloc_resolve_spec_distinct_identities_still_resolve() {
  local dir; dir=$(empty_dir res_dup_spec_ok)
  printf '%s\n' 'spec allocate core/007 alpha 20260726 jane
spec allocate core/008 beta 20260727 jane' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/007
  assert_exit "rc"      0          "$RC"
  assert_eq   "answer"  "core/007" "$OUT"
}

# AC 11: a name vacated by a rename and claimed again carries two allocate
# records and is NOT a contradiction — the reuse path this replay already
# supports must keep resolving, which is what separates the refusal from a ban
# on repeated strings. Same shape one level up: a group renamed away vacates
# every id under its old name.
case_jimalloc_resolve_spec_vacated_reuse_not_a_duplicate() {
  local dir; dir=$(empty_dir res_dup_spec_vacated)
  printf '%s\n' 'spec allocate core/007 alpha 20260726 jane
spec rename core/007 core/009 20260727 x
spec allocate core/007 beta 20260728 kai' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/007
  assert_exit "vacated-then-reused rc" 0          "$RC"
  assert_eq   "answers the live claim" "core/007" "$OUT"
  printf '%s\n' 'spec allocate dashboard/001 first 20260726 jane
group rename dashboard core 20260727 x
spec allocate dashboard/001 second 20260728 kai' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec dashboard/001
  assert_exit "group-vacated rc" 0 "$RC"
  assert_nonempty "still answers"   "$OUT"
}

# AC 11: the issue side reuses the same liveness rule — an ordinal renamed away
# and later claimed again resolves, so the refusal stays aimed at contradictions.
case_jimalloc_resolve_issue_vacated_reuse_not_a_duplicate() {
  local dir; dir=$(empty_dir res_dup_issue_vacated)
  printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jane
issue rename 5 8 20260727 x
issue allocate 5 20260728-beta 20260728 kai' > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 5
  assert_exit "vacated-then-reused rc" 0   "$RC"
  assert_eq   "answers the live claim" "5" "$OUT"
}

# AC 11: two allocate records claiming one durable issue id make resolve refuse
# — the last-wins map is exactly where a landed collision would stay invisible.
case_jimalloc_resolve_issue_duplicate_durable_id_refused() {
  local dir; dir=$(empty_dir res_dup_issue_id)
  printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jane
issue allocate 9 20260726-alpha 20260727 mallory' > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 20260726-alpha
  assert_exit  "refused"              1                "$RC"
  assert_eq    "no answer"            ""               "$OUT"
  assert_match "names the identity"   '20260726-alpha' "$ERR"
  assert_match "names both claimants" '1 and 2'        "$ERR"
}

# AC 11: two allocate records claiming one issue ordinal are the same
# contradiction from the other direction, and are refused the same way.
case_jimalloc_resolve_issue_duplicate_ordinal_refused() {
  local dir; dir=$(empty_dir res_dup_issue_ord)
  printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jane
issue allocate 5 20260726-beta 20260727 mallory' > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 5
  assert_exit  "refused"            1   "$RC"
  assert_eq    "no answer"          ""  "$OUT"
  assert_match "names both claimants" '1 and 2' "$ERR"
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
                      'spec rename core/009 dashboard/005 20260727 x')
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

# AC: the next spec id sits above every ordinal the group has ever held,
# including one vacated by a rename whose source has no allocate record.
case_jimalloc_next_id_spec_counts_rename_source() {
  local log out
  log=$(printf '%s\n' 'spec rename dashboard/005 core/001 20260727 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec dashboard <<< "$log")"
  assert_eq "vacated ordinal is not reclaimed" "dashboard/006" "$out"
}

# AC: an over-wide ordinal is skipped rather than counted, so it cannot drag the
# next id somewhere the bootstrap would refuse.
case_jimalloc_next_id_spec_skips_over_wide_ordinal() {
  local log out
  log=$(printf '%s\n' 'spec allocate dashboard/1234567890123456 wide 20260726 x' \
                      'spec allocate dashboard/002 b 20260726 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec dashboard <<< "$log")"
  assert_eq "next id unaffected" "dashboard/003" "$out"
}

# AC: the issue side of both guarantees.
case_jimalloc_next_num_issue_counts_rename_source() {
  local log out
  log=$(printf '%s\n' 'issue rename 9 3 20260727 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_num_issue <<< "$log")"
  assert_eq "vacated ordinal is not reclaimed" "10" "$out"
}

case_jimalloc_next_num_issue_skips_over_wide_ordinal() {
  local log out
  log=$(printf '%s\n' 'issue allocate 1234567890123456 20260726-wide 20260726 x' \
                      'issue allocate 5 20260726-b 20260726 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_num_issue <<< "$log")"
  assert_eq "next ordinal unaffected" "6" "$out"
}

# ─── Section: rename / realize encoders ──────────────────────────────────────

# AC 1: each rename encoder writes exactly the one shape, with the free-text
# provenance sanitized on the way in — the write-side complement to the read-side
# gate, so a newline in <who> cannot forge a second record.
case_jimalloc_encode_rename_shapes() {
  local out
  out="$(source "$SCRIPT_jimalloc"; alloc_encode_rename_spec core/003 ui/007 20260802 'jane doe')"
  assert_eq "spec rename" "spec rename core/003 ui/007 20260802 jane-doe" "$out"
  out="$(source "$SCRIPT_jimalloc"; alloc_encode_rename_group core ui 20260802 jane)"
  assert_eq "group rename" "group rename core ui 20260802 jane" "$out"
  out="$(source "$SCRIPT_jimalloc"; alloc_encode_rename_issue 5 8 20260802 jane)"
  assert_eq "issue rename" "issue rename 5 8 20260802 jane" "$out"
  out="$(source "$SCRIPT_jimalloc"
        alloc_encode_rename_spec core/003 ui/007 20260802 "$(printf 'a\nspec rename x/001 y/002 20260802 b')")"
  assert_eq "who cannot forge a record" 1 "$(printf '%s\n' "$out" | grep -c .)"
}

# AC 2: the realization record is its own kind — a provisional token on the left,
# the ordinal it became on the right, and it never spells 'rename'.
case_jimalloc_encode_realize_spec_shape() {
  local out
  out="$(source "$SCRIPT_jimalloc"
        alloc_encode_realize_spec core/P-20260802-alpha core/007 20260802 jane)"
  assert_eq "realize record" \
    "spec realize core/P-20260802-alpha core/007 20260802 jane" "$out"
}

# ─── Section: realization records ────────────────────────────────────────────

# AC 2: once a realization is recorded, the provisional identity resolves to the
# real ordinal — a citation frozen offline dereferences.
case_jimalloc_realize_record_resolves_provisional() {
  local dir; dir=$(empty_dir realize_resolve)
  printf '%s\n' 'spec allocate core/007 alpha 20260802 jane
spec realize core/P-20260802-alpha core/007 20260802 jane' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/P-20260802-alpha
  assert_exit "rc"           0          "$RC"
  assert_eq   "real ordinal" "core/007" "$OUT"
}

# AC 2: and it keeps resolving through whatever happened to the ordinal after —
# realization is the start of the walk, not a separate answer.
case_jimalloc_realize_record_then_rename() {
  local dir; dir=$(empty_dir realize_then_rename)
  printf '%s\n' 'spec allocate core/007 alpha 20260802 jane
spec realize core/P-20260802-alpha core/007 20260802 jane
spec rename core/007 ui/003 20260803 jane' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/P-20260802-alpha
  assert_eq "follows the later rename" "ui/003" "$OUT"
}

# AC 2: a provisional identity nothing has realized is not resolvable — the
# reserved form is not a claim on anything.
case_jimalloc_realize_unrealized_provisional_errors() {
  local dir; dir=$(empty_dir realize_unrealized)
  printf '%s\n' 'spec allocate core/007 alpha 20260802 jane' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/P-20260802-alpha
  assert_exit "rc" 1 "$RC"
  assert_eq   "no answer" "" "$OUT"
}

# AC 2: a realization record raises no group's high-water — neither side of it
# is an ordinal the group consumed by this record, so the fold must not read one.
case_jimalloc_realize_record_does_not_raise_high_water() {
  local log out
  log=$(printf '%s\n' 'spec realize core/P-20260802-alpha core/900 20260802 jane')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec core <<< "$log")"
  assert_eq "no high-water raise" "core/001" "$out"
}

# AC 2: the realize kind is grammar-distinct — the rename reader never sees one,
# so a provisional token can never reach the vacating fold.
case_jimalloc_realize_record_is_not_a_rename() {
  local log out
  log=$(printf '%s\n' 'spec realize core/P-20260802-alpha core/007 20260802 jane')
  out="$(source "$SCRIPT_jimalloc"; alloc_rename_scan spec <<< "$log")"
  assert_eq "not a rename" "" "$out"
}

# AC 1/2: a realize record that is not its one shape is unreadable, the same way
# a malformed rename is; a well-formed one is not an unknown verb.
case_jimalloc_realize_malformed_is_unreadable() {
  run_classify alloc_classify_spec "" \
    "$(printf '%s\n' 'spec allocate core/007 alpha 20260802 jane' \
                     'spec realize core/P-20260802-alpha core/007 20260802')"
  assert_match "counted unreadable" '^CHECKED	unreadable	spec	1$' "$OUT"
}

case_jimalloc_realize_record_is_a_known_verb() {
  local out
  out="$(source "$SCRIPT_jimalloc"
        alloc_unknown_verb_count <<< 'spec realize core/P-20260802-alpha core/007 20260802 jane')"
  assert_eq "known verb" "0" "$out"
}

# ─── Section: rename-record shape strictness ─────────────────────────────────

# AC 1/8: the shared scan rule emits one normalized row per well-formed rename
# record, carrying a PER-SIDE canonicalization verdict rather than dropping the
# whole record when one side fails; a record that is not the one shape never
# appears at all.
case_jimalloc_rename_scan_normalizes_per_side() {
  local log out want
  log=$(printf '%s\n' 'spec allocate core/003 s 20260726 jane' \
                      'spec rename core/3 ui/7 20260727 jane' \
                      'spec rename core/1234567890123456 ui/9 20260728 kai' \
                      'spec rename core/004 ui/010 20260728' \
                      'group rename dashboard ui 20260729 jane')
  out="$(source "$SCRIPT_jimalloc"; alloc_rename_scan spec <<< "$log")"
  want=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    spec  core/003                 y ui/007 y 20260727 jane 2 \
    spec  core/1234567890123456    n ui/009 y 20260728 kai  3 \
    group dashboard                y ui     y 20260729 jane 5)
  assert_eq "normalized rows, malformed dropped" "$want" "$out"
}

# AC 1: a rename record missing its provenance field is not half-parsed — it is
# not a rename at all, so the claim it would have moved stays where it is.
case_jimalloc_rename_missing_who_is_not_followed() {
  local dir; dir=$(empty_dir strict_missing_who)
  printf '%s\n' 'spec allocate core/003 s 20260726 jane
spec rename core/003 ui/007 20260727' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_exit "rc"                     0          "$RC"
  assert_eq   "five-token rename ignored" "core/003" "$OUT"
}

# AC 1: one shape, not a floor — a field past <who> makes a different shape, so
# the record is ignored rather than leniently accepted on its first six tokens.
case_jimalloc_rename_extra_field_is_not_followed() {
  local dir; dir=$(empty_dir strict_extra_field)
  printf '%s\n' 'spec allocate core/003 s 20260726 jane
spec rename core/003 ui/007 20260727 jane extra' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_eq "seven-token rename ignored" "core/003" "$OUT"
}

# AC 1: <date> is gated like every other field, not carried along unread.
case_jimalloc_rename_bad_date_is_not_followed() {
  local dir; dir=$(empty_dir strict_bad_date)
  printf '%s\n' 'spec allocate core/003 s 20260726 jane
spec rename core/003 ui/007 2026 jane' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_eq "bad date ignored" "core/003" "$OUT"
}

# AC 1/18: the <who> slot is field-gated on read, so a pushed record carrying
# ref metacharacters there is not a record this reader follows.
case_jimalloc_rename_hostile_who_is_not_followed() {
  local dir; dir=$(empty_dir strict_hostile_who)
  printf '%s\n' 'spec allocate core/003 s 20260726 jane
spec rename core/003 ui/007 20260727 he^ad~1:x' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_eq "hostile who ignored" "core/003" "$OUT"
}

# AC 1: an unknown record verb is not misparsed as a neighbouring one — the
# kind namespace stays open, so a verb this build does not know moves nothing.
case_jimalloc_rename_unknown_verb_is_not_followed() {
  local dir; dir=$(empty_dir strict_unknown_verb)
  printf '%s\n' 'spec allocate core/003 s 20260726 jane
spec supersede core/003 ui/007 20260727 jane' > "$dir/specs.log"
  run_jimalloc_reg "$dir" resolve spec core/003
  assert_eq "unknown verb ignored" "core/003" "$OUT"
}

# AC 1: the spec fold reads the same one shape — a malformed rename cannot raise
# a group's high-water, so it can never push the next id past a real ordinal.
case_jimalloc_fold_spec_ignores_malformed_rename() {
  local log out
  log=$(printf '%s\n' 'spec allocate dashboard/001 a 20260726 x' \
                      'spec rename dashboard/900 core/001 20260727')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec dashboard <<< "$log")"
  assert_eq "malformed rename does not raise the high-water" "dashboard/002" "$out"
}

# AC 1: the issue fold, same rule.
case_jimalloc_fold_issue_ignores_malformed_rename() {
  local log out
  log=$(printf '%s\n' 'issue rename 9 3 20260727')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_num_issue <<< "$log")"
  assert_eq "malformed rename does not raise the high-water" "1" "$out"
}

# AC 1: the alias map reads the one shape too — a malformed group rename
# redirects nothing, so the destination group inherits no ordinals.
case_jimalloc_alias_map_ignores_malformed_group_rename() {
  local log out
  log=$(printf '%s\n' 'spec allocate dashboard/001 a 20260726 x' \
                      'group rename dashboard ui 20260727')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec ui <<< "$log")"
  assert_eq "no aliasing from a malformed record" "ui/001" "$out"
}

# AC 1: group coverage counts a rename record only when it is the one shape —
# a malformed one leaves the group as uncovered as no record at all.
case_jimalloc_group_coverage_ignores_malformed_rename() {
  local rc
  ( source "$SCRIPT_jimalloc"
    alloc_group_has_records core <<< 'spec rename core/003 ui/007 20260727' ); rc=$?
  assert_exit "malformed rename is not coverage" 1 "$rc"
  ( source "$SCRIPT_jimalloc"
    alloc_group_has_records core <<< 'spec rename core/003 ui/007 20260727 x' ); rc=$?
  assert_exit "well-formed rename is coverage" 0 "$rc"
}

# ─── Section: group-rename aliasing (next-id membership) ─────────────────────

# AC: after a group is renamed, the next id for it counts every ordinal the
# group holds under its former name, so the allocator never offers an id that
# resolution already reports as taken.
case_jimalloc_next_id_spec_group_alias_former_name() {
  local log out
  log=$(printf '%s\n' 'spec allocate dashboard/001 a 20260726 x' \
                      'spec allocate dashboard/002 b 20260726 x' \
                      'group rename dashboard ui 20260727 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec ui <<< "$log")"
  assert_eq "former-name ordinals count" "ui/003" "$out"
}

# AC: the aliasing follows a multi-hop chain of group renames all the way to the
# group's current name.
case_jimalloc_next_id_spec_group_alias_multihop() {
  local log out
  log=$(printf '%s\n' 'spec allocate dashboard/001 a 20260726 x' \
                      'spec allocate dashboard/004 b 20260726 x' \
                      'group rename dashboard ui 20260727 x' \
                      'group rename ui surface 20260728 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec surface <<< "$log")"
  assert_eq "chain fully followed" "surface/005" "$out"
}

# AC: a crafted group-rename cycle terminates rather than spinning. A
# non-terminating walk hangs every allocation with no error message, so the only
# evidence the rule holds is a case that completes.
case_jimalloc_next_id_spec_group_alias_cycle() {
  local log out rc
  # Ordinals under both names, so the answer is wrong unless the cycle is walked
  # to completion — termination alone would pass a literal-prefix filter.
  log=$(printf '%s\n' 'spec allocate alpha/002 a 20260726 x' \
                      'spec allocate beta/007 b 20260726 x' \
                      'group rename alpha beta 20260727 x' \
                      'group rename beta alpha 20260728 x')
  out="$(timeout 10 bash -c '
    source "$1"; alloc_next_id_spec alpha <<< "$2"' _ "$SCRIPT_jimalloc" "$log")"
  rc=$?
  assert_exit "terminates within the bound" 0 "$rc"
  assert_eq   "reverted cycle lands home"   "alpha/008" "$out"
}

# AC: asking for the next id of a group that has been renamed away is refused,
# naming the redirect, so the allocator never mints into a retired namespace and
# never substitutes one group for another without the caller having said so.
case_jimalloc_next_id_spec_group_alias_renamed_away_refused() {
  local log out rc err_file
  err_file="$TMP_BASE/.err_renamed_away"
  log=$(printf '%s\n' 'spec allocate dashboard/001 a 20260726 x' \
                      'spec allocate dashboard/002 b 20260726 x' \
                      'group rename dashboard ui 20260727 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec dashboard <<< "$log" 2>"$err_file")"
  rc=$?
  assert_exit  "refused"            1  "$rc"
  assert_eq    "no stdout to parse" "" "$out"
  assert_match "names the redirect" 'ui' "$(cat "$err_file")"
}

# AC: on the acknowledged path the answer carries the group's current name — the
# refusal is retryable, and the returned group may differ from the one asked for.
case_jimalloc_next_id_spec_group_alias_follow_redirect() {
  local log out rc
  log=$(printf '%s\n' 'spec allocate dashboard/001 a 20260726 x' \
                      'spec allocate dashboard/002 b 20260726 x' \
                      'group rename dashboard ui 20260727 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec dashboard --follow-redirect <<< "$log")"
  rc=$?
  assert_exit "acknowledged path succeeds" 0 "$rc"
  assert_eq   "answers under the current group" "ui/003" "$out"
}

# AC: the acknowledgment is reachable from the CLI — 'peek spec' refuses a
# renamed-away group and answers once the redirect is acknowledged.
case_jimalloc_peek_spec_group_alias_follow_redirect() {
  local dir; dir=$(empty_dir peek_follow_redirect)
  printf '%s\n' 'spec allocate dashboard/001 a 20260726 x
spec allocate dashboard/002 b 20260726 x
group rename dashboard ui 20260727 x' > "$dir/specs.log"
  run_jimalloc_reg "$dir" peek spec dashboard
  assert_exit     "peek refuses the retired name" 1  "$RC"
  assert_eq       "no stdout to parse"            "" "$OUT"
  assert_nonempty "explains"                      "$ERR"
  run_jimalloc_reg "$dir" peek spec dashboard --follow-redirect
  assert_exit "acknowledged peek succeeds" 0         "$RC"
  assert_eq   "current group"              "ui/003"  "$OUT"
}

# ─── Section: high-water fold (rename sources, ordinal legality) ─────────────

# AC: a vacated ordinal is never reissued for every log shape — including a
# rename source carrying no allocation record of its own, where the guarantee
# would otherwise rest on an unenforced assumption about how records were emitted.
case_jimalloc_fold_max_spec_counts_rename_source() {
  local log out
  log=$(printf '%s\n' 'spec rename dashboard/005 core/001 20260727 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_fold_max_spec dashboard <<< "$log")"
  assert_eq "unallocated source raises the high-water" "5" "$out"
}

# AC: the same guarantee on the issue side.
case_jimalloc_fold_max_issue_counts_rename_source() {
  local log out
  log=$(printf '%s\n' 'issue rename 9 3 20260727 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_fold_max_issue <<< "$log")"
  assert_eq "unallocated source raises the high-water" "9" "$out"
}

# jimalloc_reused_name_log — a log where a freed group name is taken over by
# another group: `core` becomes `legacy`, then `side` becomes `core`. The two
# `core`s are different groups, and every read path has to keep them apart.
jimalloc_reused_name_log() {
  printf '%s\n' \
    'group rename core legacy 20260701 x' \
    'group rename side core 20260702 x' \
    'spec allocate side/001 a 20260703 x' \
    'spec allocate side/002 b 20260704 x' \
    'spec allocate side/003 c 20260705 x' \
    'spec allocate legacy/001 d 20260706 x'
}

# AC: the fold answers about the group it is ASKED about — the caller-resolved
# current name — counting every record that group holds under any former name,
# and counting nothing for a name the group no longer answers to. Resolving the
# argument a second time inside the fold is what lets a caller's answer land on
# another group's high-water.
case_jimalloc_fold_max_spec_takes_a_resolved_group() {
  local log
  log="$(jimalloc_reused_name_log)"
  assert_eq "current name counts its records under every former name" "3" \
    "$(source "$SCRIPT_jimalloc"; alloc_fold_max_spec core <<< "$log")"
  assert_eq "the group that vacated the name is separate" "1" \
    "$(source "$SCRIPT_jimalloc"; alloc_fold_max_spec legacy <<< "$log")"
  assert_eq "a name no longer answered to holds nothing" "0" \
    "$(source "$SCRIPT_jimalloc"; alloc_fold_max_spec side <<< "$log")"
}

# AC: on a reused-group-name log, next-id reports no ordinal the current group
# already holds.
case_jimalloc_next_id_spec_reused_group_name() {
  local log out
  log="$(jimalloc_reused_name_log)"
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec side --follow-redirect <<< "$log")"
  assert_eq "clears every ordinal the current group holds" "core/004" "$out"
}

# AC: realize reports none either — the same fold, the same log, the same answer,
# so the two read paths cannot publish a duplicate record between them.
case_jimalloc_realize_spec_reused_group_name() {
  local log
  log="$(jimalloc_reused_name_log)"
  run_realize_spec "$log" side/P-20260728-x
  assert_exit "rc" 0 "$RC"
  assert_eq "clears every ordinal the current group holds" \
    "$(printf 'side/P-20260728-x\tcore/004\tnew')" "$OUT"
}

# AC: miscounting errs only toward skipping — an ordinal too large to compute
# with reliably is passed over as malformed rather than counted, so it cannot
# drag the high-water somewhere the registry could never be rebuilt from.
case_jimalloc_fold_max_spec_skips_over_wide_ordinal() {
  local log out
  log=$(printf '%s\n' 'spec allocate dashboard/1234567890123456 wide 20260726 x' \
                      'spec allocate dashboard/002 b 20260726 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_fold_max_spec dashboard <<< "$log")"
  assert_eq "over-wide ordinal skipped" "2" "$out"
}

# AC: the same skip on the issue side.
case_jimalloc_fold_max_issue_skips_over_wide_ordinal() {
  local log out
  log=$(printf '%s\n' 'issue allocate 1234567890123456 20260726-wide 20260726 x' \
                      'issue allocate 5 20260726-b 20260726 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_fold_max_issue <<< "$log")"
  assert_eq "over-wide ordinal skipped" "5" "$out"
}

# AC: every ordinal the allocator can mint is one the registry's own bootstrap
# accepts, so a repository the allocator built can always be rebuilt into a
# registry from its own tree. Both sides decide legality from one shared value.
case_jimalloc_fold_max_spec_mint_is_seedable() {
  local log minted root
  log=$(printf '%s\n' 'spec allocate core/999 a 20260726 x')
  minted="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec core <<< "$log")"
  assert_eq "mints above three digits" "core/1000" "$minted"
  root="$(seed_specs_tree seed_wide_ord "${minted}-wide")"
  run_seed_fn alloc_seed_derive_specs "$root"
  assert_exit  "bootstrap accepts what was minted" 0 "$RC"
  assert_match "and records it"  'spec allocate core/1000 wide ' "$OUT"
}

# AC: the shared legality value still refuses what it must — a tree ordinal wider
# than the fold will count is rejected by the bootstrap rather than seeded into a
# registry the allocator would then read as malformed.
case_jimalloc_fold_max_spec_seed_refuses_over_wide() {
  local root
  root="$(seed_specs_tree seed_wide_reject core/1234567890123456-wide)"
  run_seed_fn alloc_seed_derive_specs "$root"
  assert_exit  "rc"             1                    "$RC"
  assert_eq    "no records"     ""                   "$OUT"
  assert_match "names offender" '1234567890123456'   "$ERR"
}

# ─── Section: group alias map ────────────────────────────────────────────────

# AC: the alias map reports every renamed group's current name with the chain
# fully followed, so each intermediate name also maps to the final one.
case_jimalloc_group_alias_map_chain() {
  local log out
  log=$(printf '%s\n' 'group rename dashboard ui 20260727 x' \
                      'group rename ui surface 20260728 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_group_alias_map <<< "$log" | LC_ALL=C sort)"
  assert_eq "both hops resolve to the end of the chain" \
    "$(printf 'dashboard\tsurface\nui\tsurface')" "$out"
}

# AC: a crafted cycle in the group-rename records terminates. Each record
# applies at most once in file order, matching the resolver's replay, so A→B
# followed by B→A lands both names where a forward replay would put them.
case_jimalloc_group_alias_map_cycle() {
  local log out rc
  log=$(printf '%s\n' 'group rename alpha beta 20260727 x' \
                      'group rename beta alpha 20260728 x')
  out="$(timeout 10 bash -c '
    source "$1"; alloc_group_alias_map <<< "$2" | LC_ALL=C sort' _ "$SCRIPT_jimalloc" "$log")"
  rc=$?
  assert_exit "terminates within the bound" 0 "$rc"
  assert_eq   "cycle resolves in file order" \
    "$(printf 'alpha\talpha\nbeta\talpha')" "$out"
}

# AC: a group-rename record carrying a crafted token is skipped at the id/slug
# boundary, and a well-formed record in the same log still resolves.
case_jimalloc_group_alias_map_skips_malformed() {
  local log out
  log=$(printf '%s\n' 'group rename ../../etc passwd 20260727 x' \
                      'group rename good --upload-pack=x 20260727 x' \
                      'group rename dashboard ui 20260728 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_group_alias_map <<< "$log" | LC_ALL=C sort)"
  assert_eq "only the well-formed record maps" "$(printf 'dashboard\tui')" "$out"
}

# AC: a log with no group-rename record yields an empty map.
case_jimalloc_group_alias_map_empty() {
  local log out rc
  log=$(printf '%s\n' 'spec allocate dashboard/001 a 20260726 x')
  out="$(source "$SCRIPT_jimalloc"; alloc_group_alias_map <<< "$log")"
  rc=$?
  assert_exit "empty map is not an error" 0  "$rc"
  assert_eq   "no renames → empty"        "" "$out"
}

# AC: next issue ordinal is max+1 over allocate ids and rename destinations,
# unpadded; empty registry → 1.
case_jimalloc_next_num_issue() {
  local out log
  out="$(source "$SCRIPT_jimalloc"; alloc_next_num_issue <<< "")"
  assert_eq "empty → 1" "1" "$out"
  log=$(printf '%s\n' 'issue allocate 5 20260726-a 20260726 x' \
                      'issue rename 5 11 20260727 x')
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

# ─── Section: durable-id honors issue_id_prefix ──────────────────────────────
#
# The durable id's prefix follows the configured issue_id_prefix scheme (the
# shape next-id issue produced before filing routed through the allocator), with
# a date-slug fallback wherever a scheme can't be minted at allocation time.

# AC: the sequential preset embeds the coordinated ordinal as the durable-id
# prefix — not the date. allocate issue "Alpha bug" is ordinal 1, so the id is
# the zero-padded ordinal, not today's date.
case_jimalloc_durable_id_honors_sequential_prefix() {
  local repo fid
  repo="$(alloc_new_repo alloc_prefix_sequential)"
  printf 'issue_id_prefix = "sequential"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate issue "Alpha bug"
  assert_exit "rc" 0 "$RC"
  fid="${OUT%%$'\t'*}"
  assert_eq "sequential prefix == coordinated ordinal" "0001-alpha-bug" "$fid"
}

# AC: a provisional allocation under the sequential preset has no coordinated
# ordinal, so the durable-id prefix degrades to the date-slug fallback.
case_jimalloc_durable_id_prefix_provisional_sequential_fallback() {
  local repo today fid
  repo="$(alloc_provisional_repo alloc_prefix_prov_seq)"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  printf 'id_coordination_unreachable = "provisional"\nissue_id_prefix = "sequential"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate issue "Alpha bug"
  assert_exit "rc" 0 "$RC"
  fid="${OUT%%$'\t'*}"
  assert_eq "provisional sequential → date-slug fallback" "${today}-alpha-bug" "$fid"
}

# AC: the {seq:04} template escape hatch also degrades to date-slug in
# provisional mode — it must NOT render an arbitrary 0000 prefix, which the
# shared prefix-from would otherwise emit for a num-less template.
case_jimalloc_durable_id_prefix_provisional_seq_template_fallback() {
  local repo today fid
  repo="$(alloc_provisional_repo alloc_prefix_prov_tmpl)"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  printf 'id_coordination_unreachable = "provisional"\nissue_id_prefix = "{seq:04}"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate issue "Alpha bug"
  assert_exit "rc" 0 "$RC"
  fid="${OUT%%$'\t'*}"
  assert_eq "provisional {seq} template → date-slug" "${today}-alpha-bug" "$fid"
  if [[ "$fid" == 0000-* ]]; then
    CURRENT_FAILED=1; echo "    [template] provisional {seq} rendered a bogus 0000 prefix"
  fi
}

# AC: the project scheme is num-independent, so it is honored on the real path —
# the durable-id prefix is the configured project tag.
case_jimalloc_durable_id_prefix_project_honored() {
  local repo fid
  repo="$(alloc_new_repo alloc_prefix_project)"
  printf 'issue_id_prefix = "project"\nissue_id_project = "acme"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate issue "Alpha bug"
  assert_exit "rc" 0 "$RC"
  fid="${OUT%%$'\t'*}"
  assert_eq "project prefix" "acme-alpha-bug" "$fid"
}

# AC: project needs no coordinated ordinal, so it is honored even in provisional
# mode — unlike the ordinal-bearing schemes, it does not fall back.
case_jimalloc_durable_id_prefix_project_provisional_honored() {
  local repo fid
  repo="$(alloc_provisional_repo alloc_prefix_project_prov)"
  printf 'id_coordination_unreachable = "provisional"\nissue_id_prefix = "project"\nissue_id_project = "acme"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate issue "Alpha bug"
  assert_exit "rc" 0 "$RC"
  fid="${OUT%%$'\t'*}"
  assert_eq "project honored in provisional mode" "acme-alpha-bug" "$fid"
}

# AC: the timestamp scheme is num-independent and honored; passing an ISO now
# gives it real sub-day precision (YYYYMMDDThhmmss), not a day-start.
case_jimalloc_durable_id_prefix_timestamp_honored() {
  local repo fid
  repo="$(alloc_new_repo alloc_prefix_ts)"
  printf 'issue_id_prefix = "timestamp"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate issue "Alpha bug"
  assert_exit "rc" 0 "$RC"
  fid="${OUT%%$'\t'*}"
  assert_match "timestamp prefix shape" '^[0-9]{8}T[0-9]{6}-alpha-bug$' "$fid"
}

# AC: the default date scheme is byte-for-byte unchanged — the durable id stays
# YYYYMMDD-slug and the registry record is identical to pre-change behavior, so
# platform/007's frozen record grammar is unaffected.
case_jimalloc_durable_id_prefix_date_default_unchanged() {
  local repo today fid log
  repo="$(alloc_new_repo alloc_prefix_date_default)"
  printf 'issue_id_prefix = "date"\n' > "$repo/jimconf.toml"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  run_jimalloc_in "$repo" allocate issue "Alpha bug"
  assert_exit "rc" 0 "$RC"
  fid="${OUT%%$'\t'*}"
  assert_eq "date default durable id" "${today}-alpha-bug" "$fid"
  log="$(alloc_issues_log "$repo")"
  assert_match "registry record unchanged" "^issue allocate 1 ${today}-alpha-bug ${today} " "$log"
}

# AC: a crafted issue_id_project (leading dot / path traversal) is rejected at
# the id boundary and degrades to date-slug — it never reaches a filename,
# registry token, or git argument as an injected option or traversal.
case_jimalloc_durable_id_prefix_crafted_project_degrades() {
  local repo today fid
  repo="$(alloc_new_repo alloc_prefix_crafted_project)"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  printf 'issue_id_prefix = "project"\nissue_id_project = "../../etc"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate issue "Alpha bug"
  assert_exit "rc" 0 "$RC"
  fid="${OUT%%$'\t'*}"
  assert_eq "crafted project → date-slug fallback" "${today}-alpha-bug" "$fid"
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

# AC: --follow-redirect carries an allocation into the group the old name now
# resolves to, end to end — the record lands under the current name and the
# printed id names it, so a caller that consented to the redirect never mints
# into a retired namespace.
case_jimalloc_allocate_spec_follow_redirect_end_to_end() {
  local repo log
  repo="$(alloc_new_repo alloc_follow_redirect)"
  run_jimalloc_in "$repo" allocate spec sdlc "First feature"
  assert_eq "issued under the original name" "sdlc/001" "$OUT"
  alloc_append_record "$repo" specs.log 'group rename sdlc core 20260729 jane'
  run_jimalloc_in "$repo" allocate spec sdlc "Second feature"
  assert_exit  "refuses without consent" 1         "$RC"
  assert_match "names the redirect"      'renamed' "$ERR"
  run_jimalloc_in "$repo" allocate spec sdlc "Second feature" --follow-redirect
  assert_exit "rc" 0 "$RC"
  assert_eq   "issued under the current name" "core/002" "$OUT"
  log="$(alloc_specs_log "$repo")"
  assert_match "recorded under the current name" '^spec allocate core/002 second-feature ' "$log"
  assert_eq "nothing minted into the retired name" "0" \
    "$(printf '%s\n' "$log" | grep -c '^spec allocate sdlc/002 ')"
}
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
# alloc_bare_issues <bare> — print issues.log on the bare remote's coordination branch.
alloc_bare_issues() { git -C "$1" cat-file -p refs/heads/jim/registry:issues.log 2>/dev/null; }

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

# ─── Section: origin tip re-validation (untrusted remote input) ──────────────

# alloc_lsremote_shim <name> <first-field>
#   A directory holding a `git` that answers `ls-remote` with one crafted line
#   whose first field is <first-field>, and treats `fetch` as a success;
#   everything else execs the real git. The remote's advertised tip is the one
#   value the allocator takes from outside and interpolates into later git
#   arguments, so this shim is how a crafted advertisement is staged.
alloc_lsremote_shim() {
  local dir real
  dir=$(empty_dir "$1")
  real="$(command -v git)"
  {
    printf '%s\n' '#!/usr/bin/env bash' 'set -uo pipefail'
    printf '%s\n' 'for a in "$@"; do'
    printf '%s\n' '  case "$a" in'
    printf '    ls-remote) printf "%%s\\trefs/heads/jim/registry\\n" %q; exit 0 ;;\n' "$2"
    printf '%s\n' '    fetch) exit 0 ;;'
    printf '%s\n' '  esac' 'done'
    printf 'exec %s "$@"\n' "$real"
  } > "$dir/git"
  chmod +x "$dir/git"
  printf '%s' "$dir"
}

# AC 12: a crafted tip advertised by the remote is refused at the id boundary
# before it can reach a git command — the value crosses the same boundary every
# other untrusted token on this surface crosses, so an option-shaped
# advertisement is rejected rather than interpolated.
#
# Discriminating: with the boundary check neutered the case fails on the tip it
# hands back (`--upload-pack=touch`), not merely on the exit code — verified by
# mutation.
case_jimalloc_origin_tip_rejects_crafted_advertisement() {
  local shim oldpath
  shim="$(alloc_lsremote_shim tip_crafted_shim '--upload-pack=touch /tmp/pwned')"
  oldpath="$PATH"; PATH="$shim:$PATH"
  run_seed_fn alloc_origin_tip origin jim/registry
  PATH="$oldpath"
  assert_exit     "refused"        1  "$RC"
  assert_eq       "no tip printed" "" "$OUT"
  assert_nonempty "names a reason" "$ERR"
}

# AC 12: the guard is a boundary check, not a refusal of every remote — a
# well-formed advertised tip still returns, so validation costs the normal path
# nothing.
case_jimalloc_origin_tip_accepts_wellformed_sha() {
  local shim oldpath sha
  sha="0123456789abcdef0123456789abcdef01234567"
  shim="$(alloc_lsremote_shim tip_ok_shim "$sha")"
  oldpath="$PATH"; PATH="$shim:$PATH"
  run_seed_fn alloc_origin_tip origin jim/registry
  PATH="$oldpath"
  assert_exit "rc"  0     "$RC"
  assert_eq   "tip" "$sha" "$OUT"
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

# alloc_append_record <repo> <logfile> <line>
#   Append one raw record to <logfile> on the coordination branch through
#   plumbing, preserving the prior content (so the erosion guard sees ordinary
#   growth) and every sibling log in the tree.
alloc_append_record() {
  local repo="$1" logfile="$2" line="$3"
  local parent prior blob entries tree commit
  parent="$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
  prior="$(git -C "$repo" cat-file -p "refs/heads/jim/registry:$logfile" 2>/dev/null || true)"
  if [[ -n "$prior" ]]; then
    blob="$(printf '%s\n%s\n' "$prior" "$line" | git -C "$repo" hash-object -w --stdin)"
  else
    blob="$(printf '%s\n' "$line" | git -C "$repo" hash-object -w --stdin)"
  fi
  entries="$(git -C "$repo" ls-tree "$parent" 2>/dev/null | grep -v "	$logfile\$" || true)"
  tree="$( { [[ -n "$entries" ]] && printf '%s\n' "$entries"
             printf '100644 blob %s\t%s\n' "$blob" "$logfile"; } \
           | git -C "$repo" mktree)"
  commit="$(git -C "$repo" commit-tree "$tree" ${parent:+-p "$parent"} -m append)"
  git -C "$repo" update-ref refs/heads/jim/registry "$commit"
}

# AC: when the record builder refuses with a specific reason — here a group
# renamed away, the retryable redirect — that reason is the only thing on
# stderr, so a consumer classifying the refusal by the last line it reads sees
# the redirect rather than a generic failure appended after it.
case_jimalloc_allocate_refusal_single_stderr_reason() {
  local repo lines
  repo="$(alloc_new_repo alloc_refusal_stderr)"
  run_jimalloc_in "$repo" allocate spec dashboard "First feature"
  assert_exit "setup rc" 0 "$RC"
  alloc_append_record "$repo" specs.log 'group rename dashboard ui 20260727 x'
  run_jimalloc_in "$repo" allocate spec dashboard "Second feature"
  assert_exit  "refused"            1    "$RC"
  assert_eq    "no id issued"       ""   "$OUT"
  assert_match "names the redirect" 'ui' "$ERR"
  lines="$(printf '%s\n' "$ERR" | grep -c '^error:')"
  assert_eq "exactly one error line" "1" "$lines"
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

# AC: the unreachable-origin behavior is config-governed; `provisional` is an
# accepted mode (spec AC 1). Preflight admits it, and because the no-remote
# local tier is unchanged (there is no unreachable origin to defer), allocation
# proceeds normally and returns a real id.
case_jimalloc_unreachable_provisional_accepted() {
  local repo
  repo="$(alloc_new_repo alloc_unreach_mode)"
  printf 'id_coordination_unreachable = "provisional"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate spec g "x"
  assert_exit "rc" 0       "$RC"
  assert_eq   "id" "g/001" "$OUT"
}

# AC: an unknown id_coordination_unreachable value is still rejected loudly —
# preflight admits only 'fail' and 'provisional'.
case_jimalloc_unreachable_unknown_rejected() {
  local repo
  repo="$(alloc_new_repo alloc_unreach_unknown)"
  printf 'id_coordination_unreachable = "bogus"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate spec g "x"
  assert_exit     "rc"      1  "$RC"
  assert_eq       "no id"   "" "$OUT"
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

# ─── Section: provisional allocation (unreachable origin, opt-in) ────────────

# alloc_provisional_repo <name> — a repo whose configured origin is unreachable
# and whose unreachable mode is 'provisional'; prints its path.
alloc_provisional_repo() {
  local repo; repo="$(alloc_new_repo "$1")"
  git -C "$repo" remote add origin "$TMP_BASE/no-such-provisional.git"
  printf 'id_coordination_unreachable = "provisional"\n' > "$repo/jimconf.toml"
  printf '%s' "$repo"
}

# AC: with an unreachable origin and provisional mode, an issue allocation
# returns a usable identifier locally instead of hard-failing — the durable
# date-slug id (real, offline-computed) plus a grammar-distinct provisional
# ordinal marker (never ^[0-9]+$). It contacts no network (it succeeds despite
# the unreachable origin) and writes no registry (spec AC 1/2/3).
case_jimalloc_provisional_issue_offline() {
  local repo today fid prov
  repo="$(alloc_provisional_repo prov_issue)"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  run_jimalloc_in "$repo" allocate issue "Alpha bug"
  assert_exit "rc" 0 "$RC"
  fid="${OUT%%$'\t'*}"; prov="${OUT##*$'\t'}"
  assert_eq    "durable date-slug" "${today}-alpha-bug" "$fid"
  assert_nonempty "provisional ordinal" "$prov"
  if [[ "$prov" =~ ^[0-9]+$ ]]; then
    CURRENT_FAILED=1; echo "    [grammar] provisional ordinal is a bare ordinal: [$prov]"
  fi
  assert_eq "no registry written" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
}

# AC: with an unreachable origin and provisional mode, a spec allocation returns
# a whole-identity provisional id — grammar-distinct from every real spec id
# (its ordinal slot is non-numeric), so it can never be mistaken for one; it
# writes no registry (spec AC 2/3; spec reconcile deferred to #112/#113).
case_jimalloc_provisional_spec_offline() {
  local repo ord
  repo="$(alloc_provisional_repo prov_spec)"
  run_jimalloc_in "$repo" allocate spec dashboard "New widget"
  assert_exit "rc" 0 "$RC"
  assert_match "grouped id" '^dashboard/' "$OUT"
  ord="${OUT##*/}"
  if [[ "$ord" =~ ^[0-9]+$ ]]; then
    CURRENT_FAILED=1; echo "    [grammar] provisional spec ordinal is numeric: [$ord]"
  fi
  assert_eq "no registry written" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
}

# AC: a pending provisional never enters the next-id computation or the
# read-only preview — peek reports the same next ordinal the empty registry
# would give, uninflated by the provisional issuances (spec AC 2).
case_jimalloc_provisional_peek_unaffected() {
  local repo
  repo="$(alloc_provisional_repo prov_peek)"
  run_jimalloc_in "$repo" allocate issue "First provisional"
  assert_exit "issue rc" 0 "$RC"
  run_jimalloc_in "$repo" allocate issue "Second provisional"
  assert_exit "issue rc" 0 "$RC"
  run_jimalloc_in "$repo" peek issue
  assert_exit "peek rc"  0   "$RC"
  assert_eq   "peek uninflated" "1" "$OUT"
}

# AC: an explicit 'fail' mode over an unreachable origin still hard-fails and
# never falls back to a local allocation — provisional mode changes only the
# 'provisional' value; the 'fail' path is byte-identical (spec AC 1).
case_jimalloc_provisional_fail_mode_hard_fails() {
  local repo
  repo="$(alloc_new_repo prov_fail_mode)"
  git -C "$repo" remote add origin "$TMP_BASE/no-such-fail.git"
  printf 'id_coordination_unreachable = "fail"\n' > "$repo/jimconf.toml"
  run_jimalloc_in "$repo" allocate spec g "x"
  assert_exit     "rc"      1  "$RC"
  assert_eq       "no id"   "" "$OUT"
  assert_nonempty "message" "$ERR"
  assert_eq "no coordination branch" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
}

# AC: a crafted token on the provisional path is rejected at the id/slug/name
# boundary before any deferral — an option-injection group never reaches
# issuance, and nothing is written (spec AC 12).
case_jimalloc_provisional_crafted_group_rejected() {
  local repo
  repo="$(alloc_provisional_repo prov_crafted)"
  run_jimalloc_in "$repo" allocate spec "--upload-pack=x" "sub"
  assert_exit     "rc"      1  "$RC"
  assert_eq       "no id"   "" "$OUT"
  assert_nonempty "message" "$ERR"
  assert_eq "no registry written" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
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

# ─── Section: peek (advisory, read-only preview) ─────────────────────────────

# AC: peek previews the id the next allocation would produce and leaves the
# registry byte-identical — it never binds and never mutates (spec: read-only
# preview; only allocation binds).
case_jimalloc_peek_spec_no_mutation() {
  local repo before after
  repo="$(alloc_new_repo alloc_peek_spec)"
  run_jimalloc_in "$repo" allocate spec g "one"
  before="$(git -C "$repo" rev-parse refs/heads/jim/registry)"
  run_jimalloc_in "$repo" peek spec g
  assert_exit "peek rc"       0       "$RC"
  assert_eq   "peek next id"  "g/002" "$OUT"
  after="$(git -C "$repo" rev-parse refs/heads/jim/registry)"
  assert_eq   "registry unchanged" "$before" "$after"
}

# AC: peek issue previews the next ordinal without reserving it.
case_jimalloc_peek_issue() {
  local repo
  repo="$(alloc_new_repo alloc_peek_issue)"
  run_jimalloc_in "$repo" allocate issue "First"
  run_jimalloc_in "$repo" peek issue
  assert_exit "rc"       0   "$RC"
  assert_eq   "next num" "2" "$OUT"
}

# AC: peek against an empty registry previews the first id.
case_jimalloc_peek_empty_registry() {
  local repo
  repo="$(alloc_new_repo alloc_peek_empty)"
  run_jimalloc_in "$repo" peek spec newgroup
  assert_exit "rc"       0              "$RC"
  assert_eq   "first id" "newgroup/001" "$OUT"
}

# AC: peek is advisory — an unreachable remote is non-fatal (it degrades to the
# last-seen local state), in contrast to allocate which hard-fails.
case_jimalloc_peek_unreachable_non_fatal() {
  local repo
  repo="$(alloc_new_repo alloc_peek_unreach)"
  git -C "$repo" remote add origin "$TMP_BASE/no-such-peek.git"
  run_jimalloc_in "$repo" peek spec g
  assert_exit "rc"                0       "$RC"
  assert_eq   "degrades to local" "g/001" "$OUT"
}

# ─── Section: seed (one-time registry bootstrap) ─────────────────────────────

# AC: `seed` is a dispatched subcommand that validates its own arguments — an
# unknown option is a usage error (rc 2) whose message names the `--apply` form,
# distinct from the top-level "unknown subcommand" error.
case_jimalloc_seed_usage() {
  run_jimalloc seed --bogus
  assert_exit  "seed bad-flag rc" 2      "$RC"
  assert_eq    "stdout empty"     ""     "$OUT"
  assert_match "usage names --apply" 'apply' "$ERR"
}

# seed_specs_tree <name> <group/NNN-slug>...
#   Build a fixture specs tree under a temp dir; print its root.
seed_specs_tree() {
  local root; root="$(empty_dir "$1")"; shift
  local spec
  for spec in "$@"; do mkdir -p "$root/$spec"; done
  printf '%s' "$root"
}

# seed_issue_file <dir> <name> <num> <id> <created>
#   Write a fixture issue file with the given frontmatter.
seed_issue_file() {
  printf -- '---\nid: %s\nnum: %s\ncreated: %s\ntitle: "x"\n---\nbody\n' \
    "$4" "$3" "$5" > "$1/$2"
}

# AC: derivation over a fixture specs tree emits one `group allocate` per group
# (once), one `spec allocate` per dir, skips the reserved 000-blueprint slot,
# orders groups then specs deterministically, and stamps jim-seed provenance.
case_jimalloc_seed_derive_specs() {
  local root today out expected
  root="$(seed_specs_tree seed_dspecs \
    core/000-blueprint core/001-alpha core/002-beta dashboard/001-gamma)"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  out="$(source "$SCRIPT_jimalloc"; alloc_seed_derive_specs "$root")"
  expected="$(printf '%s\n' \
    "group allocate core $today jim-seed" \
    "spec allocate core/001 alpha $today jim-seed" \
    "spec allocate core/002 beta $today jim-seed" \
    "group allocate dashboard $today jim-seed" \
    "spec allocate dashboard/001 gamma $today jim-seed")"
  assert_eq "derived specs records" "$expected" "$out"
}

# AC: a group holding only the reserved 000-blueprint slot contributes no records
# at all (no group allocate, no spec allocate).
case_jimalloc_seed_derive_specs_blueprint_only() {
  local root out
  root="$(seed_specs_tree seed_dbp core/000-blueprint)"
  out="$(source "$SCRIPT_jimalloc"; alloc_seed_derive_specs "$root")"
  assert_eq "blueprint-only group → no records" "" "$out"
}

# AC 16: any zero-valued ordinal names the reserved blueprint slot, whatever its
# padding — `0-`, `00-`, and `000-` are one rule, so the derivation can never
# mint the `<group>/000` record the sweep classifies as drift.
case_jimalloc_seed_derive_specs_zero_ordinal_widths_reserved() {
  local root today out expected
  root="$(seed_specs_tree seed_zeroord \
    core/0-blueprint core/001-alpha ui/00-blueprint ui/001-widget)"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  out="$(source "$SCRIPT_jimalloc"; alloc_seed_derive_specs "$root")"
  expected="$(printf '%s\n' \
    "group allocate core $today jim-seed" \
    "spec allocate core/001 alpha $today jim-seed" \
    "group allocate ui $today jim-seed" \
    "spec allocate ui/001 widget $today jim-seed")"
  assert_eq "zero-valued ordinals reserved at every width" "$expected" "$out"
}

# AC 16: a group holding only a narrow-spelled reserved slot contributes nothing
# — same as the canonical spelling, so a blueprint-only group never claims a
# group record on the strength of its reserved dir.
case_jimalloc_seed_derive_specs_narrow_zero_only() {
  local root out
  root="$(seed_specs_tree seed_zeroonly core/0-blueprint)"
  out="$(source "$SCRIPT_jimalloc"; alloc_seed_derive_specs "$root")"
  assert_eq "narrow reserved-only group → no records" "" "$out"
}

# AC 16: the reserved rule is numeric, so a slugless bare `000` dir still skips
# rather than falling through to the no-slug conflict — the ordering the check
# depends on, asserted rather than assumed.
case_jimalloc_seed_derive_specs_bare_zero_dir_skipped() {
  local root
  root="$(seed_specs_tree seed_barezero core/000 core/001-alpha)"
  run_seed_fn alloc_seed_derive_specs "$root"
  assert_exit  "no conflict" 0 "$RC"
  assert_match "sibling still derived" 'spec allocate core/001 alpha ' "$OUT"
  assert_eq "no reserved record" "0" \
    "$(printf '%s\n' "$OUT" | grep -c 'core/000')"
}

# AC: a pending provisional spec dir is reserved like the 000 slot — it derives
# no record, raises no conflict, and its real siblings seed normally.
case_jimalloc_seed_skips_provisional_dir() {
  local root today expected
  root="$(seed_specs_tree seed_provskip core/001-alpha core/P-20260730-new-widget)"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  run_seed_fn alloc_seed_derive_specs "$root"
  assert_exit "rc"                   0  "$RC"
  assert_eq   "no conflict reported" "" "$ERR"
  expected="$(printf '%s\n' \
    "group allocate core $today jim-seed" \
    "spec allocate core/001 alpha $today jim-seed")"
  assert_eq "sibling seeds, provisional skipped" "$expected" "$OUT"
}

# AC: a group holding only pending provisional dirs contributes no records at
# all — the reserved class is invisible to the bootstrap, like the blueprint slot.
case_jimalloc_seed_skips_provisional_only_group() {
  local root
  root="$(seed_specs_tree seed_provonly core/P-20260730-new-widget)"
  run_seed_fn alloc_seed_derive_specs "$root"
  assert_exit "rc"                                  0  "$RC"
  assert_eq   "provisional-only group → no records" "" "$OUT"
}

# AC: only the reserved form is skipped — a dir merely starting with the prefix
# but carrying a token the id boundary rejects is still a loud conflict, so the
# skip cannot be used to hide an unseedable directory from the bootstrap.
case_jimalloc_seed_provisional_prefix_invalid_token_conflicts() {
  local root
  root="$(seed_specs_tree seed_provbadtok core/P---bad)"
  run_seed_fn alloc_seed_derive_specs "$root"
  assert_exit     "rc"         1  "$RC"
  assert_eq       "no records" "" "$OUT"
  assert_nonempty "message"    "$ERR"
}

# AC: derivation over a fixture issues dir emits one `issue allocate` per file in
# ascending ordinal, reads num/id from frontmatter (not INDEX.md), normalizes the
# created timestamp to YYYYMMDD, and stamps jim-seed provenance.
case_jimalloc_seed_derive_issues() {
  local dir out expected
  dir="$(empty_dir seed_dissues)"
  seed_issue_file "$dir" "20260726-beta.md"  2 20260726-beta  2026-07-26T11:00:00Z
  seed_issue_file "$dir" "20260726-alpha.md" 1 20260726-alpha 2026-07-26T10:00:00Z
  printf 'INDEX\n' > "$dir/INDEX.md"
  out="$(source "$SCRIPT_jimalloc"; alloc_seed_derive_issues "$dir")"
  expected="$(printf '%s\n' \
    "issue allocate 1 20260726-alpha 20260726 jim-seed" \
    "issue allocate 2 20260726-beta 20260726 jim-seed")"
  assert_eq "derived issue records" "$expected" "$out"
}

# AC: a hand-authored padded ordinal seeds in canonical form. The fold and the
# seed's own dedupe read the ordinal numerically, but the issue resolver compares
# as a string — so seeding `007` verbatim would leave `resolve issue 7` reporting
# not-allocated while `peek issue` counted it. The spec seed already normalizes;
# this is the same defect class on the side that was left out.
case_jimalloc_seed_issues_padded_num_normalized() {
  local dir out
  dir="$(empty_dir seed_issues_padded)"
  seed_issue_file "$dir" "20260726-alpha.md" 007 20260726-alpha 2026-07-26T10:00:00Z
  out="$(source "$SCRIPT_jimalloc"; alloc_seed_derive_issues "$dir")"
  assert_eq "seeded unpadded" \
    "issue allocate 7 20260726-alpha 20260726 jim-seed" "$out"
}

# AC 10: the derivation's provenance marker is a parameter, so a writer other
# than the bootstrap can stamp its own — the forensic distinguisher between a
# bootstrap append and a catch-up append.
case_jimalloc_seed_derive_marker_parametrized() {
  local root dir today specs issues
  root="$(seed_specs_tree seed_marker_specs core/001-alpha)"
  dir="$(empty_dir seed_marker_issues)"
  seed_issue_file "$dir" "20260726-a.md" 1 20260726-a 2026-07-26T10:00:00Z
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  specs="$(source "$SCRIPT_jimalloc"; alloc_seed_derive_specs "$root" jim-catchup)"
  issues="$(source "$SCRIPT_jimalloc"; alloc_seed_derive_issues "$dir" jim-catchup)"
  assert_eq "spec group record carries the marker" \
    "group allocate core $today jim-catchup" "$(printf '%s\n' "$specs" | head -n1)"
  assert_match "spec record carries the marker" \
    "^spec allocate core/001 alpha $today jim-catchup\$" "$specs"
  assert_eq "issue record carries the marker" \
    "issue allocate 1 20260726-a 20260726 jim-catchup" "$issues"
}

# AC 10: omitting the marker leaves the bootstrap's own output byte-identical —
# the parameter is additive, and `jim-seed` stays what a seed writes.
case_jimalloc_seed_derive_marker_default_unchanged() {
  local root dir today specs issues
  root="$(seed_specs_tree seed_marker_default core/001-alpha)"
  dir="$(empty_dir seed_marker_default_issues)"
  seed_issue_file "$dir" "20260726-a.md" 1 20260726-a 2026-07-26T10:00:00Z
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  specs="$(source "$SCRIPT_jimalloc"; alloc_seed_derive_specs "$root")"
  issues="$(source "$SCRIPT_jimalloc"; alloc_seed_derive_issues "$dir")"
  assert_eq "specs default" \
    "$(printf 'group allocate core %s jim-seed\nspec allocate core/001 alpha %s jim-seed' "$today" "$today")" \
    "$specs"
  assert_eq "issues default" "issue allocate 1 20260726-a 20260726 jim-seed" "$issues"
}

# AC: the record a padded ordinal seeds is one the resolver can find.
case_jimalloc_resolve_issue_finds_a_seeded_padded_ordinal() {
  local dir; dir=$(empty_dir res_issue_padded_seed)
  seed_issue_file "$dir" "20260726-alpha.md" 007 20260726-alpha 2026-07-26T10:00:00Z
  ( source "$SCRIPT_jimalloc"; alloc_seed_derive_issues "$dir" ) > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 7
  assert_exit "rc" 0 "$RC"
}

# run_seed_fn <fn> <args...> — invoke a sourced seed derivation function,
# capturing stdout/stderr/rc into OUT/ERR/RC (the derive functions are pure).
run_seed_fn() {
  local err_file="$TMP_BASE/.err"
  OUT="$(source "$SCRIPT_jimalloc"; "$@" 2>"$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# AC: a spec dir whose ordinal is not pure digits halts derivation — rc 1, no
# records, the offender named (security F3: numeric-class beyond the id boundary).
case_jimalloc_seed_specs_bad_ordinal() {
  local root
  root="$(seed_specs_tree seed_badord core/007x-foo)"
  run_seed_fn alloc_seed_derive_specs "$root"
  assert_exit  "rc"            1      "$RC"
  assert_eq    "no records"    ""     "$OUT"
  assert_match "names offender" '007x' "$ERR"
}

# AC: a spec dir whose slug fails the id boundary (option-injection shape) halts
# derivation — rc 1, no records (spec AC 9).
case_jimalloc_seed_specs_injection_slug() {
  local root
  root="$(seed_specs_tree seed_injslug core/001--bad)"
  run_seed_fn alloc_seed_derive_specs "$root"
  assert_exit  "rc"         1  "$RC"
  assert_eq    "no records" "" "$OUT"
  assert_nonempty "message" "$ERR"
}

# AC: two spec dirs resolving to the same ordinal in a group halt derivation
# (a collision the registry's uniqueness cannot represent — spec AC 6).
case_jimalloc_seed_specs_dup_ordinal() {
  local root
  root="$(seed_specs_tree seed_duporb core/001-a core/001-b)"
  run_seed_fn alloc_seed_derive_specs "$root"
  assert_exit  "rc"         1  "$RC"
  assert_eq    "no records" "" "$OUT"
  assert_match "names dup"  '001' "$ERR"
}

# AC: an issue file with an absent display ordinal halts derivation — rc 1, no
# records, the file named (security F1: issue-frontmatter parse symmetry).
case_jimalloc_seed_issues_missing_num() {
  local dir
  dir="$(empty_dir seed_nonum)"
  printf -- '---\nid: 20260726-x\ncreated: 2026-07-26T10:00:00Z\n---\n' > "$dir/20260726-x.md"
  run_seed_fn alloc_seed_derive_issues "$dir"
  assert_exit  "rc"            1  "$RC"
  assert_eq    "no records"    "" "$OUT"
  assert_match "names offender" '20260726-x' "$ERR"
}

# AC: an issue file with an absent durable id halts derivation — rc 1, no records
# (security F1).
case_jimalloc_seed_issues_missing_id() {
  local dir
  dir="$(empty_dir seed_noid)"
  printf -- '---\nnum: 4\ncreated: 2026-07-26T10:00:00Z\n---\n' > "$dir/orphan.md"
  run_seed_fn alloc_seed_derive_issues "$dir"
  assert_exit  "rc"         1  "$RC"
  assert_eq    "no records" "" "$OUT"
  assert_nonempty "message" "$ERR"
}

# AC: two issue files claiming the same display ordinal halt derivation (spec
# AC 6 — the headline duplicate-ordinal case).
case_jimalloc_seed_issues_dup_num() {
  local dir
  dir="$(empty_dir seed_dupnum)"
  seed_issue_file "$dir" "a.md" 5 20260726-a 2026-07-26T10:00:00Z
  seed_issue_file "$dir" "b.md" 5 20260726-b 2026-07-26T11:00:00Z
  run_seed_fn alloc_seed_derive_issues "$dir"
  assert_exit  "rc"         1  "$RC"
  assert_eq    "no records" "" "$OUT"
  assert_match "names dup"  '5' "$ERR"
}

# AC: two issue files sharing a durable id halt derivation (spec AC 6).
case_jimalloc_seed_issues_dup_id() {
  local dir
  dir="$(empty_dir seed_dupid)"
  seed_issue_file "$dir" "a.md" 5 20260726-same 2026-07-26T10:00:00Z
  seed_issue_file "$dir" "b.md" 6 20260726-same 2026-07-26T11:00:00Z
  run_seed_fn alloc_seed_derive_issues "$dir"
  assert_exit  "rc"         1  "$RC"
  assert_eq    "no records" "" "$OUT"
  assert_match "names dup"  '20260726-same' "$ERR"
}

# seed_repo <name> — a git repo carrying a small specs+issues tree; prints path.
seed_repo() {
  local repo; repo="$(alloc_new_repo "$1")"
  mkdir -p "$repo/docs/specs/core/000-blueprint" \
           "$repo/docs/specs/core/001-alpha" \
           "$repo/docs/specs/core/002-beta" \
           "$repo/docs/specs/ui/001-widget" \
           "$repo/docs/issues"
  seed_issue_file "$repo/docs/issues" "20260726-a.md" 1 20260726-a 2026-07-26T10:00:00Z
  seed_issue_file "$repo/docs/issues" "20260726-b.md" 2 20260726-b 2026-07-26T11:00:00Z
  printf '%s' "$repo"
}

# AC: bare `seed` is a read-only preview — it reports the records it would write
# and mutates nothing (the coordination branch is never created).
case_jimalloc_seed_preview_no_mutation() {
  local repo
  repo="$(seed_repo seed_prev)"
  run_jimalloc_in "$repo" seed
  assert_exit  "rc" 0 "$RC"
  assert_match "reports would-write"   'would write'                 "$OUT"
  assert_match "shows a spec record"   'spec allocate core/001 alpha' "$OUT"
  assert_match "shows an issue record" 'issue allocate 1 20260726-a'  "$OUT"
  assert_eq "registry not created" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
}

# AC: preview over a tree with a conflict reports it (naming the offender) and
# creates nothing, exiting non-zero.
case_jimalloc_seed_preview_conflict() {
  local repo
  repo="$(alloc_new_repo seed_prev_conflict)"
  mkdir -p "$repo/docs/specs/core/007x-foo" "$repo/docs/issues"
  run_jimalloc_in "$repo" seed
  assert_exit     "rc"           1      "$RC"
  assert_match    "names offender" '007x' "$ERR"
  assert_eq "no registry" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
}

# AC: `seed --apply` on a fresh repo reconstructs both logs from the tree and
# lands them durably on the coordination branch (spec AC 1).
case_jimalloc_seed_apply_fresh() {
  local repo specs issues
  repo="$(seed_repo seed_apply)"
  run_jimalloc_in "$repo" seed --apply
  assert_exit  "rc" 0 "$RC"
  assert_match "reports seeded" 'seeded:' "$OUT"
  specs="$(alloc_specs_log "$repo")"; issues="$(alloc_issues_log "$repo")"
  assert_match "core group"  '^group allocate core '           "$specs"
  assert_match "core/001"    '^spec allocate core/001 alpha '  "$specs"
  assert_match "core/002"    '^spec allocate core/002 beta '   "$specs"
  assert_match "ui/001"      '^spec allocate ui/001 widget '   "$specs"
  assert_match "issue 1"     '^issue allocate 1 20260726-a '   "$issues"
  assert_match "issue 2"     '^issue allocate 2 20260726-b '   "$issues"
}

# AC: the whole seed lands as ONE commit setting both logs (spec AC 4).
case_jimalloc_seed_apply_single_commit() {
  local repo count
  repo="$(seed_repo seed_apply_1c)"
  run_jimalloc_in "$repo" seed --apply
  count="$(git -C "$repo" rev-list --count refs/heads/jim/registry)"
  assert_eq       "exactly one commit"  "1" "$count"
  assert_nonempty "specs.log present"   "$(alloc_specs_log "$repo")"
  assert_nonempty "issues.log present"  "$(alloc_issues_log "$repo")"
}

# AC: after seeding, the allocator's next-id equals the pre-seed tree scan for
# each materialized group, and a seeded id resolves to itself (spec AC 2).
case_jimalloc_seed_apply_next_id_parity() {
  local repo
  repo="$(seed_repo seed_parity)"
  run_jimalloc_in "$repo" seed --apply
  run_jimalloc_in "$repo" peek spec core
  assert_eq "core parity"  "core/003" "$OUT"
  run_jimalloc_in "$repo" peek spec ui
  assert_eq "ui parity"    "ui/002"   "$OUT"
  run_jimalloc_in "$repo" resolve spec core/001
  assert_eq "resolve seeded" "core/001" "$OUT"
}

# AC: a within-group gap stays a gap — next-id is max+1, never a reclaimed hole.
case_jimalloc_seed_apply_gap_preserved() {
  local repo
  repo="$(alloc_new_repo seed_gap)"
  mkdir -p "$repo/docs/specs/g/001-a" "$repo/docs/specs/g/003-c" "$repo/docs/issues"
  run_jimalloc_in "$repo" seed --apply
  run_jimalloc_in "$repo" peek spec g
  assert_eq "gap → max+1" "g/004" "$OUT"
}

# AC: seeding never mutates the repo's artifacts — the docs tree and the worktree
# status are byte-for-byte unchanged (spec AC 7); only the registry is written.
case_jimalloc_seed_apply_repo_untouched() {
  local repo tree_before tree_after st_before st_after
  repo="$(seed_repo seed_untouched)"
  tree_before="$(cd "$repo" && find docs | LC_ALL=C sort; for f in $(find docs -type f | LC_ALL=C sort); do cksum "$f"; done)"
  st_before="$(git -C "$repo" status --porcelain | LC_ALL=C sort)"
  run_jimalloc_in "$repo" seed --apply
  assert_exit "rc" 0 "$RC"
  tree_after="$(cd "$repo" && find docs | LC_ALL=C sort; for f in $(find docs -type f | LC_ALL=C sort); do cksum "$f"; done)"
  st_after="$(git -C "$repo" status --porcelain | LC_ALL=C sort)"
  assert_eq "docs tree unchanged"       "$tree_before" "$tree_after"
  assert_eq "worktree status unchanged" "$st_before"   "$st_after"
}

# AC: over a reachable remote the seed lands on the coordination branch of the
# bare remote (spec AC 8 — origin tier).
case_jimalloc_seed_apply_origin() {
  local bare A
  bare="$(alloc_new_bare seed_origin_bare)"
  A="$(alloc_new_clone "$bare" seed_origin_A)"
  mkdir -p "$A/docs/specs/core/001-alpha" "$A/docs/issues"
  seed_issue_file "$A/docs/issues" "x.md" 1 20260726-x 2026-07-26T10:00:00Z
  run_jimalloc_in "$A" seed --apply
  assert_exit  "rc" 0 "$RC"
  assert_match "spec on remote" '^spec allocate core/001 alpha ' "$(alloc_bare_specs "$bare")"
}

# AC: re-running --apply after a successful seed is a no-op failure — the
# registry is byte-identical and the command reports it is already seeded
# (spec AC 5; the empty-precondition is checked against the fetched tip).
case_jimalloc_seed_apply_idempotent() {
  local repo sha1 sha2
  repo="$(seed_repo seed_idem)"
  run_jimalloc_in "$repo" seed --apply
  assert_exit "first rc" 0 "$RC"
  sha1="$(git -C "$repo" rev-parse refs/heads/jim/registry)"
  run_jimalloc_in "$repo" seed --apply
  assert_exit  "re-run rc" 1 "$RC"
  assert_match "says already seeded" 'already seeded' "$ERR"
  sha2="$(git -C "$repo" rev-parse refs/heads/jim/registry)"
  assert_eq "registry unchanged" "$sha1" "$sha2"
}

# AC: a kind whose log already has records is skipped, not overwritten — the seed
# writes only the empty kind and preserves the existing one (spec AC 5; F2 — the
# per-kind emptiness is re-read from the fetched tip, so a log populated by a
# concurrent allocation is refused rather than clobbered).
case_jimalloc_seed_apply_partial_skip() {
  local repo issues specs
  repo="$(seed_repo seed_partial)"
  run_jimalloc_in "$repo" allocate issue "pre existing"   # populate issues.log only
  assert_exit "pre-alloc rc" 0 "$RC"
  run_jimalloc_in "$repo" seed --apply
  assert_exit  "seed rc" 0 "$RC"
  assert_match "reports issue skip" 'issues.log already had records' "$OUT"
  specs="$(alloc_specs_log "$repo")"; issues="$(alloc_issues_log "$repo")"
  assert_match "specs seeded"            '^spec allocate core/001 alpha ' "$specs"
  assert_match "pre-existing issue kept" 'pre-existing'                    "$issues"
  if printf '%s\n' "$issues" | grep -q '20260726-a'; then
    CURRENT_FAILED=1; echo "    [skip] issues.log was overwritten by the seed"
  fi
}

# AC: --apply arms the local erosion baseline from the seeded state, so a
# subsequent rewrite of the coordination history is detected by the next
# allocation rather than silently accepted (security F4).
case_jimalloc_seed_arms_erosion_baseline() {
  local repo blob tree commit
  repo="$(seed_repo seed_erosion)"
  run_jimalloc_in "$repo" seed --apply
  assert_exit "seed rc" 0 "$RC"
  # Rewrite specs.log to a truncated history the seed baseline never saw.
  blob="$(printf 'spec allocate core/001 tampered 20200101 x\n' | git -C "$repo" hash-object -w --stdin)"
  tree="$(printf '100644 blob %s\tspecs.log\n' "$blob" | git -C "$repo" mktree)"
  commit="$(git -C "$repo" commit-tree "$tree" -m rewrite)"
  git -C "$repo" update-ref refs/heads/jim/registry "$commit"
  run_jimalloc_in "$repo" allocate spec core "new one"
  assert_exit     "erosion hard-fail" 1  "$RC"
  assert_eq       "no id issued"      "" "$OUT"
  assert_nonempty "erosion message"   "$ERR"
}

# AC: the shared batch-publish carries the in-loop erosion re-check, so a
# coordination-history rewrite occurring after a seed is detected on the next
# publish path — not just on the single-record allocate path. Seeds issues only
# (arming the issues.log baseline), truncates that history, then drives a second
# publish (a spec now present): the erosion re-check hard-fails rather than
# publishing onto the rewritten log.
case_jimalloc_seed_publish_detects_erosion() {
  local repo blob tree commit
  repo="$(alloc_new_repo seed_pub_erosion)"
  mkdir -p "$repo/docs/issues"
  seed_issue_file "$repo/docs/issues" "20260726-a.md" 1 20260726-a 2026-07-26T10:00:00Z
  run_jimalloc_in "$repo" seed --apply
  assert_exit "first seed rc" 0 "$RC"
  # Truncate the coordination history to a state the baseline never saw.
  blob="$(printf 'issue allocate 1 20260726-tampered 20200101 x\n' | git -C "$repo" hash-object -w --stdin)"
  tree="$(printf '100644 blob %s\tissues.log\n' "$blob" | git -C "$repo" mktree)"
  commit="$(git -C "$repo" commit-tree "$tree" -m rewrite)"
  git -C "$repo" update-ref refs/heads/jim/registry "$commit"
  # A spec now exists, so the next seed has a writable kind and reaches publish.
  mkdir -p "$repo/docs/specs/core/001-alpha"
  run_jimalloc_in "$repo" seed --apply
  assert_exit     "erosion hard-fail" 1  "$RC"
  assert_nonempty "erosion message"   "$ERR"
}

# ─── Section: integrity classification (pure — tree vs registry) ─────────────
#
# The classifiers are the single comparison the sweep report, the catch-up
# preview, and the catch-up builder all read, so detect and repair can never
# disagree about what is missing. Each case pins one class of that comparison.

# run_classify <fn> <derived-records> <log>
#   Source the allocator and run a classifier over <derived-records> (written to
#   a temp file, as the seed derivation would produce them) with <log> on stdin.
run_classify() {
  local fn="$1" derived="$2" log="$3"
  local dir err_file="$TMP_BASE/.err"
  dir="$(empty_dir "classify_$RANDOM")"
  printf '%s\n' "$derived" > "$dir/derived"
  OUT="$(source "$SCRIPT_jimalloc"; "$fn" "$dir/derived" <<< "$log" 2>"$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# classify_rows <class> — the OUT rows of one class, TAB-separated as emitted.
classify_rows() { printf '%s\n' "$OUT" | grep "^$1	" || true; }

# AC 1/4: a tree and registry that agree produce no finding at all — only the
# coverage denominators, so a clean report always says what it checked.
case_jimalloc_classify_spec_clean() {
  run_classify alloc_classify_spec \
    "$(printf '%s\n' 'group allocate core 20260801 jim-seed' \
                     'spec allocate core/001 alpha 20260801 jim-seed')" \
    "$(printf '%s\n' 'group allocate core 20260726 jane' \
                     'spec allocate core/001 alpha 20260726 jane')"
  assert_exit "rc" 0 "$RC"
  assert_eq   "no findings" "" "$(printf '%s\n' "$OUT" | grep -v '^CHECKED	' || true)"
  assert_match "spec denominators" '^CHECKED	spec	1	1$' "$OUT"
}

# AC 2: a tree identity with no registry record is the collision risk — the
# class the catch-up verb appends from.
case_jimalloc_classify_spec_missing() {
  run_classify alloc_classify_spec \
    "$(printf '%s\n' 'group allocate core 20260801 jim-seed' \
                     'spec allocate core/007 cache 20260801 jim-seed')" \
    ""
  assert_exit "rc" 0 "$RC"
  assert_eq "missing row" "$(printf 'MISSING\tspec\tcore/007\tcache')" \
    "$(classify_rows MISSING)"
}

# AC 2: tree and registry that disagree about the identity they share are a
# mismatch — reported with both sides, never repaired.
case_jimalloc_classify_spec_mismatch() {
  run_classify alloc_classify_spec \
    "$(printf '%s\n' 'spec allocate ui/012 nav 20260801 jim-seed')" \
    "$(printf '%s\n' 'spec allocate ui/012 navbar 20260726 jane')"
  assert_match "mismatch names both sides" '^MISMATCH	spec	ui/012	tree nav, registry navbar$' "$OUT"
}

# AC 2: two live records claiming one spec ordinal are a registry-internal
# contradiction, reported with both claiming positions.
case_jimalloc_classify_spec_duplicate_ordinal() {
  run_classify alloc_classify_spec \
    "$(printf '%s\n' 'spec allocate core/007 alpha 20260801 jim-seed')" \
    "$(printf '%s\n' 'spec allocate core/007 alpha 20260726 jane' \
                     'spec allocate core/007 beta 20260727 mallory')"
  assert_match "duplicate named" '^DUP-ORD	spec	core/007	records 1 and 2$' "$OUT"
}

# AC 2: a record for the reserved blueprint slot is drift on its own — nothing
# should ever have minted it, and the derivation no longer can.
case_jimalloc_classify_spec_reserved_slot_record() {
  run_classify alloc_classify_spec "" \
    "$(printf '%s\n' 'spec allocate core/000 blueprint 20260726 jane')"
  assert_match "reserved named" '^RESERVED	spec	core/000	' "$OUT"
  assert_eq "not also reported as record-without-tree" "" "$(classify_rows INFO-NO-TREE)"
}

# AC 2: a record with no tree counterpart is informational, not drift —
# allocation from another clone and an abandoned binding are both legitimate.
case_jimalloc_classify_spec_record_without_tree() {
  run_classify alloc_classify_spec "" \
    "$(printf '%s\n' 'spec allocate core/009 gamma 20260726 jane')"
  assert_eq "informational row" "$(printf 'INFO-NO-TREE\tspec\tcore/009\tgamma')" \
    "$(classify_rows INFO-NO-TREE)"
  assert_eq "not drift" "" "$(classify_rows MISSING)"
}

# AC 1: both sides are canonicalized, so a record spelling its ordinal unpadded
# is the same identity as the padded directory — a hand-authored `core/7` is not
# drift against `core/007-alpha`.
case_jimalloc_classify_spec_padding_is_one_identity() {
  run_classify alloc_classify_spec \
    "$(printf '%s\n' 'spec allocate core/007 alpha 20260801 jim-seed')" \
    "$(printf '%s\n' 'spec allocate core/7 alpha 20260726 jane')"
  assert_eq "no findings" "" "$(printf '%s\n' "$OUT" | grep -v '^CHECKED	' || true)"
}

# AC 3: an id known only as a rename source has no tree dir by design — it is
# named as non-coverage, never as drift, and the destination it moved to is what
# the tree is compared against.
case_jimalloc_classify_spec_rename_source_not_drift() {
  run_classify alloc_classify_spec \
    "$(printf '%s\n' 'spec allocate core/009 alpha 20260801 jim-seed')" \
    "$(printf '%s\n' 'spec allocate core/007 alpha 20260726 jane' \
                     'spec rename core/007 core/009 20260727 x')"
  assert_eq   "vacated id is not drift" "" "$(classify_rows INFO-NO-TREE)"
  assert_eq   "destination matches the tree" "" "$(classify_rows MISSING)"
  assert_match "vacated id named as non-coverage" '^RENAME-SRC	spec	core/007	' "$OUT"
}

# AC 6: a group rename arriving over an OCCUPIED destination is a duplicate, the
# same finding the spec-rename branch already reports — not a silent overwrite
# of the claim that was already there.
case_jimalloc_classify_spec_group_rename_onto_occupied() {
  run_classify alloc_classify_spec "" \
    "$(printf '%s\n' 'spec allocate core/001 alpha 20260726 jane' \
                     'spec allocate ui/001 beta 20260726 kai' \
                     'group rename core ui 20260727 x')"
  assert_match "occupied destination reported" '^DUP-ORD	spec	ui/001	' "$OUT"
}

# AC 6: a group self-rename is inert — it moves every claim onto itself, so the
# claims must survive it rather than being vacated by their own arrival.
case_jimalloc_classify_spec_group_self_rename_is_inert() {
  run_classify alloc_classify_spec \
    "$(printf '%s\n' 'spec allocate core/001 alpha 20260801 jim-seed')" \
    "$(printf '%s\n' 'spec allocate core/001 alpha 20260726 jane' \
                     'group rename core core 20260727 x')"
  assert_eq "claim survives"      "" "$(classify_rows MISSING)"
  assert_eq "no false duplicate"  "" "$(classify_rows DUP-ORD)"
  assert_eq "not vacated"         "" "$(classify_rows RENAME-SRC)"
}

# AC 6: a spec self-rename likewise — it parses fine, it just says nothing, so
# it neither duplicates the claim nor vacates it.
case_jimalloc_classify_spec_self_rename_is_inert() {
  run_classify alloc_classify_spec \
    "$(printf '%s\n' 'spec allocate core/001 alpha 20260801 jim-seed')" \
    "$(printf '%s\n' 'spec allocate core/001 alpha 20260726 jane' \
                     'spec rename core/001 core/001 20260727 x')"
  assert_eq "claim survives"     "" "$(classify_rows MISSING)"
  assert_eq "no false duplicate" "" "$(classify_rows DUP-ORD)"
  assert_eq "not vacated"        "" "$(classify_rows RENAME-SRC)"
}

# AC 6: a duplicate's provenance cites the record that made the claim it
# collides with — after a rename, that is the rename record, not the allocate
# record of the identity that has since moved away.
case_jimalloc_classify_spec_dup_cites_the_rename_record() {
  run_classify alloc_classify_spec "" \
    "$(printf '%s\n' 'spec allocate core/001 alpha 20260726 jane' \
                     'spec rename core/001 ui/005 20260727 x' \
                     'spec allocate ui/005 beta 20260728 kai')"
  assert_match "cites the rename record" '^DUP-ORD	spec	ui/005	records 2 and 3$' "$OUT"
}

# AC 1: a rename record that is not the one shape names no identity to compare,
# so it is counted as unreadable rather than passing over in silence.
case_jimalloc_classify_spec_malformed_rename_is_unreadable() {
  run_classify alloc_classify_spec "" \
    "$(printf '%s\n' 'spec allocate core/001 alpha 20260726 jane' \
                     'spec rename core/001 ui/005 20260727')"
  assert_match "counted unreadable" '^CHECKED	unreadable	spec	1$' "$OUT"
}

case_jimalloc_classify_issue_malformed_rename_is_unreadable() {
  run_classify alloc_classify_issue "" \
    "$(printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jane' \
                     'issue rename 5 8 20260727')"
  assert_match "counted unreadable" '^CHECKED	unreadable	issue	1$' "$OUT"
}

# AC 1: an unknown record verb is reported as its own thing rather than folded
# into the malformed count — the kind namespace stays open, and a log carrying a
# record this build does not know says so.
case_jimalloc_sweep_names_unknown_verbs() {
  local repo
  repo="$(sweep_repo sweep_unknownverb)"
  alloc_append_record "$repo" specs.log 'spec supersede core/002 core/044 20260802 jane'
  run_jimalloc_in "$repo" sweep
  assert_match "unknown verb counted" '^    unknown-verb-records	1$' "$OUT"
  assert_match "malformed count untouched" '^    unidentifiable-records	0$' "$OUT"
}

# AC 2/4: the issue side classifies the same way over ordinals and durable ids —
# a file with no record is missing, and the denominators count both sides.
case_jimalloc_classify_issue_missing() {
  run_classify alloc_classify_issue \
    "$(printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jim-seed')" \
    ""
  assert_eq "missing row" "$(printf 'MISSING\tissue\t5\t20260726-alpha')" \
    "$(classify_rows MISSING)"
  assert_match "issue denominators" '^CHECKED	issue	1	0$' "$OUT"
}

# AC 2: an ordinal whose record carries a different durable id is a mismatch —
# the tree and the registry disagree about which issue that ordinal is.
case_jimalloc_classify_issue_mismatch() {
  run_classify alloc_classify_issue \
    "$(printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jim-seed')" \
    "$(printf '%s\n' 'issue allocate 5 20260726-beta 20260726 jane')"
  assert_match "mismatch names both sides" \
    '^MISMATCH	issue	5	tree 20260726-alpha, registry 20260726-beta$' "$OUT"
}

# AC 2: two records claiming one durable id — the silent last-wins seam — are
# reported with both claiming positions.
case_jimalloc_classify_issue_duplicate_durable_id() {
  run_classify alloc_classify_issue \
    "$(printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jim-seed')" \
    "$(printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jane' \
                     'issue allocate 9 20260726-alpha 20260727 mallory')"
  assert_match "duplicate id named" '^DUP-ID	issue	20260726-alpha	records 1 and 2$' "$OUT"
}

# AC 2: a tree issue whose ordinal is unclaimed while its durable id is claimed
# at a DIFFERENT ordinal is a mismatch, not a missing record. Misclassifying it
# would feed the repair path a second record for a durable id the log already
# holds — the same shape that made the unreadable-record case dangerous.
case_jimalloc_classify_issue_mismatch_by_durable_id() {
  run_classify alloc_classify_issue \
    "$(printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jim-seed')" \
    "$(printf '%s\n' 'issue allocate 9 20260726-alpha 20260726 jane')"
  assert_match "reported as a mismatch on the durable id" \
    '^MISMATCH	issue	20260726-alpha	tree ordinal 5, registry ordinal 9$' "$OUT"
  assert_eq "never reported missing" "" "$(classify_rows MISSING)"
}

# AC 3: the issue side names rename-vacated ordinals as non-coverage, exactly as
# the spec side does.
case_jimalloc_classify_issue_rename_source_not_drift() {
  run_classify alloc_classify_issue \
    "$(printf '%s\n' 'issue allocate 8 20260726-alpha 20260726 jim-seed')" \
    "$(printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jane' \
                     'issue rename 5 8 20260727 x')"
  assert_match "vacated ordinal named" '^RENAME-SRC	issue	5	' "$OUT"
  assert_eq    "not drift"             "" "$(classify_rows MISSING)"
}

# AC 2: an issue record with no tree counterpart is informational on the issue
# side too — another clone allocating first is legitimate for both kinds.
case_jimalloc_classify_issue_record_without_tree() {
  run_classify alloc_classify_issue "" \
    "$(printf '%s\n' 'issue allocate 9 20260726-gamma 20260726 jane')"
  assert_eq "informational row" "$(printf 'INFO-NO-TREE\tissue\t9\t20260726-gamma')" \
    "$(classify_rows INFO-NO-TREE)"
  assert_eq "not drift" "" "$(classify_rows MISSING)"
}

# AC 3: the sweep's rename-source counter reports a real count, not a constant.
case_jimalloc_sweep_counts_rename_sources() {
  local repo
  repo="$(sweep_repo sweep_renamesrc)"
  alloc_append_record "$repo" specs.log 'spec rename core/002 core/044 20260802 jane'
  run_jimalloc_in "$repo" sweep
  assert_match "counted" '^    rename-source-ids	1$' "$OUT"
}

# AC 2: two records claiming one issue ordinal are the same contradiction from
# the other direction.
case_jimalloc_classify_issue_duplicate_ordinal() {
  run_classify alloc_classify_issue "" \
    "$(printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jane' \
                     'issue allocate 5 20260726-beta 20260727 mallory')"
  assert_match "duplicate ordinal named" '^DUP-ORD	issue	5	records 1 and 2$' "$OUT"
}

# AC 2: a record that claims an identity but carries an unusable sibling field
# still CLAIMS it. Reporting the identity as missing is what let the repair verb
# append a second record for it, so the record is reported under its own class
# and the identity is never called missing.
case_jimalloc_classify_unreadable_record_claims_its_identity() {
  run_classify alloc_classify_issue \
    "$(printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jim-seed')" \
    "$(printf '%s\n' 'issue allocate 5 --upload-pack=x 20260726 mallory')"
  assert_eq    "not reported missing" "" "$(classify_rows MISSING)"
  assert_match "reported unreadable"  '^UNREADABLE	issue	5	' "$OUT"
  assert_eq "crafted payload never echoed" "0" \
    "$(printf '%s\n' "$OUT" | grep -c 'upload-pack')"
}

# AC 2: the spec side behaves the same way — an unusable slug does not vacate
# the ordinal's claim.
case_jimalloc_classify_unreadable_spec_record_claims_its_identity() {
  run_classify alloc_classify_spec \
    "$(printf '%s\n' 'spec allocate core/007 cache 20260801 jim-seed')" \
    "$(printf '%s\n' 'spec allocate core/007 c++port 20260726 mallory')"
  assert_eq    "not reported missing" "" "$(classify_rows MISSING)"
  assert_match "reported unreadable"  '^UNREADABLE	spec	core/007	' "$OUT"
}

# AC 3/4: a record too malformed to name an identity at all is still counted —
# otherwise a registry full of unreadable records reports exactly like a clean
# one, which inverts what a clean report is supposed to mean.
case_jimalloc_classify_counts_unidentifiable_records() {
  run_classify alloc_classify_spec "" \
    "$(printf '%s\n' 'spec allocate not-an-id slug 20260726 mallory' \
                     'spec allocate core/00x slug 20260726 mallory')"
  assert_match "unreadable count reported" '^CHECKED	unreadable	spec	2$' "$OUT"
}

# AC 2/7: the repair verb must not append over a claimed identity. This is the
# scenario that turned catch-up into the instrument that broke resolution: the
# record was unreadable, the identity read missing, and the append created a
# second claim the resolver then refused to answer from.
case_jimalloc_catchup_never_appends_over_an_unreadable_claim() {
  local repo issues
  repo="$(sweep_repo catchup_unreadable)"
  alloc_append_record "$repo" issues.log 'issue allocate 9 --upload-pack=x 20260726 mallory'
  seed_issue_file "$repo/docs/issues" "20260801-nine.md" 9 20260801-nine 2026-08-01T10:00:00Z
  run_jimalloc_in "$repo" catch-up --apply
  assert_eq "nothing appended for the claimed ordinal" "0" \
    "$(alloc_issues_log "$repo" | grep -c '^issue allocate 9 20260801-nine ')"
  run_jimalloc_in "$repo" resolve issue 9
  assert_exit "resolve still answers" 0 "$RC"
}

# AC 3: the sweep names unreadable records as drift rather than passing over
# them silently — a record it cannot read is a fact about the registry.
case_jimalloc_sweep_names_unreadable_records() {
  local repo
  repo="$(sweep_repo sweep_unreadable)"
  alloc_append_record "$repo" specs.log 'spec allocate core/009 c++port 20260726 mallory'
  run_jimalloc_in "$repo" sweep
  assert_exit  "drift rc" 3 "$RC"
  assert_match "named"    '^    unreadable-record	spec	core/009	' "$OUT"
}

# AC 11: the issue resolver reads an ordinal as a NUMBER, matching the
# classifier and the fold. A registry spelling it padded and a file spelling it
# bare are one identity, so the sweep cannot call clean what resolve calls
# unallocated.
case_jimalloc_resolve_issue_padding_is_one_identity() {
  local dir; dir=$(empty_dir res_issue_padding)
  printf '%s\n' 'issue allocate 007 20260726-alpha 20260726 jane' > "$dir/issues.log"
  run_jimalloc_reg "$dir" resolve issue 7
  assert_exit "padded record, bare query" 0   "$RC"
  assert_eq   "answers canonically"       "7" "$OUT"
}

# AC 1/2/15: a record whose fields fail the id boundary is reported, never
# executed and never echoed — and it still CLAIMS its ordinal, so a well-formed
# record claiming the same one is a genuine duplicate.
#
# This case previously asserted "no findings" here, which encoded the defect it
# now guards: treating the unreadable record as absent made the ordinal read
# missing, which is what let the repair verb append a second claim and turn a
# degraded record into a citation the resolver refuses to answer.
case_jimalloc_classify_skips_malformed_records() {
  run_classify alloc_classify_issue \
    "$(printf '%s\n' 'issue allocate 5 20260726-alpha 20260726 jim-seed')" \
    "$(printf '%s\n' 'issue allocate 5 --upload-pack=x 20260726 mallory' \
                     'issue allocate 5 20260726-alpha 20260726 jane')"
  assert_match "unreadable record reported" '^UNREADABLE	issue	5	' "$OUT"
  assert_match "the second claim is a duplicate" '^DUP-ORD	issue	5	' "$OUT"
  assert_eq    "never reported missing" "" "$(classify_rows MISSING)"
  assert_eq "malformed token never echoed" "0" \
    "$(printf '%s\n' "$OUT" | grep -c 'upload-pack')"
}

# ─── Section: sweep (read-only integrity report) ─────────────────────────────

# sweep_repo <name> — a repo whose tree and registry agree: two spec groups
# (each with a reserved blueprint slot), two issues, all seeded.
sweep_repo() {
  local repo; repo="$(seed_repo "$1")"
  run_jimalloc_in "$repo" seed --apply
  printf '%s' "$repo"
}

# AC 1/4/5: over a tree and registry that agree, the sweep reports its coverage
# denominators, finds nothing, mutates nothing, and exits clean.
case_jimalloc_sweep_clean() {
  local repo before status_before
  repo="$(sweep_repo sweep_clean)"
  before="$(git -C "$repo" rev-parse refs/heads/jim/registry)"
  status_before="$(git -C "$repo" status --porcelain)"
  run_jimalloc_in "$repo" sweep
  assert_exit  "clean rc"      0 "$RC"
  assert_match "spec denominators"  "^  specs:  3 records vs 3 tree dirs; 2 group records vs 2 tree groups$" "$OUT"
  assert_match "issue denominators" '^  issues: 2 records vs 2 files checked$'               "$OUT"
  assert_eq    "no drift section"   "0" "$(printf '%s\n' "$OUT" | grep -c '^  drift:')"
  assert_match "zero hazards still named" '^    duplicate-realize-keys	0$' "$OUT"
  assert_eq    "registry untouched" "$before" "$(git -C "$repo" rev-parse refs/heads/jim/registry)"
  assert_eq    "worktree unchanged" "$status_before" "$(git -C "$repo" status --porcelain)"
}

# AC 1/2/5: a spec directory the registry has never heard of is the collision
# risk — reported under its own class, with a drift exit distinct from clean.
case_jimalloc_sweep_missing_record() {
  local repo
  repo="$(sweep_repo sweep_missing)"
  mkdir -p "$repo/docs/specs/core/007-cache"
  run_jimalloc_in "$repo" sweep
  assert_exit  "drift rc"     3 "$RC"
  assert_match "names the class and identity" '^    missing-record	spec	core/007	' "$OUT"
}

# AC 2: tree and registry disagreeing about the identity they share is a
# mismatch — reported with both sides, never repaired.
case_jimalloc_sweep_mismatch() {
  local repo
  repo="$(sweep_repo sweep_mismatch)"
  mv "$repo/docs/specs/core/002-beta" "$repo/docs/specs/core/002-betamax"
  run_jimalloc_in "$repo" sweep
  assert_exit  "drift rc" 3 "$RC"
  assert_match "names both sides" '^    mismatch	spec	core/002	tree betamax, registry beta$' "$OUT"
}

# AC 2: a registry record with no tree counterpart is informational, not drift —
# a clean exit, because another clone allocating first is a legitimate state.
case_jimalloc_sweep_record_without_tree_is_info() {
  local repo
  repo="$(sweep_repo sweep_info)"
  run_jimalloc_in "$repo" allocate spec core "Elsewhere"
  assert_exit "allocate rc" 0 "$RC"
  run_jimalloc_in "$repo" sweep
  assert_exit  "informational, not drift" 0 "$RC"
  assert_match "reported under info" '^    record-without-tree	spec	core/003	' "$OUT"
}

# AC 2: registry-internal contradictions are drift in their own right — a
# duplicate ordinal is reported with both claiming record positions.
case_jimalloc_sweep_duplicate_record() {
  local repo
  repo="$(sweep_repo sweep_dup)"
  alloc_append_record "$repo" specs.log 'spec allocate core/001 alpha 20260726 mallory'
  run_jimalloc_in "$repo" sweep
  assert_exit  "drift rc" 3 "$RC"
  assert_match "names both claimants" '^    duplicate-ordinal	spec	core/001	records ' "$OUT"
}

# AC: two records legitimately claiming one (group, slug, date) triple are not
# drift — both are individually valid — but the realize path refuses any pending
# identity keyed onto that triple, so the sweep names the ambiguous key as a
# hazard while still exiting clean.
case_jimalloc_sweep_names_duplicate_realize_key() {
  local repo
  repo="$(sweep_repo sweep_dupkey)"
  alloc_append_record "$repo" specs.log 'spec allocate core/007 gadget 20260726 jane'
  alloc_append_record "$repo" specs.log 'spec allocate core/008 gadget 20260726 jane'
  run_jimalloc_in "$repo" sweep
  assert_exit  "a hazard is not drift" 0 "$RC"
  assert_match "names the ambiguous key" '^    duplicate-realize-keys	1	core/gadget/20260726$' "$OUT"
}

# AC 3: the reserved slots and pending provisionals the comparison skips are
# named with counts, so a clean report is never confused with an unlooked-at one.
case_jimalloc_sweep_names_non_coverage() {
  local repo
  repo="$(sweep_repo sweep_notcovered)"
  mkdir -p "$repo/docs/specs/core/P-20260801-pending"
  run_jimalloc_in "$repo" sweep
  assert_exit  "still clean"           0 "$RC"
  assert_match "reserved slots counted" '^    reserved-slots	1$'       "$OUT"
  assert_match "provisionals counted"   '^    pending-provisionals	1$' "$OUT"
  assert_match "rename sources counted" '^    rename-source-ids	0$'    "$OUT"
}

# AC 3 (security finding 6): a retired or partition-source group has no
# derivable rows AND no registry records, so a tree-vs-registry comparison never
# sees it at all. It is named as uncovered rather than passing silently — jim's
# own retired `jim` group is exactly this shape.
case_jimalloc_sweep_names_uncovered_group() {
  local repo
  repo="$(sweep_repo sweep_retired)"
  mkdir -p "$repo/docs/specs/jim/000-blueprint"
  run_jimalloc_in "$repo" sweep
  assert_exit  "still clean"        0 "$RC"
  assert_match "names the group" '^    uncovered-groups	1	jim$' "$OUT"
}

# AC 3/6: with an unreachable coordination point the sweep still runs against
# the last-fetched state and says so in its header — it does not refuse, and the
# staleness is visible at a glance rather than inferred.
case_jimalloc_sweep_offline_names_staleness() {
  local repo
  repo="$(sweep_repo sweep_offline)"
  git -C "$repo" remote add origin "$TMP_BASE/no-such-sweep.git"
  run_jimalloc_in "$repo" sweep
  assert_exit  "runs anyway"      0            "$RC"
  assert_match "names last-seen"  'last-seen'  "$OUT"
  assert_match "names the tip"    '^sweep: registry @ [0-9a-f]{7,} ' "$OUT"
}

# AC 5: could-not-check is distinguishable from both clean and drift — a repo
# with no coordination branch at all cannot be swept, and says so with its own
# exit code rather than reporting a clean or dirty registry it never read.
case_jimalloc_sweep_no_registry_cannot_check() {
  local repo
  repo="$(alloc_new_repo sweep_noreg)"
  mkdir -p "$repo/docs/specs/core/001-alpha" "$repo/docs/issues"
  run_jimalloc_in "$repo" sweep
  assert_exit     "could-not-check rc" 4 "$RC"
  assert_nonempty "names the reason"   "$ERR"
}

# AC 15: the emission-side sanitizer collapses the characters that would forge a
# row or shift a column, and caps length.
#
# Exercised directly, and deliberately so: every value the report prints today
# has already crossed the id boundary (the case below proves a crafted record is
# dropped before a row is composed), so no CLI input can currently reach this
# function with a tab or newline in it. That makes it defense in depth for the
# next field added to the report rather than a guard with a reachable path —
# stated here because a fixture that could not fail would otherwise read as
# coverage it is not.
case_jimalloc_sweep_sanitizes_an_emitted_field() {
  local out
  out="$(source "$SCRIPT_jimalloc"; alloc_sanitize_field "$(printf 'a\tb\nc\rd')")"
  assert_eq "row-forging characters collapsed" "a b c d" "$out"
  out="$(source "$SCRIPT_jimalloc"; alloc_sanitize_field "$(printf 'x%.0s' {1..400})")"
  assert_eq "length capped" "256" "${#out}"
}

# AC 5: a tree the sweep cannot read is could-not-check, never clean. An absent
# or misconfigured specs root would otherwise derive zero identities, reclassify
# every record as informational, and exit 0 — a check that did not look reading
# as a pass, which is the exact failure this verb exists to prevent.
case_jimalloc_sweep_absent_tree_root_cannot_check() {
  local repo
  repo="$(sweep_repo sweep_noroot)"
  rm -rf "$repo/docs/specs"
  run_jimalloc_in "$repo" sweep
  assert_exit     "could-not-check rc" 4 "$RC"
  assert_nonempty "names the reason"   "$ERR"
}

# AC 15: the derivation's conflict lines are part of the report an operator
# reads, and they echo tree tokens that by construction failed the id boundary —
# so they are sanitized before emission like every other emitted field.
case_jimalloc_derivation_conflict_is_sanitized() {
  local root out
  root="$(empty_dir seed_conflict_tab)"
  mkdir -p "$root/core/$(printf '007x\tinjected')-foo"
  run_seed_fn alloc_seed_derive_specs "$root"
  assert_exit "halts" 1 "$RC"
  assert_eq "no raw tab reaches the report" "0" \
    "$(printf '%s' "$ERR" | grep -c "$(printf '\t')")"
}

# AC 15: a crafted record cannot forge or shift a report row — its fields are
# revalidated at the id boundary before the row is composed, so the record is
# skipped and its payload never reaches stdout.
case_jimalloc_sweep_crafted_record_cannot_forge_a_row() {
  local repo
  repo="$(sweep_repo sweep_crafted)"
  alloc_append_record "$repo" specs.log \
    'spec allocate core/004 ../../etc/passwd 20260726 mallory'
  run_jimalloc_in "$repo" sweep
  assert_eq "crafted payload never echoed" "0" \
    "$(printf '%s\n' "$OUT" | grep -c 'passwd')"
}

# AC 5 (DD 5): a drift flood is bounded but never silently truncated — the
# listing caps and the full count is always reported.
case_jimalloc_sweep_caps_the_listing() {
  local repo i n
  repo="$(sweep_repo sweep_cap)"
  for ((i = 10; i < 130; i++)); do mkdir -p "$repo/docs/specs/core/$i-flood"; done
  run_jimalloc_in "$repo" sweep
  assert_exit "drift rc" 3 "$RC"
  n="$(printf '%s\n' "$OUT" | grep -c '^    missing-record	spec	')"
  assert_eq    "listing capped"        "100" "$n"
  assert_match "remainder named" 'and 20 more' "$OUT"
}

# AC 3: a pending provisional issue file is reserved like a provisional spec dir
# — the derivation passes over it instead of halting, so the sweep still runs in
# exactly the offline state that produces one.
case_jimalloc_sweep_pending_provisional_issue() {
  local repo
  repo="$(sweep_repo sweep_prov_issue)"
  seed_issue_file "$repo/docs/issues" "20260801-pending.md" \
    "P-20260801-pending" 20260801-pending 2026-08-01T10:00:00Z
  run_jimalloc_in "$repo" sweep
  assert_exit  "runs, does not halt"     0 "$RC"
  assert_match "counted as provisional" '^    pending-provisionals	1$' "$OUT"
}

# AC 1: the sweep validates its own arguments — an unknown option is a usage
# error, distinct from every content outcome.
case_jimalloc_sweep_usage() {
  run_jimalloc sweep --bogus
  assert_exit     "usage rc"    2  "$RC"
  assert_eq       "stdout empty" "" "$OUT"
  assert_nonempty "explains"    "$ERR"
}

# ─── Section: catch-up (incremental repair of a non-empty registry) ──────────

# AC 7: bare `catch-up` is a preview — it renders each record it would append
# VERBATIM rather than a count, and writes nothing.
case_jimalloc_catchup_preview_renders_records_verbatim() {
  local repo before today
  repo="$(sweep_repo catchup_prev)"
  before="$(git -C "$repo" rev-parse refs/heads/jim/registry)"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  mkdir -p "$repo/docs/specs/core/007-cache"
  seed_issue_file "$repo/docs/issues" "20260801-late.md" 9 20260801-late 2026-08-01T10:00:00Z
  run_jimalloc_in "$repo" catch-up
  assert_exit  "preview rc" 0 "$RC"
  assert_match "spec record verbatim" \
    "^    spec allocate core/007 cache $today jim-catchup\$" "$OUT"
  assert_match "issue record verbatim, with the issue's own date" \
    '^    issue allocate 9 20260801-late 20260801 jim-catchup$' "$OUT"
  assert_eq "registry untouched" "$before" \
    "$(git -C "$repo" rev-parse refs/heads/jim/registry)"
}

# AC 10: the appended records carry a marker distinguishing a catch-up append
# from both the bootstrap and a live allocation — the only forensic difference
# between them, since the record content is otherwise identical.
case_jimalloc_catchup_preview_marks_provenance() {
  local repo
  repo="$(sweep_repo catchup_marker)"
  mkdir -p "$repo/docs/specs/core/007-cache"
  run_jimalloc_in "$repo" catch-up
  assert_eq "no bootstrap marker on an appended record" "0" \
    "$(printf '%s\n' "$OUT" | grep -c '^    spec allocate .* jim-seed$')"
}

# AC 7: a group the registry has never seen gets its group record alongside the
# spec record that first claims it — the same rule an allocation follows.
case_jimalloc_catchup_preview_claims_a_new_group() {
  local repo
  repo="$(sweep_repo catchup_group)"
  mkdir -p "$repo/docs/specs/newgroup/001-thing"
  run_jimalloc_in "$repo" catch-up
  assert_match "group record"  '^    group allocate newgroup .* jim-catchup$'      "$OUT"
  assert_match "spec record"   '^    spec allocate newgroup/001 thing .* jim-catchup$' "$OUT"
}

# AC 7/9: mismatch-class drift is not appendable — it is listed as unrepairable
# and excluded from the append set, because choosing a winner is an operator
# decision this verb never makes.
case_jimalloc_catchup_preview_lists_unrepairable() {
  local repo
  repo="$(sweep_repo catchup_mismatch)"
  mv "$repo/docs/specs/core/002-beta" "$repo/docs/specs/core/002-betamax"
  run_jimalloc_in "$repo" catch-up
  assert_match "named as unrepairable" '^    mismatch	spec	core/002	' "$OUT"
  assert_eq "not in the append set" "0" \
    "$(printf '%s\n' "$OUT" | grep -c '^    spec allocate core/002 ')"
}

# AC 8: with nothing missing, the preview says so and proposes no record — the
# same no-op a re-run after a clean apply reports.
case_jimalloc_catchup_preview_clean_is_a_noop() {
  local repo
  repo="$(sweep_repo catchup_clean)"
  run_jimalloc_in "$repo" catch-up
  assert_exit  "rc" 0 "$RC"
  assert_match "says nothing to append" 'nothing to append' "$OUT"
}

# AC 16: the reserved blueprint slot is never derived into a record, so a
# catch-up can no more mint `<group>/000` than the bootstrap can.
case_jimalloc_catchup_preview_never_proposes_the_reserved_slot() {
  local repo
  repo="$(sweep_repo catchup_reserved)"
  mkdir -p "$repo/docs/specs/newgroup/0-blueprint" "$repo/docs/specs/newgroup/001-thing"
  run_jimalloc_in "$repo" catch-up
  assert_eq "no reserved-slot record proposed" "0" \
    "$(printf '%s\n' "$OUT" | grep -c 'newgroup/000')"
}

# AC 7: `--apply` lands the missing records as one commit under the same CAS and
# erosion discipline as an allocation, and reports the records it ACTUALLY
# appended — recomputed at the tip, not an echo of the preview.
case_jimalloc_catchup_apply_lands_the_missing_records() {
  local repo specs issues
  repo="$(sweep_repo catchup_apply)"
  mkdir -p "$repo/docs/specs/core/007-cache"
  seed_issue_file "$repo/docs/issues" "20260801-late.md" 9 20260801-late 2026-08-01T10:00:00Z
  run_jimalloc_in "$repo" catch-up --apply
  assert_exit  "rc" 0 "$RC"
  assert_match "reports the landed spec record" \
    '^    spec allocate core/007 cache .* jim-catchup$' "$OUT"
  specs="$(alloc_specs_log "$repo")"; issues="$(alloc_issues_log "$repo")"
  assert_match "spec record landed"  '^spec allocate core/007 cache .* jim-catchup$' "$specs"
  assert_match "issue record landed" '^issue allocate 9 20260801-late 20260801 jim-catchup$' "$issues"
  run_jimalloc_in "$repo" sweep
  assert_exit "registry now matches the tree" 0 "$RC"
}

# AC 8: catch-up is idempotent and append-only — a second apply writes nothing,
# and no existing record is rewritten, reordered, or removed.
case_jimalloc_catchup_apply_idempotent_and_append_only() {
  local repo before after sha1 sha2
  repo="$(sweep_repo catchup_idem)"
  mkdir -p "$repo/docs/specs/core/007-cache"
  before="$(alloc_specs_log "$repo")"
  run_jimalloc_in "$repo" catch-up --apply
  assert_exit "first apply rc" 0 "$RC"
  sha1="$(git -C "$repo" rev-parse refs/heads/jim/registry)"
  after="$(alloc_specs_log "$repo")"
  if [[ "$after" != "$before"* ]]; then
    CURRENT_FAILED=1; echo "    [append-only] prior content is not a prefix of the new log"
  fi
  run_jimalloc_in "$repo" catch-up --apply
  assert_exit  "re-run rc" 0 "$RC"
  assert_match "reports the no-op" 'nothing to append' "$OUT"
  sha2="$(git -C "$repo" rev-parse refs/heads/jim/registry)"
  assert_eq "registry unchanged by the re-run" "$sha1" "$sha2"
}

# AC 9: on a mix of appendable gaps and unrepairable drift, apply lands the
# clean records, names every finding it could not repair, and exits non-zero —
# a partial repair never reads as a clean run.
case_jimalloc_catchup_apply_partial_repair_exits_nonzero() {
  local repo specs
  repo="$(sweep_repo catchup_partial)"
  mkdir -p "$repo/docs/specs/core/007-cache"
  mv "$repo/docs/specs/core/002-beta" "$repo/docs/specs/core/002-betamax"
  run_jimalloc_in "$repo" catch-up --apply
  assert_exit  "partial repair rc"   3 "$RC"
  assert_match "names what it could not repair" '^    mismatch	spec	core/002	' "$OUT"
  specs="$(alloc_specs_log "$repo")"
  assert_match "the clean record still landed" '^spec allocate core/007 cache ' "$specs"
  assert_eq "nothing rewritten for the mismatch" "1" \
    "$(printf '%s\n' "$specs" | grep -c '^spec allocate core/002 ')"
}

# AC 7: the append set is recomputed against the tip inside the CAS loop, so a
# record that landed between preview and apply is not appended a second time —
# the preview→apply window cannot produce a duplicate.
case_jimalloc_catchup_apply_recomputes_at_the_tip() {
  local repo specs
  repo="$(sweep_repo catchup_race)"
  mkdir -p "$repo/docs/specs/core/007-cache"
  run_jimalloc_in "$repo" catch-up
  assert_match "preview proposes it" '^    spec allocate core/007 cache ' "$OUT"
  alloc_append_record "$repo" specs.log 'spec allocate core/007 cache 20260801 someone-else'
  run_jimalloc_in "$repo" catch-up --apply
  assert_exit "rc" 0 "$RC"
  specs="$(alloc_specs_log "$repo")"
  assert_eq "claimed exactly once" "1" \
    "$(printf '%s\n' "$specs" | grep -c '^spec allocate core/007 ')"
}

# AC 7: the append rides the shared publish path, so a coordination history that
# was truncated or rewritten is refused rather than appended onto.
case_jimalloc_catchup_apply_refuses_an_eroded_registry() {
  local repo blob tree commit
  repo="$(sweep_repo catchup_erosion)"
  mkdir -p "$repo/docs/specs/core/007-cache"
  blob="$(printf 'spec allocate core/001 tampered 20200101 x\n' | git -C "$repo" hash-object -w --stdin)"
  tree="$(printf '100644 blob %s\tspecs.log\n' "$blob" | git -C "$repo" mktree)"
  commit="$(git -C "$repo" commit-tree "$tree" -m rewrite)"
  git -C "$repo" update-ref refs/heads/jim/registry "$commit"
  run_jimalloc_in "$repo" catch-up --apply
  assert_exit     "refused"          1  "$RC"
  assert_nonempty "erosion message"  "$ERR"
}

# AC 9: every drift class catch-up cannot repair is named and drives the exit
# code — not the mismatch class alone. An operator running catch-up to clear a
# sweep failure must not read exit 0 as "done" while a contradiction stands.
case_jimalloc_catchup_names_every_unrepairable_class() {
  local repo
  repo="$(sweep_repo catchup_unrepairable)"
  alloc_append_record "$repo" specs.log 'spec allocate core/001 alpha 20260726 mallory'
  run_jimalloc_in "$repo" catch-up --apply
  assert_exit  "non-zero on unrepairable drift" 3 "$RC"
  assert_match "names the duplicate" 'duplicate-ordinal	spec	core/001' "$OUT"
}

# AC 7: catch-up repairs a NON-EMPTY registry. With no coordination branch there
# is nothing to catch up to, and seeding is the bootstrap's job — under its own
# preview and its own provenance marker, not this verb's.
case_jimalloc_catchup_refuses_an_unseeded_registry() {
  local repo
  repo="$(alloc_new_repo catchup_unseeded)"
  mkdir -p "$repo/docs/specs/core/001-alpha" "$repo/docs/issues"
  run_jimalloc_in "$repo" catch-up --apply
  assert_exit     "refuses"            1  "$RC"
  assert_match    "points at the bootstrap" 'seed' "$ERR"
  assert_eq "no registry created" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
}

# AC 1: catch-up validates its own arguments — an unknown option is a usage
# error, distinct from every content outcome.
case_jimalloc_catchup_usage() {
  run_jimalloc catch-up --bogus
  assert_exit     "usage rc"     2  "$RC"
  assert_eq       "stdout empty" "" "$OUT"
  assert_nonempty "explains"     "$ERR"
}

# ─── Section: reconcile — realize logic (pure, no git) ───────────────────────

# run_realize <log> <pending...> — source the allocator and run the pure
# reconcile-realize over <log> on stdin; capture OUT/ERR/RC.
run_realize() {
  local log="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(source "$SCRIPT_jimalloc"; alloc_reconcile_realize "$@" <<< "$log" 2>"$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# AC: reconcile realize maps each pending provisional to a real ordinal —
# already-realized ids (present in the log) keep their ordinal with no new
# allocation; new ids draw from the shared high-water in pending order (spec
# AC 4/6/8).
case_jimalloc_reconcile_realize_mapping() {
  local log expected
  log=$(printf '%s\n' 'issue allocate 5 20260726-old 20260726 jane')
  run_realize "$log" 20260726-old 20260726-new-a 20260726-new-b
  assert_exit "rc" 0 "$RC"
  expected=$(printf '%s\n' \
    '20260726-old	5	have' \
    '20260726-new-a	6	new' \
    '20260726-new-b	7	new')
  assert_eq "mapping" "$expected" "$OUT"
}

# AC: reconcile is idempotent — a provisional already realized in the log yields
# the same ordinal and allocates no second one (spec AC 6).
case_jimalloc_reconcile_realize_idempotent() {
  local log
  log=$(printf '%s\n' 'issue allocate 5 20260726-x 20260726 jane')
  run_realize "$log" 20260726-x
  assert_exit "rc" 0 "$RC"
  assert_eq   "already realized → same ordinal, no new" "$(printf '20260726-x\t5\thave')" "$OUT"
}

# AC: the realized ordinal derives solely from the shared high-water, never from
# any field of the attacker-influenceable provisional marker — a marker whose
# text embeds a high number still realizes to high-water+1 (spec AC 8).
case_jimalloc_reconcile_realize_marker_independent() {
  run_realize "" 20260726-issue-999
  assert_exit "rc" 0 "$RC"
  assert_eq   "ordinal from high-water, not marker" "$(printf '20260726-issue-999\t1\tnew')" "$OUT"
}

# AC: the high-water counts rename destinations too, so a realized ordinal never
# reclaims one vacated by a rename (never-reuse / permanent gap; spec AC 8/10).
case_jimalloc_reconcile_realize_high_water_rename() {
  local log
  log=$(printf '%s\n' 'issue allocate 5 20260726-a 20260726 jane' \
                      'issue rename 5 11 20260727 x')
  run_realize "$log" 20260726-new
  assert_exit "rc" 0 "$RC"
  assert_eq   "next above rename dst" "$(printf '20260726-new\t12\tnew')" "$OUT"
}

# AC 11: when two records claim the durable id a pending marker would resolve
# against, realize refuses that identity instead of taking the later record —
# the same contradiction the resolver refuses — and refuses it alone: the
# refusal travels as a `blocked` row with no ordinal, the claimants are named
# on stderr, and the rest of the batch still realizes. A batch-wide halt would
# let one contradicted identity strand neighbours whose ordinals are safe.
case_jimalloc_reconcile_realize_duplicate_claim_blocks_identity() {
  local log expected
  log=$(printf '%s\n' 'issue allocate 5 20260726-x 20260726 jane' \
                      'issue allocate 9 20260726-x 20260727 mallory')
  run_realize "$log" 20260726-x 20260801-unrelated
  assert_exit "per-identity refusal, not a batch halt" 0 "$RC"
  expected=$(printf '%s\n' \
    '20260726-x	-	blocked' \
    '20260801-unrelated	10	new')
  assert_eq    "blocked row, neighbour realized" "$expected" "$OUT"
  assert_match "names the identity"   '20260726-x' "$ERR"
  assert_match "names both claimants" '1 and 2'    "$ERR"
}

# AC 11: a blocked identity consumes no ordinal — once the contradiction is
# repaired, a re-run realizes it onto the next free ordinal with no gap burned
# by the earlier refusal.
case_jimalloc_reconcile_realize_blocked_consumes_no_ordinal() {
  local log
  log=$(printf '%s\n' 'issue allocate 5 20260726-x 20260726 jane' \
                      'issue allocate 9 20260726-x 20260727 mallory')
  run_realize "$log" 20260726-x 20260801-a 20260801-b
  assert_exit "rc" 0 "$RC"
  assert_eq "neighbours draw contiguous ordinals" \
    "$(printf '20260726-x\t-\tblocked\n20260801-a\t10\tnew\n20260801-b\t11\tnew')" "$OUT"
}

# AC 11: the halt is aimed at the identity the batch actually resolves — a
# contradiction elsewhere in the log does not brick an unrelated realization.
# Reporting every registry-internal contradiction is the sweep's job; this path's
# job is to never answer one wrongly.
case_jimalloc_reconcile_realize_unrelated_duplicate_does_not_halt() {
  local log
  log=$(printf '%s\n' 'issue allocate 5 20260726-x 20260726 jane' \
                      'issue allocate 9 20260726-x 20260727 mallory')
  run_realize "$log" 20260801-unrelated
  assert_exit "unrelated pending still realizes" 0 "$RC"
  assert_eq   "next above the high-water" \
    "$(printf '20260801-unrelated\t10\tnew')" "$OUT"
}

# AC: the ordinal a normal allocation would issue and the one reconcile realizes
# onto are the same value for every log shape, malformed records included. A
# record whose ordinal is numeric but whose durable id fails the id boundary
# still consumed that ordinal, so both paths must count it — otherwise reconcile
# realizes onto ground the allocation path already treats as taken.
case_jimalloc_reconcile_high_water_parity() {
  local log alloc_next realized
  log=$(printf '%s\n' 'issue allocate 9 --upload-pack=x 20260726 x' \
                      'issue allocate 2 20260726-good 20260726 x')
  alloc_next="$(source "$SCRIPT_jimalloc"; alloc_next_num_issue <<< "$log")"
  run_realize "$log" 20260726-pending
  assert_exit "rc" 0 "$RC"
  realized="$(printf '%s' "$OUT" | cut -f2)"
  assert_eq "reconcile agrees with allocation" "$alloc_next" "$realized"
  assert_eq "and clears the consumed ordinal"  "10"          "$realized"
}

# AC: a duplicate provisional identity within one pending batch halts reconcile
# (defense-in-depth: the mechanism cannot verify global uniqueness, but it
# refuses to collapse two identical pending markers onto one ordinal — security
# Finding 4).
case_jimalloc_reconcile_realize_within_batch_dup() {
  run_realize "" 20260726-dup 20260726-dup
  assert_exit     "rc"      1  "$RC"
  assert_nonempty "message" "$ERR"
}

# AC: a crafted pending identity is rejected at the id/slug/name boundary before
# it is used as a token (spec AC 12).
case_jimalloc_reconcile_realize_crafted_pending() {
  run_realize "" "--upload-pack=x"
  assert_exit     "rc"      1  "$RC"
  assert_nonempty "message" "$ERR"
}

# ─── Section: reconcile — spec realize logic (pure, no git) ──────────────────

# run_realize_spec <log> <pending...> — source the allocator and run the pure
# spec reconcile-realize over <log> on stdin; capture OUT/ERR/RC.
run_realize_spec() {
  local log="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(source "$SCRIPT_jimalloc"; alloc_reconcile_realize_spec "$@" <<< "$log" 2>"$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# AC: spec realize maps each pending provisional identity to a real ordinal
# drawn from the shared high-water, incrementing in pending order.
case_jimalloc_realize_spec_mapping() {
  local log expected
  log=$(printf '%s\n' 'spec allocate core/005 alpha 20260726 jane')
  run_realize_spec "$log" core/P-20260728-beta core/P-20260728-gamma
  assert_exit "rc" 0 "$RC"
  expected=$(printf '%s\n' \
    'core/P-20260728-beta	core/006	new' \
    'core/P-20260728-gamma	core/007	new')
  assert_eq "mapping" "$expected" "$OUT"
}

# AC: realization is idempotent — a pending identity whose realized record is
# already in the log keeps that ordinal and allocates no second one, so a re-run
# after a crash between publish and rename converges instead of double-issuing.
case_jimalloc_realize_spec_keyed_have() {
  local log
  log=$(printf '%s\n' 'spec allocate core/003 beta 20260728 jane')
  run_realize_spec "$log" core/P-20260728-beta
  assert_exit "rc" 0 "$RC"
  assert_eq "already realized → its ordinal, no new allocation" \
    "$(printf 'core/P-20260728-beta\tcore/003\thave')" "$OUT"
}

# AC 11: the spec-side map keys on (group, slug, date), and two records claiming
# that triple make the realization ambiguous — which ordinal is this identity's?
# Realize refuses that identity as a `blocked` row naming both claimants rather
# than reporting `have` from the later record — and refuses it alone, because
# two specs sharing a title-slug on one day is a state the allocator itself can
# mint, and the consumer documents that other identities in the batch land.
case_jimalloc_realize_spec_duplicate_claim_blocks_identity() {
  local log expected
  log=$(printf '%s\n' 'spec allocate core/003 beta 20260728 jane' \
                      'spec allocate core/009 beta 20260728 mallory')
  run_realize_spec "$log" core/P-20260728-beta core/P-20260728-gamma
  assert_exit "per-identity refusal, not a batch halt" 0 "$RC"
  expected=$(printf '%s\n' \
    'core/P-20260728-beta	-	blocked' \
    'core/P-20260728-gamma	core/010	new')
  assert_eq    "blocked row, neighbour realized" "$expected" "$OUT"
  assert_match "names the identity"   'beta'    "$ERR"
  assert_match "names both claimants" '1 and 2' "$ERR"
}

# AC 11: two specs sharing a title-slug in one group on one day is a state the
# allocator itself can mint, so the halt must fire on the triple the batch
# resolves and nowhere else — an unrelated identity still realizes.
case_jimalloc_realize_spec_unrelated_duplicate_does_not_halt() {
  local log
  log=$(printf '%s\n' 'spec allocate core/003 beta 20260728 jane' \
                      'spec allocate core/009 beta 20260728 mallory')
  run_realize_spec "$log" core/P-20260728-gamma
  assert_exit "unrelated pending still realizes" 0 "$RC"
  assert_eq   "next above the high-water" \
    "$(printf 'core/P-20260728-gamma\tcore/010\tnew')" "$OUT"
}

# AC: two spellings of one ordinal are one identity at the realize path's
# find-or-allocate readback — a resumed realization finds its own prior record
# even when that record spells the ordinal unpadded, and reports it canonically,
# so a crafted spelling can neither split the resume nor re-open the
# duplicate-ordinal seam.
case_jimalloc_realize_spec_unpadded_record_converges() {
  local log
  log=$(printf '%s\n' 'spec allocate core/3 beta 20260728 jane')
  run_realize_spec "$log" core/P-20260728-beta
  assert_exit "rc" 0 "$RC"
  assert_eq "unpadded record → its own ordinal, canonical, no new allocation" \
    "$(printf 'core/P-20260728-beta\tcore/003\thave')" "$OUT"
}

# AC: the padding-blind readback does not leak into the high-water either — an
# unpadded record still counts as its ordinal, so the next new allocation clears
# it instead of reissuing it.
case_jimalloc_realize_spec_unpadded_record_counts_in_high_water() {
  local log
  log=$(printf '%s\n' 'spec allocate core/7 beta 20260728 jane')
  run_realize_spec "$log" core/P-20260728-gamma
  assert_exit "rc" 0 "$RC"
  assert_eq "next ordinal clears the unpadded record" \
    "$(printf 'core/P-20260728-gamma\tcore/008\tnew')" "$OUT"
}

# jimalloc_exhausted_log — a log whose group sits on the widest ordinal the
# registry could be rebuilt from, so the next one is unmintable.
jimalloc_exhausted_log() {
  printf '%s\n' 'spec allocate core/999999999999999 a 20260726 x'
}

# AC: ordinal exhaustion halts BEFORE emitting any row, matching the documented
# contract. The preview pipes this mapping straight to the developer, so a
# partial mapping is output that looks like a plan and is not one.
case_jimalloc_realize_spec_exhaustion_emits_nothing() {
  local log
  log="$(jimalloc_exhausted_log)"
  run_realize_spec "$log" core/P-20260726-a core/P-20260727-b
  assert_exit     "rc"                1  "$RC"
  assert_eq       "no partial mapping" "" "$OUT"
  assert_match    "names the halt"    'exhausted' "$ERR"
}

# AC: the same ordering on the other read path — next-id prints nothing when the
# ordinal it would mint is one the registry could not be rebuilt from.
case_jimalloc_next_id_spec_exhaustion_emits_nothing() {
  local log out err rc
  log="$(jimalloc_exhausted_log)"
  err="$TMP_BASE/.err"
  out="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec core <<< "$log" 2>"$err")"
  rc=$?
  assert_exit  "rc"             1           "$rc"
  assert_eq    "nothing minted" ""          "$out"
  assert_match "names the halt" 'exhausted' "$(cat "$err")"
}

# AC: the key carries the date the provisional identity was issued, not the day
# realization runs — a same-slug record stamped with another date belongs to a
# different spec and never absorbs the pending identity.
case_jimalloc_realize_spec_date_is_part_of_the_key() {
  local log
  log=$(printf '%s\n' 'spec allocate core/003 beta 20260801 jane')
  run_realize_spec "$log" core/P-20260728-beta
  assert_exit "rc" 0 "$RC"
  assert_eq "different issuance date → a new ordinal" \
    "$(printf 'core/P-20260728-beta\tcore/004\tnew')" "$OUT"
}

# AC: the slug is part of the key too — a same-date record for another spec does
# not absorb the pending identity.
case_jimalloc_realize_spec_slug_is_part_of_the_key() {
  local log
  log=$(printf '%s\n' 'spec allocate core/003 alpha 20260728 jane')
  run_realize_spec "$log" core/P-20260728-beta
  assert_exit "rc" 0 "$RC"
  assert_eq "different slug → a new ordinal" \
    "$(printf 'core/P-20260728-beta\tcore/004\tnew')" "$OUT"
}

# AC: the realized ordinal derives solely from the shared high-water, never from
# any digits the tree-derived provisional token happens to carry.
case_jimalloc_realize_spec_marker_independent() {
  run_realize_spec "" core/P-20260728-spec-999
  assert_exit "rc" 0 "$RC"
  assert_eq "ordinal from high-water, not marker" \
    "$(printf 'core/P-20260728-spec-999\tcore/001\tnew')" "$OUT"
}

# AC: realization reuses the shared group-aliased fold, so a provisional issued
# under a name that has since been renamed realizes under the current name and
# above the high-water both names contribute to — never into a retired namespace.
case_jimalloc_realize_spec_group_alias() {
  local log
  log=$(printf '%s\n' 'spec allocate dashboard/002 alpha 20260726 x' \
                      'group rename dashboard ui 20260727 x')
  run_realize_spec "$log" dashboard/P-20260728-beta
  assert_exit "rc" 0 "$RC"
  assert_eq "realizes under the current group, above the folded high-water" \
    "$(printf 'dashboard/P-20260728-beta\tui/003\tnew')" "$OUT"
}

# AC: the ordinal a normal allocation would issue and the one realization lands
# on are the same value for every log shape, malformed records included — a
# record whose ordinal is legal but whose slug fails the boundary still consumed
# that ordinal, so realizing must not land on ground allocation treats as taken.
case_jimalloc_realize_spec_high_water_parity() {
  local log alloc_next realized
  log=$(printf '%s\n' 'spec allocate core/009 --upload-pack=x 20260726 x' \
                      'spec allocate core/002 good 20260726 x')
  alloc_next="$(source "$SCRIPT_jimalloc"; alloc_next_id_spec core <<< "$log")"
  run_realize_spec "$log" core/P-20260728-pending
  assert_exit "rc" 0 "$RC"
  realized="$(printf '%s' "$OUT" | cut -f2)"
  assert_eq "realization agrees with allocation" "$alloc_next" "$realized"
  assert_eq "and clears the consumed ordinal"    "core/010"    "$realized"
}

# AC: a duplicate pending identity within one batch halts realization rather
# than collapsing two markers onto one ordinal.
case_jimalloc_realize_spec_within_batch_dup() {
  run_realize_spec "" core/P-20260728-dup core/P-20260728-dup
  assert_exit     "rc"      1  "$RC"
  assert_nonempty "message" "$ERR"
}

# AC: every pending identity is revalidated at the id boundary before use — an
# option-injection shape, a real (non-provisional) id, and a group that fails
# the boundary are all refused with no partial mapping emitted.
case_jimalloc_realize_spec_crafted_pending() {
  run_realize_spec "" "--upload-pack=x"
  assert_exit     "option shape rc"      1  "$RC"
  assert_eq       "no partial mapping"   "" "$OUT"
  assert_nonempty "option shape message" "$ERR"
  run_realize_spec "" core/001
  assert_exit     "real id rc"      1  "$RC"
  assert_nonempty "real id message" "$ERR"
  run_realize_spec "" "--x/P-20260728-beta"
  assert_exit     "crafted group rc"      1  "$RC"
  assert_nonempty "crafted group message" "$ERR"
  run_realize_spec "" "core/P---bad"
  assert_exit     "invalid token rc"      1  "$RC"
  assert_nonempty "invalid token message" "$ERR"
}

# AC: a pending batch halts as a whole — a later invalid entry produces no
# mapping for the valid ones that precede it, so a preview shows either a clean
# mapping or only the stop condition.
case_jimalloc_realize_spec_halt_is_whole_batch() {
  run_realize_spec "" core/P-20260728-good "--upload-pack=x"
  assert_exit "rc"        1  "$RC"
  assert_eq   "no output" "" "$OUT"
}

# ─── Section: reconcile — publish + tiers (real git) ─────────────────────────

# run_reconcile_in <dir> <pending> <args...> — run the allocator inside <dir>
# with <pending> (a newline-joined set of ids) on stdin as the pending set;
# capture OUT/ERR/RC.
run_reconcile_in() {
  local dir="$1" pending="$2"; shift 2
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$dir" && printf '%s\n' "$pending" | bash "$SCRIPT_jimalloc" "$@" 2>"$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# AC: reconcile --apply realizes each pending provisional into a real ordinal and
# publishes it durably on the coordination branch, over the same reachability
# tier / CAS / durable-before-reported path a normal allocation uses (spec AC 4).
case_jimalloc_reconcile_apply_publishes_durably() {
  local bare A input issues
  bare="$(alloc_new_bare recon_pub_bare)"
  A="$(alloc_new_clone "$bare" recon_pub_A)"
  input=$(printf '%s\n' 20260726-alpha)
  run_reconcile_in "$A" "$input" reconcile issue --apply
  assert_exit  "rc" 0 "$RC"
  assert_match "mapping printed" '^20260726-alpha	1$' "$OUT"
  issues="$(alloc_bare_issues "$bare")"
  assert_match "real record on remote" '^issue allocate 1 20260726-alpha ' "$issues"
}

# AC: realizing N pending provisionals publishes as a single durable commit —
# all-or-none (spec AC 5).
case_jimalloc_reconcile_apply_single_commit() {
  local bare A input before after
  bare="$(alloc_new_bare recon_1c_bare)"
  A="$(alloc_new_clone "$bare" recon_1c_A)"
  run_jimalloc_in "$A" allocate issue "seed"   # branch exists at commit 1
  before="$(git -C "$bare" rev-list --count refs/heads/jim/registry)"
  input=$(printf '%s\n' 20260726-a 20260726-b)
  run_reconcile_in "$A" "$input" reconcile issue --apply
  assert_exit "rc" 0 "$RC"
  after="$(git -C "$bare" rev-list --count refs/heads/jim/registry)"
  assert_eq "one commit for N reals" "$((before + 1))" "$after"
}

# AC: two clones reconciling concurrently realize every pending provisional to a
# distinct real id — the shared-registry CAS serializes both passes (spec AC 8).
case_jimalloc_reconcile_concurrent_distinct() {
  local bare A B ra rb orda ordb count
  bare="$(alloc_new_bare recon_conc_bare)"
  A="$(alloc_new_clone "$bare" recon_conc_A)"
  B="$(alloc_new_clone "$bare" recon_conc_B)"
  run_jimalloc_in "$A" allocate issue "seed"   # create the branch @ 1, both fetch it
  ( cd "$A" && printf '%s\n' 20260726-from-a | bash "$SCRIPT_jimalloc" reconcile issue --apply ) > "$TMP_BASE/rra" 2>/dev/null &
  ( cd "$B" && printf '%s\n' 20260726-from-b | bash "$SCRIPT_jimalloc" reconcile issue --apply ) > "$TMP_BASE/rrb" 2>/dev/null &
  wait
  ra="$(cat "$TMP_BASE/rra")"; rb="$(cat "$TMP_BASE/rrb")"
  orda="${ra##*$'\t'}"; ordb="${rb##*$'\t'}"
  assert_nonempty "A ordinal" "$orda"
  assert_nonempty "B ordinal" "$ordb"
  if [[ "$orda" == "$ordb" ]]; then
    CURRENT_FAILED=1; echo "    [concurrent] both reconciles realized the same ordinal: $orda"
  fi
  count="$(alloc_bare_issues "$bare" | grep -c '^issue allocate ')"
  assert_eq "three reals on remote" "3" "$count"
}

# AC: reconcile is resumable — the real id is durable before any consumer
# rewrite, so re-running after an interruption re-maps the same provisional to
# the same ordinal and allocates no second real id (spec AC 6).
case_jimalloc_reconcile_resume_no_double_allocate() {
  local bare A input count
  bare="$(alloc_new_bare recon_resume_bare)"
  A="$(alloc_new_clone "$bare" recon_resume_A)"
  input=$(printf '%s\n' 20260726-once)
  run_reconcile_in "$A" "$input" reconcile issue --apply
  assert_exit  "first rc" 0 "$RC"
  assert_match "first mapping" '^20260726-once	1$' "$OUT"
  run_reconcile_in "$A" "$input" reconcile issue --apply   # resume after a crash
  assert_exit  "resume rc" 0 "$RC"
  assert_match "resume same ordinal" '^20260726-once	1$' "$OUT"
  count="$(alloc_bare_issues "$bare" | grep -c '20260726-once')"
  assert_eq "exactly one real record" "1" "$count"
}

# AC: when the coordination point is unreachable at reconcile time, reconcile
# realizes nothing, reports it is still offline, and changes nothing — a clean
# no-op, distinct from the allocation-time hard fail (spec AC 7).
case_jimalloc_reconcile_still_offline_noop() {
  local repo input
  repo="$(alloc_new_repo recon_offline)"
  git -C "$repo" remote add origin "$TMP_BASE/no-such-recon.git"
  input=$(printf '%s\n' 20260726-pending)
  run_reconcile_in "$repo" "$input" reconcile issue --apply
  assert_exit     "rc"      0  "$RC"
  assert_eq       "no mapping" "" "$OUT"
  assert_nonempty "still-offline message" "$ERR"
  assert_eq "nothing published" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
}

# ─── Section: reconcile spec — publish + tiers (real git) ────────────────────

# AC: `reconcile spec --apply` realizes each pending provisional spec identity
# into a real ordinal and publishes it durably over the same tier / CAS /
# durable-before-reported path a normal allocation uses.
case_jimalloc_reconcile_spec_apply_publishes_durably() {
  local bare A input specs
  bare="$(alloc_new_bare recon_spec_bare)"
  A="$(alloc_new_clone "$bare" recon_spec_A)"
  input=$(printf '%s\n' core/P-20260728-alpha)
  run_reconcile_in "$A" "$input" reconcile spec --apply
  assert_exit  "rc" 0 "$RC"
  assert_match "mapping printed" '^core/P-20260728-alpha	core/001	new$' "$OUT"
  specs="$(alloc_bare_specs "$bare")"
  assert_match "real record on remote" '^spec allocate core/001 alpha ' "$specs"
}

# AC: the published record carries the date the provisional identity was issued,
# not the day realization ran — the field the idempotency key reads back, so a
# resumed run finds its own record instead of allocating a second ordinal.
case_jimalloc_reconcile_spec_apply_stamps_issuance_date() {
  local bare A input specs today
  bare="$(alloc_new_bare recon_specdate_bare)"
  A="$(alloc_new_clone "$bare" recon_specdate_A)"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  input=$(printf '%s\n' core/P-20260728-alpha)
  run_reconcile_in "$A" "$input" reconcile spec --apply
  assert_exit  "rc" 0 "$RC"
  specs="$(alloc_bare_specs "$bare")"
  assert_match "issuance date stamped" '^spec allocate core/001 alpha 20260728 ' "$specs"
  if [[ "20260728" != "$today" ]] && printf '%s\n' "$specs" | grep -q "^spec allocate core/001 alpha $today "; then
    CURRENT_FAILED=1; echo "    [key] record stamped with the realization day, not issuance"
  fi
}

# AC: realizing N pending provisionals publishes as a single durable commit —
# all-or-none.
case_jimalloc_reconcile_spec_apply_single_commit() {
  local bare A input before after
  bare="$(alloc_new_bare recon_spec1c_bare)"
  A="$(alloc_new_clone "$bare" recon_spec1c_A)"
  run_jimalloc_in "$A" allocate spec core "seed"
  before="$(git -C "$bare" rev-list --count refs/heads/jim/registry)"
  input=$(printf '%s\n' core/P-20260728-a core/P-20260728-b)
  run_reconcile_in "$A" "$input" reconcile spec --apply
  assert_exit "rc" 0 "$RC"
  after="$(git -C "$bare" rev-list --count refs/heads/jim/registry)"
  assert_eq "one commit for N reals" "$((before + 1))" "$after"
}

# AC: realizing into a group the registry has never seen claims that group once,
# however many of its specs realize in the batch — the same allocate-once shape
# the allocation path has.
case_jimalloc_reconcile_spec_apply_claims_group_once() {
  local bare A input specs count
  bare="$(alloc_new_bare recon_specgrp_bare)"
  A="$(alloc_new_clone "$bare" recon_specgrp_A)"
  input=$(printf '%s\n' fresh/P-20260728-a fresh/P-20260728-b)
  run_reconcile_in "$A" "$input" reconcile spec --apply
  assert_exit "rc" 0 "$RC"
  specs="$(alloc_bare_specs "$bare")"
  count="$(printf '%s\n' "$specs" | grep -c '^group allocate fresh ')"
  assert_eq   "group claimed exactly once" "1" "$count"
  assert_match "first spec recorded"  '^spec allocate fresh/001 a ' "$specs"
  assert_match "second spec recorded" '^spec allocate fresh/002 b ' "$specs"
}

# AC: a group the registry already holds is not re-claimed by realization.
case_jimalloc_reconcile_spec_apply_group_not_reclaimed() {
  local bare A input count
  bare="$(alloc_new_bare recon_specgrp2_bare)"
  A="$(alloc_new_clone "$bare" recon_specgrp2_A)"
  run_jimalloc_in "$A" allocate spec core "seed"
  input=$(printf '%s\n' core/P-20260728-a)
  run_reconcile_in "$A" "$input" reconcile spec --apply
  assert_exit "rc" 0 "$RC"
  count="$(alloc_bare_specs "$bare" | grep -c '^group allocate core ')"
  assert_eq "group still claimed exactly once" "1" "$count"
}

# AC: realization is resumable — the real ordinal is durable before any consumer
# rename, so a re-run after an interruption maps the same identity to the same
# ordinal, reports it as already held, and allocates no second real id.
case_jimalloc_reconcile_spec_resume_no_double_allocate() {
  local bare A input count
  bare="$(alloc_new_bare recon_specres_bare)"
  A="$(alloc_new_clone "$bare" recon_specres_A)"
  input=$(printf '%s\n' core/P-20260728-once)
  run_reconcile_in "$A" "$input" reconcile spec --apply
  assert_exit  "first rc"      0 "$RC"
  assert_match "first mapping" '^core/P-20260728-once	core/001	new$' "$OUT"
  run_reconcile_in "$A" "$input" reconcile spec --apply   # resume after a crash
  assert_exit  "resume rc"      0 "$RC"
  assert_match "resume same ordinal, already held" '^core/P-20260728-once	core/001	have$' "$OUT"
  count="$(alloc_bare_specs "$bare" | grep -c '^spec allocate core/001 once ')"
  assert_eq "exactly one real record" "1" "$count"
}

# AC: with the coordination point still unreachable, realization realizes
# nothing, says so, and changes nothing — a clean no-op, distinct from the
# allocation-time hard fail.
case_jimalloc_reconcile_spec_still_offline_noop() {
  local repo input
  repo="$(alloc_new_repo recon_spec_offline)"
  git -C "$repo" remote add origin "$TMP_BASE/no-such-spec-recon.git"
  input=$(printf '%s\n' core/P-20260728-pending)
  run_reconcile_in "$repo" "$input" reconcile spec --apply
  assert_exit     "rc"                    0  "$RC"
  assert_eq       "no mapping"            "" "$OUT"
  assert_nonempty "still-offline message" "$ERR"
  assert_eq "nothing published" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
}

# AC: an empty pending set is a clean no-op — nothing published, the note on
# stderr so stdout stays parseable.
case_jimalloc_reconcile_spec_nothing_pending() {
  local repo
  repo="$(alloc_new_repo recon_spec_empty)"
  run_reconcile_in "$repo" "" reconcile spec --apply
  assert_exit     "rc"                     0  "$RC"
  assert_eq       "no mapping"             "" "$OUT"
  assert_nonempty "nothing-pending message" "$ERR"
}

# AC: bare `reconcile spec` is a read-only preview — it reports the mapping it
# would make and mutates nothing.
case_jimalloc_reconcile_spec_preview_no_mutation() {
  local bare A input before after
  bare="$(alloc_new_bare recon_specprev_bare)"
  A="$(alloc_new_clone "$bare" recon_specprev_A)"
  run_jimalloc_in "$A" allocate spec core "seed"
  before="$(git -C "$bare" rev-parse refs/heads/jim/registry)"
  input=$(printf '%s\n' core/P-20260728-p)
  run_reconcile_in "$A" "$input" reconcile spec
  assert_exit  "rc" 0 "$RC"
  assert_match "previews mapping" '^core/P-20260728-p	core/002	new$' "$OUT"
  after="$(git -C "$bare" rev-parse refs/heads/jim/registry)"
  assert_eq "remote registry unchanged" "$before" "$after"
}

# AC: the preview carries the state column, so an identity the registry already
# holds is visible as such before anything is applied — the tell for the residual
# same-identity case and for a crafted matching record.
case_jimalloc_reconcile_spec_preview_shows_state() {
  local bare A input
  bare="$(alloc_new_bare recon_specstate_bare)"
  A="$(alloc_new_clone "$bare" recon_specstate_A)"
  input=$(printf '%s\n' core/P-20260728-alpha)
  run_reconcile_in "$A" "$input" reconcile spec --apply
  assert_exit "apply rc" 0 "$RC"
  run_reconcile_in "$A" "$input" reconcile spec
  assert_exit  "preview rc" 0 "$RC"
  assert_match "preview names the held state" '	have$' "$OUT"
}

# AC: apply publishes exactly the mapping the preview reported.
case_jimalloc_reconcile_spec_preview_matches_apply() {
  local bare A input prev applied
  bare="$(alloc_new_bare recon_specpa_bare)"
  A="$(alloc_new_clone "$bare" recon_specpa_A)"
  input=$(printf '%s\n' core/P-20260728-x core/P-20260728-y)
  run_reconcile_in "$A" "$input" reconcile spec           # preview
  assert_exit "preview rc" 0 "$RC"
  prev="$OUT"
  run_reconcile_in "$A" "$input" reconcile spec --apply   # apply
  assert_exit "apply rc" 0 "$RC"
  applied="$OUT"
  assert_eq    "apply matches preview" "$prev" "$applied"
  assert_match "maps x" '^core/P-20260728-x	core/001	new$' "$applied"
  assert_match "maps y" '^core/P-20260728-y	core/002	new$' "$applied"
}

# AC: a crafted pending identity is refused before anything is published — the
# boundary the pure layer enforces is reached through the verb too.
case_jimalloc_reconcile_spec_crafted_pending_refused() {
  local bare A input
  bare="$(alloc_new_bare recon_speccraft_bare)"
  A="$(alloc_new_clone "$bare" recon_speccraft_A)"
  input=$(printf '%s\n' '--upload-pack=x')
  run_reconcile_in "$A" "$input" reconcile spec --apply
  assert_exit     "rc"      1  "$RC"
  assert_eq       "no mapping" "" "$OUT"
  assert_nonempty "message" "$ERR"
  assert_eq "nothing published" "" \
    "$(git -C "$bare" rev-parse --verify --quiet refs/heads/jim/registry || true)"
}

# ─── Section: reconcile — preview-then-apply (AC 9) ──────────────────────────

# AC: bare `reconcile` is a read-only preview — it reports the provisional→real
# mapping it would make and mutates nothing (spec AC 9).
case_jimalloc_reconcile_preview_no_mutation() {
  local bare A input before after
  bare="$(alloc_new_bare recon_prev_bare)"
  A="$(alloc_new_clone "$bare" recon_prev_A)"
  run_jimalloc_in "$A" allocate issue "seed"   # branch @ 1
  before="$(git -C "$bare" rev-parse refs/heads/jim/registry)"
  input=$(printf '%s\n' 20260726-p)
  run_reconcile_in "$A" "$input" reconcile issue
  assert_exit  "rc" 0 "$RC"
  assert_match "previews mapping" '^20260726-p	2$' "$OUT"
  after="$(git -C "$bare" rev-parse refs/heads/jim/registry)"
  assert_eq "remote registry unchanged" "$before" "$after"
}

# AC: apply publishes exactly the mapping the preview reported (spec AC 9).
case_jimalloc_reconcile_preview_matches_apply() {
  local bare A input prev applied
  bare="$(alloc_new_bare recon_pa_bare)"
  A="$(alloc_new_clone "$bare" recon_pa_A)"
  input=$(printf '%s\n' 20260726-x 20260726-y)
  run_reconcile_in "$A" "$input" reconcile issue           # preview
  assert_exit "preview rc" 0 "$RC"
  prev="$OUT"
  run_reconcile_in "$A" "$input" reconcile issue --apply    # apply
  assert_exit "apply rc" 0 "$RC"
  applied="$OUT"
  assert_eq    "apply matches preview" "$prev" "$applied"
  assert_match "maps x" '^20260726-x	1$' "$applied"
  assert_match "maps y" '^20260726-y	2$' "$applied"
}

# AC: preview reports a stop condition (a within-batch duplicate identity) and
# emits no mapping, mutating nothing (spec AC 9).
case_jimalloc_reconcile_preview_reports_stop() {
  local bare A input
  bare="$(alloc_new_bare recon_stop_bare)"
  A="$(alloc_new_clone "$bare" recon_stop_A)"
  input=$(printf '%s\n' 20260726-dup 20260726-dup)
  run_reconcile_in "$A" "$input" reconcile issue
  assert_exit     "rc"      1  "$RC"
  assert_eq       "no mapping" "" "$OUT"
  assert_nonempty "stop condition reported" "$ERR"
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
