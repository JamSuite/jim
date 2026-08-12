---
id: 20260812-records-docs-and-commit-subject-hygiene-after-the-review
num: P-20260812-records-docs-and-commit-subject-hygiene-after-the-review
title: "Records docs and commit subject hygiene after the review"
status: open
priority: low
labels: [docs, records, hygiene]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:54:00Z
updated: 2026-08-12T21:54:00Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

Low-priority record and documentation corrections surfaced by the fourth review.
Grouped because each is a one-line fix and none blocks anything.

## 1. `remediation.md` contradicts itself about the cross-group write paths

`docs/specs/issue/011-issue-placement/remediation.md:68` says "`review.md`'s 'five
that gate closure' list is fully stale — all five are closed."

`:813-814` says "Four of those five are closed by the round that followed; **only
item 3, the two cross-group write paths, is still owed**."

Its own § *The review-remediation round* (`:907-908`) records both as shipped, and
both issues are `status: closed`. A resuming reader who hits `:814` first inherits
phantom owed work.

**Action:** update the `**Superseded 2026-08-12.**` paragraph to say all five are
closed.

## 2. Two issues are closed carrying an unfiled remainder

- `docs/issues/20260812-dirty-guard-is-fail-open-on-any-git-failure.md:72-80` —
  "**The handle fingerprint is not taken.** The finding's second, structural half
  stands… Deferred rather than dropped." No follow-on exists (grep for
  `fingerprint` across `docs/issues/` hits only this file).
- `docs/issues/20260812-two-placement-cases-cannot-fail-and-four-guards-have-no-coverage.md:86-92`
  — five named guards "are not yet pinned." No follow-on exists.

This inverts the stated convention (`remediation.md:226-227`): a narrowed issue
takes a `## Progress` section *instead* of being closed. "Deferred rather than
dropped" is only true if something tracks it. The tracked set of eight therefore
under-counts by two.

**Action:** file each remainder as its own issue and cite it from the `## Progress`
section, or reopen the parent.

## 3. Documentation that contradicts the code

- `jimconf.toml.example:12` still says "Nested TOML tables and arrays are
  **silently ignored** — flat config only." An array value now **refuses**. This is
  the file a user edits while writing the offending line.
- `skills/conf/scripts/jimconf.sh:137-138` — `parse_value`'s summary says
  "…or nothing if the key is missing **or the file is unreadable**", contradicting
  its own body at `:144-152` and `:166-169`, where an unreadable file is an rc-1
  refusal. Same class at `:141` and implementation note 1 (`:413-416`), which claim
  nested-table lines are ignored when in fact a scalar line inside any `[section]`
  matches.
- `README.md:112` and implementation note 2 state the value-form refusal more
  broadly than the code implements (a triple-quoted value still falls back).

**Action:** correct each to state the current grammar.

## 4. The provider blueprint does not declare a guarantee its consumer relies on

`docs/specs/platform/000-blueprint/spec.md:30-35` records only "zero-config
defaults when `jimconf.toml` or a key is absent". The unset-vs-failed distinction —
what lets the placement gate's refusal hold — is declared only in the consumer's
blueprint (`docs/specs/issue/000-blueprint/spec.md:107-110`).

**Action:** add it to the `jimconf.sh` Provides entry via `/jim:blueprint`.

## 5. Commit-subject discipline

74 of 140 subjects over `f024b9e..HEAD` exceed the 50-character limit
`CLAUDE.md` sets. The remediation named this as a standing rule for the round
(`remediation.md:219-221`, citing 25 of 41 in the reviewed range); the ratio did
not improve. Not worth rewriting history for — noted so the next round's author
sets out knowing the rule is currently honoured in the breach.

## 6. Trivial

`skills/issue/scripts/index.sh:259-261` — `resolve_dir`'s docstring is separated
from `resolve_dir()` at `:283` by `row_safe`'s docstring and body, so the file
reads as if `row_safe` is documented twice and `resolve_dir` not at all.

`skills/issue/scripts/new.sh:6` — the sentence rewritten this round to de-count the
roster still carries `(spec 025 AC1–AC3)`, against `CLAUDE.md`'s rule that script
comments carry no artifact IDs. The surrounding SECURITY MODEL block's citations
are pre-existing and covered by the open purge issue; this one sits inside text the
round edited.
