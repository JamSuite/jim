---
id: 20260826-untrusted-values-reach-awk-through-v-in-two-scripts
num: 398
title: "Untrusted values reach awk through -v in two scripts"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, security, awk]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:35:24Z
updated: 2026-08-27T09:48:37Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## What

`migrate.sh` and `transition.sh` pass untrusted values into awk with `-v`.
`backfill.sh` deliberately does not, and says why: POSIX awk processes a `-v`
operand as a string literal and expands backslash escape sequences in it, so a
value carrying `\n` becomes a real newline inside the awk program's variable.

`ARCHITECTURE.md` records this reasoning as the project's convention — values
reach awk through the environment, not through `-v`.

## Where

- `skills/issue/scripts/migrate.sh` — `apply_schema_plan`, `apply_identity_plan`
- `skills/issue/scripts/transition.sh` — `set_fields`

Both write frontmatter fields, so the values in question are identities and
enumerated scalars rather than free text — which is what bounds the exposure.

## Exposure

Narrow, because of what else is true:

- identities clear `IDENTITY_CHARS` before they reach either path, and that set
  admits no backslash;
- outcomes and types clear their own enums.

So there is no presently-reachable value that carries an escape sequence into
either call. The concern is that the guarantee currently rests on the callers'
gates rather than on the channel, while the project has already decided the
channel is where it belongs — and `backfill.sh` already pays that cost.

## Provenance

Pre-existing; untouched by the read-view filter work. Surfaced while auditing
that work's own awk usage, which is clean throughout (every new program is a
single-quoted literal taking the index file as a positional argument, with the
relation type compared in shell rather than passed in).

## Fix shape

Route both through `ENVIRON`, matching `backfill.sh`'s `cmd_timestamp`. The
change is mechanical and the pattern to copy is in the same directory.

## Resolution

Fixed in `3b60434`, taking the fix shape above — and at five call sites
rather than the two this record names.

**Every claim here was checked by running it, and all of them hold.** `awk -v
v='a\nb'` yields a three-character value carrying a real newline where the
environment yields the four characters written; `IDENTITY_CHARS` is
`A-Za-z0-9._%+@-` and admits no backslash; `identity.sh` refuses
`a\nb@example.test` at rc 2; `--from` and `--to` each clear `jid validate`
before use; the history-recovered filer clears `jid normalize` or is
classified `unresolved` and never converted; an unrecognized outcome refuses
at rc 2 naming the vocabulary. Nothing presently reachable carried an escape
sequence into either call, exactly as recorded.

**The harm is sharper than "expands escape sequences" suggests.** A value
printed into frontmatter does not merely wrap onto a second line — it writes a
second `key: value` pair. Through the field rewriter's own shape,
`x\nstatus: closed` written to `filed-by` produces a `status: closed` line
sitting beside the record's own `status: open`. That is the row-forgery
property one layer down: in the file, rather than in the index where
`row_safe` already prevents it.

**Three sites were named; the group holds ten.** The seven unnamed were
checked one by one. Five carry literals, computed integers, or a `mktemp` path
the script itself made, and stay on `-v`. Two were the same shape as the named
pair and moved with them: the realizer's mapping lookup in `reconcile.sh`,
whose key clears a validator in a different function, and `apply_plan`'s
lookup in `migrate.sh`, whose key is a raw directory entry that has cleared
nothing at all. `apply_plan` was the one genuinely ungated value in the group,
and there the consequence was not forgery but silence — an expanded escape
misses a row it should have matched and takes the fallback. It stayed
fail-safe because that fallback is validated before any path is composed, and
it still is: a collection holding a `20260101-a\nb.md` is skipped at preview
and refused at apply, unchanged either way.

**One premise here is overstated, and it is worth correcting rather than
inheriting.** This record argues the guarantee "rests on the callers' gates
rather than on the channel, while the project has already decided the channel
is where it belongs". `ARCHITECTURE.md` records the opposite for a validated
value: `jimledger.sh updates-since` parses the untrusted ledger *through*
`awk -v`, justified because the watermark is format-validated first. So the
decided rule is narrower than stated — an **unvalidated** value goes through
the environment, and a format-validated one may use `-v`. Both sites named
here pass values that clear a charset or enum gate, so they already matched
the accepted exception rather than breaching the rule.

That does not undo the fix; it re-describes it. `set_fields` reads both halves
out of its `<pairs>` argument and cannot see which caller built them, and the
realizer's key is gated in another function — each was holding a guarantee at
a distance, which is the shape this increment's retrospective is about. Moving
them puts the guarantee in the channel, where it holds regardless of what a
caller does next. It is a consistency change, which is why it was low.

**Blast radius: none for real data.** No recorded identity, outcome or field
name contains a backslash, so `-v` and the environment produce identical
strings for every value the collection holds. Confirmed by the suite at 1,628
green and by exercising both rewritten write paths end to end against a real
repository — a `close --as wontfix` and an identity remap, both byte-correct.

**Not closed by this.** `backfill.sh` is not a `-v`-free script and this
record can be read as saying so: it uses `awk -v n=` for a computed number.
The rule it embodies is about untrusted values, not about the flag.
