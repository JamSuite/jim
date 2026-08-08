---
id: 20260808-origin-is-not-yaml-encoded-and-a-bare-brace-argument-is-substitu
num: P-20260808-origin-is-not-yaml-encoded-and-a-bare-brace-argument-is-substitu
title: "origin is not YAML-encoded and a bare brace argument is substituted"
status: open
priority: high
labels: [issue, security, invariant]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:49:41Z
updated: 2026-08-08T18:49:41Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

The `untrusted-body-never-shell` invariant (critical) is judged **violated** on
two counts. Neither is an injection — both are integrity gaps.

## 1. `--origin` is not YAML-encoded

The invariant reads: "title/label/origin scalars are YAML-encoded". The code
encodes two of the three. `skills/issue/scripts/new.sh:222-239`:

```bash
title_enc="$(printf '%s' "$title" | tr '\n\r' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g')"
# --origin: collapse newlines; emitted as a plain scalar (skill-controlled path
# or "conversation"). Not in the AC4 untrusted-field set, but normalized anyway.
origin_enc="$(printf '%s' "$origin" | tr '\n\r' '  ')"
```

and `:253-260` emits `title: "%s"` quoted but `origin: %s` bare. The template
agrees (`skills/issue/assets/issue-template.md:18`).

Because newlines are collapsed, origin **cannot** inject a new key or cross the
`---` boundary — the containment story holds. But an origin of `[a, b]`,
`foo: bar`, `#x`, or a `!!tag` changes the parsed type or makes the frontmatter
unparseable for a real YAML consumer, and it lands verbatim in `INDEX.md` prose
(`skills/issue/scripts/index.sh:465`, `:504`).

**This predates issue/011** — the code's own comment records the narrower scope
deliberately. It is a standing divergence between the invariant text and the
code, surfaced because the invariant was judged for the first time.

Resolution is a fork: quote origin the way title is quoted, **or** narrow the
invariant to the deliberate, documented scope (title + labels). Do not resolve it
by assuming the invariant was always aspirational.

## 2. An argument that is exactly `{}` is still substituted

`place_substitute` (`skills/issue/scripts/place.sh:174-185`) was narrowed so only
a whole-argument match is replaced — which closed the realistic case
(`interface{}`, `map[string]interface{}`). It did not close the literal case:

```bash
case "$a" in
  '{}')      a="$dir" ;;
  '{token}') a="$token" ;;
esac
```

`new.sh:126-127` forwards the caller's entire argv through `place.sh run`, so
`new.sh --title '{}'` under a branch placement re-execs with `title` set to the
run's temp collection path. That value then feeds `jimalloc allocate issue`
(`new.sh:157`) and becomes both the stored title and the durable slug an
append-only registry records — permanently.

Low likelihood, permanent consequence, and the same durable-id harm the
narrowing was written to prevent.

## Proposed action

For (2): substitute only the trailing `--dir` / `--place-token` operands that
`new.sh` itself appends, rather than scanning all of argv — position plus value,
not value alone. That removes the class rather than shrinking it again.

## Test

`tests/place.sh:271-288` covers `'Fix the {} placeholder'`, `'a{token}b'` and
`'map[string]interface{}'`. No case passes an argument that IS exactly `{}`.
