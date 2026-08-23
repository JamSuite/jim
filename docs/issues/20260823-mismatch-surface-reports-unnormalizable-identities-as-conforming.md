---
id: 20260823-mismatch-surface-reports-unnormalizable-identities-as-conforming
num: 361
title: "Mismatch surface reports unnormalizable identities as conforming"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, index, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:45Z
updated: 2026-08-23T23:21:45Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

## Description

## Description

`index.sh`'s configured-form mismatch warning treats a value it cannot
normalize as a value that already matches, so the records most in need of
attention are the ones it stays silent about.

## What happens

When `identity.sh normalize` fails for a recorded value, the code falls back to
the value itself:

```
ident_form="$(bash "$IDENTITY" normalize "$ident_value" 2>/dev/null)" \
  || ident_form="$ident_value"
```

`ident_form` then trivially equals `ident_value`, the comparison finds no
difference, and the record is stored as conforming.

## Demonstrated

A collection holding three issues:

| recorded `filed-by` | flagged? |
| :--- | :--- |
| `bob]smith@example.test` | no |
| `has space@example.test` | no |
| `1234+Dev@users.noreply.github.com` | yes |

The first two hold identities that are not recordable at all — outside the
accepted character set — and the surface reports them as matching the
configured form. Only the well-formed relay address is flagged.

## Why it matters

A value that cannot be normalized can never legitimately equal a normalized
form. It is either unrecordable content or a value the form cannot judge, and
both are exactly what an operator running a form migration needs surfaced. The
current behaviour narrows the acceptance criterion — "when the collection holds
identities the project's current form would record differently, that mismatch
is surfaced" — to only those mismatches whose value happens to already be
clean.

Pre-conversion and hand-edited records are a realistic source: this project's
own collection carried three such records until they were re-normalized.

## Direction

Failing to normalize should count as a mismatch, not as a match. The fallback
is the wrong default in a check whose whole purpose is to notice trouble.

Origin: `docs/specs/issue/013-recorded-identity-schemes/review.md` — Finding 3.
