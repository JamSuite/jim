---
id: 20260823-six-identity-tests-do-not-discriminate-a-wrong-implementation
num: 362
title: "Six identity tests do not discriminate a wrong implementation"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [testing]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:50Z
updated: 2026-08-23T23:21:50Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

## Description

## Description

Six of the identity test cases pass regardless of whether the code under test
is correct. They make coverage read as real where it is not.

## The cases

**`case_migrate_identity_usage_refuses_both_modes`** asserts the error text
contains `renormalize`. Both refusal branches contain that word:

```
error: choose one of --renormalize or --from/--to, not both
error: identity requires --renormalize, or --from <old> --to <new>
```

A regression collapsing the two distinct branches into one generic message —
losing the both-given versus neither-given distinction — still passes.
Asserting `not both` would pin the branch under test.

**`case_identity_mailmap_absent_mapping_changes_nothing`** and
**`case_identity_map_carries_an_unmapped_address_through`** — git returns an
unmapped address unchanged whether the alias-resolution step is implemented,
stubbed, or deleted outright. Neither case can tell the difference.

**`case_identity_scheme_absent_takes_the_default`** uses an address that is a
no-op under both `email` and `github`, so it rules out a default of `local` and
nothing more. It never pins the documented default. Using a relay address and
asserting the extracted account name would.

**`case_identity_normalize_case_leaves_a_lower_value_alone`** — a `normalize`
that was a plain passthrough would pass identically.

**`case_migrate_identity_apply_regenerates_the_index`** checks only that
`INDEX.md` exists. A regeneration from stale state, from the wrong directory,
or before the rewrite landed would still leave a file there. Asserting that the
mismatch warning is present before the apply and gone after would discriminate.

## Related

`case_identity_option_shaped_values_are_read_as_data` is sound but cannot
isolate the mutant it appears to target: the value is wrapped in angle brackets
before reaching git, and the wrapping alone neutralizes option shape, so
removing the end-of-options separator does not break it. Worth a comment
recording what the case does and does not prove.

## Why it matters

One case in this same family was already found non-discriminating during the
build and deleted — it asserted the git manual page never appears, and passed
even when the value was reaching git as an option. These six are the same class.

Origin: `docs/specs/issue/013-recorded-identity-schemes/review.md` — Finding 8.
