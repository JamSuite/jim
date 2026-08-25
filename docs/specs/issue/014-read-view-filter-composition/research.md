---
spec: "docs/specs/issue/014-read-view-filter-composition/spec.md"
status: Needs PM Review
date: "2026-08-25"
---

# Research: Read-view filter composition

## Anchors

**The parse surface to widen**

- `skills/issue/scripts/render.sh:394-424` — `cmd_list`'s argument handling.
  The stray-token guard at `:405-424` is the refusal the spec preserves: it
  already separates "mistyped filter" from "no such collection", and fires
  before the directory positional binds.
- `skills/issue/scripts/render.sh:242-250` — `cmd_stats`'s head, carrying the
  same trailing-directory positional via `named_dir_exists` (`:236`). Gains the
  identical parse surface, so it needs the same ordering.
- `skills/issue/scripts/render.sh:66-68` — `STATUS_TOKENS` (already
  `open active closed`), `PRIORITY_TOKENS`, `COL_TOKENS`: where the reserved
  vocabularies extend. `is_filter_token` (`:141`) is their single gate.
- `skills/issue/scripts/render.sh:161-196` — `read_issue_rows`. The awk iterates
  ` · `-separated `key: value` parts and matches known keys, ignoring the rest,
  so new fields are additional `else if` arms rather than a new parser.
- `skills/issue/scripts/render.sh:364-390` — `format_row`; new column tokens are
  new `case` arms.

**The index side**

- `skills/issue/scripts/index.sh:153-171` — `parse_scalar_fields`. Its key
  allowlist **already includes** `type`, `filed-by`, `claimed-by`, `outcome`.
  No parser change is needed to obtain them.
- `skills/issue/scripts/index.sh:489-492` — where those four land in
  `meta_type` / `meta_outcome` / `meta_filed_by` / `meta_claimed_by`, read today
  only by the integrity checks and the identity-drift surface.
- `skills/issue/scripts/index.sh:740-748` — the Issues-row emitter. Every field
  appends under `[[ -n … ]]`, so empty-field omission falls out for free.
- `skills/issue/scripts/index.sh:301` — `row_safe`: strips control characters,
  **deletes the `·` separator**, truncates at 512. Every new field value must go
  through it; that is the whole of the row-injection guard.

**Prior art inside the repo for the flag parser**

- `skills/issue/scripts/migrate.sh:57` + `:73-86` — `MIGRATE_OPTIONS` and
  `need_operand`, refusing a flag with no operand *and* a flag whose operand is
  another known flag. Exactly the spec's flag-operand AC, already hardened.

**Tests**

- `tests/issues.sh:1541-1570` — `case_issues_render_list_filter_status` and
  `case_issues_render_list_unknown_filter_errors`: the template for every new
  filter case. Shape: `empty_dir` → `write_issue` with inline frontmatter →
  `run_render list <args> "$dir"` → `assert_exit` / `assert_match`.
- `tests/issues.sh:977` — `case_issues_render_blocking_ordered_by_count`, the
  template for anything reading the Graph section.
- Conventions are canonical in `skills/meta-test/scripts/testlib.sh` header;
  scaffold new files with `/jim:meta-test`.

## Local Patterns

**Two of the new axes do not belong in the row at all.** This is the main
finding, and it narrows the substrate work.

`part-of` is not a scalar — it lives inside the `relations:` block, and
`parse_scalar_fields` correctly does not list it. `parse_relations`
(`index.sh:178-207`) is **type-agnostic**: it emits any `<type>: [<slugs>]` pair
it finds, so `part-of` already flows into `outgoing_all` and is already rendered
into the index's Graph section as `- \`member\` --part-of--> \`epic\``.
`depends-on` is there on the same terms.

So `--epic` and `blocked`/`unblocked` are both answerable from the Graph section
the index already writes, and `cmd_stats:322-333` already parses that section.
Only four scalars — `type`, `filed-by`, `claimed-by`, `outcome` — need to reach
the Issues row. The spec's AC ("the index describes each record with every field
a filter can name") is satisfied without a `part-of` row column, because the
Graph *is* part of the index. **The measured +16.5 KB / +11.8 % in the spec's
Handoff already counts exactly these four scalars, so the number stands.**

**Config resolution is one call, already batched.** `cmd_list:438-446` pulls
every `issue_list_*` key from one `jimconf.sh list` invocation into an assoc
array, with `cfg_validated` (`:149`) applying per-key allowlists. A
per-invocation column selection sits on top of that resolution, not in place
of it.

**Identity has the seam the person filter needs.** `identity.sh` exposes
`resolve`, `validate`, `normalize` and `map` as separate verbs (see its USAGE
header), so a query goes through the same `normalize` the write paths use.
`index.sh:614-645` shows the memoization pattern to copy: an `ident_seen` assoc
array keyed by raw value, so `normalize` runs once per *distinct* value rather
than once per record.

## Security & Performance

- **Filter values are untrusted input reaching awk.** `ARCHITECTURE.md`
  (§ Skills, the `backfill.sh` timestamp discussion) records that awk's `-v`
  processes its operand as a string literal and expands escape sequences, which
  is why the issue scripts pass values through the *environment* instead. Any
  filter value handed to awk must follow that convention.
- **Prefix matching must be literal, not pattern.** `[[ "$origin" == "$prefix"* ]]`
  treats an unquoted `$prefix` as a glob, so a `--spec`/`--origin` value
  containing `*`, `?`, or `[` would silently widen the match. This is the one
  place a filter value is used in a comparison operator rather than an equality
  test.
- **No filter value may be composed into a path.** `--spec` resolves against the
  configured specs root only to build a *string* to compare against `origin`;
  nothing is opened. This keeps the group's `id-gate-before-path` invariant
  intact — the read views resolve ids only against the indexed set.
- **Identity concentration** is already recorded in the spec's Out of Scope. The
  index is published to the same destination as the issue files by the same
  door, so this is a convenience change, not a disclosure change.
- **Performance is flat.** All 350 rows are already in shell memory after
  `read_issue_rows`. `blocked` needs each `depends-on` target's status — build
  one assoc array from the rows already loaded and look up in it; there is no
  n+1 and no second file scan. The Graph parse is one `awk` over one file.

**Latent narrowing that this work would inherit.** Both Graph-section readers
match slugs with `[a-z0-9-]+`:

- `render.sh:324` — the stats blocking rollup
- `render.sh:703` — `cmd_insights_graph`

`is_valid_id` (`render.sh:560`, byte-identical across three files) allows
`^[A-Za-z0-9][A-Za-z0-9._-]*$`. Under `issue_id_prefix=project` — a supported
mode, and the `JIM-` example ARCHITECTURE.md itself cites — every edge touching
an uppercase or dotted id is silently dropped from both surfaces. The current
collection is entirely lowercase date-prefixed, so this is latent rather than
live. It matters here because `blocked` and `--epic` would be a third and fourth
copy of the same pattern.

## Alignment

Phase 1 was skipped: the spec references no external API, library, or example,
and the group is bash + POSIX with zero third-party dependencies, so there is no
dependency comparison to make and nothing to fetch.

This work aligns with `ARCHITECTURE.md` § Plugin Conventions → Scripting Layer
(deterministic bash read views, line-oriented parsing, no `jq`) and with the
`issue` group blueprint's `atomic-index-write`, `staleness-gated-reads` and
`issue-file-never-sourced` invariants — widening the row it already writes keeps
one index, one atomic write, and one staleness question. It **diverges from
`VISION.md`** § Non-Goals, treated below.

## Recommendations

*Options and trade-offs for the architect — not decisions.*

1. **Split the axes by source.** Four scalars from the widened Issues row;
   `part-of` and `depends-on` from the Graph section already written. The
   alternative — rendering `part-of` as a row column too — duplicates a fact the
   index already carries in a form the scripts already parse, and would make the
   epic increment's derived roster read from a different place than the graph it
   renders.

2. **One filter parser, two callers.** `cmd_list` and `cmd_stats` need identical
   vocabulary, identical combining rules, and identically-ordered refusal
   (before the directory positional binds). A shared parse function is the
   obvious shape; the trade-off is that `cmd_stats` must then ignore axes it has
   no use for rather than reject them.

3. **`need_operand` is a copy decision, not just a code decision.** Lifting
   `migrate.sh:73` gives a hardened helper for free, but the group carries a
   `cross-copy-lockstep` invariant: a true copy wants a sync marker naming its
   sibling, while a render-local variant with its own option list is an
   independent implementation and wants no marker. Worth deciding deliberately —
   the invariant explicitly says an intended asymmetry must declare itself so it
   never reads as drift.

4. **Decide whether the slug-pattern narrowing is fixed here or filed.** Fixing
   both existing copies as part of this work stops the new filters inheriting it
   and keeps one pattern rather than four. Filing it separately keeps this spec's
   diff to its own scope. Recommendation is to fix it here, because the
   alternative ships two new consumers of a pattern already known to be wrong.

## Peer Feedback

**For the PM — strategic contention, already tracked.** `VISION.md:67` still
states that issue capture is in scope "not as a team-coordination primitive",
while this spec makes the holder a queryable axis. The contention is not new —
spec 012 shipped `claimed-by`, `claim`, and `release` — but this increment is
what makes it user-visible. The originating brainstorm recorded the decision
that "the vision gets amended if it needs to be"; the amendment never happened.
Filed as `20260825-amend-vision-md-team-coordination-non-goal`. **This does not
block the spec** — the decision to build was taken deliberately — but the
alignment gate in `/jim:spec` will keep raising it against every future spec in
this area until the vision is amended.

**For the Architect — no plan invalidation.** No `plan.md` exists in this spec
directory yet, so nothing is invalidated. Two Handoff insights are refined by
the findings above rather than contradicted: Insight 1's substrate change is
smaller than stated (four scalars, not five fields), and Insight 5's traversal
reuses an existing parse that carries a latent defect worth fixing in the same
pass.

**For the Architect — ARCHITECTURE.md carries the row format.** The `INDEX.md`
row shape is described in `ARCHITECTURE.md` § Skills, around the
`read_issue_rows` / `parse_scalar_fields` degradation discussion. Widening the
row changes a documented artifact, so the build-completion refresh must update
that passage rather than leave it describing a six-field row.
