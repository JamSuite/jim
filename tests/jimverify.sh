#!/usr/bin/env bash
#
# tests/jimverify.sh — Tests for skills/verify/scripts/jimverify.sh
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# WHAT THIS FILE TESTS
#   The jimverify.sh deterministic verification core: `parse` (blueprint
#   Invariants table + verify-checks block → normalized TSV, with id / enum /
#   registry-name validation, malformed-row degradation, legacy-table → judge
#   fallback, TSV field sanitization) and `territory` (group territory
#   extraction from the project map, each path through valid-relpath). The
#   `check` verb is exercised in the spec 035 Task 4 cases below.
#
# HOW TO RUN
#   bash tests/jimverify.sh                  # every case in this file
#   bash skills/meta-test/scripts/run.sh     # this file alongside every other tests/*.sh
#

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT_jimverify="$REPO_ROOT/skills/verify/scripts/jimverify.sh"

# ─── Section: Per-script invoker ─────────────────────────────────────────────

# run_jimverify <args...>
#   Invoke jimverify.sh; capture stdout, stderr, exit code into OUT, ERR, RC.
run_jimverify() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_jimverify" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# tsv_fields <id> — echo the TAB-field count of the first OUT line whose first
#   field equals <id>. Empty if no such line. Used to assert column stability.
tsv_fields() {
  printf '%s\n' "$OUT" | awk -F'\t' -v id="$1" '$1==id {print NF; exit}'
}

# tsv_field <id> <n> — echo TAB-field <n> of the first OUT line keyed by <id>.
tsv_field() {
  printf '%s\n' "$OUT" | awk -F'\t' -v id="$1" -v n="$2" '$1==id {print $n; exit}'
}

# ─── Section: parse — well-formed table ──────────────────────────────────────

# AC: parse emits one normalized TSV record per invariant — id, criticality,
# method (closed enum), params (joined from the verify-checks block, or -), and
# the verbatim invariant text (spec 035 AC #9, DD #2/#8).
case_jimverify_parse_wellformed() {
  local cfg
  cfg=$(fixture inv-well.md '## Invariants

| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| path-resolver | Paths are resolved via jimfile | critical | pattern |
| skill-budget | SKILL.md under 500 lines | medium | registry:linecount |
| domain-bounds | Agents do not cross domains | high | judge |

```verify-checks
path-resolver polarity=must-not regex=docs/(specs|issues)/[^ ]*\.md scope=skills/
```

## Next section')
  run_jimverify parse "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_eq "path-resolver criticality" "critical" "$(tsv_field path-resolver 2)"
  assert_eq "path-resolver method"      "pattern"  "$(tsv_field path-resolver 3)"
  assert_match "path-resolver params carry the check line" 'polarity=must-not' "$(tsv_field path-resolver 4)"
  assert_match "path-resolver params carry scope"          'scope=skills/'     "$(tsv_field path-resolver 4)"
  assert_match "path-resolver invariant text"  'Paths are resolved via jimfile' "$(tsv_field path-resolver 5)"
  assert_eq "skill-budget method" "registry:linecount" "$(tsv_field skill-budget 3)"
  assert_eq "skill-budget no params" "-" "$(tsv_field skill-budget 4)"
  assert_eq "domain-bounds method" "judge" "$(tsv_field domain-bounds 3)"
  assert_eq "every row is 5 fields (path-resolver)" "5" "$(tsv_fields path-resolver)"
}

# AC: a legacy 3-column table (Invariant | Criticality | Verification method,
# no Id column) verifies unchanged — every row falls back to the judge rung
# under a synthesized inv-<n> id, never an error (spec 035 AC #10).
case_jimverify_parse_legacy_judge_fallback() {
  local cfg
  cfg=$(fixture inv-legacy.md '## Invariants

| Invariant | Criticality | Verification method |
| :--- | :--- | :--- |
| Scripts never source config | critical | grep for source/eval |
| SKILL.md under 500 lines | medium | line count check |
')
  run_jimverify parse "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_eq "row 1 method judge"   "judge"    "$(tsv_field inv-1 3)"
  assert_eq "row 1 criticality"    "critical" "$(tsv_field inv-1 2)"
  assert_match "row 1 invariant"   'Scripts never source config' "$(tsv_field inv-1 5)"
  assert_eq "row 2 method judge"   "judge"    "$(tsv_field inv-2 3)"
  assert_eq "row 2 no params"      "-"        "$(tsv_field inv-2 4)"
}

# AC: a non-slug Id degrades that row to a malformed record (method field
# "malformed", reason in the params slot) — never a silent drop, never an error
# (spec 035 DD #2, parse contract).
case_jimverify_parse_malformed_id() {
  local cfg
  cfg=$(fixture inv-badid.md '## Invariants

| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| Bad_Id | some rule | high | pattern |
')
  run_jimverify parse "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_match "malformed method emitted" '	malformed	' "$OUT"
}

# AC: a registry check naming a non-slug entry degrades to malformed and the
# raw name is never echoed into the record — the resolver-side twin of the
# lookup-time gate (spec 035 AC #6, security Finding 1).
case_jimverify_parse_bad_registry_name() {
  local cfg
  cfg=$(fixture inv-badreg.md '## Invariants

| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| reg-row | some rule | high | registry:Bad_Name |
')
  run_jimverify parse "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_eq "method malformed" "malformed" "$(tsv_field reg-row 3)"
  assert_eq "raw name not echoed" "0" "$(printf '%s\n' "$OUT" | grep -c 'Bad_Name')"
}

# AC: TSV integrity — an embedded tab in a cell is sanitized so it can never
# shift columns or smuggle a spurious record (spec 035 security Finding 7, the
# spec 022 column-shift lesson).
case_jimverify_parse_tab_sanitized() {
  local cfg
  cfg=$(fixture inv-tab.md "$(printf '## Invariants\n\n| Id | Invariant | Criticality | Check |\n| :--- | :--- | :--- | :--- |\n| tabby | has\ta tab inside | high | judge |\n')")
  run_jimverify parse "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_eq "tabby row stays 5 fields" "5" "$(tsv_fields tabby)"
}

# AC: parse with a missing file argument exits 2 (usage / unreadable input).
case_jimverify_parse_missing_file_exits_2() {
  run_jimverify parse "$TMP_BASE/does-not-exist.md"
  assert_exit "rc" 2 "$RC"
}

# AC: a blueprint with no Invariants section emits nothing and exits 0 — the
# skill reports "no invariants" without error litter (spec 035 AC #2).
case_jimverify_parse_no_invariants_section() {
  local cfg
  cfg=$(fixture inv-empty.md '# Blueprint

## Responsibility

Just prose, no invariants table.
')
  run_jimverify parse "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_eq "no output" "" "$OUT"
}

# ─── Section: territory — map extraction ─────────────────────────────────────

# AC: territory extracts a group's declared territory paths from the project
# map, one validated relpath per line (spec 035 AC #4; the spec 033 map is the
# territory source).
case_jimverify_territory_extracts_paths() {
  local cfg
  cfg=$(fixture map-terr.md '## Groups

### jim

- **Purpose:** the plugin
- **Territory:** `skills/`, `agents/`, `tests/`
- **Blueprint:** docs/specs/jim/000-blueprint/
')
  run_jimverify territory "$cfg" jim
  assert_exit "rc" 0 "$RC"
  assert_match "skills listed" '^skills/$' "$OUT"
  assert_match "agents listed" '^agents/$' "$OUT"
  assert_match "tests listed"  '^tests/$'  "$OUT"
}

# AC: territory for a group absent from the map exits 2 (the group has no
# declared boundary to read).
case_jimverify_territory_group_absent_exits_2() {
  local cfg
  cfg=$(fixture map-absent.md '## Groups

### jim

- **Territory:** `skills/`
')
  run_jimverify territory "$cfg" ghost
  assert_exit "rc" 2 "$RC"
}

# AC: a territory path that fails valid-relpath (absolute, or a `..` segment) is
# reported as map hygiene and excluded from the validated list — a declared
# boundary can never escape the repo (spec 035 AC #4, the spec 033 gate).
case_jimverify_territory_hygiene_excludes_unsafe() {
  local cfg
  cfg=$(fixture map-hygiene.md '## Groups

### jim

- **Territory:** `/etc/passwd`, `../escape`, `skills/`
')
  run_jimverify territory "$cfg" jim
  assert_exit "rc" 0 "$RC"
  assert_match "safe path emitted"   '^skills/$'             "$OUT"
  assert_match "absolute → hygiene"  '^HYGIENE	/etc/passwd$' "$OUT"
  assert_match "dotdot → hygiene"    '^HYGIENE	../escape$'    "$OUT"
  assert_eq "unsafe path never emitted as a plain relpath" "0" \
    "$(printf '%s\n' "$OUT" | grep -c '^/etc/passwd$')"
}

# AC: a group whose Territory is an em-dash / none marker emits nothing and
# exits 0 — no fabricated path (the group_territory=none / undeclared case).
case_jimverify_territory_none_marker() {
  local cfg
  cfg=$(fixture map-noterr.md '## Groups

### jim

- **Purpose:** the plugin
- **Territory:** —
')
  run_jimverify territory "$cfg" jim
  assert_exit "rc" 0 "$RC"
  assert_eq "no paths" "" "$OUT"
}

# ─── Section: dispatch ───────────────────────────────────────────────────────

# AC: no subcommand exits 2 with usage on stderr.
case_jimverify_no_args_exits_2() {
  run_jimverify
  assert_exit     "rc" 2 "$RC"
  assert_nonempty "usage on stderr" "$ERR"
}

# AC: an unknown subcommand exits 2.
case_jimverify_unknown_subcommand_exits_2() {
  run_jimverify bogus x
  assert_exit "rc" 2 "$RC"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_jimverify" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_jimverify — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
