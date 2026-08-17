---
id: 20260808-origin-is-not-yaml-encoded-and-a-bare-brace-argument-is-substitu
num: 290
title: "origin is not YAML-encoded and a bare brace argument is substituted"
status: closed
priority: high
labels: [issue, security, invariant]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:49:41Z
updated: 2026-08-12T08:31:52Z
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

## Progress (2026-08-11)

**Part 2 is fixed** in `00f84dc`. `place_substitute` now reads a placeholder by
position as well as value: `{}` counts as one only as the operand of `--dir` or
as the trailing argument, and `{token}` only after `--place-token` or trailing.
Every entry script already builds its re-exec in one of those two shapes, so
nothing travelling through the middle of an argv can reach a marker position —
which removes the class rather than shrinking it a second time, as the proposed
action asked.

Reproduced before fixing, and it was worse than "low likelihood, permanent
consequence" suggests: `new.sh --title '{}'` under a placement filed at **rc 0**
with the slug `20260811-tmp-tmp-<rand>-collection` and wrote that row to the
append-only registry, where no later run can reclaim it. It now refuses, because
the title reaches slug derivation verbatim and `{}` yields an empty slug — the
right outcome for a degenerate title, and it burns no ordinal.

Pinned in `tests/place.sh` by that exact invocation, asserting the temp path
reaches neither stdout nor the registry log. Nine fixtures that passed a
placeholder mid-argv were moved to the trailing position, which is the shape the
contract now describes.

**Part 1 remains open** and is the reason this issue is not closed: whether to
YAML-encode `--origin` or narrow `untrusted-body-never-shell` to the documented
scope. One fact for whoever takes it, which this issue does not currently
record: `new.sh` contradicts itself. Its file header says the encoding exists
because `--title`/`--labels`/`--origin` are untrusted; the implementation
comment at the emit site says origin is skill-controlled and outside that set. A
comment changes whichever way the fork is resolved, so "the code deliberately
recorded the narrower scope" is not settled intent to defer to.

## Resolution (2026-08-12)

**Both halves are now closed.** Part 2 — the bare-brace argument — was closed
under WP14 and is described above.

Part 1 is closed in `227ce29` by the first arm of the fork: `--origin` is encoded
the way `--title` is, rather than narrowing the invariant to match the code.

The deciding fact is one the issue left open. The code's comment called origin
"skill-controlled", but `skills/issue/SKILL.md` defines it as "relative path to
the source artifact when knowable… or `conversation`" — a convention with nothing
mechanical enforcing it, composed by a skill's *prompt*. That makes it
model-produced text of the same trust class as a title, so the narrower scope was
not a deliberate security judgment to defer to. Narrowing a critical invariant to
match code that had just produced a finding would also have been the move the
remediation's own standing rule forbids.

Note this does **not** close the index-row forgery route that shares an origin:
the row is built from the *parsed* value, so ` · ` survives any YAML quoting.
That is fixed at the index writer under
`20260812-index-md-rows-are-forgeable-by-two-independent-routes`.

Pinned by `case_new_origin_is_a_quoted_scalar`; the template and the file's
security-model header were brought into agreement in the same pass.
