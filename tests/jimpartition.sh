#!/usr/bin/env bash
#
# tests/jimpartition.sh — Tests for skills/partition/scripts/jimpartition.sh
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# MUTATION AUDIT
#   SCOPE, stated first because a coverage claim is only as good as its bounds:
#   exactly one guard in this file has been mutation-audited — merge-map's
#   newline refusal. Nothing else here has been shown to discriminate; absence
#   from this list is absence of evidence, not a passing grade.
#
#   Audited (2 mutations, both discriminating): the refusal downgraded to a
#   `continue` (the silent-skip shape), and the gate deleted outright. Both turn
#   the two newline cases red.
#
# HOW TO RUN
#   bash tests/jimpartition.sh                  # every case in this file
#   bash skills/meta-test/scripts/run.sh    # this file alongside every other tests/*.sh
#

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT_jimpartition="$REPO_ROOT/skills/partition/scripts/jimpartition.sh"
# Sibling scripts the rename continuity/ratchet cases (Task 7) compose with.
SCRIPT_JIMLEDGER="$REPO_ROOT/skills/ledger/scripts/jimledger.sh"
SCRIPT_jimverify="$REPO_ROOT/skills/verify/scripts/jimverify.sh"

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

# split_repo <name> — a multi-group jim project fixture for the split verbs
#   (spec 047). Two mapped groups (cart / orders) with 000-blueprints, a
#   BLUEPRINT.md map (Groups + Territory + Contract Graph), plus the split-
#   specific surface: a cart foundation (modules/cart) and a checkout-side
#   subtree (modules/cart/checkout) whose flow.js imports back into the
#   foundation's catalog module — the cross-child edge a split reveals when the
#   boundary is drawn between the two subtrees. One committed baseline (clean
#   tree). Print the absolute repo dir.
#
#   Token discipline (rename_repo parity): `cart` occurs as a whole slug token
#   only in identity positions; the surfaces `cart-session-api` /
#   `catalog-query-api` embed it inside a larger token, so the slug-token
#   boundary must not flag them.
split_repo() {
  local name="${1:?split_repo needs a name}"
  local root="$TMP_BASE/$name"
  mkdir -p "$root"
  git -C "$root" init -q
  git -C "$root" config user.email "test@example.com"
  git -C "$root" config user.name "Test"
  git -C "$root" config commit.gpgsign false

  mkdir -p "$root/modules/cart/checkout" "$root/modules/orders"
  printf 'export const cartSessionApi = {};\n'  > "$root/modules/cart/session.js"
  printf 'export const catalogQueryApi = {};\n' > "$root/modules/cart/catalog.js"
  printf 'import { catalogQueryApi } from "../catalog";\nexport const checkoutFlow = {};\n' \
                                                > "$root/modules/cart/checkout/flow.js"
  printf 'import { catalogQueryApi } from "../cart/catalog";\nexport const orderApi = {};\n' \
                                                > "$root/modules/orders/order.js"

  mkdir -p "$root/docs/specs/cart/000-blueprint"
  cat > "$root/docs/specs/cart/000-blueprint/spec.md" <<'EOF'
# cart — group blueprint

## Provides

- `cart-session-api` — the session surface.
- `catalog-query-api` — catalog reads.
EOF

  mkdir -p "$root/docs/specs/orders/000-blueprint"
  printf '# orders\n\n## Requires\n\n- `cart.cart-session-api` — session reads.\n' \
    > "$root/docs/specs/orders/000-blueprint/spec.md"

  cat > "$root/BLUEPRINT.md" <<'EOF'
# Project Blueprint

## Groups

### cart

- **Role:** domain
- **Territory:** `modules/cart`

### orders

- **Role:** domain
- **Territory:** `modules/orders`

## Contract Graph

*Last reconciled: 2026-07-16T00:00:00Z (via /jim:blueprint)*

| Consumer | Relies on | Provider |
| :--- | :--- | :--- |
| orders | cart-session-api | cart |
EOF

  git -C "$root" add -A
  git -C "$root" commit -q -m "chore: seed split fixture"
  printf '%s' "$root"
}

# merge_repo <name> — a THREE-group git work tree for the merge verbs: cart,
#   orders, and wishlist, each a mapped domain group with a `modules/<slug>`
#   territory, a 000-blueprint carrying a Provides / Requires face, and numbered
#   specs (so merge-map renumber-appends real spec dirs). The map's Contract
#   Graph carries a cross-source edge (wishlist -> cart, which dissolves when
#   both merge) and a third-party edge (orders -> cart, the bystander that forces
#   a re-point). Three groups give a multi-source merge plus a bystander for the
#   re-point and full-collapse-negative cases. One committed baseline (clean
#   tree). Print the absolute repo dir.
#
#   Token discipline (split_repo parity): each group slug occurs as a whole
#   token only in identity positions; the surface names embed the slug inside a
#   larger token (`cart-checkout-hold`, `wishlist-gift-flag`) so the slug-token
#   boundary must not flag them.
merge_repo() {
  local name="${1:?merge_repo needs a name}"
  local root="$TMP_BASE/$name"
  mkdir -p "$root"
  git -C "$root" init -q
  git -C "$root" config user.email "test@example.com"
  git -C "$root" config user.name "Test"
  git -C "$root" config commit.gpgsign false

  mkdir -p "$root/modules/cart" "$root/modules/orders" "$root/modules/wishlist"
  printf 'export const cartCheckoutHold = {};\n' > "$root/modules/cart/checkout.js"
  printf 'export const orderApi = {};\n'         > "$root/modules/orders/order.js"
  printf 'export const wishlistGiftFlag = {};\n' > "$root/modules/wishlist/gift.js"

  # cart — absorption target in the absorption arm; a source in the fresh-target arm.
  mkdir -p "$root/docs/specs/cart/000-blueprint" \
           "$root/docs/specs/cart/001-cart-a" "$root/docs/specs/cart/002-cart-b"
  cat > "$root/docs/specs/cart/000-blueprint/spec.md" <<'EOF'
# cart — group blueprint

## Provides

- `cart-checkout-hold` — the checkout hold surface.
EOF
  printf '# cart a\n' > "$root/docs/specs/cart/001-cart-a/spec.md"
  printf '# cart b\n' > "$root/docs/specs/cart/002-cart-b/spec.md"

  # orders — the bystander (third-party consumer of cart).
  mkdir -p "$root/docs/specs/orders/000-blueprint" "$root/docs/specs/orders/001-orders-a"
  printf '# orders\n\n## Requires\n\n- `cart.cart-checkout-hold` — hold reads.\n' \
    > "$root/docs/specs/orders/000-blueprint/spec.md"
  printf '# orders a\n' > "$root/docs/specs/orders/001-orders-a/spec.md"

  # wishlist — the absorbed source; requires cart (a cross-source edge that
  # dissolves when wishlist and cart merge).
  mkdir -p "$root/docs/specs/wishlist/000-blueprint" \
           "$root/docs/specs/wishlist/001-wishlist-a" "$root/docs/specs/wishlist/002-wishlist-b"
  cat > "$root/docs/specs/wishlist/000-blueprint/spec.md" <<'EOF'
# wishlist — group blueprint

## Provides

- `wishlist-gift-flag` — the gift-flag surface.

## Requires

- `cart.cart-checkout-hold` — hold reads.
EOF
  printf '# wishlist a\n' > "$root/docs/specs/wishlist/001-wishlist-a/spec.md"
  printf '# wishlist b\n' > "$root/docs/specs/wishlist/002-wishlist-b/spec.md"

  cat > "$root/BLUEPRINT.md" <<'EOF'
# Project Blueprint

## Groups

### cart

- **Role:** domain
- **Territory:** `modules/cart`

### orders

- **Role:** domain
- **Territory:** `modules/orders`

### wishlist

- **Role:** domain
- **Territory:** `modules/wishlist`

## Contract Graph

*Last reconciled: 2026-07-20T00:00:00Z (via /jim:blueprint)*

| Consumer | Relies on | Provider |
| :--- | :--- | :--- |
| orders | cart-checkout-hold | cart |
| wishlist | cart-checkout-hold | cart |
EOF

  git -C "$root" add -A
  git -C "$root" commit -q -m "chore: seed merge fixture"
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

# ─── Section: occurrences cases (Task 3) ─────────────────────────────────────

# AC #4/#19: a dotted requires key's group half is a dotted-key hit; output is
# location-only (file + line number + kind), never the matched content.
case_jimpartition_occurrences_dotted_key() {
  local dir T; dir="$(rename_repo occ_dot)"; T=$'\t'
  run_jimpartition_in "$dir" occurrences cart docs/specs/orders/000-blueprint/spec.md
  assert_exit "rc" 0 "$RC"
  assert_match "dotted-key hit" "^HIT${T}docs/specs/orders/000-blueprint/spec\.md${T}[0-9]+${T}dotted-key$" "$OUT"
}

# AC #4: a path-segment mention (the territory path in the map) is a path hit.
case_jimpartition_occurrences_path() {
  local dir T; dir="$(rename_repo occ_path)"; T=$'\t'
  run_jimpartition_in "$dir" occurrences cart BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_match "path hit" "^HIT${T}BLUEPRINT\.md${T}[0-9]+${T}path$" "$OUT"
}

# AC #6: config keys and values are distinguished — the orphaned per-group
# appetite key is config-key; a territory path inside a command string value is
# config-value.
case_jimpartition_occurrences_config_kinds() {
  local dir T; dir="$(rename_repo occ_cfg)"; T=$'\t'
  run_jimpartition_in "$dir" occurrences cart jimconf.toml
  assert_exit "rc" 0 "$RC"
  assert_match "config-key hit"   "^HIT${T}jimconf\.toml${T}[0-9]+${T}config-key$"   "$OUT"
  assert_match "config-value hit" "^HIT${T}jimconf\.toml${T}[0-9]+${T}config-value$" "$OUT"
}

# AC #4: a free-text mention is a prose hit.
case_jimpartition_occurrences_prose() {
  local dir T; dir="$(rename_repo occ_prose)"; T=$'\t'
  run_jimpartition_in "$dir" occurrences cart docs/specs/billing/000-blueprint/spec.md
  assert_exit "rc" 0 "$RC"
  assert_match "prose hit" "^HIT${T}docs/specs/billing/000-blueprint/spec\.md${T}[0-9]+${T}prose$" "$OUT"
}

# Match rule: the slug matches only as a whole slug token — `cartel` (slug
# continues with a letter) and the kebab surface `cart-session-api` (continues
# with '-') never match.
case_jimpartition_occurrences_token_boundary() {
  local dir; dir="$(rename_repo occ_bound)"
  printf 'the cartel runs a cart-session-api endpoint\n' > "$dir/boundary.txt"
  run_jimpartition_in "$dir" occurrences cart boundary.txt
  assert_exit "rc" 0 "$RC"
  assert_eq "no hit for cartel / cart-session-api" "0" "$(printf '%s\n' "$OUT" | grep -c '^HIT')"
}

# AC #19 structural guarantee: every emitted line is HIT<TAB>file<TAB>line<TAB>
# kind — never the matched line's content. Distinctive surrounding words must
# not leak into the output.
case_jimpartition_occurrences_location_only() {
  local dir T; dir="$(rename_repo occ_loc)"; T=$'\t'
  run_jimpartition_in "$dir" occurrences cart \
    docs/specs/orders/000-blueprint/spec.md docs/specs/billing/000-blueprint/spec.md jimconf.toml BLUEPRINT.md
  assert_exit "rc" 0 "$RC"
  assert_eq "no 'reads' leak"      "0" "$(printf '%s\n' "$OUT" | grep -c 'reads')"
  assert_eq "no 'settlement' leak" "0" "$(printf '%s\n' "$OUT" | grep -c 'settlement')"
  assert_eq "all lines HIT-shaped" "0" \
    "$(printf '%s\n' "$OUT" | grep -vcE "^HIT${T}[^${T}]+${T}[0-9]+${T}(dotted-key|path|config-key|config-value|prose)$")"
}

# rc 2 on an invalid slug (a map/blueprint-recorded name can never inject here).
case_jimpartition_occurrences_invalid_slug() {
  local dir; dir="$(rename_repo occ_badslug)"
  run_jimpartition_in "$dir" occurrences 'Bad.Slug' BLUEPRINT.md
  assert_exit "rc" 2 "$RC"
}

# rc 2 when no path arguments are given.
case_jimpartition_occurrences_missing_paths() {
  local dir; dir="$(rename_repo occ_nopath)"
  run_jimpartition_in "$dir" occurrences cart
  assert_exit "rc" 2 "$RC"
}

# ─── Section: edges-diff cases (Task 4) ──────────────────────────────────────

# AC #14: after == before with old→new rewritten in the consumer/provider
# columns (relies-on surface untouched) is identical-modulo-rename → rc 0, no
# output. Exercises both a provider-column and a consumer-column rewrite.
case_jimpartition_edges_diff_identical() {
  local before after
  before=$(fixture ed_id_before.tsv "$(printf 'orders\tcart-session-api\tcart\ncart\tledger feed\tvendor')")
  after=$(fixture ed_id_after.tsv "$(printf 'orders\tcart-session-api\tcheckout\ncheckout\tledger feed\tvendor')")
  run_jimpartition edges-diff "$before" "$after" cart checkout
  assert_exit "rc" 0 "$RC"
  assert_eq "no divergence" "" "$OUT"
}

# AC #14: a dropped edge is a MISSING divergence → rc 1.
case_jimpartition_edges_diff_dropped() {
  local before after T; T=$'\t'
  before=$(fixture ed_dr_before.tsv "$(printf 'orders\tcart-session-api\tcart\nbilling\tcart-session-api\tcart')")
  after=$(fixture ed_dr_after.tsv "$(printf 'orders\tcart-session-api\tcheckout')")
  run_jimpartition edges-diff "$before" "$after" cart checkout
  assert_exit "rc" 1 "$RC"
  assert_match "billing edge missing" "^MISSING${T}billing${T}cart-session-api${T}checkout$" "$OUT"
}

# AC #14: an extra edge not present modulo-rename is an EXTRA divergence → rc 1.
case_jimpartition_edges_diff_extra() {
  local before after T; T=$'\t'
  before=$(fixture ed_ex_before.tsv "$(printf 'orders\tcart-session-api\tcart')")
  after=$(fixture ed_ex_after.tsv "$(printf 'orders\tcart-session-api\tcheckout\nsurprise\tnew feed\tcheckout')")
  run_jimpartition edges-diff "$before" "$after" cart checkout
  assert_exit "rc" 1 "$RC"
  assert_match "surprise edge extra" "^EXTRA${T}surprise${T}new feed${T}checkout$" "$OUT"
}

# AC #11 ratchet: rewriting the relies-on surface half (cart-session-api →
# checkout-session-api) is a divergence — only the group-slug columns rename.
case_jimpartition_edges_diff_surface_rewrite_divergent() {
  local before after T; T=$'\t'
  before=$(fixture ed_sr_before.tsv "$(printf 'orders\tcart-session-api\tcart')")
  after=$(fixture ed_sr_after.tsv "$(printf 'orders\tcheckout-session-api\tcheckout')")
  run_jimpartition edges-diff "$before" "$after" cart checkout
  assert_exit "rc" 1 "$RC"
  assert_match "expected surface untouched missing" "^MISSING${T}orders${T}cart-session-api${T}checkout$" "$OUT"
  assert_match "rewritten surface extra"            "^EXTRA${T}orders${T}checkout-session-api${T}checkout$" "$OUT"
}

# rc 2 on a missing argument.
case_jimpartition_edges_diff_missing_args() {
  local before; before=$(fixture ed_ma.tsv "$(printf 'orders\tx\tcart')")
  run_jimpartition edges-diff "$before" cart checkout
  assert_exit "rc" 2 "$RC"
}

# rc 2 when an input file is absent.
case_jimpartition_edges_diff_missing_file() {
  local before; before=$(fixture ed_mf.tsv "$(printf 'orders\tx\tcart')")
  run_jimpartition edges-diff "$before" "$TMP_BASE/no-such-after.tsv" cart checkout
  assert_exit "rc" 2 "$RC"
}

# ─── Section: rename continuity + ratchet (Task 7) ───────────────────────────

# AC #11: invariant ids and provides surface names are byte-for-byte unchanged
# across a rename (they ratchet — stable keys / code-tracking descriptions),
# even when the blueprint's identity PROSE is rewritten.
case_jimpartition_rename_identifier_ratchet() {
  local dir; dir="$(rename_repo r7_ratchet)"
  local bp_old="$dir/docs/specs/cart/000-blueprint/spec.md"
  local before_faces; before_faces="$(bash "$SCRIPT_jimverify" faces "$bp_old")"
  ( cd "$dir" && bash "$SCRIPT_JIMLEDGER" rename-tracked docs/specs/cart docs/specs/checkout ) >/dev/null 2>&1
  local bp_new="$dir/docs/specs/checkout/000-blueprint/spec.md"
  # the --rename arm rewrites identity prose only (heading + group mention)
  sed -i 's/# cart —/# checkout —/; s/The cart group/The checkout group/' "$bp_new"
  assert_eq    "provides surface names unchanged" "$before_faces" "$(bash "$SCRIPT_jimverify" faces "$bp_new")"
  assert_match "invariant id preserved"           'session-shape' "$(cat "$bp_new")"
  assert_eq    "identity prose did update"        "1" "$(grep -c 'The checkout group' "$bp_new")"
}

# AC #10/#11: a sibling's dotted requires key re-points its group half only
# (cart.<surface> → checkout.<surface>); the surface half is untouched.
case_jimpartition_rename_dotted_repoint() {
  local dir; dir="$(rename_repo r7_dotted)"
  local bp="$dir/docs/specs/orders/000-blueprint/spec.md"
  sed -i 's/`cart\.cart-session-api`/`checkout.cart-session-api`/' "$bp"
  local faces; faces="$(bash "$SCRIPT_jimverify" faces "$bp")"
  assert_match "group half re-pointed"        'checkout\.cart-session-api' "$faces"
  assert_eq    "old dotted group half gone" "0" "$(printf '%s\n' "$faces" | grep -c 'cart\.cart-session-api')"
}

# AC #15: after materializing the identity edits, a re-run occurrence sweep finds
# zero pure-identity old-name mentions — no dotted-key and no config-key hits
# survive (every remaining mention is a classified code-surface or historical
# keep). A frozen numbered spec's historical body text is left untouched.
case_jimpartition_rename_zero_unclassified_sweep() {
  local dir; dir="$(rename_repo r7_sweep)"
  # --- simulate the full arm-b (docs-only) identity materialization ---
  ( cd "$dir" && bash "$SCRIPT_JIMLEDGER" rename-tracked docs/specs/cart docs/specs/checkout ) >/dev/null 2>&1
  sed -i 's/`cart\.cart-session-api`/`checkout.cart-session-api`/' \
    "$dir/docs/specs/orders/000-blueprint/spec.md" \
    "$dir/docs/specs/billing/000-blueprint/spec.md"
  sed -i 's/the cart group/the checkout group/' "$dir/docs/specs/billing/000-blueprint/spec.md"
  sed -i 's/# cart —/# checkout —/; s/The cart group/The checkout group/' \
    "$dir/docs/specs/checkout/000-blueprint/spec.md"
  sed -i 's/### cart/### checkout/; s/depends on cart/depends on checkout/; s/| cart |/| checkout |/' "$dir/BLUEPRINT.md"
  sed -i 's/verify_appetite_cart/verify_appetite_checkout/' "$dir/jimconf.toml"
  # --- sweep: no pure-identity (dotted-key / config-key) old-name hits remain ---
  run_jimpartition_in "$dir" occurrences cart \
    BLUEPRINT.md jimconf.toml \
    docs/specs/orders/000-blueprint/spec.md \
    docs/specs/billing/000-blueprint/spec.md \
    docs/specs/checkout/000-blueprint/spec.md
  assert_exit "rc" 0 "$RC"
  assert_eq "no dotted-key identity remains" "0" "$(printf '%s\n' "$OUT" | grep -c 'dotted-key')"
  assert_eq "no config-key identity remains" "0" "$(printf '%s\n' "$OUT" | grep -c 'config-key')"
  # a historical keep is preserved — the frozen numbered spec still mentions cart
  run_jimpartition_in "$dir" occurrences cart docs/specs/checkout/001-initial/spec.md
  assert_match "historical mention preserved" '^HIT.*prose$' "$OUT"
}

# ─── spec 044: health-eval (threshold evaluation over the reconcile series) ───

# recline <iso> <breaking> <cycles> <fanin> <uncovered> <faces_max>
#   One `blueprint finished op=reconcile` ledger line with the given counters
#   (edges/faces fixed, other finding counters zeroed). The epoch field is a
#   constant — the series verb keys on iso/phase/event/kv only.
recline() {
  printf '1\t%s\tblueprint\tfinished\ttier=project;op=reconcile;edges=5;leaks=0;breaking=%s;dead=0;unresolved=0;undeclared=0;stale=0;groups=3;cycles=%s;fanin=%s;uncovered=%s;faces=10;faces_max=%s\n' \
    "$1" "$2" "$3" "$4" "$5" "$6"
}

# health_fixture <name> <ledger-content> [<jimconf-content>]
#   Build a working dir with spec/ledger.md (the reconcile series) and an
#   optional jimconf.toml (threshold config). Print the working-dir path; the
#   specs-dir is <printed>/spec, and health-eval is invoked with CWD=<printed>
#   so jimconf.sh resolves ./jimconf.toml.
health_fixture() {
  local name="$1" ledger="$2" conf="${3:-}"
  local w="$TMP_BASE/$name"
  mkdir -p "$w/spec"
  printf '%s\n' "$ledger" > "$w/spec/ledger.md"
  [[ -n "$conf" ]] && printf '%s\n' "$conf" > "$w/jimconf.toml"
  printf '%s' "$w"
}

# AC: with no thresholds configured, health-eval reports all five disabled and
# fires nothing — the silent-hook path (spec 044 AC #5, Task 4).
case_jimpartition_health_eval_no_thresholds() {
  local w; w="$(health_fixture t44hent "$(recline 2026-01-01T00:00:00Z 0 2 3 1 5)")"
  run_jimpartition_in "$w" health-eval "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_eq "all five disabled" "$(printf 'THRESHOLDS\t0\t5')" "$(printf '%s\n' "$OUT" | grep '^THRESHOLDS')"
  assert_eq "no CROSSED" "0" "$(printf '%s\n' "$OUT" | grep -c '^CROSSED')"
}

# AC: a junk threshold value disables that key and is noted with INVALID; a
# valid sibling still arms (spec 032 semantics; spec 044 AC #6, Task 4).
case_jimpartition_health_eval_junk_invalid() {
  local w; w="$(health_fixture t44hei "$(recline 2026-01-01T00:00:00Z 0 0 2 0 5)" 'health_threshold_cycles = "abc"
health_threshold_fanin = "2"')"
  run_jimpartition_in "$w" health-eval "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_match "cycles noted invalid" 'INVALID[[:space:]]health_threshold_cycles' "$OUT"
  assert_eq "one active four disabled" "$(printf 'THRESHOLDS\t1\t4')" "$(printf '%s\n' "$OUT" | grep '^THRESHOLDS')"
}

# AC: a latest-value predicate fires when the newest event's counter meets the
# threshold; observed value + threshold ride the CROSSED fact (spec 044 Task 4).
case_jimpartition_health_eval_latest_fires() {
  local w; w="$(health_fixture t44hef "$( { recline 2026-01-01T00:00:00Z 0 0 3 1 5; recline 2026-02-01T00:00:00Z 0 2 3 1 5; } )" 'health_threshold_cycles = "2"')"
  run_jimpartition_in "$w" health-eval "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_match "cycles crossed at latest" 'CROSSED[[:space:]]cycles[[:space:]]2[[:space:]]2' "$OUT"
}

# AC: a latest-value predicate does NOT fire when the newest event is below the
# threshold, even if an earlier event crossed it (spec 044 Task 4).
case_jimpartition_health_eval_latest_below_no_fire() {
  local w; w="$(health_fixture t44henf "$( { recline 2026-01-01T00:00:00Z 0 5 3 1 5; recline 2026-02-01T00:00:00Z 0 1 3 1 5; } )" 'health_threshold_cycles = "2"')"
  run_jimpartition_in "$w" health-eval "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_eq "no CROSSED" "0" "$(printf '%s\n' "$OUT" | grep -c '^CROSSED')"
}

# AC: an `na` latest value never crosses — a not-computable coverage read is
# never treated as healthy or as a numeric crossing (spec 044 AC #13, Task 4).
case_jimpartition_health_eval_na_never_crosses() {
  local w; w="$(health_fixture t44hena "$(recline 2026-01-01T00:00:00Z 0 0 3 na 5)" 'health_threshold_uncovered = "1"')"
  run_jimpartition_in "$w" health-eval "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_eq "na does not cross" "0" "$(printf '%s\n' "$OUT" | grep -c '^CROSSED')"
}

# AC: breaking_runs fires on the trailing consecutive count of events with
# breaking>0 (a single noisy reconcile does not arm); observed = run length
# (spec 044 DD #3, Task 4).
case_jimpartition_health_eval_breaking_run_fires() {
  local w; w="$(health_fixture t44hebr "$( { recline 2026-01-01T00:00:00Z 0 0 3 1 5; recline 2026-02-01T00:00:00Z 1 0 3 1 5; recline 2026-03-01T00:00:00Z 1 0 3 1 5; } )" 'health_threshold_breaking_runs = "2"')"
  run_jimpartition_in "$w" health-eval "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_match "breaking run crosses" 'CROSSED[[:space:]]breaking_runs[[:space:]]2[[:space:]]2' "$OUT"
}

# AC: a broken trailing run does not arm breaking_runs — the last event carries
# breaking but the prior event reset the run (spec 044 DD #3, Task 4).
case_jimpartition_health_eval_breaking_run_broken() {
  local w; w="$(health_fixture t44hebb "$( { recline 2026-01-01T00:00:00Z 1 0 3 1 5; recline 2026-02-01T00:00:00Z 0 0 3 1 5; recline 2026-03-01T00:00:00Z 1 0 3 1 5; } )" 'health_threshold_breaking_runs = "2"')"
  run_jimpartition_in "$w" health-eval "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_eq "no CROSSED" "0" "$(printf '%s\n' "$OUT" | grep -c '^CROSSED')"
}

# AC: with no reconcile series, health-eval returns rc 1 (nothing to evaluate).
case_jimpartition_health_eval_no_series_rc1() {
  local w; w="$(health_fixture t44hens "$(printf '1\t2026-01-01T00:00:00Z\tplan\tfinished\t')" 'health_threshold_cycles = "1"')"
  run_jimpartition_in "$w" health-eval "$w/spec"
  assert_exit "rc" 1 "$RC"
}

# AC: a missing specs-dir argument is a usage error (rc 2).
case_jimpartition_health_eval_bad_args_rc2() {
  run_jimpartition health-eval
  assert_exit "rc" 2 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# ─── spec 044: identity-check (territory name-mismatch sensor) ────────────────

# identity_map <name> <groups-body> — write a BLUEPRINT.md with a ## Groups
#   section (the given body) and print its path.
identity_map() {
  local name="$1" body="$2"
  local p="$TMP_BASE/$name.md"
  { printf '# Map\n\n## Groups\n\n'; printf '%s\n' "$body"; printf '\n## Contract Graph\n'; } > "$p"
  printf '%s' "$p"
}

# AC: a group whose territory path embeds ANOTHER current group's slug as a
# whole token is flagged foreign; the group's own-name territory is never
# flagged (spec 044 AC #8, Task 5).
case_jimpartition_identity_check_foreign() {
  local map; map="$(identity_map t44icf '### payments
- Territory: `src/orders/**`

### orders
- Territory: `src/orders/**`')"
  run_jimpartition identity-check "$map"
  assert_exit "rc" 0 "$RC"
  assert_eq "foreign mismatch flagged" "$(printf 'MISMATCH\tpayments\tsrc/orders/**\torders\tforeign')" "$(printf '%s\n' "$OUT" | grep '^MISMATCH')"
  assert_eq "orders own territory clean" "0" "$(printf '%s\n' "$OUT" | grep -c '^MISMATCH	orders')"
}

# AC: a territory embedding a RETIRED slug (old= from a partition op=rename
# event) is flagged retired, but only when a specs-dir with the ledger is given
# — the stalled docs-only rename of issue #71 (spec 044 AC #8, DD #5, Task 5).
case_jimpartition_identity_check_retired() {
  local w; w="$TMP_BASE/t44icr"; mkdir -p "$w/spec"
  local map; map="$(identity_map t44icr_map '### payments
- Territory: `src/billing/**`

### orders
- Territory: `src/orders/**`')"
  printf '1\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=rename;old=billing;new=payments\n' > "$w/spec/ledger.md"
  run_jimpartition identity-check "$map" "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_eq "retired mismatch flagged" "$(printf 'MISMATCH\tpayments\tsrc/billing/**\tbilling\tretired')" "$(printf '%s\n' "$OUT" | grep '^MISMATCH')"
  run_jimpartition identity-check "$map"
  assert_eq "no retired class without specs-dir" "0" "$(printf '%s\n' "$OUT" | grep -c '^MISMATCH')"
}

# AC: a territory embedding no identity token is not a mismatch — the
# false-positive guard (spec 044 AC #8, Task 5).
case_jimpartition_identity_check_token_free_silent() {
  local map; map="$(identity_map t44ictf '### payments
- Territory: `src/lib/**`

### orders
- Territory: `src/orders/**`')"
  run_jimpartition identity-check "$map"
  assert_exit "rc" 0 "$RC"
  assert_eq "no mismatch at all" "0" "$(printf '%s\n' "$OUT" | grep -c '^MISMATCH')"
}

# AC: a non-slug group heading is not a group — it is neither scanned nor a
# foreign-match target (map_group_slugs slug-gates the H3s; spec 044 Task 5).
case_jimpartition_identity_check_nonslug_excluded() {
  local map; map="$(identity_map t44icn '### Payments
- Territory: `src/orders/**`

### orders
- Territory: `src/orders/**`')"
  run_jimpartition identity-check "$map"
  assert_exit "rc" 0 "$RC"
  assert_eq "non-slug group excluded" "0" "$(printf '%s\n' "$OUT" | grep -c '^MISMATCH')"
}

# AC: an absent map is rejected rc 2; a missing map argument is rc 2.
case_jimpartition_identity_check_no_map_rc2() {
  run_jimpartition identity-check "$TMP_BASE/nonexistent-map.md"
  assert_exit "absent map rc" 2 "$RC"
  assert_nonempty "stderr explains" "$ERR"
  run_jimpartition identity-check
  assert_exit "missing arg rc" 2 "$RC"
}

# ─── Section: rewrite-identity cases (spec 046) ──────────────────────────────

# rewrite_repo <name> — a rename_repo whose frozen numbered cart/001-initial
#   spec is enriched with the three structural identity positions the verb
#   rewrites (frontmatter `group:` value, a dotted requires group-half, a typed
#   `Spec: <group>/NNN` ref) plus two free-prose `cart` mentions (the
#   freeze-on-doubt boundary). Committed so the tree is clean and the numbered
#   spec is tracked (the containment guard rejects an untracked target). Prints
#   the repo dir.
rewrite_repo() {
  local repo; repo="$(rename_repo "$1")"
  cat > "$repo/docs/specs/cart/001-initial/spec.md" <<'EOF'
---
group: "cart"
---

# 001 initial cart design

Requires `cart.cart-session-api` from the cart group.
Supersedes Spec: cart/000 during checkout.

The cart group was introduced to hold session logic during checkout.
EOF
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "enrich numbered spec with identity positions"
  printf '%s' "$repo"
}

# AC #10/#11: rewrite edits the three structurally-unambiguous identity
# positions (group: frontmatter, dotted-key group-half, typed group/NNN ref) and
# leaves the dotted surface half and free prose untouched (freeze-on-doubt).
case_jimpartition_rewrite_identity_structural() {
  local repo body spec T; T=$'\t'
  repo="$(rewrite_repo rwid_struct)"
  spec="docs/specs/cart/001-initial/spec.md"
  run_jimpartition_in "$repo" rewrite-identity cart checkout "$spec"
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/$spec")"
  assert_match "group rewritten"        '^group: "checkout"$'          "$body"
  assert_eq    "no old group remains"   "0" "$(printf '%s\n' "$body" | grep -c '^group: "cart"$')"
  assert_match "dotted group-half rewritten"  'checkout\.cart-session-api' "$body"
  assert_match "typed ref rewritten"          'Spec: checkout/000'         "$body"
  assert_match "prose cart mention preserved" 'the cart group'             "$body"
  assert_match "group record"  "^REWROTE${T}[^${T}]+${T}[0-9]+${T}group$"      "$OUT"
  assert_match "dotted record" "^REWROTE${T}[^${T}]+${T}[0-9]+${T}dotted-key$" "$OUT"
  assert_match "typed record"  "^REWROTE${T}[^${T}]+${T}[0-9]+${T}typed-ref$"  "$OUT"
}

# AC #10 / security Finding 6: success output is location-only — never the
# matched or surrounding line content.
case_jimpartition_rewrite_identity_location_only() {
  local repo spec T; T=$'\t'
  repo="$(rewrite_repo rwid_loc)"; spec="docs/specs/cart/001-initial/spec.md"
  run_jimpartition_in "$repo" rewrite-identity cart checkout "$spec"
  assert_exit "rc" 0 "$RC"
  assert_eq "no 'session' leak"  "0" "$(printf '%s\n' "$OUT" | grep -c 'session')"
  assert_eq "no 'Requires' leak" "0" "$(printf '%s\n' "$OUT" | grep -c 'Requires')"
  assert_eq "all lines REWROTE-shaped" "0" \
    "$(printf '%s\n' "$OUT" | grep -vcE "^REWROTE${T}[^${T}]+${T}[0-9]+${T}(group|dotted-key|typed-ref)$")"
}

# AC #11: a second identical run rewrites nothing (idempotent) — the file is
# byte-stable and no REWROTE line is emitted.
case_jimpartition_rewrite_identity_idempotent() {
  local repo spec before after
  repo="$(rewrite_repo rwid_idem)"; spec="docs/specs/cart/001-initial/spec.md"
  run_jimpartition_in "$repo" rewrite-identity cart checkout "$spec"
  assert_exit "first run rc" 0 "$RC"
  before="$(cat "$repo/$spec")"
  run_jimpartition_in "$repo" rewrite-identity cart checkout "$spec"
  assert_exit "second run rc" 0 "$RC"
  assert_eq "no rewrites second run" "" "$OUT"
  after="$(cat "$repo/$spec")"
  assert_eq "file byte-stable" "$before" "$after"
}

# security Finding 5: a target that symlinks out of the worktree is refused
# before any edit (containment guard), leaving the outside file untouched.
case_jimpartition_rewrite_identity_symlink_escape() {
  local repo outside
  repo="$(rewrite_repo rwid_sym)"
  outside="$TMP_BASE/rwid_outside_target.md"
  printf -- '---\ngroup: "cart"\n---\n' > "$outside"
  ln -s "$outside" "$repo/docs/specs/cart/escape.md"
  git -C "$repo" add -A && git -C "$repo" commit -q -m "add escaping symlink"
  run_jimpartition_in "$repo" rewrite-identity cart checkout docs/specs/cart/escape.md
  assert_exit "symlink-escape rc" 2 "$RC"
  assert_nonempty "stderr explains" "$ERR"
  assert_match "outside target intact" 'group: "cart"' "$(cat "$outside")"
}

# security Finding 5: an untracked target is refused (the verb edits only
# tracked numbered specs).
case_jimpartition_rewrite_identity_untracked() {
  local repo
  repo="$(rewrite_repo rwid_untrack)"
  printf -- '---\ngroup: "cart"\n---\n' > "$repo/docs/specs/cart/002-untracked.md"
  run_jimpartition_in "$repo" rewrite-identity cart checkout docs/specs/cart/002-untracked.md
  assert_exit "untracked rc" 2 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC #3 / security Finding 6: a malformed frontmatter group value errors
# location-only (rc 2), echoes no content, and applies no edit.
case_jimpartition_rewrite_identity_malformed_group() {
  local repo spec
  repo="$(rewrite_repo rwid_malformed)"; spec="docs/specs/cart/001-initial/spec.md"
  printf -- '---\ngroup: "not a slug!"\n---\n\n# body\n' > "$repo/$spec"
  git -C "$repo" add -A && git -C "$repo" commit -q -m "malformed group value"
  run_jimpartition_in "$repo" rewrite-identity cart checkout "$spec"
  assert_exit "malformed rc" 2 "$RC"
  assert_nonempty "stderr explains" "$ERR"
  assert_eq "no content echoed" "0" "$(printf '%s\n' "$ERR" | grep -c 'not a slug')"
  assert_match "file left unedited" 'not a slug!' "$(cat "$repo/$spec")"
}

# rc 2 on an invalid slug and on no file arguments (a recorded name can never
# inject; usage is a caller error).
case_jimpartition_rewrite_identity_usage() {
  local repo
  repo="$(rewrite_repo rwid_usage)"
  run_jimpartition_in "$repo" rewrite-identity 'Bad.Slug' checkout docs/specs/cart/001-initial/spec.md
  assert_exit "invalid old slug rc" 2 "$RC"
  run_jimpartition_in "$repo" rewrite-identity cart checkout
  assert_exit "no files rc" 2 "$RC"
}

# ─── rewrite-identity hardening (spec 047 Task 8; closes #77 / #78) ───────────

# rwid_hard_repo <name> — a rename_repo whose numbered cart spec carries the
#   over-match positions #77/#78 name: a real dotted-key (rewritten), a typed body
#   ref (rewritten), a non-group frontmatter field, a file-extension dotted
#   (cart.json / cart.py — filenames, not group.surface), and a cart/handlers path
#   segment (a subdir, not a typed ref). Committed clean. Prints the repo dir.
rwid_hard_repo() {
  local repo; repo="$(rename_repo "$1")"
  cat > "$repo/docs/specs/cart/001-initial/spec.md" <<'EOF'
---
group: "cart"
origin: cart/006
---

# 001 initial cart design

Requires `cart.cart-session-api` from the cart group.
Supersedes Spec: cart/000 during checkout.
Config lives in cart.json and cart.py files.
Handlers live in cart.java and cart.c and cart.rb sources.
The path cart/handlers holds code.
EOF
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "enrich spec with over-match positions"
  printf '%s' "$repo"
}

# #77: the dotted-key rule excludes a bare file-extension suffix — cart.json /
# cart.py are filenames, left untouched, while a real group.surface dotted-key
# still rewrites.
case_jimpartition_rewrite_identity_skips_extension_dotted() {
  local repo spec body; repo="$(rwid_hard_repo rwid_ext)"
  spec="docs/specs/cart/001-initial/spec.md"
  run_jimpartition_in "$repo" rewrite-identity cart checkout "$spec"
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/$spec")"
  assert_match "cart.json filename untouched" 'cart\.json'                 "$body"
  assert_match "cart.py filename untouched"   'cart\.py'                   "$body"
  assert_match "real dotted-key rewritten"    'checkout\.cart-session-api' "$body"
}

# #77: the extension-exclusion set covers the source extensions classify_ext
# recognizes — a C-family / compiled-lang filename mention (cart.java / cart.c /
# cart.rb) is a filename, not a group.surface dotted-key, so it is left untouched.
case_jimpartition_rewrite_identity_skips_cfamily_extension() {
  local repo spec body; repo="$(rwid_hard_repo rwid_cfam)"
  spec="docs/specs/cart/001-initial/spec.md"
  run_jimpartition_in "$repo" rewrite-identity cart checkout "$spec"
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/$spec")"
  assert_match "cart.java untouched" 'cart\.java' "$body"
  assert_match "cart.c untouched"    'cart\.c'    "$body"
  assert_match "cart.rb untouched"   'cart\.rb'   "$body"
}

# #77: a non-group frontmatter field is skipped — identity in frontmatter is
# ONLY `group:`; a cart/NNN-shaped value elsewhere is left for rewrite-refs.
case_jimpartition_rewrite_identity_skips_nongroup_frontmatter() {
  local repo spec body; repo="$(rwid_hard_repo rwid_fm)"
  spec="docs/specs/cart/001-initial/spec.md"
  run_jimpartition_in "$repo" rewrite-identity cart checkout "$spec"
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/$spec")"
  assert_match "group identity rewritten"   '^group: "checkout"$' "$body"
  assert_match "non-group frontmatter kept" '^origin: cart/006$'  "$body"
}

# #78: a cart/subdir path segment is left untouched — only <old>/<digit> is a
# typed ref (the after2 alpha-negative branch).
case_jimpartition_rewrite_identity_path_segment_untouched() {
  local repo spec; repo="$(rwid_hard_repo rwid_seg)"
  spec="docs/specs/cart/001-initial/spec.md"
  run_jimpartition_in "$repo" rewrite-identity cart checkout "$spec"
  assert_exit "rc" 0 "$RC"
  assert_match "path segment kept" 'cart/handlers' "$(cat "$repo/$spec")"
}

# #78: a multi-file batch with one guard-failing (untracked) target edits nothing
# — the good tracked spec is left unedited (all guards before any edit).
case_jimpartition_rewrite_identity_guard_abort() {
  local repo good; repo="$(rwid_hard_repo rwid_ga)"
  good="docs/specs/cart/001-initial/spec.md"
  printf -- '---\ngroup: "cart"\n---\n' > "$repo/docs/specs/cart/002-untracked.md"  # untracked
  run_jimpartition_in "$repo" rewrite-identity cart checkout "$good" docs/specs/cart/002-untracked.md
  assert_exit "rc" 2 "$RC"
  assert_match "good file unedited" '^group: "cart"$' "$(cat "$repo/$good")"
}

# #78: a '..'-segment target is refused by the valid_relpath boundary (rc 2).
case_jimpartition_rewrite_identity_dotdot_rejected() {
  local repo; repo="$(rwid_hard_repo rwid_dd)"
  run_jimpartition_in "$repo" rewrite-identity cart checkout ../escape.md
  assert_exit "rc" 2 "$RC"
}

# #78: an invalid <new> slug is a usage error (rc 2) — distinct from the existing
# invalid-<old> case.
case_jimpartition_rewrite_identity_invalid_new_slug() {
  local repo; repo="$(rwid_hard_repo rwid_bn)"
  run_jimpartition_in "$repo" rewrite-identity cart 'Bad_New' docs/specs/cart/001-initial/spec.md
  assert_exit "rc" 2 "$RC"
}

# #78: outside a git repo the containment top cannot resolve → rc 2 before any edit.
case_jimpartition_rewrite_identity_no_git_repo() {
  local d; d="$(empty_dir rwid_nogit)"
  printf -- '---\ngroup: "cart"\n---\n' > "$d/spec.md"
  run_jimpartition_in "$d" rewrite-identity cart checkout spec.md
  assert_exit "rc" 2 "$RC"
}

# jimpart_failing_awk_shim <name>
#   A directory holding an `awk` that fails mid-stream — but ONLY for a rewrite
#   verb's own invocation, identified by its `recfile=` binding; everything else
#   execs the real awk. It writes a REWROTE record first, so the record file is
#   non-empty exactly as it would be when a real awk dies partway through a file
#   it had already rewritten lines of.
jimpart_failing_awk_shim() {
  local dir real
  dir=$(empty_dir "$1")
  real="$(command -v awk)"
  {
    printf '%s\n' '#!/usr/bin/env bash' 'set -uo pipefail' 'for a in "$@"; do'
    printf '%s\n' '  case "$a" in'
    printf '%s\n' '    recfile=*)'
    printf '%s\n' '      printf "REWROTE\\tsentinel\\t1\\ttyped-ref\\n" > "${a#recfile=}"'
    printf '%s\n' '      printf "truncated\\n"; exit 1 ;;'
    printf '%s\n' '  esac' 'done'
    printf 'exec %s "$@"\n' "$real"
  } > "$dir/awk"
  chmod +x "$dir/awk"
  printf '%s' "$dir"
}

# A rewritten file is installed only when awk actually succeeded. A mid-stream
# failure after at least one REWROTE record leaves the record file non-empty, so
# the record-based guard alone would install a truncated file over a real one.
case_jimpartition_rewrite_identity_awk_failure_does_not_install() {
  local repo spec shim before oldpath
  repo="$(rewrite_repo rwid_awkfail)"
  spec="docs/specs/cart/001-initial/spec.md"
  before="$(cat "$repo/$spec")"
  shim=$(jimpart_failing_awk_shim rwid_awkfail_bin)
  oldpath="$PATH"; PATH="$shim:$PATH"
  run_jimpartition_in "$repo" rewrite-identity cart checkout "$spec"
  PATH="$oldpath"
  assert_exit "rc" 1 "$RC"
  assert_eq "file byte-unchanged" "$before" "$(cat "$repo/$spec")"
  assert_eq "no truncated marker" "0" "$(grep -c '^truncated$' "$repo/$spec")"
  assert_eq "no REWROTE claimed" "0" "$(printf '%s\n' "$OUT" | grep -c 'REWROTE')"
}

# ─── Section: rewrite-identity --skip-typed-refs (spec 051) ───────────────────

# skiptyped_repo <name> — a git_init repo with one tracked numbered-spec fixture
#   carrying all three identity positions: a frontmatter group: value, a body
#   dotted-key group-half, and a typed group/NNN ref. The --skip-typed-refs cases
#   assert the flag drops ONLY the typed ref while group:/dotted-key still rewrite;
#   the unflagged case pins today's behavior on the same fixture.
skiptyped_repo() {
  local dir; dir="$(git_init "$1")"
  repo_add "$dir" spec.md $'---\ngroup: "cart"\n---\n\nRequires cart.session-api now.\nSupersedes cart/002 here.'
  printf '%s' "$dir"
}

# 051 AC 1: with --skip-typed-refs the typed group/NNN ref is left untouched and
# emits no typed-ref record, while the group: and dotted-key rewrites still land.
case_jimpartition_rewrite_identity_skip_typed_refs() {
  local dir body T; T=$'\t'
  dir="$(skiptyped_repo rwid_skiptyped)"
  run_jimpartition_in "$dir" rewrite-identity --skip-typed-refs cart checkout spec.md
  assert_exit "rc" 0 "$RC"
  body="$(cat "$dir/spec.md")"
  assert_match "group rewritten"      '^group: "checkout"$'      "$body"
  assert_match "dotted-key rewritten" 'checkout\.session-api'    "$body"
  assert_match "typed ref untouched"  'Supersedes cart/002 here' "$body"
  assert_eq    "typed ref not rewritten" "0" "$(printf '%s\n' "$body" | grep -c 'checkout/002')"
  assert_match "group record"  "^REWROTE${T}[^${T}]+${T}[0-9]+${T}group$"      "$OUT"
  assert_match "dotted record" "^REWROTE${T}[^${T}]+${T}[0-9]+${T}dotted-key$" "$OUT"
  assert_eq    "no typed-ref record"  "0" "$(printf '%s\n' "$OUT" | grep -c 'typed-ref')"
}

# 051 AC 3: without the flag the same fixture rewrites the typed ref number-
# preserving (today's rename-path behavior) — the flag only NARROWS the pass.
case_jimpartition_rewrite_identity_typed_refs_default_on() {
  local dir body T; T=$'\t'
  dir="$(skiptyped_repo rwid_skiptyped_off)"
  run_jimpartition_in "$dir" rewrite-identity cart checkout spec.md
  assert_exit "rc" 0 "$RC"
  body="$(cat "$dir/spec.md")"
  assert_match "typed ref rewritten"  'Supersedes checkout/002 here' "$body"
  assert_match "typed record present" "^REWROTE${T}[^${T}]+${T}[0-9]+${T}typed-ref$" "$OUT"
}

# ─── Section: pending-provisional preflight refusals ─────────────────────────

# AC 10: a group holding a spec bound while the coordination point was
# unreachable cannot be moved — the identity has not been issued yet, so a move
# would leave a pending claim under a name the allocator resolves away from.
# Rename refuses, naming every pending identity.
case_jimpartition_rename_preflight_refuses_provisional() {
  local dir; dir="$(rename_repo pfprov_rename)"
  mkdir -p "$dir/docs/specs/cart/P-20260802-offline-work"
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart checkout
  assert_exit  "rc" 1 "$RC"
  assert_match "check fails"          'pending-provisionals.*fail'  "$OUT"
  assert_match "names the identity"   'P-20260802-offline-work'     "$OUT"
  assert_match "names the remedy"     'reconcile'                   "$ERR"
}

# AC 10: split refuses on the same shape — symmetric with rename, rather than
# hard-failing later in the renumber map.
case_jimpartition_split_preflight_refuses_provisional() {
  local dir; dir="$(split_repo pfprov_split)"
  mkdir -p "$dir/docs/specs/cart/P-20260802-offline-work"
  run_jimpartition_in "$dir" split-preflight BLUEPRINT.md docs/specs cart shop store
  assert_exit  "rc" 1 "$RC"
  assert_match "check fails"        'pending-provisionals.*fail' "$OUT"
  assert_match "names the identity" 'P-20260802-offline-work'    "$OUT"
}

# AC 10: merge refuses on the same shape too — the side that used to skip a
# pending dir silently is the one this closes.
case_jimpartition_merge_preflight_refuses_provisional() {
  local dir; dir="$(merge_repo pfprov_merge)"
  mkdir -p "$dir/docs/specs/wishlist/P-20260802-offline-work"
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs cart wishlist
  assert_exit  "rc" 1 "$RC"
  assert_match "check fails"        'pending-provisionals.*fail' "$OUT"
  assert_match "names the identity" 'P-20260802-offline-work'    "$OUT"
}

# "Naming every pending identity" must say when it could not: a long list is
# capped for display, and a cap without a note reads as the whole list — the
# sweep's own truncation discipline, applied to the preflight fact.
case_jimpartition_pending_provisional_list_truncation_is_noted() {
  local dir i
  dir="$(rename_repo pftrunc)"
  for i in $(seq 1 24); do
    mkdir -p "$dir/docs/specs/cart/P-20260801-pending-identity-number-$(printf '%02d' "$i")"
  done
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart checkout
  assert_exit  "rc" 1 "$RC"
  assert_match "the cut is disclosed" 'list truncated' "$OUT"
}

# The other half, which the positive case above cannot see: a list that FITS
# must not claim it was cut. A note that fires either way carries no information.
case_jimpartition_pending_provisional_short_list_is_not_noted() {
  local dir
  dir="$(rename_repo pfshort)"
  mkdir -p "$dir/docs/specs/cart/P-20260801-one" "$dir/docs/specs/cart/P-20260801-two"
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart checkout
  assert_exit "rc" 1 "$RC"
  assert_eq "no truncation claimed" "0" \
    "$(printf '%s\n' "$OUT" | grep -c 'truncated')"
  assert_match "both identities named" 'P-20260801-one' "$OUT"
}

# The false positive the comparison had to be written around. A basename is not
# token-gated on the way in, so a control byte makes the SANITIZED string differ
# from the raw one — comparing those two would report a truncation on a list
# that is complete, and the operator would go looking for identities that are
# all already there.
case_jimpartition_pending_provisional_control_byte_is_not_a_truncation() {
  local dir esc
  dir="$(rename_repo pfctl)"
  esc="$(printf 'P-20260801-evil\033mark')"
  mkdir -p "$dir/docs/specs/cart/$esc"
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart checkout
  assert_exit "rc" 1 "$RC"
  assert_eq "a stripped byte is not a cut" "0" \
    "$(printf '%s\n' "$OUT" | grep -c 'truncated')"
  # The fact grammar is tab-separated, so tabs are expected; ESC is what must
  # not survive into a terminal.
  assert_eq "the escape byte is stripped" "0" \
    "$(printf '%s' "$OUT" | LC_ALL=C grep -c $'\033')"
}

# The funnel every CHECK detail crosses. Disclosing the cut here rather than at
# each caller is what makes it impossible for a caller to forget — and it is
# reachable, since a caller-supplied path is a detail with no length gate of
# its own.
case_jimpartition_check_detail_truncation_is_disclosed() {
  local dir long
  dir="$(rename_repo pfemit)"
  long="$(printf 'aaaaaaaaaa/%.0s' $(seq 1 60))map.md"
  run_jimpartition_in "$dir" rename-preflight "$long" docs/specs cart checkout
  assert_exit  "rc" 1 "$RC"
  assert_match "the fact says it was cut" 'map not found: a.* … .truncated.' "$OUT"
}

# The other half: a detail that fits is not annotated. Without this, the note
# above could fire unconditionally and still pass.
case_jimpartition_check_detail_short_is_not_annotated() {
  local dir
  dir="$(rename_repo pfemitshort)"
  run_jimpartition_in "$dir" rename-preflight nosuchmap.md docs/specs cart checkout
  assert_exit "rc" 1 "$RC"
  assert_match "the short detail is verbatim" 'map not found: nosuchmap.md' "$OUT"
  assert_eq "nothing claims a cut" "0" "$(printf '%s\n' "$OUT" | grep -c 'truncated')"
}

# The registry-boundary rule: a dynamic path component is slug-validated before
# ANY filesystem lookup. merge-preflight passed its effective source set to the
# provisional probe ungated — the one probe in its function that did not follow
# the convention the surrounding code states twice.
case_jimpartition_merge_preflight_slug_gates_the_provisional_probe() {
  local dir; dir="$(merge_repo pfslug_merge)"
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs cart '../../OUTSIDE'
  assert_exit  "rc" 1 "$RC"
  assert_match "the probe is refused, not run" \
    $'pending-provisionals\tfail\t../../OUTSIDE: invalid group slug' "$OUT"
  assert_eq    "never reported as clean" "0" \
    "$(printf '%s\n' "$OUT" | grep -c $'pending-provisionals\tpass\t\\.\\./')"
}

# AC 10/18: the named identity is a directory basename — untrusted content —
# so it is sanitized before it is printed, exactly as every other preflight
# fact is.
case_jimpartition_preflight_provisional_name_is_sanitized() {
  local dir; dir="$(rename_repo pfprov_san)"
  mkdir -p "$dir/docs/specs/cart/$(printf 'P-20260802-a\tb')"
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart checkout
  assert_exit "rc" 1 "$RC"
  assert_eq   "no raw tab in the fact" "0" \
    "$(printf '%s\n' "$OUT" | grep 'pending-provisionals' | awk -F'\t' '{print NF}' | awk '$1>4' | grep -c .)"
}

# AC 10: a group with no pending provisional passes the check rather than
# having it silently absent — a gate that did not run must not read like a pass.
case_jimpartition_rename_preflight_provisional_check_passes_clean() {
  local dir; dir="$(rename_repo pfprov_clean)"
  run_jimpartition_in "$dir" rename-preflight BLUEPRINT.md docs/specs cart checkout
  assert_match "check present and passing" 'pending-provisionals.*pass' "$OUT"
}

# ─── Section: split-preflight cases (spec 047 Task 5) ────────────────────────

# AC 1/2: a clean extraction preflight — old ∈ targets, so the ARM is extraction,
# the remainder target (== old) is EXEMPT from the collision check even though its
# group and dir pre-exist, and the checkout target passes. rc 0.
case_jimpartition_split_preflight_extraction_pass() {
  local dir; dir="$(split_repo sp_extract)"
  run_jimpartition_in "$dir" split-preflight BLUEPRINT.md docs/specs cart cart checkout
  assert_exit "rc" 0 "$RC"
  assert_match "extraction arm"        'ARM.*extraction'              "$OUT"
  assert_match "old mapped"            'old-mapped.*pass'             "$OUT"
  assert_match "checkout no collision" 'target-collision:checkout.*pass' "$OUT"
  assert_eq    "remainder collision exempted" "0" "$(printf '%s\n' "$OUT" | grep -c 'target-collision:cart')"
  assert_match "territory identity"    'TERRITORY-IDENTITY.*modules/cart' "$OUT"
}

# AC 1: old ∉ targets → symmetric arm (the source is retired); both fresh targets
# clear the collision check. rc 0.
case_jimpartition_split_preflight_symmetric_pass() {
  local dir; dir="$(split_repo sp_sym)"
  run_jimpartition_in "$dir" split-preflight BLUEPRINT.md docs/specs cart shop store
  assert_exit "rc" 0 "$RC"
  assert_match "symmetric arm"    'ARM.*symmetric'            "$OUT"
  assert_match "shop no collision"  'target-collision:shop.*pass'  "$OUT"
  assert_match "store no collision" 'target-collision:store.*pass' "$OUT"
}

# AC 1: a duplicate target fails the arity check (rc 1, structural).
case_jimpartition_split_preflight_duplicate_target() {
  local dir; dir="$(split_repo sp_dup)"
  run_jimpartition_in "$dir" split-preflight BLUEPRINT.md docs/specs cart checkout checkout
  assert_exit "rc" 1 "$RC"
  assert_match "arity fail" 'targets-arity.*fail' "$OUT"
}

# AC 1: fewer than two targets fails the arity check (rc 1) — distinct from the
# no-targets usage error (rc 2).
case_jimpartition_split_preflight_too_few_targets() {
  local dir; dir="$(split_repo sp_few)"
  run_jimpartition_in "$dir" split-preflight BLUEPRINT.md docs/specs cart checkout
  assert_exit "rc" 1 "$RC"
  assert_match "arity fail" 'targets-arity.*fail' "$OUT"
}

# AC 1: a target colliding with an existing mapped group / spec dir fails (rc 1);
# the exemption is ONLY for a target equal to old.
case_jimpartition_split_preflight_collision() {
  local dir; dir="$(split_repo sp_coll)"
  run_jimpartition_in "$dir" split-preflight BLUEPRINT.md docs/specs cart shop orders
  assert_exit "rc" 1 "$RC"
  assert_match "orders collides" 'target-collision:orders.*fail' "$OUT"
}

# AC 2: a missing source 000-blueprint is a structural fail (rc 1).
case_jimpartition_split_preflight_missing_blueprint() {
  local dir; dir="$(split_repo sp_nobp)"
  rm -rf "$dir/docs/specs/cart/000-blueprint"
  run_jimpartition_in "$dir" split-preflight BLUEPRINT.md docs/specs cart cart checkout
  assert_exit "rc" 1 "$RC"
  assert_match "blueprint fail" 'blueprint-exists.*fail' "$OUT"
}

# AC 2: a dirty tree warn-confirms (non-fatal, rc 0) and classifies each dirty
# path as affected (inside the source spec dir) vs unrelated (rename parity).
case_jimpartition_split_preflight_dirty_tree_dirt() {
  local dir; dir="$(split_repo sp_dirt)"
  printf '# edited\n'   >> "$dir/docs/specs/cart/000-blueprint/spec.md"  # affected
  printf 'export const x = 1;\n' >> "$dir/modules/orders/order.js"       # unrelated
  run_jimpartition_in "$dir" split-preflight BLUEPRINT.md docs/specs cart cart checkout
  assert_exit "dirt is non-fatal" 0 "$RC"
  assert_match "tree-clean warns" 'tree-clean.*fail'              "$OUT"
  assert_match "affected dirt"    'DIRT.*affected.*000-blueprint' "$OUT"
  assert_match "unrelated dirt"   'DIRT.*unrelated.*order'        "$OUT"
}

# rc 2 on usage: no targets, or an invalid old slug (distinct from structural).
case_jimpartition_split_preflight_usage_rc2() {
  local dir; dir="$(split_repo sp_usage)"
  run_jimpartition_in "$dir" split-preflight BLUEPRINT.md docs/specs cart
  assert_exit "no targets rc" 2 "$RC"
  run_jimpartition_in "$dir" split-preflight BLUEPRINT.md docs/specs 'Bad/Old' cart checkout
  assert_exit "invalid old slug rc" 2 "$RC"
}

# ─── Section: renumber-map cases (spec 047 Task 6) ───────────────────────────

# AC 7/11: extraction tail move — the continuing remainder (child == old) keeps
# its numbers; the fresh child renumbers its arrivals densely from its peek-fed
# start, by source order.
case_jimpartition_renumber_map_extraction_tail() {
  local assign
  assign=$(fixture rm-tail.txt $'001\tcart\n002\tcart\n005\tcart\n006\tcheckout\n007\tcheckout\n008\tcheckout\n009\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=001
  assert_exit "rc" 0 "$RC"
  assert_match "remainder keeps 005" $'MAP\tcart/005\tcart/005'      "$OUT"
  assert_match "006 -> checkout/001" $'MAP\tcart/006\tcheckout/001'  "$OUT"
  assert_match "009 -> checkout/004" $'MAP\tcart/009\tcheckout/004'  "$OUT"
}

# AC 7: interleaved extraction — the remainder preserves its numbering gaps while
# the fresh child is dense from its start.
case_jimpartition_renumber_map_interleaved() {
  local assign
  assign=$(fixture rm-inter.txt $'001\tcart\n003\tcart\n005\tcheckout\n007\tcheckout\n009\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=001
  assert_exit "rc" 0 "$RC"
  assert_match "gap 003 preserved" $'MAP\tcart/003\tcart/003'     "$OUT"
  assert_match "fresh dense 005->001" $'MAP\tcart/005\tcheckout/001' "$OUT"
  assert_match "fresh dense 009->003" $'MAP\tcart/009\tcheckout/003' "$OUT"
}

# AC 7: symmetric split — old ∉ targets, so BOTH children are fresh and each
# carries its own start.
case_jimpartition_renumber_map_symmetric() {
  local assign
  assign=$(fixture rm-sym.txt $'001\tshop\n002\tshop\n003\tstore\n004\tstore')
  run_jimpartition renumber-map cart shop,store "$assign" shop=001 store=001
  assert_exit "rc" 0 "$RC"
  assert_match "shop from 001"  $'MAP\tcart/001\tshop/001'  "$OUT"
  assert_match "store from 001" $'MAP\tcart/003\tstore/001' "$OUT"
}

# AC 11: a wip row rides the renumber in source order, keeping its -wip suffix.
case_jimpartition_renumber_map_wip_rides() {
  local assign
  assign=$(fixture rm-wip.txt $'006\tcheckout\n007\tcheckout\n010-wip\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=001
  assert_exit "rc" 0 "$RC"
  assert_match "wip renumbered, suffix kept" $'MAP\tcart/010-wip\tcheckout/003-wip' "$OUT"
}

# A fresh child whose name was previously retired densifies from its peek-fed
# start, not from 001 — the registry never reissues a vacated ordinal, so the
# map must propose only ordinals the Close's partition-batch can accept.
case_jimpartition_renumber_map_start_resumes_retired_name() {
  local assign
  assign=$(fixture rm-retired.txt $'006\tcheckout\n007\tcheckout\n010-wip\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=053
  assert_exit "rc" 0 "$RC"
  assert_match "resumes at the start" $'MAP\tcart/006\tcheckout/053'      "$OUT"
  assert_match "dense from there"     $'MAP\tcart/007\tcheckout/054'      "$OUT"
  assert_match "wip rides in sequence" $'MAP\tcart/010-wip\tcheckout/055-wip' "$OUT"
}

# rc 2: every fresh child requires a start — the map must not silently assume
# 001 for a name whose registry high-water nobody consulted.
case_jimpartition_renumber_map_missing_start_rc2() {
  local assign
  assign=$(fixture rm-nostart.txt $'006\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign"
  assert_exit  "rc" 2 "$RC"
  assert_match "names the child and the remedy" 'checkout' "$ERR"
  assert_match "points at peek" 'peek' "$ERR"
}

# rc 2: the continuing child keeps its numbers — a start for it is a
# contradiction in the invocation.
case_jimpartition_renumber_map_start_for_continuing_child_rc2() {
  local assign
  assign=$(fixture rm-contstart.txt $'006\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=001 cart=005
  assert_exit "rc" 2 "$RC"
}

# rc 2: a start that is not <known-child>=<3-digit nonzero id> is refused.
case_jimpartition_renumber_map_bad_start_rc2() {
  local assign
  assign=$(fixture rm-badstart.txt $'006\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=0
  assert_exit "rc" 2 "$RC"
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=000
  assert_exit "rc" 2 "$RC"
  run_jimpartition renumber-map cart cart,checkout "$assign" nonesuch=004
  assert_exit "rc" 2 "$RC"
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=001 checkout=002
  assert_exit "rc" 2 "$RC"
}

# rc 1: an assignment that would pass the ordinal width bound exhausts the
# child's id space — no partial output, mirroring merge-map's overflow contract.
# Written AT the bound so the case pins its value, not merely that a cap exists.
case_jimpartition_renumber_map_start_overflow_rc1() {
  local assign
  assign=$(fixture rm-over.txt $'006\tcheckout\n007\tcheckout\n008\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=999999999999999
  assert_exit "rc" 1 "$RC"
  assert_eq   "no partial output" "" "$OUT"
}

# The start comes from `peek spec`, which answers past 999 for a group that has
# got that far — so a 4-digit start is a value the skill instructs an operator to
# paste in, and this verb must take it.
case_jimpartition_renumber_map_start_past_999_is_accepted() {
  local assign
  assign=$(fixture rm-wide.txt $'006\tcheckout\n007\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=1000
  assert_exit "rc" 0 "$RC"
  assert_eq   "dense from the 4-digit start" \
    "$(printf 'MAP\tcart/006\tcheckout/1000\nMAP\tcart/007\tcheckout/1001')" "$OUT"
}

# The source-token gate spans the same bound, probed on both edges.
case_jimpartition_renumber_map_source_width_bounds() {
  local assign
  assign=$(fixture rm-wsrc.txt $'1000\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=001
  assert_exit "a 4-digit source is representable" 0 "$RC"
  assign=$(fixture rm-osrc.txt $'1000000000000000\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=001
  assert_exit "past the bound is refused" 1 "$RC"
}

# rc 1: an assignment to a child not in the target set.
case_jimpartition_renumber_map_unknown_child_rc1() {
  local assign
  assign=$(fixture rm-unk.txt $'006\tnonesuch')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=001
  assert_exit "rc" 1 "$RC"
}

# rc 1: the same source id assigned twice.
case_jimpartition_renumber_map_duplicate_source_rc1() {
  local assign
  assign=$(fixture rm-dup.txt $'006\tcheckout\n006\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=001
  assert_exit "rc" 1 "$RC"
}

# rc 1: a source token that is not an NNN / NNN-wip shape.
case_jimpartition_renumber_map_bad_shape_rc1() {
  local assign
  assign=$(fixture rm-bad.txt $'6\tcheckout')
  run_jimpartition renumber-map cart cart,checkout "$assign" checkout=001
  assert_exit "rc" 1 "$RC"
}

# rc 2 on usage (missing args).
case_jimpartition_renumber_map_usage_rc2() {
  run_jimpartition renumber-map cart cart,checkout
  assert_exit "rc" 2 "$RC"
}

# ─── Section: rewrite-refs cases (spec 047 Task 7) ───────────────────────────

# AC 8: a typed group/NNN reference is rewritten whole-token to its remap target;
# the REWROTE record is location-only (no surrounding prose leaks).
case_jimpartition_rewrite_refs_typed_ref() {
  local dir; dir="$(git_init rr_typed)"
  repo_add "$dir" doc.md 'see cart/006 for details'
  printf 'cart/006\tcheckout/001\n' > "$dir/remap.tsv"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv doc.md
  assert_exit "rc" 0 "$RC"
  assert_eq "ref rewritten" "see checkout/001 for details" "$(cat "$dir/doc.md")"
  assert_match "location-only record" $'REWROTE\tdoc.md\t1\ttyped-ref' "$OUT"
  assert_eq "no content leaked" "0" "$(printf '%s\n' "$OUT" | grep -c 'details')"
}

# AC 8: a spec-directory path prefix (an issue origin: line) is rewritten — the
# dash after the number is a permitted delimiter; kind is path.
case_jimpartition_rewrite_refs_dir_path() {
  local dir; dir="$(git_init rr_path)"
  repo_add "$dir" issue.md 'origin: docs/specs/cart/006-checkout'
  printf 'cart/006\tcheckout/001\n' > "$dir/remap.tsv"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv issue.md
  assert_exit "rc" 0 "$RC"
  assert_eq "path prefix rewritten" "origin: docs/specs/checkout/001-checkout" "$(cat "$dir/issue.md")"
  assert_match "path kind" $'REWROTE\tissue.md\t1\tpath' "$OUT"
}

# security Finding 8: the boundary rule leaves cart/0060, cart/006abc, cart/006x,
# xcart/006, and cart-x/006 untouched (a longer digit / alnum after the number,
# or an alnum-dash before the group, breaks the whole-token match).
case_jimpartition_rewrite_refs_boundary_negatives() {
  local dir; dir="$(git_init rr_bound)"
  repo_add "$dir" neg.md $'a cart/0060 b\nc cart/006abc d\ne cart/006x f\ng xcart/006 h\ni cart-x/006 j'
  printf 'cart/006\tcheckout/001\n' > "$dir/remap.tsv"
  local before; before="$(cat "$dir/neg.md")"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv neg.md
  assert_exit "rc" 0 "$RC"
  assert_eq "no rewrites emitted" "0" "$(printf '%s\n' "$OUT" | grep -c 'REWROTE')"
  assert_eq "file byte-unchanged" "$before" "$(cat "$dir/neg.md")"
}

# AC 8: the remap IS the whitelist — a reference to an unmoved number (absent from
# the remap) is never touched, only the moved one is.
case_jimpartition_rewrite_refs_whitelist() {
  local dir; dir="$(git_init rr_wl)"
  repo_add "$dir" doc.md $'moved cart/006\nunmoved cart/003'
  printf 'cart/006\tcheckout/001\n' > "$dir/remap.tsv"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv doc.md
  assert_exit "rc" 0 "$RC"
  assert_match "moved rewritten"  'moved checkout/001' "$(cat "$dir/doc.md")"
  assert_match "unmoved retained" 'unmoved cart/003'   "$(cat "$dir/doc.md")"
}

# AC 8: a second run over the already-rewritten file makes no change (idempotent).
case_jimpartition_rewrite_refs_idempotent() {
  local dir; dir="$(git_init rr_idem)"
  repo_add "$dir" doc.md 'see cart/006'
  printf 'cart/006\tcheckout/001\n' > "$dir/remap.tsv"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv doc.md
  local after1; after1="$(cat "$dir/doc.md")"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv doc.md
  assert_exit "second run rc" 0 "$RC"
  assert_eq "no rewrites on second run" "0" "$(printf '%s\n' "$OUT" | grep -c 'REWROTE')"
  assert_eq "file stable" "$after1" "$(cat "$dir/doc.md")"
}

# security Finding 8 (guard-before-edit): a multi-file batch with one guard-failing
# (untracked) target edits NOTHING — the good file is left byte-unchanged, rc 2.
case_jimpartition_rewrite_refs_guard_abort() {
  local dir; dir="$(git_init rr_guard)"
  repo_add "$dir" good.md 'see cart/006'
  printf 'later cart/006\n' > "$dir/bad.md"   # on disk, never staged → untracked
  printf 'cart/006\tcheckout/001\n' > "$dir/remap.tsv"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv good.md bad.md
  assert_exit "rc" 2 "$RC"
  assert_eq "good file untouched" "see cart/006" "$(cat "$dir/good.md")"
}

# rc 2: a malformed remap line (a number that is not 3 digits) is rejected before
# any edit — the target file is untouched.
case_jimpartition_rewrite_refs_malformed_remap_rc2() {
  local dir; dir="$(git_init rr_badmap)"
  repo_add "$dir" doc.md 'see cart/006'
  printf 'cart/6\tcheckout/001\n' > "$dir/remap.tsv"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv doc.md
  assert_exit "rc" 2 "$RC"
  assert_eq "target untouched" "see cart/006" "$(cat "$dir/doc.md")"
}

# The remap gate spans the same width bound as the map verbs that produce it, on
# both halves of the line — otherwise a map this tool emitted would be a map it
# refuses to apply. The whole-token rule still holds at the wider width: a
# reference to cart/006 inside cart/0060 is not a match, since the char after
# the ordinal is [a-z0-9].
case_jimpartition_rewrite_refs_wide_ordinals() {
  local dir; dir="$(git_init rr_wide)"
  repo_add "$dir" doc.md 'see cart/1000 and cart/10000 and cart/006'
  printf 'cart/1000\tcheckout/2000\n' > "$dir/remap.tsv"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv doc.md
  assert_exit "rc" 0 "$RC"
  assert_eq "wide ordinal rewritten, its longer sibling untouched" \
    "see checkout/2000 and cart/10000 and cart/006" "$(cat "$dir/doc.md")"
}

# rc 2: a target symlinked OUT of the worktree is refused by the containment guard.
case_jimpartition_rewrite_refs_symlink_escape_rc2() {
  local dir; dir="$(git_init rr_sym)"
  mkdir -p "$TMP_BASE/rr_outside"
  printf 'cart/006\n' > "$TMP_BASE/rr_outside/target.md"
  ln -s "$TMP_BASE/rr_outside/target.md" "$dir/link.md"
  printf 'cart/006\tcheckout/001\n' > "$dir/remap.tsv"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv link.md
  assert_exit "rc" 2 "$RC"
}

# rc 2 on usage (no target files).
case_jimpartition_rewrite_refs_usage_rc2() {
  local dir; dir="$(git_init rr_usage)"
  printf 'cart/006\tcheckout/001\n' > "$dir/remap.tsv"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv
  assert_exit "rc" 2 "$RC"
}

# The sibling of the rewrite-identity awk guard: a mid-stream failure leaves a
# non-empty record file, so the record-based check alone would install a
# truncated file over a real one.
case_jimpartition_rewrite_refs_awk_failure_does_not_install() {
  local dir shim before oldpath
  dir="$(git_init rr_awkfail)"
  repo_add "$dir" doc.md 'see cart/006 for details'
  printf 'cart/006\tcheckout/001\n' > "$dir/remap.tsv"
  before="$(cat "$dir/doc.md")"
  shim=$(jimpart_failing_awk_shim rr_awkfail_bin)
  oldpath="$PATH"; PATH="$shim:$PATH"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv doc.md
  PATH="$oldpath"
  assert_exit "rc" 1 "$RC"
  assert_eq "file byte-unchanged" "$before" "$(cat "$dir/doc.md")"
  assert_eq "no truncated marker" "0" "$(grep -c '^truncated$' "$dir/doc.md")"
  assert_eq "no REWROTE claimed" "0" "$(printf '%s\n' "$OUT" | grep -c 'REWROTE')"
}

# ─── Section: composed-sweep regressions — renumbering moves (spec 051) ───────
#
# The materialize sweep as the split/merge flows document it: flag-carrying
# rewrite-identity, then the remap sweep, over one moved body. Guards both
# manifestations of the ref-sweep defect at the composition level (a script-only
# unit test cannot catch a wrong two-verb composition).

# 051 AC 1/2/5 (split extraction arm): a moved body cites a spec that ALSO moves
# and renumbers (cart/002 → checkout/001) AND a spec that stays in the remainder
# (cart/005). After the composed sweep the renumbered ref lands on its new id and
# the remainder ref is untouched — no stale-number mispoint (M1), no group
# mispoint on the remainder ref (M2).
case_jimpartition_rewrite_split_extraction_composed() {
  local dir body id_out T; T=$'\t'
  dir="$(git_init rw_split_composed)"
  repo_add "$dir" moved.md $'---\ngroup: "cart"\n---\n\nDepends on cart/002 for the flow.\nAlso see cart/005 in the remainder.'
  # renumber-map output: the moved+renumbered row plus the remainder identity row.
  printf 'cart/002\tcheckout/001\ncart/005\tcart/005\n' > "$dir/remap.tsv"
  run_jimpartition_in "$dir" rewrite-identity --skip-typed-refs cart checkout moved.md
  assert_exit "identity rc" 0 "$RC"; id_out="$OUT"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv moved.md
  assert_exit "refs rc" 0 "$RC"
  body="$(cat "$dir/moved.md")"
  assert_match "group re-pointed"        '^group: "checkout"$'         "$body"
  assert_match "renumbered ref landed"   'Depends on checkout/001 for' "$body"
  assert_match "remainder ref untouched" 'Also see cart/005 in'        "$body"
  assert_eq "no stale-number mispoint (M1)" "0" "$(printf '%s\n' "$body" | grep -c 'checkout/002')"
  assert_eq "no remainder mispoint (M2)"    "0" "$(printf '%s\n' "$body" | grep -c 'checkout/005')"
  assert_match "identity group record"      "^REWROTE${T}moved.md${T}[0-9]+${T}group$" "$id_out"
  assert_eq "identity emitted no typed-ref" "0" "$(printf '%s\n' "$id_out" | grep -c 'typed-ref')"
}

# 051 AC 1/5 (merge arm): a moved source body cites a same-source ref (src/002)
# that renumber-appends to target/008. After the composed sweep the ref lands on
# the appended id — no stale-number mispoint (M1).
case_jimpartition_rewrite_merge_composed() {
  local dir body
  dir="$(git_init rw_merge_composed)"
  repo_add "$dir" moved.md $'---\ngroup: "src"\n---\n\nRefers to src/002 upstream.'
  printf 'src/002\ttarget/008\n' > "$dir/remap.tsv"
  run_jimpartition_in "$dir" rewrite-identity --skip-typed-refs src target moved.md
  assert_exit "identity rc" 0 "$RC"
  run_jimpartition_in "$dir" rewrite-refs remap.tsv moved.md
  assert_exit "refs rc" 0 "$RC"
  body="$(cat "$dir/moved.md")"
  assert_match "group re-pointed"        '^group: "target"$'              "$body"
  assert_match "renumber-append landed"  'Refers to target/008 upstream'  "$body"
  assert_eq "no stale-number mispoint (M1)" "0" "$(printf '%s\n' "$body" | grep -c 'target/002')"
}

# 051 AC 4: the four canonical materialize invocation lines — split and merge, in
# both SKILL.md and the methodology reference — pin the --skip-typed-refs flag, so a
# future flow edit that drops it fails this suite rather than silently corrupting a
# renumbering move's refs. The rename invocation deliberately carries no flag and is
# not pinned. This case asserts doc CONTENT, not script behavior — a deliberate
# stretch of the per-script charter, the mechanical guard for the prose-drift
# channel the defect shipped through.
case_jimpartition_prose_pin_skip_typed_refs_flag() {
  local skill meth
  skill="$REPO_ROOT/skills/partition/SKILL.md"
  meth="$REPO_ROOT/skills/partition/references/partition-methodology.md"
  assert_eq "SKILL.md canonical lines carry flag"    "2" "$(grep -c 'rewrite-identity --skip-typed-refs' "$skill")"
  assert_eq "methodology canonical lines carry flag" "2" "$(grep -c 'rewrite-identity --skip-typed-refs' "$meth")"
}

# ─── Section: identity-check op=split arm + aggregate reveal (spec 047 Task 9) ─

# AC 17: a symmetric split retires the source slug (old ∉ new) — a surviving
# group's territory that still embeds `cart` is flagged retired.
case_jimpartition_identity_check_split_symmetric_retired() {
  local w; w="$TMP_BASE/icsr"; mkdir -p "$w/spec"
  local map; map="$(identity_map icsr_map '### shop
- Territory: `modules/shop`

### store
- Territory: `services/cart/data`')"
  printf '1\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=split;old=cart;new=shop,store\n' > "$w/spec/ledger.md"
  run_jimpartition identity-check "$map" "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_match "symmetric split retires cart" 'MISMATCH.*store.*cart.*retired' "$OUT"
}

# AC 17: an extraction split (old ∈ new — the remainder continues) does NOT retire
# the source slug.
case_jimpartition_identity_check_split_extraction_none() {
  local w; w="$TMP_BASE/icen"; mkdir -p "$w/spec"
  local map; map="$(identity_map icen_map '### shop
- Territory: `modules/shop`

### store
- Territory: `services/cart/data`')"
  printf '1\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=split;old=cart;new=cart,checkout\n' > "$w/spec/ledger.md"
  run_jimpartition identity-check "$map" "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_eq "extraction keeps cart live" "0" "$(printf '%s\n' "$OUT" | grep -c 'retired')"
}

# AC 17: a malformed new= token is ignored, and the retirement of a valid old=
# slug is still determined correctly (cart ∉ {shop,store}).
case_jimpartition_identity_check_split_malformed_new_ignored() {
  local w; w="$TMP_BASE/icmn"; mkdir -p "$w/spec"
  local map; map="$(identity_map icmn_map '### shop
- Territory: `modules/shop`

### store
- Territory: `services/cart/data`')"
  printf '1\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=split;old=cart;new=shop,BAD!,store\n' > "$w/spec/ledger.md"
  run_jimpartition identity-check "$map" "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_match "malformed sibling ignored, cart retired" 'MISMATCH.*store.*cart.*retired' "$OUT"
}

# AC 15: an op=merge absorbed source (old ∉ new) retires its slug under the
# uniform rule — a surviving group whose territory still embeds `wishlist` is
# flagged retired.
case_jimpartition_identity_check_merge_source_retired() {
  local w; w="$TMP_BASE/icmsr"; mkdir -p "$w/spec"
  local map; map="$(identity_map icmsr_map '### cart
- Territory: `modules/cart`

### orders
- Territory: `services/wishlist/data`')"
  printf '1\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=merge;old=wishlist,cart;new=cart\n' > "$w/spec/ledger.md"
  run_jimpartition identity-check "$map" "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_match "absorbed wishlist retired" 'MISMATCH.*orders.*wishlist.*retired' "$OUT"
}

# AC 15: the surviving absorption target (old ∩ new) is NOT retired — wishlist is
# flagged (merge was processed) while cart, which survived, never is.
case_jimpartition_identity_check_merge_target_exempt() {
  local w; w="$TMP_BASE/icmte"; mkdir -p "$w/spec"
  local map; map="$(identity_map icmte_map '### shop
- Territory: `services/cart/data`

### orders
- Territory: `services/wishlist/data`')"
  printf '1\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=merge;old=wishlist,cart;new=cart\n' > "$w/spec/ledger.md"
  run_jimpartition identity-check "$map" "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_match "wishlist retired (merge processed)" 'MISMATCH.*orders.*wishlist.*retired' "$OUT"
  assert_eq "cart survived — not retired" "0" "$(printf '%s\n' "$OUT" | grep -c 'cart.*retired')"
}

# AC 15: the fresh-target arm retires every source (old ∩ new = ∅) — a surviving
# territory embedding `wishlist` is flagged retired.
case_jimpartition_identity_check_merge_fresh_all_retired() {
  local w; w="$TMP_BASE/icmfa"; mkdir -p "$w/spec"
  local map; map="$(identity_map icmfa_map '### shopping
- Territory: `modules/shopping`

### orders
- Territory: `services/wishlist/data`')"
  printf '1\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=merge;old=cart,wishlist;new=shopping\n' > "$w/spec/ledger.md"
  run_jimpartition identity-check "$map" "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_match "wishlist retired" 'MISMATCH.*orders.*wishlist.*retired' "$OUT"
}

# security Finding 3: a hand-edited op=merge naming a LIVE group in old= makes
# identity-check advise that live slug retired — bounded sensor noise, never a
# veto (rc stays 0), the machine-consumption residual risk 047 flagged.
case_jimpartition_identity_check_merge_live_slug_in_old_bounded() {
  local w; w="$TMP_BASE/icmls"; mkdir -p "$w/spec"
  local map; map="$(identity_map icmls_map '### orders
- Territory: `modules/orders`

### shop
- Territory: `services/orders/data`')"
  printf '1\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=merge;old=orders,wishlist,cart;new=cart\n' > "$w/spec/ledger.md"
  run_jimpartition identity-check "$map" "$w/spec"
  assert_exit "still advisory, never a veto" 0 "$RC"
  assert_match "live orders slug advised retired (bounded)" 'MISMATCH.*shop.*orders.*retired' "$OUT"
}

# review Finding 2: a no-op op=rename (old==new) retires nothing under the
# uniform rule (old ∈ new) — a fail-closed edge, no false-positive retired flag.
case_jimpartition_identity_check_noop_rename_retires_nothing() {
  local w; w="$TMP_BASE/icnr"; mkdir -p "$w/spec"
  local map; map="$(identity_map icnr_map '### cart
- Territory: `services/cart/data`')"
  printf '1\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=rename;old=cart;new=cart\n' > "$w/spec/ledger.md"
  run_jimpartition identity-check "$map" "$w/spec"
  assert_exit "rc" 0 "$RC"
  assert_eq "no-op rename retires nothing" "0" "$(printf '%s\n' "$OUT" | grep -c 'retired')"
}

# review Finding 2: a malformed comma-bearing op=rename old= retires each
# slug-valid token not among new (fail-closed, bounded advisory — never fatal).
case_jimpartition_identity_check_malformed_old_bounded() {
  local w; w="$TMP_BASE/icmo"; mkdir -p "$w/spec"
  local map; map="$(identity_map icmo_map '### shop
- Territory: `services/orders/data`')"
  printf '1\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=rename;old=orders,BAD!;new=payments\n' > "$w/spec/ledger.md"
  run_jimpartition identity-check "$map" "$w/spec"
  assert_exit "still advisory rc 0" 0 "$RC"
  assert_match "valid token retired, malformed inert" 'MISMATCH.*shop.*orders.*retired' "$OUT"
}

# AC 4: the revealed-edge floor — projecting the substrate onto proposed child
# territories surfaces the cross-child requires edge (GEDGE) a naive split would
# miss, plus a straddling provider (STRADDLE), as deterministic gate evidence.
case_jimpartition_aggregate_split_reveal() {
  local dir edges terr; dir="$(split_repo agg_reveal)"
  run_jimpartition_in "$dir" scan
  edges="$dir/edges.tsv"; printf '%s\n' "$OUT" > "$edges"
  terr=$(terr_file "$dir" terr.tsv $'GROUP\tcart\tmodules/cart\nGROUP\tcheckout\tmodules/cart/checkout\nGROUP\torders\tmodules/orders')
  run_jimpartition_in "$dir" aggregate edges.tsv terr.tsv
  assert_exit "rc" 0 "$RC"
  assert_match "revealed cross-child requires edge" 'GEDGE.*checkout.*cart' "$OUT"
  assert_match "straddling provider surfaced"       'STRADDLE.*catalog'      "$OUT"
}

# ─── Section: merge-preflight cases (spec 048 Task 5) ────────────────────────

# AC 1: merge wishlist into cart — target cart is a mapped group, so the ARM is
# absorption; the effective set is {wishlist (listed), cart (implicit — the
# sugar-promoted target)} and each source's mapping / blueprint passes. rc 0.
case_jimpartition_merge_preflight_absorption() {
  local dir; dir="$(merge_repo mp_absorb)"
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs cart wishlist
  assert_exit "rc" 0 "$RC"
  assert_match "absorption arm"     'ARM.*absorption'                 "$OUT"
  assert_match "wishlist listed"    $'EFFECTIVE\twishlist\tlisted'    "$OUT"
  assert_match "cart implicit"      $'EFFECTIVE\tcart\timplicit'      "$OUT"
  assert_match "wishlist mapped"    'source-mapped:wishlist.*pass'    "$OUT"
  assert_match "wishlist blueprint" 'blueprint-exists:wishlist.*pass' "$OUT"
  assert_match "territory identity"  $'TERRITORY-IDENTITY\twishlist\tmodules/wishlist' "$OUT"
}

# AC 1: merge cart wishlist into shopping — target shopping is fresh (not
# mapped), so the ARM is fresh-target and both listed sources retire; the
# effective set is exactly the two listed sources (no implicit row). rc 0.
case_jimpartition_merge_preflight_fresh_target() {
  local dir; dir="$(merge_repo mp_fresh)"
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs shopping cart wishlist
  assert_exit "rc" 0 "$RC"
  assert_match "fresh-target arm" 'ARM.*fresh-target'            "$OUT"
  assert_match "cart listed"      $'EFFECTIVE\tcart\tlisted'     "$OUT"
  assert_match "wishlist listed"  $'EFFECTIVE\twishlist\tlisted' "$OUT"
  assert_eq    "no implicit row (target unmapped)" "0" "$(printf '%s\n' "$OUT" | grep -c 'implicit')"
  assert_match "target slug valid" 'target-slug-valid.*pass'     "$OUT"
  assert_match "no collision (shopping fresh)" 'target-collision:shopping.*pass' "$OUT"
}

# AC 2: merge wishlist into shopping (shopping fresh) yields an effective set of
# one — refused with sources-arity fail naming /jim:partition rename; a merge
# never masquerades as a rename. rc 1.
case_jimpartition_merge_preflight_degenerate_rename() {
  local dir; dir="$(merge_repo mp_degen)"
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs shopping wishlist
  assert_exit "rc" 1 "$RC"
  assert_match "arity fail names rename" 'sources-arity.*fail.*rename' "$OUT"
}

# AC 1: a duplicate listed source fails sources-dup (rc 1, structural).
case_jimpartition_merge_preflight_dup_sources() {
  local dir; dir="$(merge_repo mp_dup)"
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs cart wishlist wishlist
  assert_exit "rc" 1 "$RC"
  assert_match "dup fail" 'sources-dup.*fail' "$OUT"
}

# AC 3: a fresh target whose name is already a spec-group directory collides
# (rc 1); the check is skipped for a mapped absorption target.
case_jimpartition_merge_preflight_target_collision() {
  local dir; dir="$(merge_repo mp_coll)"
  mkdir -p "$dir/docs/specs/newgrp"          # a stray dir, not a mapped group
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs newgrp cart wishlist
  assert_exit "rc" 1 "$RC"
  assert_match "collision fail" 'target-collision:newgrp.*fail' "$OUT"
}

# AC 4: merging every mapped group into one emits the COLLAPSE full advisory
# fact (the partition collapses to a single group).
case_jimpartition_merge_preflight_collapse_full() {
  local dir; dir="$(merge_repo mp_collapse)"
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs cart orders wishlist
  assert_exit "rc" 0 "$RC"
  assert_match "collapse full" $'COLLAPSE\tfull' "$OUT"
}

# AC 3: territory-identity and dirt are collected across EVERY effective source —
# a dirty file inside any source's territory is affected, unrelated dirt is
# classified as such (dirt is non-fatal; rc 0 with no structural fail).
case_jimpartition_merge_preflight_territory_and_dirt() {
  local dir; dir="$(merge_repo mp_dirt)"
  printf 'export const y = 1;\n' >> "$dir/modules/wishlist/gift.js"  # affected (source territory)
  printf 'export const z = 1;\n' >> "$dir/modules/orders/order.js"   # unrelated (bystander)
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs cart wishlist
  assert_exit "rc" 0 "$RC"
  assert_match "wishlist territory" $'TERRITORY-IDENTITY\twishlist\tmodules/wishlist' "$OUT"
  assert_match "cart territory"     $'TERRITORY-IDENTITY\tcart\tmodules/cart'         "$OUT"
  assert_match "affected dirt in source" 'DIRT.*affected.*modules/wishlist' "$OUT"
  assert_match "unrelated dirt"          'DIRT.*unrelated.*modules/orders'   "$OUT"
}

# AC 3: a listed source that is not a mapped group fails source-mapped (rc 1).
case_jimpartition_merge_preflight_unmapped_source() {
  local dir; dir="$(merge_repo mp_unmapped)"
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs cart nosuch
  assert_exit "rc" 1 "$RC"
  assert_match "unmapped source fail" 'source-mapped:nosuch.*fail' "$OUT"
}

# rc 2 on usage: no sources after the target.
case_jimpartition_merge_preflight_usage_rc2() {
  local dir; dir="$(merge_repo mp_usage)"
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs cart
  assert_exit "no sources rc" 2 "$RC"
}

# review Finding 1: a fresh target with an invalid slug is caught by
# target-slug-valid and its filesystem collision probe is SKIPPED — a `test -d`
# never runs on an unvalidated component (sibling gate-before-probe parity).
case_jimpartition_merge_preflight_invalid_target_no_probe() {
  local dir; dir="$(merge_repo mp_badtarget)"
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs 'Bad' cart wishlist
  assert_exit "rc" 1 "$RC"
  assert_match "target slug invalid" 'target-slug-valid.*fail' "$OUT"
  assert_eq "collision probe skipped for invalid target" "0" "$(printf '%s\n' "$OUT" | grep -c 'target-collision')"
}

# review Finding 1: an invalid source slug fails blueprint-exists with an
# invalid-slug reason — the 000-blueprint `test -d` never runs on the
# unvalidated component.
case_jimpartition_merge_preflight_invalid_source_no_probe() {
  local dir; dir="$(merge_repo mp_badsource)"
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs cart 'Bad'
  assert_exit "rc" 1 "$RC"
  assert_match "invalid source blueprint-exists gated" 'blueprint-exists:Bad.*fail.*invalid' "$OUT"
}

# review Finding 2: the target listed explicitly among the sources dedupes to a
# single EFFECTIVE row tagged `listed` (never the implicit promotion).
case_jimpartition_merge_preflight_target_listed_explicitly() {
  local dir; dir="$(merge_repo mp_tlisted)"
  run_jimpartition_in "$dir" merge-preflight BLUEPRINT.md docs/specs cart wishlist cart
  assert_exit "rc" 0 "$RC"
  assert_eq "cart appears once in EFFECTIVE" "1" "$(printf '%s\n' "$OUT" | grep -c $'^EFFECTIVE\tcart\t')"
  assert_match "cart tagged listed (explicit)" $'EFFECTIVE\tcart\tlisted' "$OUT"
  assert_eq "no implicit promotion for cart" "0" "$(printf '%s\n' "$OUT" | grep -c $'EFFECTIVE\tcart\timplicit')"
}

# ─── Section: merge-map cases (spec 048 Task 6) ──────────────────────────────

# mm_specs <name> <group>/<basename>... — a specs-dir with numbered spec dirs
#   (no git needed — merge-map only reads directories). Prints the root; specs
#   live under <root>/specs, so cases pass `specs` as the relative specs-dir.
mm_specs() {
  local name="$1"; shift
  local root; root="$(empty_dir "$name")"
  local pair
  for pair in "$@"; do mkdir -p "$root/specs/$pair"; done
  printf '%s' "$root"
}

# AC 9 / DD 2 / security Finding 6: the first absorbed spec receives EXACTLY the
# passed <start> — merge-map copies the allocator's advisory peek and never
# computes the seed from the target's directory contents; the source's specs ascend.
case_jimpartition_merge_map_first_is_start() {
  local dir; dir="$(merge_repo mm_start)"
  run_jimpartition_in "$dir" merge-map docs/specs cart 003 wishlist
  assert_exit "rc" 0 "$RC"
  assert_match "first absorbed -> start"    $'MAP\twishlist/001\tcart/003' "$OUT"
  assert_match "second absorbed ascending"  $'MAP\twishlist/002\tcart/004' "$OUT"
}

# AC 9: a fresh target renumbers from 001; sources are consumed in CLI argument
# order, each source ascending, appended into one dense sequence.
case_jimpartition_merge_map_fresh_cli_order() {
  local dir; dir="$(merge_repo mm_fresh)"
  run_jimpartition_in "$dir" merge-map docs/specs shopping 001 cart wishlist
  assert_exit "rc" 0 "$RC"
  assert_match "cart 001 -> shopping/001"     $'MAP\tcart/001\tshopping/001'     "$OUT"
  assert_match "cart 002 -> shopping/002"     $'MAP\tcart/002\tshopping/002'     "$OUT"
  assert_match "wishlist 001 -> shopping/003" $'MAP\twishlist/001\tshopping/003' "$OUT"
  assert_match "wishlist 002 -> shopping/004" $'MAP\twishlist/002\tshopping/004' "$OUT"
}

# AC 9: an in-flight wip dir rides the renumber in sequence, -wip suffix kept; the
# absorption target's own specs are untouched (target != a source).
case_jimpartition_merge_map_wip_rides() {
  local root; root="$(mm_specs mm_wip cart/001-a cart/002-b wishlist/001-p wishlist/005-wip)"
  run_jimpartition_in "$root" merge-map specs cart 003 wishlist
  assert_exit "rc" 0 "$RC"
  assert_match "normal source renumbered" $'MAP\twishlist/001\tcart/003'     "$OUT"
  assert_match "wip rides, suffix kept"   $'MAP\twishlist/005-wip\tcart/004-wip' "$OUT"
  assert_eq    "target specs not remapped" "0" "$(printf '%s\n' "$OUT" | grep -c $'MAP\tcart/')"
}

# AC 9 / security Finding 6: the append seed is honored verbatim — a caller-passed
# start of 010 (past a dir-max of 5, as the registry's high-water would answer)
# assigns the first absorbed spec target/010, never re-deriving from the target's
# dir contents.
case_jimpartition_merge_map_floored_start() {
  local root; root="$(mm_specs mm_floor cart/001-a cart/002-b cart/005-e wishlist/001-p)"
  run_jimpartition_in "$root" merge-map specs cart 010 wishlist
  assert_exit "rc" 0 "$RC"
  assert_match "floored start honored" $'MAP\twishlist/001\tcart/010' "$OUT"
}

# AC 9: a renumber that would pass the ordinal width bound is refused rc 1 with
# no MAP output. The bound is the registry's, so the case is written AT it —
# starting one below the 15-digit ceiling — rather than at a value that merely
# happens to be refused today.
case_jimpartition_merge_map_exhaustion_rc1() {
  local root; root="$(mm_specs mm_wide cart/001-a wishlist/001-p wishlist/002-q)"
  run_jimpartition_in "$root" merge-map specs cart 999999999999999 wishlist
  assert_exit "rc" 1 "$RC"
  assert_eq "no partial MAP output" "" "$OUT"
}

# The bound is shared with the registry, not a protocol cap of this file's own:
# a 4-digit start is a value `peek spec` can print, so the verb the skill tells
# an operator to paste it into must accept it.
case_jimpartition_merge_map_start_past_999_is_accepted() {
  local root; root="$(mm_specs mm_wide_ok cart/001-a wishlist/001-p)"
  run_jimpartition_in "$root" merge-map specs cart 1000 wishlist
  assert_exit "rc" 0 "$RC"
  assert_eq "maps at the 4-digit start" "MAP	wishlist/001	cart/1000" "$OUT"
}

# rc 2 on a non-numeric or out-of-bound start (usage / bad start), probed on
# BOTH edges — under-width and over-width.
case_jimpartition_merge_map_bad_start_rc2() {
  local root; root="$(mm_specs mm_badstart cart/001-a wishlist/001-p)"
  run_jimpartition_in "$root" merge-map specs cart abc wishlist
  assert_exit "non-numeric start rc" 2 "$RC"
  run_jimpartition_in "$root" merge-map specs cart 5 wishlist
  assert_exit "under-width start rc" 2 "$RC"
  run_jimpartition_in "$root" merge-map specs cart 1000000000000000 wishlist
  assert_exit "over-width start rc" 2 "$RC"
}

# The silent drop: a spec dir the registry can represent must never be omitted
# from the map at rc 0. A dir that is not ordinal-shaped at all is not a spec
# and stays silently skipped — the two cases are distinguished by leading digits.
case_jimpartition_merge_map_refuses_an_out_of_bound_spec_dir() {
  local root; root="$(mm_specs mm_wide_dir cart/001-a wishlist/001-p)"
  mkdir -p "$root/specs/wishlist/1000000000000000-huge"
  run_jimpartition_in "$root" merge-map specs cart 003 wishlist
  assert_exit "refuses rather than omitting" 1 "$RC"
  assert_eq   "no partial MAP output" "" "$OUT"
  assert_match "names the offender" 'outside the ordinal width bound' "$ERR"
}

# The sort that puts the map in numeric order is line-oriented, so a newline in
# a basename would split one directory into several map rows — ids for specs
# that do not exist, at rc 0, inside arithmetic the gate presents verbatim and
# partition-batch binds into an append-only registry. Refused, and the offending
# name never reaches stderr.
case_jimpartition_merge_map_refuses_a_newline_basename() {
  local root; root="$(mm_specs mm_nlbase cart/001-a wishlist/001-p)"
  mkdir -p "$root/specs/wishlist/$(printf 'notes\n004-fabricated-a\n005-fabricated-b')"
  run_jimpartition_in "$root" merge-map specs cart 003 wishlist
  assert_exit  "refuses"           1  "$RC"
  assert_eq    "no partial MAP output" "" "$OUT"
  assert_match "names the class"   'contains a newline' "$ERR"
  assert_eq "no row for a spec that does not exist" "0" \
    "$(printf '%s\n' "$OUT" | grep -c 'fabricated')"
  assert_eq "the unprintable name is never echoed" "1" \
    "$(printf '%s\n' "$ERR" | grep -c .)"
}

# The refusal is the whole directory's, not one row's: a real spec sharing the
# scan with a newline-bearing sibling is withheld too, so the operator never
# sees a map that looks complete over a tree the verb could not read.
case_jimpartition_merge_map_newline_withholds_the_whole_map() {
  local root; root="$(mm_specs mm_nlwhole cart/001-a wishlist/001-p wishlist/002-q)"
  mkdir -p "$root/specs/wishlist/$(printf 'x\n003-y')"
  run_jimpartition_in "$root" merge-map specs cart 003 wishlist
  assert_exit "refuses" 1 "$RC"
  assert_eq   "the representable specs are withheld too" "" "$OUT"
}

case_jimpartition_merge_map_ignores_a_non_spec_dir() {
  local root; root="$(mm_specs mm_nonspec cart/001-a wishlist/001-p)"
  mkdir -p "$root/specs/wishlist/notes"
  run_jimpartition_in "$root" merge-map specs cart 003 wishlist
  assert_exit "rc" 0 "$RC"
  assert_eq "only the spec is mapped" "MAP	wishlist/001	cart/003" "$OUT"
}

# The glob is lexical; ordinal order is numeric. Once two ordinals differ in
# width the two disagree, and merge-map's output order IS its id assignment.
case_jimpartition_merge_map_orders_numerically_not_lexically() {
  local root; root="$(mm_specs mm_order cart/001-a wishlist/999-late wishlist/1000-later)"
  run_jimpartition_in "$root" merge-map specs cart 003 wishlist
  assert_exit "rc" 0 "$RC"
  assert_eq "999 is assigned before 1000" \
    "$(printf 'MAP\twishlist/999\tcart/003\nMAP\twishlist/1000\tcart/004')" "$OUT"
}

# rc 2 on usage (no sources after the trio).
case_jimpartition_merge_map_usage_rc2() {
  local root; root="$(mm_specs mm_mmusage cart/001-a)"
  run_jimpartition_in "$root" merge-map specs cart 003
  assert_exit "no sources rc" 2 "$RC"
}

# ─── Section: merge-edges-diff cases (spec 048 Task 7) ───────────────────────

# AC 16: the post-merge done-condition — the before graph with each source
# rewritten to the target and the dissolved cross-source edge elided equals the
# actual after graph. Absorption (wishlist into cart): the wishlist->cart edge
# internalizes, the orders->cart bystander stays. rc 0.
case_jimpartition_merge_edges_clean_collapse() {
  local before after
  before=$(fixture me-clean-b.tsv "$(printf 'orders\tcart-checkout-hold\tcart\nwishlist\tcart-checkout-hold\tcart')")
  after=$(fixture me-clean-a.tsv "$(printf 'orders\tcart-checkout-hold\tcart')")
  run_jimpartition merge-edges-diff "$before" "$after" cart wishlist
  assert_exit "identical modulo merge" 0 "$RC"
  assert_eq "no divergence rows" "" "$OUT"
}

# AC 7/16: a third-party edge re-points to the target on the provider column while
# the cross-source edge dissolves; the fresh-target arm rewrites both sources
# (cart, wishlist -> shopping), so orders->cart becomes orders->shopping.
case_jimpartition_merge_edges_third_party_repoint() {
  local before after
  before=$(fixture me-tp-b.tsv "$(printf 'orders\tcart-checkout-hold\tcart\nwishlist\tcart-checkout-hold\tcart')")
  after=$(fixture me-tp-a.tsv "$(printf 'orders\tcart-checkout-hold\tshopping')")
  run_jimpartition merge-edges-diff "$before" "$after" shopping cart wishlist
  assert_exit "re-point clean" 0 "$RC"
}

# AC 16: every edge internal to the merged set dissolves — an all-internal before
# graph (cart<->wishlist both directions) matches an empty after graph (self-edge
# elision, safe because a pre-merge graph has no self-edges).
case_jimpartition_merge_edges_self_edge_elision() {
  local before after
  before=$(fixture me-self-b.tsv "$(printf 'wishlist\twishlist-gift-flag\tcart\ncart\tcart-checkout-hold\twishlist')")
  after=$(fixture me-self-a.tsv "")
  run_jimpartition merge-edges-diff "$before" "$after" cart wishlist
  assert_exit "all internal dissolve to empty" 0 "$RC"
  assert_eq "no rows" "" "$OUT"
}

# AC 16: a divergence (an expected re-pointed edge absent from the after graph) is
# reported MISSING with rc 1.
case_jimpartition_merge_edges_divergent_rc1() {
  local before after
  before=$(fixture me-div-b.tsv "$(printf 'orders\tcart-checkout-hold\tcart\nwishlist\tcart-checkout-hold\tcart')")
  after=$(fixture me-div-a.tsv "")
  run_jimpartition merge-edges-diff "$before" "$after" cart wishlist
  assert_exit "divergent" 1 "$RC"
  assert_match "missing third-party edge" 'MISSING.*orders.*cart' "$OUT"
}

# rc 2 on usage (no sources) or a missing file.
case_jimpartition_merge_edges_usage_rc2() {
  local before; before=$(fixture me-u-b.tsv "$(printf 'orders\tx\tcart')")
  run_jimpartition merge-edges-diff "$before" "$before" cart
  assert_exit "no sources rc" 2 "$RC"
  run_jimpartition merge-edges-diff "$before" /nonexistent-after cart wishlist
  assert_exit "missing after rc" 2 "$RC"
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
