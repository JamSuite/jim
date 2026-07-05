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
| abs-exists | absolute exists | high | structure |

```verify-checks
abs-scope polarity=must regex=x scope=/etc
dotdot-scope polarity=must regex=x scope=../outside
dash-scope polarity=must regex=x scope=-rf
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
