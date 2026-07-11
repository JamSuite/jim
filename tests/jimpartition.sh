#!/usr/bin/env bash
#
# tests/jimpartition.sh — Tests for skills/partition/scripts/jimpartition.sh
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# HOW TO RUN
#   bash tests/jimpartition.sh                  # every case in this file
#   bash skills/meta-test/scripts/run.sh    # this file alongside every other tests/*.sh
#

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT_jimpartition="$REPO_ROOT/skills/partition/scripts/jimpartition.sh"

# ─── Section: Per-script invokers ────────────────────────────────────────────

# run_jimpartition <args...>
#   Invoke the script-under-test in the CURRENT dir; capture stdout, stderr,
#   and exit code into OUT/ERR/RC. Same shape as run/run_jimfile in siblings.
run_jimpartition() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_jimpartition" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# run_jimpartition_in <dir> <args...>
#   Invoke with CWD set to <dir> (a git work-tree fixture). The scan / ingest /
#   coverage / aggregate verbs read the repo at CWD, so most cases need this.
run_jimpartition_in() {
  local dir="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$dir" && bash "$SCRIPT_jimpartition" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# ─── Section: Fixture helpers ────────────────────────────────────────────────

# git_repo <name> <relpath> [<relpath> ...]
#   Create a git work tree under TMP_BASE/<name>, write each <relpath> (content
#   = a single line) and stage it so `git ls-files` lists it. No commit needed —
#   the index is enough for ls-files. Prints the absolute repo dir.
git_repo() {
  local name="$1"; shift
  local dir="$TMP_BASE/$name"
  mkdir -p "$dir"
  git -C "$dir" init -q
  local f
  for f in "$@"; do
    mkdir -p "$dir/$(dirname "$f")"
    printf 'x\n' > "$dir/$f"
    git -C "$dir" add "$f"
  done
  printf '%s' "$dir"
}

# terr_file <dir> <name> <content>
#   Write a territories-file (TAB-separated) into <dir> and print its path.
terr_file() {
  local dir="$1" name="$2" content="$3"
  local path="$dir/$name"
  printf '%s\n' "$content" > "$path"
  printf '%s' "$path"
}

# git_init <name> — create an empty git work tree under TMP_BASE/<name>; print
#   the absolute repo dir. Companion to repo_add for scan fixtures that need
#   real file content.
git_init() {
  local dir="$TMP_BASE/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '%s' "$dir"
}

# repo_add <dir> <relpath> <content> — write <content> to <dir>/<relpath> and
#   stage it (git ls-files then lists it — no commit needed).
repo_add() {
  local dir="$1" rel="$2" content="$3"
  mkdir -p "$dir/$(dirname "$rel")"
  printf '%s\n' "$content" > "$dir/$rel"
  git -C "$dir" add "$rel"
}

# rename_repo <name> — build a throwaway git repo modelling a multi-group jim
#   project for the rename verbs: three groups (cart / orders / billing) each
#   with a `000-blueprint/spec.md` carrying Provides/Requires faces (orders and
#   billing require the dotted `cart.cart-session-api` surface), a frozen
#   numbered spec under cart with historical body text, a `BLUEPRINT.md` map
#   with a `## Groups` section (per-group Territory) and a `## Contract Graph`
#   (orders→cart, billing→cart), an identity-bearing `modules/cart` territory,
#   and a `jimconf.toml` carrying the per-group `verify_appetite_cart` key. One
#   committed baseline so the tree is clean. Print the absolute repo dir.
#
#   Token discipline: the group slug `cart` appears as a whole slug token only
#   in identity positions (group name, dotted requires group-half, spec-dir
#   path, territory path, config-key suffix, prose); the surface `cart-session-
#   api` embeds it inside a larger token, so the slug-token boundary must NOT
#   flag it — this is the ratchet the occurrences/edges-diff cases lean on.
rename_repo() {
  local name="${1:?rename_repo needs a name}"
  local root="$TMP_BASE/$name"
  mkdir -p "$root"
  git -C "$root" init -q
  git -C "$root" config user.email "test@example.com"
  git -C "$root" config user.name "Test"
  git -C "$root" config commit.gpgsign false

  # Identity-bearing territory + sibling group territories (real dirs so the
  # map's Territory declarations point at tracked code).
  mkdir -p "$root/modules/cart" "$root/modules/orders" "$root/modules/billing"
  printf 'export const cartSessionApi = {};\n' > "$root/modules/cart/session.js"
  printf 'export const orderApi = {};\n'        > "$root/modules/orders/order.js"
  printf 'export const invoiceApi = {};\n'      > "$root/modules/billing/invoice.js"

  # cart group blueprint — provides the (code-surface-named) session surface;
  # its verify-check carries a modules/cart path fact.
  mkdir -p "$root/docs/specs/cart/000-blueprint"
  cat > "$root/docs/specs/cart/000-blueprint/spec.md" <<'EOF'
# cart — group blueprint

The cart group owns session state for checkout.

## Provides

- `cart-session-api` — the session surface other groups consume.

## Requires

## Invariants

| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| session-shape | session objects carry an id | high | pattern |

```verify-checks
session-shape polarity=must regex=cartSessionApi scope=modules/cart/
```
EOF

  # A frozen numbered spec under cart — historical body text (a keep forever).
  mkdir -p "$root/docs/specs/cart/001-initial"
  cat > "$root/docs/specs/cart/001-initial/spec.md" <<'EOF'
# 001 initial cart design

The cart group was introduced to hold session logic during checkout.
EOF

  # orders group blueprint — dotted requires into cart.
  mkdir -p "$root/docs/specs/orders/000-blueprint"
  cat > "$root/docs/specs/orders/000-blueprint/spec.md" <<'EOF'
# orders — group blueprint

## Provides

- `order-api` — order lifecycle surface.

## Requires

- `cart.cart-session-api` — reads the session surface.
EOF

  # billing group blueprint — dotted requires into cart plus a prose mention.
  mkdir -p "$root/docs/specs/billing/000-blueprint"
  cat > "$root/docs/specs/billing/000-blueprint/spec.md" <<'EOF'
# billing — group blueprint

## Provides

- `invoice-api` — invoice surface.

## Requires

- `cart.cart-session-api` — reads the session surface during settlement.

Billing coordinates with the cart group when resolving disputes.
EOF

  # Project map — groups (with Territory), Relations, and a Contract Graph.
  cat > "$root/BLUEPRINT.md" <<'EOF'
# Project Blueprint

## Groups

### cart

- **Role:** domain
- **Territory:** `modules/cart`

### orders

- **Role:** domain
- **Territory:** `modules/orders`

### billing

- **Role:** domain
- **Territory:** `modules/billing`

## Relations

- orders depends on cart for session state.

## Contract Graph

*Derived from the group blueprints' provides/requires faces. Last reconciled: 2026-07-11T00:00:00Z (via /jim:blueprint)*

| Consumer | Relies on | Provider |
| :--- | :--- | :--- |
| orders | cart-session-api | cart |
| billing | cart-session-api | cart |
EOF

  # Project config — a per-group appetite key (orphaned by a rename) and an
  # operator command string embedding a cart territory path.
  cat > "$root/jimconf.toml" <<'EOF'
verify_appetite_cart = "streamlined"
deps_command_graph = "scan modules/cart"
EOF

  git -C "$root" add -A
  git -C "$root" commit -q -m "chore: seed multi-group fixture"
  printf '%s' "$root"
}

# ─── Section: coverage cases (Task 2) ────────────────────────────────────────

# AC #4: tracked files under no proposed territory are reported, dirname-
# aggregated, with a TOTAL count. Covered files (under a declared territory
# prefix) are excluded via slash-anchored prefix match.
case_jimpartition_coverage_uncovered_and_total() {
  local dir terr
  dir=$(git_repo cov_basic \
    src/foo/a.go src/foo/b.go src/bar/c.go src/uncov/d.go top.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tfoo\tsrc/foo\nGROUP\tbar\tsrc/bar')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'UNCOVERED\t./\t1\nUNCOVERED\tsrc/uncov/\t1\nTOTAL\t2')"
  assert_eq "uncovered dirs + total" "$expected" "$OUT"
}

# AC #4: when every tracked file falls under a declared territory, no UNCOVERED
# dir lines are emitted and TOTAL is 0 (never absent — 0 is an honest answer).
case_jimpartition_coverage_all_covered() {
  local dir terr
  dir=$(git_repo cov_all src/foo/a.go src/foo/b.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tfoo\tsrc/foo')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 0 "$RC"
  assert_eq "total zero" "$(printf 'TOTAL\t0')" "$OUT"
}

# AC #4: multiple uncovered files in one directory aggregate to a single
# UNCOVERED line with the per-directory count (the 039 dirname rule).
case_jimpartition_coverage_dirname_aggregation() {
  local dir terr
  dir=$(git_repo cov_agg src/a.go src/b.go src/c.go lib/keep.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tlib\tlib')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'UNCOVERED\tsrc/\t3\nTOTAL\t3')"
  assert_eq "src aggregates to 3" "$expected" "$OUT"
}

# AC #4: a territory whose path is a prefix STRING but not a slash-anchored
# ancestor does not falsely cover (src2/x is not under src).
case_jimpartition_coverage_slash_anchored() {
  local dir terr
  dir=$(git_repo cov_anchor src/a.go src2/b.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tsrc\tsrc')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'UNCOVERED\tsrc2/\t1\nTOTAL\t1')"
  assert_eq "src2 not covered by src" "$expected" "$OUT"
}

# rc 2 when invoked outside a git work tree (the substrate needs git ls-files).
case_jimpartition_coverage_no_git() {
  local dir terr
  dir=$(empty_dir cov_nogit)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tfoo\tsrc/foo')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 2 "$RC"
}

# rc 2 on a malformed territories line — the file is caller-written, so a bad
# line is a caller error (distinct from ingest's HYGIENE counting of untrusted
# extractor output).
case_jimpartition_coverage_malformed_territory_wrongtag() {
  local dir terr
  dir=$(git_repo cov_badtag src/a.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'NOTGROUP\tfoo\tsrc/foo')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 2 "$RC"
}

# rc 2 on an unsafe territory path (absolute / '..' segment) — the valid-relpath
# boundary rejects it before any set math.
case_jimpartition_coverage_malformed_territory_unsafe_path() {
  local dir terr
  dir=$(git_repo cov_badpath src/a.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tfoo\t../escape')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 2 "$RC"
}

# rc 2 on a non-slug group token.
case_jimpartition_coverage_malformed_territory_badslug() {
  local dir terr
  dir=$(git_repo cov_badslug src/a.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tBad_Slug\tsrc')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 2 "$RC"
}

# rc 2 when the territories-file argument is missing.
case_jimpartition_coverage_missing_arg() {
  local dir
  dir=$(git_repo cov_noarg src/a.go)
  run_jimpartition_in "$dir" coverage
  assert_exit "rc" 2 "$RC"
}

# ─── Section: ingest cases (Task 3) ──────────────────────────────────────────

# AC #2/#17: valid tracked edges pass the gate and are emitted with the channel
# arg; a directory endpoint (a Go package dir containing tracked files) is
# accepted. Output is sorted; no HYGIENE on clean input.
case_jimpartition_ingest_valid_edges() {
  local dir raw
  dir=$(git_repo ing_valid pkg/a/f1.go pkg/a/f2.go pkg/b/g.go main.go)
  raw=$(fixture ing_valid_raw.txt "$(printf 'pkg/a/f1.go\tpkg/b/g.go\nmain.go\tpkg/a')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tmain.go\tpkg/a\timports\nEDGE\tpkg/a/f1.go\tpkg/b/g.go\timports')"
  assert_eq "sorted edges, no hygiene" "$expected" "$OUT"
}

# AC #2: duplicate raw lines collapse to a single EDGE.
case_jimpartition_ingest_dedup() {
  local dir raw
  dir=$(git_repo ing_dedup pkg/a.go pkg/b.go)
  raw=$(fixture ing_dedup_raw.txt "$(printf 'pkg/a.go\tpkg/b.go\npkg/a.go\tpkg/b.go\npkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  assert_eq "deduped" "$(printf 'EDGE\tpkg/a.go\tpkg/b.go\timports')" "$OUT"
}

# AC #2: a per-edge 3rd field overrides the CLI channel for that edge (the
# deps_command output contract's optional channel), leaving 2-field lines on
# the CLI channel.
case_jimpartition_ingest_per_edge_channel() {
  local dir raw
  dir=$(git_repo ing_chan pkg/a.go pkg/b.go)
  raw=$(fixture ing_chan_raw.txt "$(printf 'pkg/a.go\tpkg/b.go\tevents\npkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tpkg/a.go\tpkg/b.go\tevents\nEDGE\tpkg/a.go\tpkg/b.go\timports')"
  assert_eq "per-edge + cli channel" "$expected" "$OUT"
}

# AC #17 / sec Finding 3: absolute and '..'-segment endpoints are rejected by
# the valid-relpath boundary, counted as unsafe-path, and never emitted.
case_jimpartition_ingest_unsafe_path() {
  local dir raw
  dir=$(git_repo ing_unsafe pkg/a.go pkg/b.go)
  raw=$(fixture ing_unsafe_raw.txt "$(printf '/etc/passwd\tpkg/b.go\npkg/a.go\t../escape\npkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tpkg/a.go\tpkg/b.go\timports\nHYGIENE\tunsafe-path\t2')"
  assert_eq "unsafe dropped + counted" "$expected" "$OUT"
}

# AC #17 / sec Finding 3: an endpoint outside the tracked set is dropped and
# counted as untracked — scanning can't be scoped to a path that isn't real.
case_jimpartition_ingest_untracked() {
  local dir raw
  dir=$(git_repo ing_untracked pkg/a.go pkg/b.go)
  raw=$(fixture ing_untracked_raw.txt "$(printf 'pkg/a.go\tnope/missing.go\npkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tpkg/a.go\tpkg/b.go\timports\nHYGIENE\tuntracked\t1')"
  assert_eq "untracked dropped + counted" "$expected" "$OUT"
}

# sec Finding 3: single-field / empty-endpoint lines are malformed; blank lines
# are benign and skipped (not counted).
case_jimpartition_ingest_malformed_and_blank() {
  local dir raw
  dir=$(git_repo ing_malformed pkg/a.go pkg/b.go)
  raw=$(fixture ing_malformed_raw.txt "$(printf 'onlyonefield\n\npkg/a.go\tpkg/b.go\n\t')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tpkg/a.go\tpkg/b.go\timports\nHYGIENE\tmalformed-line\t2')"
  assert_eq "malformed counted, blanks skipped" "$expected" "$OUT"
}

# sec Finding 3: a control byte in an endpoint is not a tracked path, so the
# edge is dropped (counted, never emitted). The run does not crash.
case_jimpartition_ingest_control_bytes() {
  local dir raw
  dir=$(git_repo ing_ctrl pkg/a.go pkg/b.go)
  raw=$(fixture ing_ctrl_raw.txt "$(printf 'pkg/a.go\tpkg/\x01b.go\npkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  assert_match "clean edge emitted" '^EDGE'"$(printf '\t')"'pkg/a\.go'"$(printf '\t')"'pkg/b\.go'"$(printf '\t')"'imports$' "$OUT"
  assert_match "control-byte edge dropped as hygiene" '^HYGIENE' "$OUT"
}

# rc 2 on a non-slug channel argument (the whole invocation is rejected — a
# blueprint/map-recorded name can never inject via the channel arg).
case_jimpartition_ingest_invalid_channel() {
  local dir raw
  dir=$(git_repo ing_badchan pkg/a.go pkg/b.go)
  raw=$(fixture ing_badchan_raw.txt "$(printf 'pkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw" 'BAD.CHAN'
  assert_exit "rc" 2 "$RC"
}

# rc 2 when the raw file is unreadable / missing.
case_jimpartition_ingest_unreadable_file() {
  local dir
  dir=$(git_repo ing_noraw pkg/a.go)
  run_jimpartition_in "$dir" ingest "$dir/does-not-exist.txt" imports
  assert_exit "rc" 2 "$RC"
}

# rc 2 when the channel argument is missing.
case_jimpartition_ingest_missing_channel_arg() {
  local dir raw
  dir=$(git_repo ing_noarg pkg/a.go)
  raw=$(fixture ing_noarg_raw.txt "$(printf 'pkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw"
  assert_exit "rc" 2 "$RC"
}

# ─── Section: scan cases (Task 4) ────────────────────────────────────────────

# rc 2 when scan runs outside a git work tree.
case_jimpartition_scan_no_git() {
  local dir
  dir=$(empty_dir scan_nogit)
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 2 "$RC"
}

# AC #3: a repo of only unmodeled source is labeled UNMODELED (by language),
# emits no edges, and no CHANNEL — the honest degraded graph. Non-source files
# (manifests, docs) are not counted.
case_jimpartition_scan_unmodeled_only() {
  local dir
  dir=$(git_init scan_unmodeled)
  repo_add "$dir" Foo.java 'class Foo {}'
  repo_add "$dir" Bar.java 'class Bar {}'
  repo_add "$dir" README.md '# docs'
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  assert_match "java unmodeled x2" '^UNMODELED'"$(printf '\t')"'java'"$(printf '\t')"'2$' "$OUT"
  assert_eq "no edges" "0" "$(printf '%s\n' "$OUT" | grep -c '^EDGE' || true)"
  assert_eq "no channel" "0" "$(printf '%s\n' "$OUT" | grep -c '^CHANNEL' || true)"
  assert_eq "md not counted" "0" "$(printf '%s\n' "$OUT" | grep -c 'md' || true)"
}

# AC #2/#3: a mixed repo emits a CHANNEL for the modeled language and an
# UNMODELED fact for the unmodeled source — both coverage signals present.
case_jimpartition_scan_mixed() {
  local dir
  dir=$(git_init scan_mixed)
  repo_add "$dir" go.mod "$(printf 'module example.com/m\n\ngo 1.21')"
  repo_add "$dir" main.go "$(printf 'package main')"
  repo_add "$dir" Extra.java 'class Extra {}'
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  assert_match "go channel scanned 1" '^CHANNEL'"$(printf '\t')"'imports'"$(printf '\t')"'go'"$(printf '\t')"'1$' "$OUT"
  assert_match "java unmodeled 1" '^UNMODELED'"$(printf '\t')"'java'"$(printf '\t')"'1$' "$OUT"
}

# AC #2: Go internal imports (single and block form) resolve to package dirs;
# external imports (fmt) are ignored. CHANNEL counts every scanned .go file.
case_jimpartition_scan_go() {
  local dir
  dir=$(git_init scan_go)
  repo_add "$dir" go.mod "$(printf 'module example.com/proj\n\ngo 1.21')"
  repo_add "$dir" a/main.go "$(printf 'package main\nimport "example.com/proj/lib/foo"')"
  repo_add "$dir" b/x.go "$(printf 'package b\n\nimport (\n\t"example.com/proj/lib/foo"\n\t"fmt"\n)')"
  repo_add "$dir" lib/foo/foo.go 'package foo'
  repo_add "$dir" lib/foo/bar.go 'package foo'
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\ta/main.go\tlib/foo\timports\nEDGE\tb/x.go\tlib/foo\timports\nCHANNEL\timports\tgo\t4')"
  assert_eq "go edges + channel" "$expected" "$OUT"
}

# sec Finding 7: a go.mod module carrying regex metacharacters fails the charset
# gate, so Go degrades to UNMODELED (no crash, no injected match, no edges).
case_jimpartition_scan_go_metachar_module() {
  local dir
  dir=$(git_init scan_go_meta)
  repo_add "$dir" go.mod "$(printf 'module example.com/pro*j\n\ngo 1.21')"
  repo_add "$dir" main.go "$(printf 'package main\nimport "example.com/pro*j/lib/foo"')"
  repo_add "$dir" lib/foo/foo.go 'package foo'
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  assert_eq "no edges" "0" "$(printf '%s\n' "$OUT" | grep -c '^EDGE' || true)"
  assert_match "go degraded to unmodeled" '^UNMODELED'"$(printf '\t')"'go'"$(printf '\t')" "$OUT"
}

# AC #2: Python dotted `import` statements resolve to a/b.py (or the package's
# __init__.py). CHANNEL counts every scanned .py file.
case_jimpartition_scan_python() {
  local dir
  dir=$(git_init scan_py)
  repo_add "$dir" pkg/__init__.py '# pkg'
  repo_add "$dir" pkg/a.py "$(printf 'import pkg.b')"
  repo_add "$dir" pkg/b.py '# b'
  repo_add "$dir" main.py "$(printf 'import pkg.a')"
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tmain.py\tpkg/a.py\timports\nEDGE\tpkg/a.py\tpkg/b.py\timports\nCHANNEL\timports\tpython\t4')"
  assert_eq "python import edges" "$expected" "$OUT"
}

# AC #2: `from pkg import sub` resolves both the package (__init__.py) and the
# named submodule (pkg/sub.py); a symbol import that names no file yields no
# false edge.
case_jimpartition_scan_python_from() {
  local dir
  dir=$(git_init scan_py_from)
  repo_add "$dir" pkg/__init__.py '# pkg'
  repo_add "$dir" pkg/sub.py '# sub'
  repo_add "$dir" app.py "$(printf 'from pkg import sub')"
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tapp.py\tpkg/__init__.py\timports\nEDGE\tapp.py\tpkg/sub.py\timports\nCHANNEL\timports\tpython\t3')"
  assert_eq "python from-import edges" "$expected" "$OUT"
}

# AC #2: JS/TS relative specifiers resolve with extension and /index resolution
# (bare package specifiers are external and ignored). Both single- and
# double-quoted, import and require forms are recognized.
case_jimpartition_scan_jsts() {
  local dir
  dir=$(git_init scan_jsts)
  repo_add "$dir" src/index.js "$(printf "import { a } from './lib/a';\nconst b = require('./lib/b.js');\nimport react from 'react';")"
  repo_add "$dir" src/lib/a.js '// a'
  repo_add "$dir" src/lib/b.js '// b'
  repo_add "$dir" src/lib/c/index.ts '// c'
  repo_add "$dir" src/main.ts "$(printf "import x from './lib/c';")"
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tsrc/index.js\tsrc/lib/a.js\timports\nEDGE\tsrc/index.js\tsrc/lib/b.js\timports\nEDGE\tsrc/main.ts\tsrc/lib/c/index.ts\timports\nCHANNEL\timports\tjs-ts\t5')"
  assert_eq "js/ts relative edges" "$expected" "$OUT"
}

# AC #2: a two-member Rust workspace — intra-crate `mod` + `use crate::` resolve
# within the crate; cross-crate `use crate_a::` (underscore) normalizes to the
# member crate-a (hyphen) and edges to its src dir. Crate identity comes from
# each Cargo.toml [package] name.
case_jimpartition_scan_rust_workspace() {
  local dir
  dir=$(git_init scan_rust)
  repo_add "$dir" Cargo.toml "$(printf '[workspace]\nmembers = ["crate-a", "crate-b"]')"
  repo_add "$dir" crate-a/Cargo.toml "$(printf '[package]\nname = "crate-a"')"
  repo_add "$dir" crate-a/src/lib.rs "$(printf 'mod helper;\npub use crate::helper::thing;')"
  repo_add "$dir" crate-a/src/helper.rs "$(printf 'pub fn thing() {}')"
  repo_add "$dir" crate-b/Cargo.toml "$(printf '[package]\nname = "crate-b"')"
  repo_add "$dir" crate-b/src/lib.rs "$(printf 'use crate_a::thing;')"
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tcrate-a/src/lib.rs\tcrate-a/src/helper.rs\timports\nEDGE\tcrate-b/src/lib.rs\tcrate-a/src\timports\nCHANNEL\timports\trust\t3')"
  assert_eq "rust workspace edges" "$expected" "$OUT"
}

# sec Finding 7: a Cargo.toml [package] name with regex metacharacters fails the
# charset gate, degrading that crate's files to UNMODELED (no crash, no edges).
case_jimpartition_scan_rust_metachar_name() {
  local dir
  dir=$(git_init scan_rust_meta)
  repo_add "$dir" Cargo.toml "$(printf '[package]\nname = "bad*name"')"
  repo_add "$dir" src/lib.rs "$(printf 'mod foo;')"
  repo_add "$dir" src/foo.rs "$(printf 'pub fn f() {}')"
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  assert_eq "no edges" "0" "$(printf '%s\n' "$OUT" | grep -c '^EDGE' || true)"
  assert_match "rust degraded to unmodeled" '^UNMODELED'"$(printf '\t')"'rust'"$(printf '\t')"'2$' "$OUT"
}

# AC #2: Elixir resolves references (alias/import/use/require, including the
# `Ns.{Qux}` brace form) against a defmodule->file map built over tracked
# .ex/.exs. CHANNEL counts every scanned Elixir file.
case_jimpartition_scan_elixir() {
  local dir
  dir=$(git_init scan_ex)
  repo_add "$dir" lib/foo.ex "$(printf 'defmodule Foo do\n  alias Bar\n  alias Ns.{Qux}\nend')"
  repo_add "$dir" lib/bar.ex "$(printf 'defmodule Bar do\nend')"
  repo_add "$dir" lib/ns/qux.ex "$(printf 'defmodule Ns.Qux do\nend')"
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tlib/foo.ex\tlib/bar.ex\timports\nEDGE\tlib/foo.ex\tlib/ns/qux.ex\timports\nCHANNEL\timports\telixir\t3')"
  assert_eq "elixir alias edges" "$expected" "$OUT"
}

# ─── Section: aggregate cases (Task 5) ───────────────────────────────────────

# AC #2/#20: aggregate joins file EDGEs against proposed territories → GEDGE
# counts (intra-group edges dropped), STRADDLE facts for units consumed by >=2
# distinct foreign groups, and UNASSIGNED dirs for endpoints under no territory.
case_jimpartition_aggregate_full() {
  local edges terr
  edges=$(fixture agg_edges.txt "$(printf 'EDGE\tsrc/api/h.go\tsrc/core/x.go\timports\nEDGE\tsrc/web/w.go\tsrc/core/x.go\timports\nEDGE\tsrc/core/a.go\tsrc/core/b.go\timports\nEDGE\tsrc/api/h.go\tsrc/platform/log.go\timports\nEDGE\tsrc/web/w.go\tsrc/platform/log.go\timports\nEDGE\tsrc/core/x.go\tsrc/platform/log.go\timports\nEDGE\tsrc/web/w.go\torphan/util.go\timports')")
  terr=$(fixture agg_terr.txt "$(printf 'GROUP\tcore\tsrc/core\nGROUP\tapi\tsrc/api\nGROUP\tweb\tsrc/web\nGROUP\tplatform\tsrc/platform')")
  run_jimpartition aggregate "$edges" "$terr"
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'GEDGE\tapi\tcore\t1\nGEDGE\tapi\tplatform\t1\nGEDGE\tcore\tplatform\t1\nGEDGE\tweb\tcore\t1\nGEDGE\tweb\tplatform\t1\nSTRADDLE\tsrc/core/x.go\tcore\t2\nSTRADDLE\tsrc/platform/log.go\tplatform\t3\nUNASSIGNED\torphan/\t1')"
  assert_eq "group edges + straddles + unassigned" "$expected" "$OUT"
}

# DD 14: a unit consumed by exactly one foreign group is a normal GEDGE, never a
# STRADDLE (the >=2 threshold).
case_jimpartition_aggregate_one_foreign_no_straddle() {
  local edges terr
  edges=$(fixture agg1_edges.txt "$(printf 'EDGE\tsrc/api/h.go\tsrc/core/x.go\timports')")
  terr=$(fixture agg1_terr.txt "$(printf 'GROUP\tcore\tsrc/core\nGROUP\tapi\tsrc/api')")
  run_jimpartition aggregate "$edges" "$terr"
  assert_exit "rc" 0 "$RC"
  assert_eq "no straddle" "0" "$(printf '%s\n' "$OUT" | grep -c '^STRADDLE' || true)"
  assert_match "single gedge" '^GEDGE'"$(printf '\t')"'api'"$(printf '\t')"'core'"$(printf '\t')"'1$' "$OUT"
}

# rc 2 when the edges file is missing.
case_jimpartition_aggregate_missing_edges() {
  local terr
  terr=$(fixture agg_me_terr.txt "$(printf 'GROUP\tcore\tsrc/core')")
  run_jimpartition aggregate "$TMP_BASE/no-such-edges.txt" "$terr"
  assert_exit "rc" 2 "$RC"
}

# rc 2 on a malformed territories file (caller error).
case_jimpartition_aggregate_malformed_territories() {
  local edges terr
  edges=$(fixture agg_mt_edges.txt "$(printf 'EDGE\tsrc/a.go\tsrc/b.go\timports')")
  terr=$(fixture agg_mt_terr.txt "$(printf 'GROUP\tcore\t../escape')")
  run_jimpartition aggregate "$edges" "$terr"
  assert_exit "rc" 2 "$RC"
}

# rc 2 when arguments are missing.
case_jimpartition_aggregate_missing_args() {
  local edges
  edges=$(fixture agg_ma_edges.txt "$(printf 'EDGE\tsrc/a.go\tsrc/b.go\timports')")
  run_jimpartition aggregate "$edges"
  assert_exit "rc" 2 "$RC"
}

# ─── Section: rename fixture smoke (Task 1) ──────────────────────────────────

# AC #18: the multi-group rename fixture builds a clean, committed baseline with
# three groups' blueprints, an identity-bearing cart territory, a project map
# with a Contract Graph, and a per-group appetite key in config — the substrate
# every rename scan/verify case below reads.
case_jimpartition_rename_fixture_smoke() {
  local dir; dir="$(rename_repo rn_smoke)"
  assert_eq "clean committed tree" "" "$(git -C "$dir" status --porcelain)"
  local files; files="$(git -C "$dir" ls-files)"
  assert_match "cart blueprint tracked"   '^docs/specs/cart/000-blueprint/spec\.md$'   "$files"
  assert_match "orders blueprint tracked" '^docs/specs/orders/000-blueprint/spec\.md$' "$files"
  assert_match "cart numbered spec tracked" '^docs/specs/cart/001-initial/spec\.md$'   "$files"
  assert_match "cart territory tracked"   '^modules/cart/'                             "$files"
  assert_match "map tracked"              '^BLUEPRINT\.md$'                             "$files"
  assert_match "config tracked"           '^jimconf\.toml$'                            "$files"
  assert_match "appetite key present"     'verify_appetite_cart'                       "$(cat "$dir/jimconf.toml")"
}

# ─── Section: rename-preflight cases (Task 2) ────────────────────────────────

# AC #2/#3/#5: a clean rename passes every structural check, detects the
# identity-bearing cart territory, and reports no dirt (dirt is not fatal → rc 0).
case_jimpartition_preflight_clean_pass() {
  local dir T; dir="$(rename_repo rp_clean)"; T=$'\t'
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart checkout
  assert_exit "rc" 0 "$RC"
  assert_match "map-exists pass"       "^CHECK${T}map-exists${T}pass"       "$OUT"
  assert_match "old-mapped pass"       "^CHECK${T}old-mapped${T}pass"       "$OUT"
  assert_match "new-slug-valid pass"   "^CHECK${T}new-slug-valid${T}pass"   "$OUT"
  assert_match "new-collision pass"    "^CHECK${T}new-collision${T}pass"    "$OUT"
  assert_match "blueprint-exists pass" "^CHECK${T}blueprint-exists${T}pass" "$OUT"
  assert_match "tree-clean pass"       "^CHECK${T}tree-clean${T}pass"       "$OUT"
  assert_match "territory identity"    "^TERRITORY-IDENTITY${T}modules/cart$" "$OUT"
  assert_eq    "no dirt"               "0" "$(printf '%s\n' "$OUT" | grep -c '^DIRT')"
  assert_eq    "only cart territory"   "0" "$(printf '%s\n' "$OUT" | grep -c 'modules/orders')"
}

# AC #2: a missing map fails the map-exists check with rc 1 (nothing written).
case_jimpartition_preflight_no_map() {
  local dir T; dir="$(rename_repo rp_nomap)"; T=$'\t'
  run_jimpartition_in "$dir" rename-preflight no-such-map.md docs/specs cart checkout
  assert_exit "rc" 1 "$RC"
  assert_match "map-exists fail" "^CHECK${T}map-exists${T}fail" "$OUT"
}

# AC #2: an old name that is not a mapped group fails old-mapped with rc 1.
case_jimpartition_preflight_old_not_mapped() {
  local dir T; dir="$(rename_repo rp_oldnm)"; T=$'\t'
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs nonesuch checkout
  assert_exit "rc" 1 "$RC"
  assert_match "old-mapped fail" "^CHECK${T}old-mapped${T}fail" "$OUT"
}

# AC #2: a new name that is not a valid group slug fails new-slug-valid with rc 1.
case_jimpartition_preflight_new_bad_slug() {
  local dir T; dir="$(rename_repo rp_badslug)"; T=$'\t'
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart 'Bad_New'
  assert_exit "rc" 1 "$RC"
  assert_match "new-slug-valid fail" "^CHECK${T}new-slug-valid${T}fail" "$OUT"
}

# AC #2: a new name colliding with an existing mapped group fails new-collision.
case_jimpartition_preflight_new_collision_group() {
  local dir T; dir="$(rename_repo rp_coll)"; T=$'\t'
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart orders
  assert_exit "rc" 1 "$RC"
  assert_match "new-collision fail" "^CHECK${T}new-collision${T}fail" "$OUT"
}

# AC #2: a new name colliding with an existing spec-group directory (not yet in
# the map) also fails new-collision — the directory is authority too.
case_jimpartition_preflight_new_collision_dir() {
  local dir T; dir="$(rename_repo rp_colld)"; T=$'\t'
  mkdir -p "$dir/docs/specs/archived/000-blueprint"
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart archived
  assert_exit "rc" 1 "$RC"
  assert_match "new-collision fail" "^CHECK${T}new-collision${T}fail" "$OUT"
}

# AC #2: a group whose 000-blueprint is absent fails blueprint-exists with rc 1.
# The removal is committed so the tree stays clean and isolates the check.
case_jimpartition_preflight_blueprint_absent() {
  local dir T; dir="$(rename_repo rp_nobp)"; T=$'\t'
  git -C "$dir" rm -q -r docs/specs/cart/000-blueprint >/dev/null
  git -C "$dir" commit -q -m "chore: drop cart blueprint"
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart checkout
  assert_exit "rc" 1 "$RC"
  assert_match "blueprint-exists fail" "^CHECK${T}blueprint-exists${T}fail" "$OUT"
}

# AC #3: a dirty tree is not fatal (rc 0) but names dirt inside the affected path
# set file-by-file (affected) distinct from unrelated dirt elsewhere.
case_jimpartition_preflight_dirt_split() {
  local dir T; dir="$(rename_repo rp_dirt)"; T=$'\t'
  printf 'wip\n' > "$dir/docs/specs/cart/000-blueprint/notes.txt"   # inside affected set
  printf 'x\n'   > "$dir/unrelated.txt"                              # unrelated dirt
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart checkout
  assert_exit "rc" 0 "$RC"
  assert_match "tree-clean fail" "^CHECK${T}tree-clean${T}fail" "$OUT"
  assert_match "affected dirt named" "^DIRT${T}affected${T}docs/specs/cart/000-blueprint/notes\.txt$" "$OUT"
  assert_match "unrelated dirt named" "^DIRT${T}unrelated${T}unrelated\.txt$" "$OUT"
}

# AC #5: dirt inside the identity-bearing territory is classified affected too.
case_jimpartition_preflight_dirt_territory_affected() {
  local dir T; dir="$(rename_repo rp_dirtt)"; T=$'\t'
  printf 'wip\n' > "$dir/modules/cart/extra.js"
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart checkout
  assert_exit "rc" 0 "$RC"
  assert_match "territory dirt affected" "^DIRT${T}affected${T}modules/cart/extra\.js$" "$OUT"
}

# rc 2 on a missing argument (usage error, distinct from a structural failure).
case_jimpartition_preflight_missing_args() {
  local dir; dir="$(rename_repo rp_noargs)"
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart
  assert_exit "rc" 2 "$RC"
}

# rc 2 on an <old> that is not even a valid slug — a usage error before any
# map/filesystem work (the input boundary, not a named CHECK).
case_jimpartition_preflight_old_bad_slug() {
  local dir; dir="$(rename_repo rp_oldbad)"
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs 'Bad/Old' checkout
  assert_exit "rc" 2 "$RC"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
#
# This file works two ways:
#   1. bash tests/jimpartition.sh        → runs only this file's cases (standalone).
#   2. bash skills/meta-test/scripts/run.sh
#                                    → sources this file alongside every other
#                                      tests/*.sh and runs the union of cases.
#
# How the dual-mode works:
#   ${BASH_SOURCE[0]} is the file bash is currently reading.
#   ${0} is the file bash was invoked with.
#   They match ONLY when this file is run directly. When the aggregate runner
#   sources us, BASH_SOURCE[0] is this file but $0 is run.sh — they diverge.
#   So the block below runs the cases only on direct invocation; otherwise it
#   stays silent and lets the aggregate runner decide what to dispatch.
#
# DO NOT "tidy" this into something simpler — $BASH_SOURCE (no index) and
# ${BASH_SOURCE} behave subtly differently in older bash and break aggregate
# runs.
#
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_jimpartition" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_jimpartition — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
