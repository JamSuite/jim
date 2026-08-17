---
id: 20260812-emitter-writes-created-and-updated-to-yaml-unencoded
num: 331
title: "Emitter writes created and updated to YAML unencoded"
status: open
priority: high
labels: [issue, security, emitter]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:22Z
updated: 2026-08-12T21:53:22Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

`new.sh` emits nine frontmatter scalars. Seven are gated or encoded; two are
neither.

`skills/issue/scripts/new.sh:308-320`:

    printf 'id: %s\n' "$slug"             # validated: jimfile.sh valid-id (:252, :264)
    printf 'num: %s\n' "$num"             # validated: ^[0-9]+$ | P-<valid-id> (:220-226)
    printf 'title: "%s"\n' "$title_enc"   # encoded (:279)
    printf 'status: %s\n' "$status"       # enum-validated (:190-193)
    printf 'priority: %s\n' "$priority"   # enum-validated (:185-188)
    printf 'labels: [%s]\n' "$labels_enc" # encoded (:291-298)
    printf 'created: %s\n' "$created"     # NEITHER
    printf 'updated: %s\n' "$updated"     # NEITHER
    printf 'origin: "%s"\n' "$origin_enc" # encoded (:287)

`--created` / `--updated` are parsed raw at `:96-97` and, when non-empty, reach
lines 317-318 untouched — `:213-214` only supplies a default when they are absent.
No `case`, no regex, no `tr`/`sed` pass anywhere in the file.

A value carrying a newline emits a second frontmatter pair. Because these two are
written **before** `origin:`, an injected `origin:` becomes the *first* occurrence,
and both readers take first-match — `index.sh:141` (`if (key in seen) next`) and
`render.sh:574` (`head -n1`). A value containing a bare `---` line closes the
frontmatter block early against `index.sh:107-117`.

The file header claims otherwise, at `new.sh:15-18`:

    #   - Scalar fields are YAML-encoded so an untrusted --title/--labels/--origin
    #     cannot inject or alter frontmatter or cross the frontmatter/body boundary

True of three of them. `created`/`updated` are scalar fields it writes and does
not encode.

The group's own reasoning already covers this case. `new.sh:282-286`, on why
`--origin` is not exempt despite a convention:

    # convention is a source path or the `conversation` sentinel, but nothing
    # mechanical enforces either — it is composed by a skill's prompt, which makes
    # it model-produced text of the same trust class as a title.

That applies verbatim: `skills/issue/SKILL.md:152-156` has the agent substitute
the timestamps into the command line, and `SKILL.md:129` enforces the shape by
prose alone ("never hand-write the timestamp").

The shape pattern already exists and is drift-tested — `SYNC(ts-shape)` in
`render.sh:176`, `index.sh:389`, `backfill.sh:80`, with
`tests/issues.sh:1701-1709`. The emitter is the one writer that does not apply it.

`tests/issues.sh` has injection-containment cases for `--title` (`:2433`),
`--origin` (`:2580`), `--labels` (`:2615`) and `--num` (`:2735`). There is no
`--created`/`--updated` counterpart.

Judged a `critical` `untrusted-body-never-shell` violation in the fourth review's
living-intent sensor.

Minor, same area: the `tr '\n\r' '  '` at `:279`/`:287` collapses only CR and LF,
so other C0 control characters survive into the double-quoted scalar.

## Action

Gate both values against the `SYNC(ts-shape)` grammar before `:302`, refusing
otherwise, and add the two field names to the header's untrusted list at `:14-18`.
Pin with a case passing a newline-bearing `--created` and asserting the emitted
file has exactly one `origin:` and one `status:`.
