---
id: 20260823-identity-domain-with-a-leading-dot-silently-no-ops
num: 359
title: "identity_domain with a leading dot silently no-ops"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, conf]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:51Z
updated: 2026-08-25T06:48:13Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

## Description

`identity_domain = ".company.example"` — a plausible mistype — clears every
gate and then silently makes organization-local extraction a permanent no-op.

## What happens

The domain gate refuses an empty value, a value naming several domains, and a
value outside the accepted character set. A leading dot passes all three: it is
non-empty, names one domain, and `.` is in the accepted set.

Extraction then matches addresses ending in `@.company.example`. No real
address ends that way, so every address falls through to the form below and the
organization-local form does nothing at all — with no refusal, no warning, and
no signal of any kind.

## Why it matters

The project's stated position on the neighbouring case is that a warning is the
weaker choice: selecting the organization-local form with no domain configured
refuses every operation that would record an identity, rather than proceeding
and mentioning it. A domain that cannot match anything is the same situation
reached by a different typo, and it currently proceeds silently.

The consequence is quiet rather than loud: identities keep being recorded, just
not in the form the project chose, and the mismatch surface will not flag them
because they do match the form as the code is actually applying it.

## Direction

A domain whose shape cannot match any address is a configuration that cannot be
applied. Refusing it, naming the setting, would match how the absent-domain case
is already handled.

Origin: `docs/specs/issue/013-recorded-identity-schemes/review.md` — Finding 10.

## Resolution (2026-08-25)

Refused at the gate, in `d0bc02d`.

`domain()` in `skills/issue/scripts/identity.sh` carries a fourth guard: a
value whose label is empty or edged with a hyphen is refused, with a message
that names the setting and withholds the value, like the three guards above
it. The function's comment block gains the matching bullet.

**Extended past the reported shape.** A leading dot is one of several
unmatchable shapes that clear the charset gate — a trailing dot, consecutive
dots, a leading or trailing hyphen, and a hyphen on either side of a dot are
the same configuration reached by different typos, and each makes the form a
permanent no-op in exactly the same way. The guard is label-boundary validity
rather than a list of the mistypes anyone thought of.

`case_identity_domain_that_cannot_match_refuses` pins all nine values, each
asserted against the message unique to this guard so the guard is what the
case holds rather than the outcome.
`case_identity_domain_single_label_is_accepted` pins the other edge: the
guard refuses what can never match, not every domain without a dot, so
`localhost` still extracts.

`README.md`'s `identity_domain` row records the new refusal beside the
absent-value one it already described.
