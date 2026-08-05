---
id: 20260802-make-the-blueprint-pending-provisional-disclosure-enumerable-and
num: 208
title: "Make the blueprint pending-provisional disclosure enumerable and bounded"
status: open
priority: medium
labels: [blueprint, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-02T21:35:13Z
updated: 2026-08-05T02:25:13Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

## Description

blueprint/025 added an instruction at `skills/blueprint/SKILL.md:63`: a pending
provisional spec directory is excluded from synthesis, and the run's summary
must name each excluded identity rather than omitting it silently. The intent is
sound — a blueprint written over an incomplete group should read as incomplete.
The instruction as written cannot reliably do that, for three separate reasons.

**1. Nothing makes the model see the directory.** The same sentence directs the
model to glob the group's **numbered** spec directories — a glob that never
surfaces a `P-` basename. There is no `P-*` enumeration step, `pending_provisionals`
is not exposed as a CLI verb (`jimpartition.sh usage()` has no such subcommand),
and the skill's `allowed-tools` grants neither `jimalloc.sh` nor the relevant
`jimpartition.sh` verbs. `jimfile.sh glob specs <group>` does list every
directory including `P-` ones and *is* granted — but nothing points the model at
it.

**2. The obligation has no Step 5 hook.** Every other summary obligation in this
skill is restated where the summary is written (the downgrade classification,
the present-tense and provenance self-scans). This one lives only in Step 2
prose and must survive three steps of context.

**3. The payload is untrusted and unsanitized** — the living-intent sensor
graded `present-tense` (high) as violated on exactly this. A spec-directory
basename is filesystem-derived, attacker-influenceable content, and the
instruction routes it into the gate-facing summary through no sanitizer, no
length cap, and no delimiter, inline with the model's own framing. The
exit-door self-scans do not cover it (they are textually *draft*-scoped) and
neither does the secret-scrub obligation (*itemization*-scoped), so it falls
between them. Under `auto_blueprint` this reaches an unattended write summary.
The sibling code handling the identical data pushes every basename through
`san_field` (`jimpartition.sh:944-946`).

Related, in the same family: `jimpartition.sh:852`'s `san_field` truncates at
512 bytes with **no truncation note**, so the preflight's own "naming every
pending identity" (AC 10) is silently conditional for a group holding ~21+
pending identities. The sweep's discipline (`jimalloc.sh:2847`, `:2886`)
compares sanitized against raw and appends "… (list truncated)" for exactly this
reason.

## Proposed action

- Give the model a concrete enumeration step — either point it at
  `jimfile.sh glob specs <group>` (already granted) or expose
  `pending_provisionals` as a `jimpartition.sh` verb and grant it.
- Route the identities through a sanitizing boundary and present them delimited,
  matching the gate-presentation rule's treatment of untrusted evidence.
- Add a Validation Checklist line so the obligation is restated where the
  summary is composed.
- Add the truncation note to `san_field`'s consumers in the preflight path.

Note the textual-invariant tests (`tests/presenttense.sh`, `tests/provenance.sh`)
are not vacuous — the pointer counts sit exactly at their 5/5 minimum — but a
`>=` minimum is structurally blind to a newly added site that fails to cite,
which is the class this edit sits in. Worth considering whether those tests
should assert an exact count or enumerate sites.

Surfaced by the post-build review of blueprint/025 (findings 10, 11) and its
living-intent sensor (`present-tense`, high, in-change).

## Partially delivered (2026-08-05)

Two of the four proposed bullets shipped; two did not. Staying open for the
remainder.

**Delivered.** Bullet 1 — `skills/blueprint/SKILL.md:63` now points at
`jimfile.sh glob specs <group>`, and it fires: `cmd_glob` globs `*/` rather than
`[0-9]*`, so `P-` directories are returned. The prior instruction globbed
numbered directories and could never have surfaced a provisional. Bullet 3 — the
Validation Checklist line exists at `:518`, at the presentation boundary,
restating the cap verbatim.

**Not delivered.** Bullet 2 asked to route the identities "through a sanitizing
boundary **and** present them delimited". Delimiting shipped (backticks); no
sanitizer is named anywhere in the skill, and `glob specs` returns raw — a
directory named ``P-20260804-tick-`x`-end`` breaks the code span the instruction
relies on for containment. Bullet 4 asked for the truncation note on `san_field`'s
**consumers**, plural; exactly one got it.

**And the note that shipped is weaker than the model it cites.**
`jimpartition.sh:952-955` credits "the sweep's truncation discipline", but the
sweep it names (`jimalloc.sh:2983-2986`) emits `%d\t%s … (list truncated)` — a
count beside the cut list, with its own comment explaining why: "rather than
letting a count and a shorter list silently disagree." The new site copied the
note and dropped the count. Its cut is also **character-based, not item-based**
(`cut -c1-256`), so it fires identically at 9, 10, 11 and 50 provisionals and can
split a basename mid-identity.

**A false-positive disclosure, reproduced.** `shown="$(san_field "$pend" | cut
-c1-256)"` is compared against the raw `"$pend"`, so *any* sanitization trips the
note. One basename containing a tab produces `… (list truncated)` with nothing
truncated — on precisely the attacker-influenceable path this issue was written
about. Fail-safe in direction, but the fact now misreports its own completeness.

The two halves also disagree on the cut: the skill specifies ten items with a
counted tail, the script does 256 characters with an uncounted one.

Existing fixture (`tests/jimpartition.sh:1723`) asserts only that the note *can*
appear. Nothing pins the negative case, any count, the 255/256/257 boundary, the
control-character false positive, or the mid-name split.

Source: post-build review of the B-prime cluster,
`docs/notes/20260805-b-prime-review.md` (Finding 10).
