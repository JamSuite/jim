---
id: 20260812-jimconf-value-form-refusal-covers-one-of-three-read-doors
num: P-20260812-jimconf-value-form-refusal-covers-one-of-three-read-doors
title: "jimconf value-form refusal covers one of three read doors"
status: open
priority: high
labels: [platform, config, fail-open]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:32Z
updated: 2026-08-12T21:53:32Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

The value-form refusal added in the review-remediation round is real and
correctly scoped where it applies — but it applies to `get` only, and the two
doors it misses include the one family whose values reach bash.

## 1. `cmd_list` discards `resolve`'s exit status

`skills/conf/scripts/jimconf.sh:323-329` assigns without checking, and the loop's
final `printf` sets the function's status. With an unreadable `./jimconf.toml`,
`jimconf.sh list` prints all 55 keys as `key=` (empty) at **rc 0**.

This contradicts the file's own EXIT CODES block at `:30-38`, which states rc 1
for "a config that exists but cannot be read" with no subcommand qualifier, and
the `issue` blueprint's claim at `docs/specs/issue/000-blueprint/spec.md:107-110`
that "the resolver distinguishes an unset key from a failed resolution".

Live consumer: `skills/issue/scripts/render.sh:425` (`list`, rc unchecked). The
consequences there are cosmetic — view knobs — but the door is the shared one.

## 2. The dynamic-suffix arm drops `parse_value`'s status

`jimconf.sh:228-234`:

    dyn_value="$(parse_value "$file" "$cli_key")"   # no `|| return 1`

and its `-f "$file"` pre-guard means a directory or dangling-symlink config never
reaches `parse_value` at all. So `get deps_command_refs` /
`get verify_command_<name>` resolve **empty at rc 0** on an unreadable config, a
directory config, or a single-quoted value — printing an error on stderr while
exiting 0.

These are exactly the two families the walk-up rationale at `:288-292` singles out
as command strings jim hands to bash. The direction is fail-safe (empty reads as
"not configured"), but the contract is inverted relative to `get` on every static
key.

## 3. An unterminated double-quoted value resolves to the raw config line

`jimconf.sh:197-199`. `pre_commit_path = "` passes the new quote check at
`:185-187` (the character after `=` *is* `"`), then the
`sed -E 's/…"([^"]*)".*/\1/'` finds no closing quote, does not substitute, and
prints the input line unchanged. `get pre_commit` returns the literal string
`pre_commit_path = "` at rc 0.

That is a fabricated **value**, not a fabricated default — the sharper form of the
class the refusal was written to close. On the `issues` key it reaches
`place_prefix` / `ensure_index` as a directory name.

A TOML multi-line basic string (`key = """`) resolves to the silent default by the
same sed; an escaped quote (`key = "say \"hi\""`) truncates to `say \`.

## Action

1. `cmd_list` — capture `resolve`'s status in the loop and return non-zero when
   any key fails, keeping the remaining keys printed.
2. `:228-234` — add `|| return 1` to the `parse_value` call and drop the `-f`
   short-circuit so the file-shape checks are reached.
3. `:185-191` — require a closing quote in the refusal regex
   (`=[[:space:]]*"[^"]*"[[:space:]]*(#.*)?$`), so an unterminated or multi-line
   string refuses like any other unreadable form.

Add cases for `list` against an unreadable config and for a dynamic-suffix key
against a malformed one. Also worth pinning: the dangling-symlink refusal at
`:155-158` is unpinned (`tests/jimconf.sh:62` builds only a directory), and the
walk-up guard's scoping is unpinned in all three directions (`-c`, `path`/`keys`,
and `list`).

Note for whoever takes this: `README.md:112` and implementation note 2 both state
the refusal more broadly than the code implements, so they need narrowing or the
code needs widening — pick one.
