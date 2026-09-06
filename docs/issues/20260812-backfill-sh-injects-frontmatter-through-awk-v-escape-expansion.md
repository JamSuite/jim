---
id: 20260812-backfill-sh-injects-frontmatter-through-awk-v-escape-expansion
num: 301
title: "backfill.sh injects frontmatter through awk -v escape expansion"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T03:41:36Z
updated: 2026-08-12T18:58:07Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

`backfill.sh` passes untrusted timestamp values through `awk -v`, whose
escape-sequence processing turns a literal `\n` in an issue file into a real
newline inside the frontmatter block.

## Mechanism

`skills/issue/scripts/backfill.sh:168-183`:

```
cval="$(field_value "$f" created)"
new_c="$(normalize_ts "$cval" "$f" created)"      # malformed -> returned UNCHANGED
[[ "$new_c" == "$cval" && "$new_u" == "$uval" ]] && continue
if awk -v c="$new_c" -v u="$new_u" '
  fm == 1 && /^created:/ && !cdone { print "created: " c; cdone = 1; next }
```

`awk -v var=value` processes the value as a **string literal**, expanding escape
sequences — POSIX awk, gawk and mawk alike. `created`/`updated` are read straight
out of an untrusted issue file, and `normalize_ts` returns a malformed value
verbatim.

The skip fires only when *both* fields are unchanged, so a file with one
normalizable date-only field and one malformed field **is** rewritten. A file
carrying (literal backslash-n):

```
created: not-a-date\nstatus: closed
updated: 2026-06-13
```

is rewritten to a frontmatter block with a real newline and an attacker-chosen
key — or a `\n---\n` that closes the frontmatter early.

`reconcile.sh:150` passes `-v n="$newnum"` gated on `^[0-9]+$`, and
`migrate.sh:302` is clean by comparison. `backfill.sh:178` is the one unguarded
site.

## Proposed action

Validate the value against the timestamp shape before it reaches `awk -v`, or
pass it through a file / `ENVIRON` rather than `-v`. Note that
`normalize_ts` returning malformed input unchanged is what makes the value
reachable at all.

## Origin

Post-build review of `issue/011`; found by the `untrusted-body-never-shell`
judge. Pre-existing rather than introduced by that spec.

## Resolution (2026-08-12)

Fixed in `ff56061`, taking **both** halves the mechanism names rather than
either alone.

1. **The value no longer travels through `awk -v`.** `c` and `u` reach awk
   through the environment and are read as `ENVIRON["c"]` / `ENVIRON["u"]`, which
   performs no escape expansion.
2. **Only a value the normalizer minted is ever written.** The rewrite is now
   gated per field on whether `normalize_ts` actually changed it, so the
   malformed-and-returned-unchanged path — the thing that made the value
   reachable at all, as this issue's proposed action notes — no longer reprints
   issue-file text through the writer. A skipped field's line is passed through
   verbatim.

Either guard closes the vector on its own. Both stand because the first rests on
a contract `normalize_ts` states and the rewrite loop cannot see; a later change
to the normalizer's malformed-input behaviour would silently re-open a
single-guard fix.

Pinned by `case_issues_backfill_normalize_no_escape_expansion`, which places
`status:` *after* `created:` in the fixture so an injected pair becomes the first
match a reader resolves. Proven to go red against the pre-fix code: the case
reports `status` resolving to `closed` and two `status:` pairs in the file. The
assertion is deliberately on what a reader resolves rather than on whether the
attacker's text survives — the text is the issue's own field value and not this
script's to censor; what must not survive is its ability to form a pair.

`reconcile.sh:150` and `migrate.sh:302` were re-checked and remain clean: the
first gates its `-v` operand on `^[0-9]+$`, the second passes a mapfile path.
