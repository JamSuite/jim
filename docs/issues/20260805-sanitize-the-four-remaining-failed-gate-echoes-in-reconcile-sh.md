---
id: 20260805-sanitize-the-four-remaining-failed-gate-echoes-in-reconcile-sh
num: 232
title: "Sanitize the four remaining failed-gate echoes in reconcile.sh"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, security, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T01:53:42Z
updated: 2026-08-05T10:21:33Z
origin: "20260805-b-prime-review.md (retired; see 5e712bf)"
---

## Description

`display_field` (`skills/spec/scripts/reconcile.sh:117`) carries the docstring
"used on values whose whole reason for being printed is that they just failed a
gate." It is called at exactly one of the five sites in its own file that match
that description, plus one sibling in `jimledger.sh`.

| site | token | source | sanitized | reachable with hostile bytes |
| :--- | :--- | :--- | :---: | :--- |
| `reconcile.sh:317` | `$newgroup` | registry | yes | — |
| `reconcile.sh:346` | `$held` | directory basename | no | **yes** |
| `reconcile.sh:155` | `$group` | directory name | no | yes |
| `reconcile.sh:162` | `$base` | directory name | no | yes |
| `reconcile.sh:172` | `$id` | **spec.md frontmatter** | no | yes |
| `reconcile.sh:327` | `$ord` | registry | no | no — see below |
| `jimledger.sh:649` | `$held` | directory basename | no | **yes** |

`spec_ordinal_holder` (`jimfile.sh:399-422`) constrains only the leading
`[0-9]{1,15}` token of a holder name, so `001-<ESC>[1;31mEVIL` is a valid holder
and is returned verbatim into both `$held` echoes. `$id` at `:172` is read
straight from a spec.md's frontmatter, so it is controlled by anyone who can land
a file in the repo. Live terminal-escape bytes on stderr were demonstrated with
`od -c` at every site marked reachable.

`reconcile.sh:327` (`$ord`) is listed for completeness and is **not** a live
escape: every producer emits either `printf '%s/%03d'` or `alloc_canon_specid`
output, and the security sweep could reach it through no real path. It is a
defence-in-depth inconsistency rather than a hole.

Severity is low — an operator's terminal, not data or control flow — but the
pattern is the point: a sanitizer was added for a class and applied to one member
of it, in the same file, ten lines from a sibling.

## Proposed action

Route `$held` (`reconcile.sh:346`, `jimledger.sh:649`), `$group` (`:155`),
`$base` (`:162`) and `$id` (`:172`) through the sanitizer. Include `$ord` (`:327`)
for consistency even though it is currently unreachable — the whole argument for
the primitive is that a reader should not have to re-derive reachability per site.

Consider whether `display_field` should also carry `alloc_display_field`'s
alteration disclosure (`… (sanitized for display)`), whose own docstring notes
that a silently-stripped token "reads as a DIFFERENT token".

Note `display_field` and `alloc_sanitize_field` agree on the deletion class but
differ on tab/newline handling (space vs delete) and cap (256 vs 512). Worth
deciding whether that divergence is deliberate.

## Provenance

Post-build review of the B-prime hardening cluster
(`docs/notes/20260805-b-prime-review.md`, Finding 4).

## Resolution (2026-08-05)

All six sites routed through the sanitizer, including `$ord` — the one the issue
listed as currently unreachable — for exactly the reason the issue gives: the
argument for having the primitive is that a reader should not re-derive
reachability per site.

`jimledger.sh` had no sanitizer at all, so it gained one with the same contract
its two siblings carry, rather than the single call site being special-cased.

**The two open questions are settled, one each way.**

*The tab/newline divergence is deliberate and now says so.* `alloc_sanitize_field`
maps them to spaces because its output is TAB-separated report rows, where
deleting a tab would join two fields into one plausible-looking token;
`display_field` deletes them because its output is prose on stderr, where a
surviving newline would forge a whole diagnostic line. Each is the safe choice
for where its result lands. The 512-vs-256 cap difference is arbitrary, nothing
depends on either value, and the comment says that too rather than implying a
rationale.

*The alteration disclosure was not added.* `alloc_display_field`'s "(sanitized
for display)" earns its keep where a report row is machine-read and a silently
stripped token reads as a different token. These sites are one-line human
diagnostics that already name what failed, so the suffix would be noise on every
message to disambiguate a case the operator is not comparing anything against.

Pinned behaviourally where each site is reachable — a hostile frontmatter id, a
hostile group name, a hostile provisional dirname, and a hostile occupancy holder
in `jimledger` — each asserting the offender is still named while no control byte
reaches the terminal. The remaining site, `$held` in the realize path, is harder
to reach behaviourally and is covered by a **class sweep** instead: no diagnostic
in `reconcile.sh` may interpolate `$held`, `$id` or `$ord` without the sanitizer.
Unwrapping that one site turns the sweep red, which is what makes the site
without a behavioural fixture something other than a blind spot.

Six mutations red, including one that strips the sanitizer's own body.
