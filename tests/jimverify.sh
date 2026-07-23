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

# AC: a dashes-only Id in a DATA row is a malformed record (invalid id), never
# silently swallowed as if it were the table separator — the separator skip
# binds only to the one row right after the header (issue #51, review Finding 4).
case_jimverify_parse_dashes_only_id_not_dropped() {
  local cfg
  cfg=$(fixture inv-dashid.md '## Invariants

| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| --- | some rule | high | pattern |
')
  run_jimverify parse "$cfg"
  assert_exit    "rc" 0 "$RC"
  assert_nonempty "dashes-only id row not silently dropped" "$OUT"
  assert_match   "dashes-only id → malformed" '	malformed	' "$OUT"
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

# ─── Section: check — the mechanical floor (spec 035 Task 4) ─────────────────

# verify_repo_scoped <name> — build a throwaway git repo with a group blueprint
#   (pattern + structure checks), a project map declaring territory `skills/`,
#   group code under skills/, and a stray file outside territory. Echo the root.
verify_repo_scoped() {
  local name="$1"; local root="$TMP_BASE/$name"
  mkdir -p "$root/skills/foo" "$root/docs/specs/g/000-blueprint"
  git -C "$root" init -q
  git -C "$root" config user.email "test@example.com"
  git -C "$root" config user.name "Test"
  git -C "$root" config commit.gpgsign false
  printf 'see docs/specs/x.md for details\n' > "$root/skills/foo/bad.sh"
  printf 'CLEANMARKER only\n'                > "$root/skills/foo/good.sh"
  printf 'stray file\n'                      > "$root/loose.txt"
  cat > "$root/docs/specs/g/000-blueprint/spec.md" <<'EOF'
## Invariants

| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| no-inline | no inline doc paths in skills | high | pattern |
| want-clean | skills carry the clean marker | medium | pattern |
| no-tmp | no tmp files under skills | low | structure |
| good-exists | the good file exists | low | structure |

```verify-checks
no-inline polarity=must-not regex=docs/specs/[^ ]*\.md scope=skills/
want-clean polarity=must regex=CLEANMARKER scope=skills/
no-tmp absent=skills/*.tmp
good-exists exists=skills/foo/good.sh
```
EOF
  cat > "$root/BLUEPRINT.md" <<'EOF'
## Groups

### g

- **Territory:** `skills/`
EOF
  git -C "$root" add -A
  git -C "$root" commit -q -m "seed"
  printf '%s' "$root"
}

# run_jimverify_in <dir> <args...> — invoke jimverify.sh with CWD=<dir> so the
#   floor's grep/find/git run against the fixture repo. Capture OUT/ERR/RC.
run_jimverify_in() {
  local dir="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$dir" && bash "$SCRIPT_jimverify" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# AC: a must-not pattern check that matches inside territory reports violated,
# with the offending location as evidence (spec 035 AC #4).
case_jimverify_check_pattern_mustnot_violated() {
  local root; root="$(verify_repo_scoped t4mn)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_exit "rc" 0 "$RC"
  assert_eq    "no-inline violated" "violated"       "$(tsv_field no-inline 2)"
  assert_match "evidence names file" 'skills/foo/bad\.sh' "$(tsv_field no-inline 3)"
}

# AC: a must pattern check that finds its required match inside territory holds
# (spec 035 AC #4).
case_jimverify_check_pattern_must_holds() {
  local root; root="$(verify_repo_scoped t4mh)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_eq "want-clean holds" "holds" "$(tsv_field want-clean 2)"
}

# verify_repo_count <name> — build a throwaway git repo whose territory holds a
#   file with exactly three MARKER lines, and a blueprint whose verify-checks
#   exercise the pattern count= parameter (exact, mismatch, malformed). Echo root.
verify_repo_count() {
  local name="$1"; local root="$TMP_BASE/$name"
  mkdir -p "$root/skills/foo" "$root/docs/specs/g/000-blueprint"
  git -C "$root" init -q
  git -C "$root" config user.email "test@example.com"
  git -C "$root" config user.name "Test"
  git -C "$root" config commit.gpgsign false
  printf 'alpha MARKER\nbeta MARKER\ngamma MARKER\ndelta plain\n' > "$root/skills/foo/code.sh"
  cat > "$root/docs/specs/g/000-blueprint/spec.md" <<'EOF'
## Invariants

| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| cnt-exact | marker appears exactly three times | low | pattern |
| cnt-miss | marker count does not match | low | pattern |
| cnt-bad | malformed count parameter | low | pattern |

```verify-checks
cnt-exact polarity=must regex=MARKER scope=skills/ count=3
cnt-miss polarity=must regex=MARKER scope=skills/ count=5
cnt-bad polarity=must regex=MARKER scope=skills/ count=three
```
EOF
  cat > "$root/BLUEPRINT.md" <<'EOF'
## Groups

### g

- **Territory:** `skills/`
EOF
  git -C "$root" add -A
  git -C "$root" commit -q -m "seed"
  printf '%s' "$root"
}

# AC: the pattern count= parameter runs exact-match semantics that override
# polarity — an exact match holds, a mismatch is violated, and a non-numeric
# count fails; each carries the documented evidence (spec 035 AC #4, issue #47).
case_jimverify_check_pattern_count() {
  local root; root="$(verify_repo_count t4cnt)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_exit  "rc" 0 "$RC"
  assert_eq    "count exact holds"          "holds"    "$(tsv_field cnt-exact 2)"
  assert_match "count exact evidence"       'matched 3 \(expected 3\)' "$(tsv_field cnt-exact 3)"
  assert_eq    "count mismatch violated"    "violated" "$(tsv_field cnt-miss 2)"
  assert_match "count mismatch evidence"    'matched 3, expected 5'    "$(tsv_field cnt-miss 3)"
  assert_eq    "count non-numeric failed"   "failed"   "$(tsv_field cnt-bad 2)"
  assert_match "count non-numeric evidence" 'invalid count parameter'  "$(tsv_field cnt-bad 3)"
}

# AC: structure existence / absence checks run deterministically — an existing
# path holds, an absent glob holds (spec 035 AC #4).
case_jimverify_check_structure_holds() {
  local root; root="$(verify_repo_scoped t4st)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_eq "good-exists holds" "holds" "$(tsv_field good-exists 2)"
  assert_eq "no-tmp holds"      "holds" "$(tsv_field no-tmp 2)"
}

# AC: territory conformance is the deterministic set difference — a tracked file
# outside the declared territory surfaces as a TERRITORY-CONFORMANCE record; the
# skill frames attribution (spec 035 AC #5, DD #8).
case_jimverify_check_conformance_detects_outside_file() {
  local root; root="$(verify_repo_scoped t4cf)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_match "loose flagged" '^TERRITORY-CONFORMANCE	loose\.txt$' "$OUT"
  assert_eq "skills code not flagged" "0" \
    "$(printf '%s\n' "$OUT" | grep -c '^TERRITORY-CONFORMANCE	skills/')"
}

# AC: with no declared territory the floor runs unscoped and emits the UNSCOPED
# sentinel, and territory conformance is skipped — the degradation is named on
# stdout, never silently absorbed (spec 035 AC #3, DD #8).
case_jimverify_check_unscoped_sentinel() {
  local root="$TMP_BASE/t4un"
  mkdir -p "$root/skills" "$root/docs/specs/g/000-blueprint"
  git -C "$root" init -q
  git -C "$root" config user.email "t@e.com"; git -C "$root" config user.name "T"
  git -C "$root" config commit.gpgsign false
  printf 'CLEANMARKER\n' > "$root/skills/a.sh"
  cat > "$root/docs/specs/g/000-blueprint/spec.md" <<'EOF'
## Invariants

| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| want-clean | clean marker present | medium | pattern |

```verify-checks
want-clean polarity=must regex=CLEANMARKER scope=skills/
```
EOF
  cat > "$root/BLUEPRINT.md" <<'EOF'
## Groups

### g

- **Territory:** —
EOF
  git -C "$root" add -A; git -C "$root" commit -q -m seed
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_exit  "rc" 0 "$RC"
  assert_match "unscoped sentinel" '^UNSCOPED$' "$OUT"
  assert_eq "no conformance when unscoped" "0" \
    "$(printf '%s\n' "$OUT" | grep -c '^TERRITORY-CONFORMANCE')"
  assert_eq "explicit-scope check still runs" "holds" "$(tsv_field want-clean 2)"
}

# AC: every path-bearing check parameter passes the valid-relpath + leading-dash
# gate before use — an absolute path, a `..` segment, or a leading-dash value
# degrades that check to failed and is never handed to grep/find (spec 035
# security Finding 6).
case_jimverify_check_bad_params_fail() {
  local root="$TMP_BASE/t4bp"
  mkdir -p "$root/skills" "$root/docs/specs/g/000-blueprint"
  git -C "$root" init -q
  git -C "$root" config user.email "t@e.com"; git -C "$root" config user.name "T"
  git -C "$root" config commit.gpgsign false
  printf 'x\n' > "$root/skills/a.sh"
  cat > "$root/docs/specs/g/000-blueprint/spec.md" <<'EOF'
## Invariants

| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| abs-scope | absolute scope | high | pattern |
| dotdot-scope | dotdot scope | high | pattern |
| dash-scope | leading-dash scope | high | pattern |
| space-dash-scope | leading-space-dash scope | high | pattern |
| abs-exists | absolute exists | high | structure |

```verify-checks
abs-scope polarity=must regex=x scope=/etc
dotdot-scope polarity=must regex=x scope=../outside
dash-scope polarity=must regex=x scope=-rf
space-dash-scope polarity=must regex=x scope= -rf
abs-exists exists=/etc/passwd
```
EOF
  cat > "$root/BLUEPRINT.md" <<'EOF'
## Groups

### g

- **Territory:** `skills/`
EOF
  git -C "$root" add -A; git -C "$root" commit -q -m seed
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_exit "rc" 0 "$RC"
  assert_eq "absolute scope → failed"   "failed" "$(tsv_field abs-scope 2)"
  assert_eq "dotdot scope → failed"     "failed" "$(tsv_field dotdot-scope 2)"
  assert_eq "leading-dash scope → failed" "failed" "$(tsv_field dash-scope 2)"
  assert_eq "leading-space-dash scope → failed" "failed" "$(tsv_field space-dash-scope 2)"
  assert_eq "absolute exists → failed"  "failed" "$(tsv_field abs-exists 2)"
}

# ─── Section: check — scoped 4th <files-list> arg (spec 036 Task 2) ──────────

# mk_flist <name> <line…> — write one path per line to $TMP_BASE/<name>; echo it.
mk_flist() {
  local name="$1"; shift
  local path="$TMP_BASE/$name"
  : > "$path"
  local l
  for l in "$@"; do printf '%s\n' "$l" >> "$path"; done
  printf '%s' "$path"
}

# AC: a scoped pattern check searches only the listed files (∩ territory). The
# whole-group run reports no-inline VIOLATED (bad.sh matches); scoping to good.sh
# alone flips it to HOLDS — proof the scope is the listed set, not the territory.
case_jimverify_check_scoped_pattern_listed_only() {
  local root fl; root="$(verify_repo_scoped t36sp)"
  fl="$(mk_flist t36sp.list skills/foo/good.sh)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g "$fl"
  assert_exit "rc" 0 "$RC"
  assert_eq "no-inline holds when only good.sh is listed" "holds" "$(tsv_field no-inline 2)"
  assert_eq "want-clean holds (good.sh carries the marker)" "holds" "$(tsv_field want-clean 2)"
}

# AC: the same pattern scoped to bad.sh reports violated — the listed file drives
# the outcome (the converse of the case above).
case_jimverify_check_scoped_pattern_violated_when_listed() {
  local root fl; root="$(verify_repo_scoped t36spv)"
  fl="$(mk_flist t36spv.list skills/foo/bad.sh)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g "$fl"
  assert_eq "no-inline violated when bad.sh listed" "violated" "$(tsv_field no-inline 2)"
  assert_match "evidence names bad.sh" 'skills/foo/bad\.sh' "$(tsv_field no-inline 3)"
}

# AC: a structure check runs only when its param path is in the listed set;
# otherwise it makes no record (falls to the caller's sweep/judge accounting).
case_jimverify_check_scoped_structure_skipped_when_unlisted() {
  local root fl; root="$(verify_repo_scoped t36ss)"
  fl="$(mk_flist t36ss.list skills/foo/bad.sh)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g "$fl"
  assert_eq "good-exists makes no record (its path unlisted)" "" "$(tsv_field good-exists 2)"
}

# AC: a structure check whose exists path IS listed still runs and holds.
case_jimverify_check_scoped_structure_runs_when_listed() {
  local root fl; root="$(verify_repo_scoped t36sr)"
  fl="$(mk_flist t36sr.list skills/foo/good.sh)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g "$fl"
  assert_eq "good-exists holds when its path is listed" "holds" "$(tsv_field good-exists 2)"
}

# AC: territory conformance runs over the listed files only. Listing an in-territory
# file surfaces NO conformance record even though a tracked outside file exists;
# listing the outside file surfaces it — proof the scan set is the listed set.
case_jimverify_check_scoped_conformance_listed_only() {
  local root fl; root="$(verify_repo_scoped t36cf)"
  fl="$(mk_flist t36cf.list skills/foo/good.sh)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g "$fl"
  assert_eq "loose.txt NOT flagged — it is unlisted" "0" \
    "$(printf '%s\n' "$OUT" | grep -c '^TERRITORY-CONFORMANCE')"
  fl="$(mk_flist t36cf2.list loose.txt skills/foo/good.sh)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g "$fl"
  assert_match "loose.txt flagged when listed" '^TERRITORY-CONFORMANCE	loose\.txt$' "$OUT"
}

# AC: an unsafe list line (absolute / '..' segment) emits HYGIENE and is excluded
# from the scope — never handed to grep/find (security.md Finding 10).
case_jimverify_check_scoped_unsafe_line_hygiene() {
  local root fl; root="$(verify_repo_scoped t36hy)"
  fl="$(mk_flist t36hy.list /etc/passwd skills/../outside skills/foo/good.sh)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g "$fl"
  assert_exit "rc" 0 "$RC"
  assert_match "absolute path → HYGIENE"  '^HYGIENE	/etc/passwd$'     "$OUT"
  assert_match "dotdot path → HYGIENE"    '^HYGIENE	skills/\.\./outside$' "$OUT"
}

# AC: a C-quoted (non-ASCII) or space-bearing list line — the exact untrusted
# shapes files-range emits — is HYGIENE-excluded and never mis-scoped
# (security.md Finding 10). valid-relpath alone accepts spaces, so the scoped
# gate is stricter.
case_jimverify_check_scoped_cquoted_space_hygiene() {
  local root fl; root="$(verify_repo_scoped t36cq)"
  fl="$(mk_flist t36cq.list '"uni-caf\303\251.txt"' 'has space.txt' skills/foo/good.sh)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g "$fl"
  assert_exit "rc" 0 "$RC"
  assert_match "C-quoted path → HYGIENE"    '^HYGIENE	"uni-caf' "$OUT"
  assert_match "space-bearing path → HYGIENE" '^HYGIENE	has space\.txt$' "$OUT"
  assert_eq "good.sh still scoped (structure holds)" "holds" "$(tsv_field good-exists 2)"
}

# AC: an unreadable / absent files-list file exits 2 (contained), so the caller
# degrades rather than silently running whole-group.
case_jimverify_check_scoped_unreadable_list_exits_2() {
  local root; root="$(verify_repo_scoped t36ur)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g "$TMP_BASE/no-such.list"
  assert_exit "rc" 2 "$RC"
}

# AC: with no 4th arg the output is byte-for-byte today's whole-group behavior —
# the scoped path is purely additive (interface contract).
case_jimverify_check_no_filelist_unchanged() {
  local root; root="$(verify_repo_scoped t36bc)"
  run_jimverify_in "$root" check docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_exit "rc" 0 "$RC"
  assert_eq    "no-inline violated (whole-group)" "violated" "$(tsv_field no-inline 2)"
  assert_eq    "good-exists holds (whole-group)"  "holds"    "$(tsv_field good-exists 2)"
  assert_match "loose flagged (whole-group)" '^TERRITORY-CONFORMANCE	loose\.txt$' "$OUT"
  assert_eq "no HYGIENE lines without a list" "0" \
    "$(printf '%s\n' "$OUT" | grep -c '^HYGIENE')"
}

# ─── Section: faces — provides/requires + contract-checks (spec 037 Task 1) ──

# faces_field <key> <n> — echo TAB-field <n> of the first OUT line whose SECOND
#   field (the entry key) equals <key>. faces records repeat field 1 (the kind),
#   so keying on field 2 is how a specific provides/requires entry is asserted.
faces_field() {
  printf '%s\n' "$OUT" | awk -F'\t' -v k="$1" -v n="$2" '$2==k {print $n; exit}'
}

# faces_fields <key> — echo the TAB-field count of the first row keyed by <key>.
faces_fields() {
  printf '%s\n' "$OUT" | awk -F'\t' -v k="$1" '$2==k {print NF; exit}'
}

# bp_faces <name> <body> — write a group blueprint fixture; echo its path.
bp_faces() { fixture "$1" "$2"; }

# AC: faces emits one record per Provides/Requires entry — kind, slugified key,
# target (requires only), declared criticality (provides only, from the
# contract-checks line), joined params, and the verbatim guarantee text
# (spec 037 AC #6, interface contract).
case_jimverify_faces_wellformed() {
  local cfg
  cfg=$(bp_faces bp-well.md '## Provides

- `identity lookup` — read-after-write customer identity resolution
- `session token` — signed token with a 15 minute expiry

## Requires

- `platform.rate limiter` — best-effort request throttling

## Structure

Real files here.

```contract-checks
identity-lookup criticality=high provider-ref=function getIdentity consumer-ref=getIdentity\( scope=accounts/
session-token criticality=medium
```

## Invariants

None.')
  run_jimverify faces "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_eq "identity-lookup kind"        "provides" "$(faces_field identity-lookup 1)"
  assert_eq "identity-lookup criticality" "high"     "$(faces_field identity-lookup 4)"
  assert_match "identity-lookup params carry provider-ref" 'provider-ref=function getIdentity' "$(faces_field identity-lookup 5)"
  assert_match "identity-lookup params carry scope"        'scope=accounts/'                   "$(faces_field identity-lookup 5)"
  assert_match "identity-lookup text"     'read-after-write customer identity resolution' "$(faces_field identity-lookup 6)"
  assert_eq "identity-lookup is 6 fields" "6" "$(faces_fields identity-lookup)"
  assert_eq "session-token criticality"   "medium"   "$(faces_field session-token 4)"
  assert_eq "requires kind"               "requires" "$(faces_field platform-rate-limiter 1)"
  assert_eq "requires target group-attributed" "platform.rate limiter" "$(faces_field platform-rate-limiter 3)"
}

# AC: a blueprint with no contract-checks block verifies unchanged — every
# provides entry emits criticality "-" and params "-", never an error (spec 037
# AC #6, the legacy-no-migration rule).
case_jimverify_faces_legacy_no_block() {
  local cfg
  cfg=$(bp_faces bp-legacy.md '## Provides

- `identity lookup` — resolves a customer id

## Requires

- `platform.rate limiter` — throttling
')
  run_jimverify faces "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_eq "no-block criticality dash" "-" "$(faces_field identity-lookup 4)"
  assert_eq "no-block params dash"      "-" "$(faces_field identity-lookup 5)"
}

# AC: a contract-checks line with an out-of-enum criticality degrades that
# entry's params to malformed:<reason> — never a silent drop, never an error
# (interface contract, the parse malformed-row precedent).
case_jimverify_faces_malformed_criticality() {
  local cfg
  cfg=$(bp_faces bp-badcrit.md '## Provides

- `identity lookup` — resolves a customer id

```contract-checks
identity-lookup criticality=BOGUS provider-ref=x
```
')
  run_jimverify faces "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_match "malformed params" '^malformed:' "$(faces_field identity-lookup 5)"
  assert_eq "criticality falls back to dash" "-" "$(faces_field identity-lookup 4)"
}

# AC: a contract-checks line whose key is not a valid slug matches no provides
# entry and is inert — the raw key is never echoed and the entry falls back to
# "-" (the verify-checks orphan precedent; TSV integrity).
case_jimverify_faces_badkey_inert() {
  local cfg
  cfg=$(bp_faces bp-badkey.md '## Provides

- `identity lookup` — resolves a customer id

```contract-checks
Bad_Key criticality=high provider-ref=x
```
')
  run_jimverify faces "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_eq "raw bad key never echoed" "0" "$(printf '%s\n' "$OUT" | grep -c 'Bad_Key')"
  assert_eq "unmatched entry params dash" "-" "$(faces_field identity-lookup 5)"
}

# AC: a tab embedded in guarantee text is sanitized so it can never shift TSV
# columns or smuggle a spurious record (spec 037 AC #17, the Finding-7 lineage).
case_jimverify_faces_tab_sanitized() {
  local cfg
  cfg=$(bp_faces bp-tab.md "$(printf '## Provides\n\n- `surf` — has\ta tab inside\n')")
  run_jimverify faces "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_eq "surf row stays 6 fields" "6" "$(faces_fields surf)"
}

# AC: faces with a missing file argument exits 2.
case_jimverify_faces_missing_file_exits_2() {
  run_jimverify faces "$TMP_BASE/no-such-blueprint.md"
  assert_exit "rc" 2 "$RC"
}

# ─── Section: edges — Contract Graph parse (spec 037 Task 2) ─────────────────

# AC: edges parses the persisted `## Contract Graph` table into one
# consumer/relies-on/provider record per data row, header and separator rows
# skipped (spec 037 interface contract; the reconcile pass is the graph's sole
# writer, this verb only reads it).
case_jimverify_edges_present() {
  local cfg
  cfg=$(fixture map-graph.md '# Blueprint — acme

## Contract Graph

*Derived from the group blueprints. Last reconciled: 2026-07-04 (via /jim:blueprint)*

| Consumer | Relies on | Provider |
| :--- | :--- | :--- |
| billing | customer identity lookup | accounts |
| orders | cart pricing | catalog |
')
  run_jimverify edges "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_eq "billing→accounts relies-on" "customer identity lookup" "$(tsv_field billing 2)"
  assert_eq "billing→accounts provider"  "accounts"                 "$(tsv_field billing 3)"
  assert_eq "orders→catalog provider"    "catalog"                  "$(tsv_field orders 3)"
  assert_eq "billing row is 3 fields"    "3"                        "$(tsv_fields billing)"
}

# AC: a map with no `## Contract Graph` section exits 2 — the caller names the
# degradation rather than silently reporting an empty graph (DD 8).
case_jimverify_edges_no_section_exits_2() {
  local cfg
  cfg=$(fixture map-nograph.md '# Blueprint — acme

## Context Map

| Group | Role | Purpose | Relations |
| :--- | :--- | :--- | :--- |
| accounts | domain | identity | — |
')
  run_jimverify edges "$cfg"
  assert_exit "rc" 2 "$RC"
}

# AC: a `Nothing to reconcile` graph (fewer than two blueprint-bearing groups)
# has a section but no data rows — the verb emits nothing and exits 0, so the
# caller reports nothing to check without error litter (spec 037 AC #1).
case_jimverify_edges_nothing_to_reconcile() {
  local cfg
  cfg=$(fixture map-nothing.md '# Blueprint — acme

## Contract Graph

*Derived from the group blueprints. Last reconciled: 2026-07-04 (via /jim:blueprint)*

*Nothing to reconcile — fewer than two groups have blueprints.*
')
  run_jimverify edges "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_eq "no edges emitted" "" "$OUT"
}

# AC: a graph row whose consumer or provider cell is not a valid group slug is
# excluded as HYGIENE and never emitted as a plain edge — a crafted map cell
# can never smuggle a path or shift columns (spec 037 AC #17).
case_jimverify_edges_crafted_cell_hygiene() {
  local cfg
  cfg=$(fixture map-crafted.md '# Blueprint — acme

## Contract Graph

| Consumer | Relies on | Provider |
| :--- | :--- | :--- |
| ../evil | x | accounts |
| billing | identity | /etc/passwd |
| orders | pricing | catalog |
')
  run_jimverify edges "$cfg"
  assert_exit "rc" 0 "$RC"
  assert_match "crafted consumer → HYGIENE" '^HYGIENE	' "$OUT"
  assert_eq "crafted consumer never a plain edge" "0" \
    "$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="../evil"' | grep -c .)"
  assert_eq "crafted provider never a plain edge" "0" \
    "$(printf '%s\n' "$OUT" | awk -F'\t' '$3=="/etc/passwd"' | grep -c .)"
  assert_eq "clean row still emitted" "catalog" "$(tsv_field orders 3)"
}

# ─── Section: contracts-check — the composite floor (spec 037 Task 3) ────────

# contracts_repo <name> — build a two-group project (accounts provider, billing
#   consumer) with territories, blueprints (accounts declares a provider-ref /
#   consumer-ref contract-check), a live graph edge, and code on both sides.
#   No git needed — contracts-check greps directories and reads files. Echo root.
contracts_repo() {
  local name="$1"; local root="$TMP_BASE/$name"
  mkdir -p "$root/accounts" "$root/billing" \
           "$root/docs/specs/accounts/000-blueprint" \
           "$root/docs/specs/billing/000-blueprint"
  printf 'function getIdentity() { return id; }\n' > "$root/accounts/session.js"
  printf 'const s = require("accounts/session");\nfunction pay() { return getIdentity(); }\n' > "$root/billing/invoice.js"
  cat > "$root/docs/specs/accounts/000-blueprint/spec.md" <<'EOF'
## Provides

- `identity lookup` — read-after-write identity resolution

```contract-checks
identity-lookup criticality=high provider-ref=getIdentity consumer-ref=getIdentity
```
EOF
  cat > "$root/docs/specs/billing/000-blueprint/spec.md" <<'EOF'
## Provides

- `invoice total` — computed total

## Requires

- `accounts.identity lookup` — resolves the customer
EOF
  cat > "$root/BLUEPRINT.md" <<'EOF'
# Blueprint — shop

## Groups

### accounts

- **Territory:** `accounts/`
- **Blueprint:** docs/specs/accounts/000-blueprint/

### billing

- **Territory:** `billing/`
- **Blueprint:** docs/specs/billing/000-blueprint/

## Contract Graph

| Consumer | Relies on | Provider |
| :--- | :--- | :--- |
| billing | customer identity lookup | accounts |
EOF
  printf '%s' "$root"
}

# AC: the floor emits a COVERAGE fact and a CROSS-REF reference fact for a
# consumer reaching into provider territory — evidence is location-only, the
# matched code line is never emitted (spec 037 AC #5/#13/#17; the Finding-2
# exfiltration guard).
case_jimverify_contracts_coverage_crossref_locationonly() {
  local root; root="$(contracts_repo cc1)"
  run_jimverify_in "$root" contracts-check BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_match "coverage 2 mapped 2 with blueprints" '^COVERAGE	2	2$' "$OUT"
  assert_match "cross-ref billing→accounts with file:line" \
    '^CROSS-REF	billing	billing/invoice\.js:1	accounts$' "$OUT"
  assert_eq "matched code content never emitted" "0" \
    "$(printf '%s\n' "$OUT" | grep -c 'require')"
}

# AC: when a consumer's references into one provider territory exceed the
# per-path 50-line cap, the floor still emits at most 50 CROSS-REF facts AND
# names the truncation with a CROSS-REF-CAPPED marker carrying the shown count —
# never a silent drop (issue #56; the "name every degradation" doctrine).
case_jimverify_contracts_crossref_cap_named() {
  local root; root="$(contracts_repo cccap)"
  # 60 consumer lines reaching into accounts/ territory — over the 50-line cap.
  printf 'x = require("accounts/m%s");\n' {1..60} > "$root/billing/bulk.js"
  run_jimverify_in "$root" contracts-check BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "at most 50 cross-ref facts shown for the capped pair" "50" \
    "$(printf '%s\n' "$OUT" | grep -c '^CROSS-REF	billing	')"
  assert_match "capped pair named with shown count" \
    '^CROSS-REF-CAPPED	billing	accounts	50$' "$OUT"
}

# AC: a provider-ref pattern check holds when the declared surface is present in
# provider territory — the provider still honors the guarantee (spec 037 AC #2).
case_jimverify_contracts_provider_holds() {
  local root; root="$(contracts_repo cc2)"
  run_jimverify_in "$root" contracts-check BLUEPRINT.md
  assert_eq "provider side holds" "holds" \
    "$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="billing>accounts#identity-lookup" && $2=="provider" {print $3; exit}')"
}

# AC: a provider-ref check reports violated when the declared surface is gone
# from provider code — a code-level breaking, grounded in evidence (spec 037
# AC #3).
case_jimverify_contracts_provider_violated() {
  local root; root="$(contracts_repo cc3)"
  printf 'function resolveCustomer() { return id; }\n' > "$root/accounts/session.js"
  run_jimverify_in "$root" contracts-check BLUEPRINT.md
  assert_eq "provider side violated when surface gone" "violated" \
    "$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="billing>accounts#identity-lookup" && $2=="provider" {print $3; exit}')"
}

# AC: a consumer-ref pattern check holds when the consumer's declared usage is
# present in consumer territory — the usage is within the declared surface
# (spec 037 AC #2).
case_jimverify_contracts_consumer_holds() {
  local root; root="$(contracts_repo cc4)"
  run_jimverify_in "$root" contracts-check BLUEPRINT.md
  assert_eq "consumer side holds" "holds" \
    "$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="billing>accounts#identity-lookup" && $2=="consumer" {print $3; exit}')"
}

# AC: a mapped group with no declared territory surfaces as UNSCOPED-GROUP — the
# degradation is named, never silently absorbed (spec 037 AC #5/#13).
case_jimverify_contracts_unscoped_group() {
  local root; root="$(contracts_repo cc5)"
  # Rewrite the map with a third group (platform) that declares no Territory,
  # placed inside the ## Groups section (before ## Contract Graph).
  cat > "$root/BLUEPRINT.md" <<'EOF'
# Blueprint — shop

## Groups

### accounts

- **Territory:** `accounts/`

### billing

- **Territory:** `billing/`

### platform

- **Purpose:** shared infra

## Contract Graph

| Consumer | Relies on | Provider |
| :--- | :--- | :--- |
| billing | customer identity lookup | accounts |
EOF
  run_jimverify_in "$root" contracts-check BLUEPRINT.md
  assert_match "platform → UNSCOPED-GROUP" '^UNSCOPED-GROUP	platform$' "$OUT"
}

# AC: an unsafe scope in the provider's contract-check degrades the provider
# side to failed — the path never reaches grep (spec 037 AC #17; the Finding-2
# param gate, the safe_path_param twin of the check verb).
case_jimverify_contracts_unsafe_scope_failed() {
  local root; root="$(contracts_repo cc6)"
  cat > "$root/docs/specs/accounts/000-blueprint/spec.md" <<'EOF'
## Provides

- `identity lookup` — read-after-write identity resolution

```contract-checks
identity-lookup criticality=high provider-ref=getIdentity scope=/etc
```
EOF
  run_jimverify_in "$root" contracts-check BLUEPRINT.md
  assert_eq "unsafe scope → provider failed" "failed" \
    "$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="billing>accounts#identity-lookup" && $2=="provider" {print $3; exit}')"
}

# AC: an unsafe files-list line (absolute / C-quoted / tab-bearing) is excluded
# as HYGIENE and never handed to grep; a safe listed file is still scanned
# (spec 037 AC #17; the security.md Finding-10 lineage, carried to the floor).
case_jimverify_contracts_filelist_hygiene() {
  local root fl; root="$(contracts_repo cc7)"
  fl="$(mk_flist cc7.list /etc/passwd '"uni-caf\303\251.js"' billing/invoice.js)"
  run_jimverify_in "$root" contracts-check BLUEPRINT.md "$fl"
  assert_exit "rc" 0 "$RC"
  assert_match "absolute path → HYGIENE" '^HYGIENE	/etc/passwd$' "$OUT"
  assert_match "C-quoted path → HYGIENE" '^HYGIENE	"uni-caf' "$OUT"
  assert_match "listed billing file still cross-ref scanned" \
    '^CROSS-REF	billing	billing/invoice\.js:1	accounts$' "$OUT"
}

# AC: a files-list scopes the cross-reference scan to the listed files — scoping
# to a provider-only file surfaces no cross-ref; scoping to the consumer file
# surfaces it (spec 037 AC #10 sensor-scope; the 036 amplification lesson).
case_jimverify_contracts_scoped_crossref() {
  local root fl; root="$(contracts_repo cc8)"
  fl="$(mk_flist cc8a.list accounts/session.js)"
  run_jimverify_in "$root" contracts-check BLUEPRINT.md "$fl"
  assert_eq "no cross-ref when only provider file is listed" "0" \
    "$(printf '%s\n' "$OUT" | grep -c '^CROSS-REF')"
  fl="$(mk_flist cc8b.list billing/invoice.js)"
  run_jimverify_in "$root" contracts-check BLUEPRINT.md "$fl"
  assert_match "cross-ref when consumer file is listed" '^CROSS-REF	billing	' "$OUT"
}

# AC: contracts-check with missing arguments exits 2.
case_jimverify_contracts_missing_args_exits_2() {
  run_jimverify contracts-check
  assert_exit "rc" 2 "$RC"
  assert_match "need message" 'need <map-path>' "$ERR"
}

# ─── Section: health — graph metrics (spec 039 Task 1) ───────────────────────

# hmap <name> <groups> <rows> — build a project map with a `## Groups` section
#   (one `### <g>` per whitespace token in <groups>) and a `## Contract Graph`
#   whose table body is <rows> (literal `| … |` lines). Echo the map path.
hmap() {
  local name="$1" groups="$2" rows="$3" g body=""
  for g in $groups; do body="$body### $g
"; done
  fixture "$name" "# Blueprint — acme

## Groups

$body
## Contract Graph

| Consumer | Relies on | Provider |
| :--- | :--- | :--- |
$rows"
}

# hcycle <group> — echo the cluster index of <group>'s CYCLE line (empty if the
#   group is on no cycle).
hcycle() {
  printf '%s\n' "$OUT" | awk -F'\t' -v g="$1" '$1=="CYCLE" && $3==g {print $2; exit}'
}

# AC: health emits GROUPS/EDGES/FANIN and CYCLES 0 over an acyclic graph
# (spec 039 AC #1, interface contract; Kahn peel leaves no cyclic core).
case_jimverify_health_acyclic() {
  local m
  m=$(hmap m-acyclic.md "accounts billing catalog orders" '| billing | x | accounts |
| orders | y | catalog |')
  run_jimverify health "$m"
  assert_exit "rc" 0 "$RC"
  assert_eq "groups" "4" "$(tsv_field GROUPS 2)"
  assert_eq "edges"  "2" "$(tsv_field EDGES 2)"
  assert_eq "cycles" "0" "$(tsv_field CYCLES 2)"
  assert_eq "fanin"  "1" "$(tsv_field FANIN 2)"
  assert_eq "no CYCLE lines" "" "$(printf '%s\n' "$OUT" | grep '^CYCLE	' || true)"
}

# AC: a mutual pair (billing ⇄ orders) is one cycle cluster; both groups are
# named under the same cluster index (spec 039 AC #1; DD 2 mockup semantics).
case_jimverify_health_mutual_pair() {
  local m
  m=$(hmap m-mutual.md "billing orders" '| billing | x | orders |
| orders | y | billing |')
  run_jimverify health "$m"
  assert_exit "rc" 0 "$RC"
  assert_eq "cycles" "1" "$(tsv_field CYCLES 2)"
  assert_nonempty "billing on a cycle" "$(hcycle billing)"
  assert_eq "billing and orders share a cluster" "$(hcycle billing)" "$(hcycle orders)"
}

# AC: two disjoint mutual pairs are two clusters, each self-contained (DD 2 WCC).
case_jimverify_health_two_disjoint_cycles() {
  local m
  m=$(hmap m-disjoint.md "billing orders catalog shipping" '| billing | x | orders |
| orders | y | billing |
| catalog | z | shipping |
| shipping | w | catalog |')
  run_jimverify health "$m"
  assert_exit "rc" 0 "$RC"
  assert_eq "cycles" "2" "$(tsv_field CYCLES 2)"
  assert_eq "billing/orders together" "$(hcycle billing)" "$(hcycle orders)"
  assert_eq "catalog/shipping together" "$(hcycle catalog)" "$(hcycle shipping)"
  local a b; a="$(hcycle billing)"; b="$(hcycle catalog)"
  assert_eq "the two clusters differ" "1" "$([ "$a" != "$b" ] && echo 1 || echo 0)"
}

# AC: two cycles sharing a node collapse into one cluster (DD 2 WCC over the
# cyclic core — a shared-node tangle reads as one degradation unit).
case_jimverify_health_shared_node_tangle() {
  local m
  m=$(hmap m-tangle.md "billing orders catalog" '| billing | x | orders |
| orders | y | billing |
| orders | z | catalog |
| catalog | w | orders |')
  run_jimverify health "$m"
  assert_exit "rc" 0 "$RC"
  assert_eq "cycles" "1" "$(tsv_field CYCLES 2)"
  assert_eq "orders is the max fan-in" "2" "$(tsv_field FANIN 2)"
  assert_match "orders named at max fan-in" '^FANIN_GROUP	orders$' "$OUT"
}

# AC: on a fan-in tie every group at the max is named, sorted (interface
# contract: ties → all, sorted).
case_jimverify_health_fanin_ties_sorted() {
  local m
  m=$(hmap m-fanin.md "acct cat alpha bravo charlie delta" '| alpha | x | acct |
| bravo | y | acct |
| charlie | z | cat |
| delta | w | cat |')
  run_jimverify health "$m"
  assert_exit "rc" 0 "$RC"
  assert_eq "fanin" "2" "$(tsv_field FANIN 2)"
  assert_eq "both maxed groups, sorted" "acct
cat" "$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="FANIN_GROUP"{print $2}')"
}

# AC: a present-but-empty graph (nothing-to-reconcile note, no rows) yields
# zero-valued metrics without error — EDGES/CYCLES/FANIN all 0 (spec 039 AC #1).
case_jimverify_health_empty_graph() {
  local m
  m=$(fixture m-empty.md '# Blueprint — acme

## Groups

### accounts

## Contract Graph

*Nothing to reconcile — fewer than two groups have blueprints.*
')
  run_jimverify health "$m"
  assert_exit "rc" 0 "$RC"
  assert_eq "edges"  "0" "$(tsv_field EDGES 2)"
  assert_eq "cycles" "0" "$(tsv_field CYCLES 2)"
  assert_eq "fanin"  "0" "$(tsv_field FANIN 2)"
}

# AC: a map with no `## Contract Graph` section exits 2 — the caller names the
# degradation (mirrors the edges verb; interface contract rc 2).
case_jimverify_health_no_section_exits_2() {
  local m
  m=$(fixture m-nograph.md '# Blueprint — acme

## Groups

### accounts
')
  run_jimverify health "$m"
  assert_exit "rc" 2 "$RC"
}

# AC: a crafted (non-slug) consumer/provider cell is HYGIENE-excluded upstream,
# so it never counts as an edge or appears as a group in the metrics (spec 039
# AC #5, the edges-verb slug gate carried into health).
case_jimverify_health_crafted_cell_excluded() {
  local m
  m=$(hmap m-crafted.md "billing accounts orders catalog" '| ../evil | x | accounts |
| billing | y | accounts |
| orders | z | catalog |')
  run_jimverify health "$m"
  assert_exit "rc" 0 "$RC"
  assert_eq "edges count valid rows only" "2" "$(tsv_field EDGES 2)"
  assert_eq "crafted cell never a group" "" "$(printf '%s\n' "$OUT" | grep '\.\./evil' || true)"
}

# AC: measurements are deterministic AND canonically ordered (spec 039 AC #9).
# The run-twice check alone is weak: a dropped isort() stays byte-identical
# run-to-run (awk hash iteration is stable within a build) while silently
# reordering lines into hash order. Assert the CYCLE nodes come out sorted so an
# isort(AN) regression is caught — FANIN_GROUP ordering is separately guarded by
# case_jimverify_health_fanin_ties_sorted.
case_jimverify_health_deterministic() {
  local m first
  m=$(hmap m-determ.md "billing orders catalog" '| billing | x | orders |
| orders | y | billing |
| orders | z | catalog |
| catalog | w | orders |')
  run_jimverify health "$m"; first="$OUT"
  run_jimverify health "$m"
  assert_eq "identical across runs" "$first" "$OUT"
  assert_eq "CYCLE nodes emitted in sorted order" "billing
catalog
orders" "$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="CYCLE"{print $3}')"
}

# AC: a duplicated (consumer, provider) row counts once per raw row in EDGES (the
# density numerator) but is deduped out of the graph structure — fan-in and cycles
# read the deduped edge set (the `eseen` guard), so the duplicate never inflates a
# provider's in-degree. Without dedup, b's fan-in would be 2 and it would stand
# alone at the max; with dedup it ties c at 1.
case_jimverify_health_duplicate_row() {
  local m
  m=$(hmap m-duprow.md "a b c" '| a | x | b |
| a | y | b |
| b | z | c |')
  run_jimverify health "$m"
  assert_exit "rc" 0 "$RC"
  assert_eq "EDGES counts raw rows incl the duplicate" "3" "$(tsv_field EDGES 2)"
  assert_eq "fan-in dedupes the duplicate row" "1" "$(tsv_field FANIN 2)"
  assert_eq "both providers tied at deduped fan-in" "b
c" "$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="FANIN_GROUP"{print $2}')"
  assert_eq "no cycle from the duplicate row" "0" "$(tsv_field CYCLES 2)"
}

# ─── Section: health — territory coverage (spec 039 Task 2) ──────────────────

# health_git <name> — build a git repo whose only tracked files are
#   accounts/session.js and billing/invoice.js. Echo the repo root. The map is
#   read from disk (never git), so leaving BLUEPRINT.md untracked keeps the
#   coverage set to exactly the code files a test declares.
health_git() {
  local name="$1"
  local root="$TMP_BASE/$name"
  mkdir -p "$root/accounts" "$root/billing"
  git -C "$root" init -q
  git -C "$root" config user.email "test@example.com"
  git -C "$root" config user.name "Test"
  git -C "$root" config commit.gpgsign false
  printf 'code\n' > "$root/accounts/session.js"
  printf 'code\n' > "$root/billing/invoice.js"
  git -C "$root" add accounts billing
  git -C "$root" commit -q -m "seed"
  printf '%s' "$root"
}

# hmap_territory <root> — write an untracked BLUEPRINT.md declaring accounts/
#   and billing/ territories plus a one-edge Contract Graph.
hmap_territory() {
  cat > "$1/BLUEPRINT.md" <<'EOF'
# Blueprint — shop

## Groups

### accounts

- **Territory:** `accounts/`

### billing

- **Territory:** `billing/`

## Contract Graph

| Consumer | Relies on | Provider |
| :--- | :--- | :--- |
| billing | identity | accounts |
EOF
}

# AC: coverage is 0 when every tracked file falls under a declared territory —
# the conformance set-difference, unioned across groups, is empty (spec 039 AC #6).
case_jimverify_health_coverage_zero() {
  local root; root="$(health_git t2cz)"; hmap_territory "$root"
  run_jimverify_in "$root" health BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "no uncovered paths" "0" "$(tsv_field UNCOVERED 2)"
}

# AC: a tracked file under no territory is uncovered — the event carries the
# exact count and the report gets a row aggregated by its containing directory
# (spec 039 AC #6, DD 5).
case_jimverify_health_coverage_stray() {
  local root; root="$(health_git t2cs)"; hmap_territory "$root"
  mkdir -p "$root/src/metrics"
  printf 'm\n' > "$root/src/metrics/foo.js"
  git -C "$root" add src && git -C "$root" commit -q -m "stray"
  run_jimverify_in "$root" health BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "one uncovered path" "1" "$(tsv_field UNCOVERED 2)"
  assert_match "dir row by containing dir" '^UNCOVERED_DIR	src/metrics/	1$' "$OUT"
}

# AC: a map with no path-bearing territory reports coverage as not computable —
# na with an explicit reason, never "0 uncovered" (spec 039 AC #7, DD 5).
case_jimverify_health_coverage_no_territories() {
  local root; root="$(health_git t2nt)"
  cat > "$root/BLUEPRINT.md" <<'EOF'
# Blueprint — shop

## Groups

### accounts

### billing

## Contract Graph

| Consumer | Relies on | Provider |
| :--- | :--- | :--- |
| billing | identity | accounts |
EOF
  run_jimverify_in "$root" health BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "coverage na" "na" "$(tsv_field UNCOVERED 2)"
  assert_match "reason no-territories" '^UNCOVERED_NA_REASON	no-territories$' "$OUT"
}

# AC: outside a git repo, coverage is na with reason no-git — a broken
# environment never silently reads as none-mode (security Finding 5, the 035
# vocabulary doctrine keeping not-applicable distinct from measurement failure).
case_jimverify_health_coverage_no_git() {
  local dir; dir="$(empty_dir t2ng)"
  hmap_territory "$dir"
  run_jimverify_in "$dir" health BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "coverage na" "na" "$(tsv_field UNCOVERED 2)"
  assert_match "reason no-git" '^UNCOVERED_NA_REASON	no-git$' "$OUT"
}

# AC: the territory prefix match is slash-anchored — a file under accountsfoo/ is
# NOT covered by the accounts/ territory. Guards the trailing-slash prefix
# (`index(f "/", t "/") == 1`): a bare-prefix match would wrongly absorb an
# adjacent sibling directory.
case_jimverify_health_coverage_adjacent_prefix() {
  local root; root="$(health_git t2ap)"; hmap_territory "$root"
  mkdir -p "$root/accountsfoo"
  printf 'x\n' > "$root/accountsfoo/x.js"
  git -C "$root" add accountsfoo && git -C "$root" commit -q -m "adjacent"
  run_jimverify_in "$root" health BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "adjacent-prefix file stays uncovered" "1" "$(tsv_field UNCOVERED 2)"
  assert_match "dir row for the sibling dir" '^UNCOVERED_DIR	accountsfoo/	1$' "$OUT"
}

# AC: an uncovered directory path longer than the 512-char cap is length-capped in
# the UNCOVERED_DIR field (the coverage awk's san()), bounding alarm-fatigue output
# from a pathological tree. Only the length cap is reachable via a real tracked
# path: git ls-files C-escapes control bytes, so the same san()'s control-strip is
# belt-only and cannot be exercised through the real coverage input.
case_jimverify_health_coverage_dir_capped() {
  local root; root="$(health_git t2cap)"; hmap_territory "$root"
  local seg; seg=$(printf 'a%.0s' {1..200})     # 200 < NAME_MAX; three nest > 512
  local deep="$seg/$seg/$seg"
  mkdir -p "$root/$deep"
  printf 'x\n' > "$root/$deep/f.js"
  git -C "$root" add "$deep" && git -C "$root" commit -q -m "deep"
  run_jimverify_in "$root" health BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "the deep path is uncovered" "1" "$(tsv_field UNCOVERED 2)"
  local dir; dir="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="UNCOVERED_DIR"{print $2; exit}')"
  assert_eq "UNCOVERED_DIR capped at 512 chars" "512" "${#dir}"
}

# ─── Section: scope-census — retirement staleness facts (spec 041 Task 1) ────

# census_repo <name> — a throwaway git repo whose blueprint exercises every
#   scope-census kind: a populated scoped pattern, an empty scoped pattern, a
#   territory-default pattern, present/absent `exists=` structure checks, an
#   `absent=` glob, a prose (judge) invariant, and a git-pathspec-magic scope.
#   Territory is `skills/` and holds two tracked files.
census_repo() {
  local name="$1"; local root="$TMP_BASE/$name"
  mkdir -p "$root/skills/foo" "$root/docs/specs/g/000-blueprint"
  git -C "$root" init -q
  git -C "$root" config user.email "t@e.com"; git -C "$root" config user.name "T"
  git -C "$root" config commit.gpgsign false
  printf 'code\n' > "$root/skills/foo/good.sh"
  printf 'more\n' > "$root/skills/foo/bar.sh"
  cat > "$root/docs/specs/g/000-blueprint/spec.md" <<'EOF'
## Invariants

| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| pat-pop | populated scoped pattern | high | pattern |
| pat-empty | empty scoped pattern | high | pattern |
| pat-terr | territory-default pattern | medium | pattern |
| ex-present | present file | low | structure |
| ex-absent | absent file | low | structure |
| abs-check | forbidden glob | low | structure |
| prose-inv | prose only | medium | judge |
| pat-magic | pathspec magic scope | low | pattern |

```verify-checks
pat-pop polarity=must-not regex=NOPE scope=skills/
pat-empty polarity=must-not regex=NOPE scope=skills/gone/
pat-terr polarity=must regex=code
ex-present exists=skills/foo/good.sh
ex-absent exists=skills/foo/missing.sh
abs-check absent=skills/*.tmp
pat-magic polarity=must-not regex=NOPE scope=:(exclude)*
```
EOF
  cat > "$root/BLUEPRINT.md" <<'EOF'
## Groups

### g

- **Territory:** `skills/`
EOF
  git -C "$root" add -A
  git -C "$root" commit -q -m seed
  printf '%s' "$root"
}

# scope_field <id> <n> — TAB-field <n> of the first SCOPE record keyed by <id>
#   (SCOPE records lead with the literal tag, so the id is field 2).
scope_field() {
  printf '%s\n' "$OUT" | awk -F'\t' -v id="$1" -v n="$2" '$1=="SCOPE" && $2==id {print $n; exit}'
}

# AC (spec 041 Task 1): a pattern scoped to a populated directory reports its
# tracked-file count (≥1), kind `pattern`, and the scope as location-only desc.
case_jimverify_scope_census_populated() {
  local root; root="$(census_repo scpop)"
  run_jimverify_in "$root" scope-census docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_exit "rc" 0 "$RC"
  assert_match "pat-pop counted ≥1" '^[1-9][0-9]*$' "$(scope_field pat-pop 3)"
  assert_eq "pat-pop kind" "pattern" "$(scope_field pat-pop 4)"
  assert_eq "pat-pop desc" "skills/" "$(scope_field pat-pop 5)"
}

# AC: a pattern scoped to an empty/absent directory reports count 0 — the
# zombie signal the `check` grammar cannot express (a must-not over an empty
# scope reads `holds`).
case_jimverify_scope_census_empty_scope() {
  local root; root="$(census_repo scempty)"
  run_jimverify_in "$root" scope-census docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_eq "pat-empty count 0" "0" "$(scope_field pat-empty 3)"
  assert_eq "pat-empty kind" "pattern" "$(scope_field pat-empty 4)"
}

# AC: a scope-less pattern defaults to the group's territory; the desc reads
# `territory` and the count reflects the populated territory.
case_jimverify_scope_census_territory_default() {
  local root; root="$(census_repo scterr)"
  run_jimverify_in "$root" scope-census docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_eq "pat-terr desc" "territory" "$(scope_field pat-terr 5)"
  assert_match "pat-terr counted ≥1" '^[1-9][0-9]*$' "$(scope_field pat-terr 3)"
}

# AC: `exists=` structure checks report kind `exists`; a present path counts 1,
# an absent path counts 0 (the required artifact vanished — a stale candidate).
case_jimverify_scope_census_exists() {
  local root; root="$(census_repo scex)"
  run_jimverify_in "$root" scope-census docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_eq "ex-present count 1" "1" "$(scope_field ex-present 3)"
  assert_eq "ex-present kind" "exists" "$(scope_field ex-present 4)"
  assert_eq "ex-absent count 0" "0" "$(scope_field ex-absent 3)"
  assert_eq "ex-absent kind" "exists" "$(scope_field ex-absent 4)"
}

# AC (DD 3): an `absent=` check is tagged kind `absent` so the skill excludes it
# from the emptiness hint (zero matches is the healthy state, not obsolescence).
case_jimverify_scope_census_absent_kind() {
  local root; root="$(census_repo scabs)"
  run_jimverify_in "$root" scope-census docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_eq "abs-check kind" "absent" "$(scope_field abs-check 4)"
}

# AC: judge / registry / malformed invariants have no mechanical scope — they
# emit NO SCOPE record (the skill accounts for them from `parse`).
case_jimverify_scope_census_judge_no_record() {
  local root; root="$(census_repo scjudge)"
  run_jimverify_in "$root" scope-census docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_eq "prose-inv emits no SCOPE record" "" "$(scope_field prose-inv 3)"
}

# AC (security Finding 4): a git-pathspec-magic scope is never handed to git as
# a pathspec — it either fails the safe_path_param gate (HYGIENE) or is counted
# literally (0), never interpreted as `:(exclude)` / `:/`.
case_jimverify_scope_census_pathspec_magic_not_interpreted() {
  local root; root="$(census_repo scmagic)"
  run_jimverify_in "$root" scope-census docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_exit "rc" 0 "$RC"
  assert_match "pat-magic gated or literal-0, never git-interpreted" \
    '(^SCOPE	pat-magic	0	)|(^HYGIENE	:\(exclude\))' "$OUT"
}

# AC (AC #6): a non-git tree yields `na`, not `0` — unavailable is not
# evidence of absence.
case_jimverify_scope_census_non_git_na() {
  local root="$TMP_BASE/scnogit"
  mkdir -p "$root/skills/foo" "$root/docs/specs/g/000-blueprint"
  printf 'code\n' > "$root/skills/foo/good.sh"
  cat > "$root/docs/specs/g/000-blueprint/spec.md" <<'EOF'
## Invariants

| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| pat-pop | scoped pattern | high | pattern |

```verify-checks
pat-pop polarity=must-not regex=NOPE scope=skills/
```
EOF
  cat > "$root/BLUEPRINT.md" <<'EOF'
## Groups

### g

- **Territory:** `skills/`
EOF
  run_jimverify_in "$root" scope-census docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_exit "rc" 0 "$RC"
  assert_eq "pat-pop na on non-git tree" "na" "$(scope_field pat-pop 3)"
}

# AC: with no declared territory, scope-census emits the UNSCOPED sentinel so
# the skill names the degradation (mirrors the check verb).
case_jimverify_scope_census_unscoped_sentinel() {
  local root="$TMP_BASE/scunsc"
  mkdir -p "$root/skills" "$root/docs/specs/g/000-blueprint"
  git -C "$root" init -q
  git -C "$root" config user.email "t@e.com"; git -C "$root" config user.name "T"
  git -C "$root" config commit.gpgsign false
  printf 'code\n' > "$root/skills/a.sh"
  cat > "$root/docs/specs/g/000-blueprint/spec.md" <<'EOF'
## Invariants

| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| pat-terr | territory-default pattern | medium | pattern |

```verify-checks
pat-terr polarity=must regex=code
```
EOF
  cat > "$root/BLUEPRINT.md" <<'EOF'
## Groups

### g

- **Territory:** —
EOF
  git -C "$root" add -A; git -C "$root" commit -q -m seed
  run_jimverify_in "$root" scope-census docs/specs/g/000-blueprint BLUEPRINT.md g
  assert_exit "rc" 0 "$RC"
  assert_match "unscoped sentinel" '^UNSCOPED$' "$OUT"
}

# AC: missing args exit 2 with a usage message on stderr (mirrors check).
case_jimverify_scope_census_no_args_rc2() {
  run_jimverify scope-census
  assert_exit "rc" 2 "$RC"
  assert_match "need message" 'need <blueprint-dir>' "$ERR"
}

# ─── Section: faces-aggregate — deterministic reconcile counters (spec 045) ──

# fa_repo <name> <graph> <group:count>... — build a project for faces-aggregate:
#   a BLUEPRINT.md with a `## Groups` section (one `### <g>` per pair) and, when
#   <graph> is non-empty, a `## Contract Graph` whose body is the literal <graph>
#   rows; plus each group's docs/specs/<g>/000-blueprint/spec.md carrying <count>
#   Provides entries. No git needed — faces-aggregate reads files as data. Echo root.
fa_repo() {
  local name="$1" graph="$2"; shift 2
  local root="$TMP_BASE/$name" pair grp cnt i pv groups_body=""
  mkdir -p "$root"
  for pair in "$@"; do
    grp="${pair%%:*}"; cnt="${pair##*:}"
    groups_body="$groups_body### $grp
"
    mkdir -p "$root/docs/specs/$grp/000-blueprint"
    pv="## Provides
"
    for ((i = 1; i <= cnt; i++)); do pv="$pv
- \`$grp surface $i\`"; done
    printf '%s\n' "$pv" > "$root/docs/specs/$grp/000-blueprint/spec.md"
  done
  {
    printf '# Blueprint — fa\n\n## Groups\n\n%s\n' "$groups_body"
    [[ -n "$graph" ]] && printf '## Contract Graph\n\n| Consumer | Relies on | Provider |\n| :--- | :--- | :--- |\n%s\n' "$graph"
  } > "$root/BLUEPRINT.md"
  printf '%s' "$root"
}

# AC: faces-aggregate emits FACES_TOTAL (Σ provides over blueprint-bearing
# groups), FACES_MAX (per-group max), and FACES_MAX_GROUP (the max holder) — the
# three face measurements in one deterministic call (spec 045 AC #1).
case_jimverify_faces_aggregate_total_max_holder() {
  local root; root="$(fa_repo faTMH "" accounts:3 billing:1)"
  run_jimverify_in "$root" faces-aggregate BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "total sums provides across groups" "4" "$(tsv_field FACES_TOTAL 2)"
  assert_eq "max is the per-group maximum"       "3" "$(tsv_field FACES_MAX 2)"
  assert_eq "max holder named"           "accounts" "$(tsv_field FACES_MAX_GROUP 2)"
}

# AC: on a tie every group at the max is named, sorted ascending and comma-joined
# — ties → all holders (spec 045 AC #1/#4).
case_jimverify_faces_aggregate_max_ties_sorted() {
  local root; root="$(fa_repo faTie "" zebra:2 alpha:2 mid:1)"
  run_jimverify_in "$root" faces-aggregate BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "max" "2" "$(tsv_field FACES_MAX 2)"
  assert_eq "both max holders, sorted comma-joined" "alpha,zebra" "$(tsv_field FACES_MAX_GROUP 2)"
}

# AC: the all-zero case — every group's provides face is empty — yields FACES_MAX
# 0 and NO FACES_MAX_GROUP attribution key (the emit-only-when->0 rule, AC #6).
case_jimverify_faces_aggregate_all_zero_no_attribution() {
  local root; root="$(fa_repo faZero "" alpha:0 bravo:0)"
  run_jimverify_in "$root" faces-aggregate BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "total 0" "0" "$(tsv_field FACES_TOTAL 2)"
  assert_eq "max 0"   "0" "$(tsv_field FACES_MAX 2)"
  assert_eq "no FACES_MAX_GROUP emitted" "" "$(printf '%s\n' "$OUT" | grep '^FACES_MAX_GROUP	' || true)"
}

# AC: the holder attribution is byte-capped at 256 with every element a whole
# valid group slug — the value the ledger consumer's valid_sluglist accepts
# (spec 045 AC #4; jimledger RECONCILE_SLUG_KEYS parity).
case_jimverify_faces_aggregate_holder_cap_256() {
  local pairs=() i
  for ((i = 1; i <= 40; i++)); do pairs+=("$(printf 'grp-%04d:1' "$i")"); done
  local root; root="$(fa_repo faCap "" "${pairs[@]}")"
  run_jimverify_in "$root" faces-aggregate BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  local v; v="$(tsv_field FACES_MAX_GROUP 2)"
  assert_nonempty "holder value present" "$v"
  assert_eq "holder value <= 256 bytes" "1" "$([ "${#v}" -le 256 ] && echo 1 || echo 0)"
  assert_match "holder value is a valid slug-list" '^[a-z0-9][a-z0-9-]*(,[a-z0-9][a-z0-9-]*)*$' "$v"
}

# AC: a crafted / `..`-bearing `## Groups` heading is slug-guarded BEFORE path
# construction — the token is skipped and its (decoy) blueprint is never read, so
# it contributes nothing to the counters (spec 045 AC #2; security.md Finding 1).
case_jimverify_faces_aggregate_crafted_heading_no_file_access() {
  local root; root="$(fa_repo faEvil "" accounts:2)"
  # A decoy blueprint the crafted `### ../evil` heading would resolve to iff the
  # guard were absent (docs/specs/../evil → docs/evil), with a high provides count.
  mkdir -p "$root/docs/evil/000-blueprint"
  printf '## Provides\n\n- `a`\n- `b`\n- `c`\n- `d`\n- `e`\n' \
    > "$root/docs/evil/000-blueprint/spec.md"
  cat > "$root/BLUEPRINT.md" <<'EOF'
# Blueprint — fa

## Groups

### accounts

### ../evil
EOF
  run_jimverify_in "$root" faces-aggregate BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "only the valid group counted (decoy never read)" "2" "$(tsv_field FACES_TOTAL 2)"
  assert_eq "max unaffected by the decoy's 5 provides"        "2" "$(tsv_field FACES_MAX 2)"
  assert_eq "crafted token never a holder" "accounts" "$(tsv_field FACES_MAX_GROUP 2)"
  assert_eq "no traversal token in output" "" "$(printf '%s\n' "$OUT" | grep -F '..' || true)"
}

# AC: missing args exit 2 with a usage message on stderr (mirrors sibling verbs).
case_jimverify_faces_aggregate_no_args_rc2() {
  run_jimverify faces-aggregate
  assert_exit "rc" 2 "$RC"
  assert_match "need message" 'need <map-path>' "$ERR"
}

# AC: faces-aggregate co-emits FANIN_GROUP — the graph fan-in max holder, sourced
# read-only from cmd_health, ready to copy verbatim onto the event (spec 045 AC #3).
case_jimverify_faces_aggregate_fanin_single() {
  local root; root="$(fa_repo faFan '| alpha | x | acct |
| bravo | y | acct |
| gamma | z | cat |' acct:1 cat:1 alpha:1 bravo:1 gamma:1)"
  run_jimverify_in "$root" faces-aggregate BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "fan-in max holder" "acct" "$(tsv_field FANIN_GROUP 2)"
}

# AC: on a fan-in tie every max-holder is named, sorted and comma-joined — ties →
# all holders (spec 045 AC #3/#4; mirrors cmd_health's fan-in ties → all sorted).
case_jimverify_faces_aggregate_fanin_ties_sorted() {
  local root; root="$(fa_repo faFanTie '| alpha | x | acct |
| bravo | y | acct |
| gamma | z | cat |
| delta | w | cat |' acct:1 cat:1 alpha:1 bravo:1 gamma:1 delta:1)"
  run_jimverify_in "$root" faces-aggregate BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "both fan-in max holders, sorted comma-joined" "acct,cat" "$(tsv_field FANIN_GROUP 2)"
}

# AC: with no graph fan-in (an absent Contract Graph), FANIN_GROUP is omitted —
# the emit-only-when->0 rule — while the face counters still emit (spec 045 AC #3
# boundary; interface contract rc 0).
case_jimverify_faces_aggregate_fanin_zero_omitted() {
  local root; root="$(fa_repo faNoFan "" solo:2)"
  run_jimverify_in "$root" faces-aggregate BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "faces still emitted" "2" "$(tsv_field FACES_TOTAL 2)"
  assert_eq "no FANIN_GROUP without graph fan-in" "" "$(printf '%s\n' "$OUT" | grep '^FANIN_GROUP	' || true)"
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
