---
id: 20260827-a-pinned-slug-silently-overwrites-an-existing-issue
num: 403
title: "A pinned slug silently overwrites an existing issue"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [emitter, data-loss]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-27T11:30:51Z
updated: 2026-08-27T11:30:51Z
origin: "docs/specs/issue/000-blueprint/spec.md"
---

## What

`new.sh` refuses to overwrite an existing issue file when the id came from the
allocator, and silently overwrites one when the caller pinned it.

The collision handling lives entirely inside `if (( slug_via_alloc ))`. A
caller who pins both `--slug` and `--num` never enters that branch, so the path
is composed with no existence check and the atomic `tmp + mv` replaces whatever
was there.

## Reproduced

Two filings, same pinned slug, different bodies, in a fresh collection:

```
new.sh --slug 20260101-pinned --num 1 --title First  --body-file b1   rc=0
new.sh --slug 20260101-pinned --num 2 --title Second --body-file b2   rc=0
```

After the second: the first issue's body is gone, the second's is in its place,
one file in the collection, nothing on stderr, exit 0 both times. The record
that was destroyed left no trace — not a warning, not a status, not a second
file.

## Why this is a contradiction rather than a gap

The adjacent arm already states the rule the pinned arm breaks. Where the
allocator issued the id, a local collision is refused:

> a local filename collision here is tree/registry drift — refused, never
> overwritten

`never overwritten` is the project's stated stance, eight lines above the
branch that overwrites. The comment that governs the pinned path says only that
a caller-pinned slug `is never altered` — which is about declining to suffix it,
not about declining to refuse.

## Reachability

Latent, and narrower than it sounds. `SKILL.md` step 6 tells every caller not
to pass `--slug` or `--num`, and no production caller does — the flag appears
only in `new.sh`'s own parsing, in tests, and in specs. It is reachable by an
operator invoking the emitter directly, and by any future caller that pins an
identity.

## Fix shape

Apply the existing refusal to the pinned arm: when `--slug` names a file the
collection already holds, refuse rather than compose the path. The message the
allocator arm uses does not fit (this is not registry drift), so it needs its
own — naming the slug and that a record already holds it.

The suffixing behaviour should stay allocator-only. A pinned slug is a caller's
assertion about identity, and quietly turning it into `<slug>-2` would answer a
different question than the one asked. Refusing answers it.

## Relations

Distinct from the mixed-pin skew already filed, which is about pinning exactly
one of `--slug`/`--num` and discarding the unused half of an allocated pair.
That one produces a registry↔disk disagreement; this one destroys a record.
Same flag, different failure, and a fix for either leaves the other standing.

## Provenance

Surfaced in passing by a judge during a blueprint grounding run, while it was
judging `atomic-index-write` — which it correctly reported as holding, naming
this as a duplicate-prevention gap rather than an atomicity one, since the
overwrite is itself a clean `tmp + mv`. No current invariant covers it.
