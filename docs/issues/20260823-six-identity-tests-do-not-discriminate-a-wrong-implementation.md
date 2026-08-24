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

## Resolution (2026-08-24)

Fixed in `2275999`. All six are confirmed and corrected, and the census that
confirmed them found three more.

**How they were confirmed.** Not by reading the cases — by mutating the surface.
Twenty mutants across `identity.sh`, `migrate.sh`'s identity subcommand and the
configured default, each applied to the real script, the identity subset run
against it, and the set of cases that went red recorded. A case its own mutant
does not kill is the finding. The whole census costs about twenty seconds per
mutant.

Five of the six were confirmed exactly as described. The sixth was confirmed
only against the mutant this issue actually names: the index **not** regenerated
does kill the case, because the fixture has no prior `INDEX.md`; the index
regenerated **before the rewrite lands** does not. The wording above is precise
and the first mutant tried was the wrong one.

**Three more of the same class, reported by nobody.**

- `case_identity_domain_naming_several_refuses` — remove the several-domains
  guard and the charset gate refuses the same input, because a comma and a space
  are both outside the domain set. Both messages say `identity_domain`, which is
  all the case matched.
- `case_migrate_identity_usage_requires_both_halves_of_a_remap` — remove the
  both-halves guard and the recordability check refuses the empty half. Its
  message names the same flag the case matched.
- `case_migrate_identity_remap_matches_without_case` — folds the record's side
  and never the operand's, so removing `from="${from,,}"` changes nothing it
  asserts. The property is symmetric; the case drove one direction.

All three are one shape: **an assertion matching a substring that two branches
share.** That is what the six have in common too, and it is searchable — where a
guard's refusal shares vocabulary with the guard after it, matching the shared
words pins the outcome rather than the guard.

**Two could not be made to discriminate and are paired instead.** An unmapped
address comes back unchanged whether the lookup ran, was stubbed, or was deleted
— there is no assertion that separates those. The mapped address in the same
fixture is what says a lookup happened at all, so the pair is the case now. That
recovers the coverage rather than recording its absence, which is the remedy the
notes had for this shape.

`case_identity_option_shaped_values_are_read_as_data` keeps its note, as the
Related section asked: the bracket wrapping neutralizes option shape on its own,
so neither mechanism is provable from outside and the case pins the property.

**What the census does not cover.** Its mutants target `identity.sh`,
`migrate.sh identity` and the configured default. Cases reaching the identity
surface through `new.sh`, `transition.sh`, `render.sh` or `index.sh` were run but
had no mutant aimed at them, so their silence is untested rather than clean.
