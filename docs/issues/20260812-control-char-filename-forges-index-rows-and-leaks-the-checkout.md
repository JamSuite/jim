---
id: 20260812-control-char-filename-forges-index-rows-and-leaks-the-checkout
num: 328
title: "Control-char filename forges index rows and leaks the checkout"
status: closed
priority: critical
labels: [issue, security, data-integrity]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:18Z
updated: 2026-08-13T07:57:24Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

Under a branch placement the collection arrives from a shared branch any
teammate can write, so an entry name is untrusted input. Nothing in the chain
rejects control characters in one.

`place_materialize` (`skills/issue/scripts/place.sh:1293-1341`) gates five
things: mode `100644|100755`, no `*/*` and not `.`/`..`, no leading `-`,
`jimfile.sh valid-relpath`, and a `realpath -m` containment check. None of them
sees a newline or a tab. `cmd_valid_relpath` (`skills/file/scripts/jimfile.sh:229-246`)
checks only empty, absolute, and `..` segments.

`index.sh` then enumerates with an unquoted expansion
(`skills/issue/scripts/index.sh:338`):

    IFS=$'\n' files_sorted=($(printf '%s\n' "${files[@]}" | sort))

`IFS=$'\n'` closes space-splitting but pathname expansion is still live, and
`set -f` appears nowhere in the corpus. So an ordinarily-committed file named
`20260101-a.md<LF>*.md` splits into two words and each is glob-expanded. The
fragment after the newline is a **relative path resolved against the run's CWD**,
which is the developer's primary checkout — `place.sh` never leaves it. A
fragment of `*.md` therefore enumerates the project root's markdown,
`index.sh:361-366` takes `basename … .md` as a slug (which passes `is_valid_id`),
parses each file's frontmatter scalars, and renders them as issue rows. `place.sh`
publishes that index to the shared destination branch.

The per-slug validator at `index.sh:364` cannot catch this: it runs on the
fragments, after the split. A tab instead of a newline takes the other branch —
the entry is materialized and published, but its slug fails `is_valid_id`, so the
file is silently never indexed.

A narrower path corrupts `place.sh` itself. The two-phase base snapshot is a
line-oriented round trip (`place_save_snapshot:878-886` writes `sha\tname`,
`place_load_snapshot:888-899` reads it back per line), so a newline-bearing name
loads as two bogus records. A fabricated record reaches the deletion loop at
`place_build_commit:1433-1436` as a real name, which can drop a dotfile entry from
the published tree and land the empty commit the retry guard promises never to
leave.

Reached independently by three agents on different tasks during the fourth
review — one region investigator and the `untrusted-body-never-shell` and
`materialization-contained` judges.

No test in `tests/place.sh` or `tests/issues.sh` covers a control character in an
entry name, in either direction. The outbound gate (`place_snapshot`,
`place.sh:1362-1389`) has the same hole, so a wrapped command can create such a
name too.

## Action

Two fixes, both wanted — the second is the containment gate, the first is the
defence in depth that makes the enumeration correct regardless:

1. `index.sh:338` — quote the substitution and read the sorted list with
   `while IFS= read -r -d ''` (or `sort -z`), so a filename is one word whatever
   bytes it holds.
2. `place.sh` — reject any entry name containing `[[:cntrl:]]` in **both**
   `place_materialize` (inbound) and `place_snapshot` (outbound), beside the
   existing gates.

Pin each direction with a case that plants a newline-bearing name and asserts the
refusal, and one asserting no row is rendered for a path outside the collection.

## Progress (2026-08-13)

**Action item 1 is closed** in `6e68a22`; **action item 2 is not taken.** The
issue stays open on the containment gate.

**What shipped — the enumeration.** Taken differently from the proposal, and the
difference is worth recording. The action asked to quote the substitution and
read the sorted list NUL-delimited. Instead the re-sort is **removed**: the glob
that builds the list already returns it in order, because bash sorts pathname
expansion and `LC_ALL=C` makes that byte order — byte-for-byte the order a sort
of the same full paths yields, since they share a directory prefix. That
equivalence was checked against a sweep of one filename per byte value 1–255
before being relied on. Deleting the round trip removes the splitting surface
outright rather than quoting around it, and drops a `sort -z` dependency the
NUL-delimited form would have added.

The sweep found exactly one input where glob order and sort order disagree, and
it is this finding's own: a name carrying a newline. There the old path did not
produce a different order — it produced a **corrupted array**, one element torn
into two, the second having lost its directory prefix entirely. That fragment is
what re-globbed.

Pinned by `case_issues_index_control_char_name_does_not_reglob`, which plants a
decoy in the invoking working directory and asserts neither its row nor its
frontmatter reaches the collection's index. Proven by neutering: restoring the
split turns it red.

**What the fix exposed.** With the enumeration corrected, the raw name reaches
the "not a valid id" refusal, and that message was concatenated into the
warnings block unsanitized — so a committed filename forges a second
`## Issues` section and a row inside it. That site is named by neither this
issue nor the sanitizer one. It is fixed and pinned in the same commit, and it
is why the two were taken as one pass: this issue's fix is what made it
reachable.

**What is left — the containment gate.** `place_materialize` (inbound) and
`place_snapshot` (outbound) still accept an entry name containing
`[[:cntrl:]]`. Everything this issue records about the two-phase base snapshot
stands: it is a line-oriented `sha\tname` round trip, so a newline-bearing name
still loads as two bogus records, and a fabricated record still reaches the
deletion loop as a real name. `index.sh` no longer *renders* anything from such
a name — it refuses it with one sanitized warning — but nothing yet stops one
being materialized or published.

That half belongs with the `place.sh` pass rather than here, because it is the
same file and the same read of the placement door as three other open findings,
and the by-file rule puts them in one edit.

## Resolution

**2026-08-13.** Closed. **The `## Progress` section above is superseded**: it
was written when action item 1 had landed and item 2 had not, and item 2 has
since landed in `19eb76e`. Item 1's account there still stands — read it for why
the enumeration was fixed by removing the re-sort rather than by quoting it.

**The containment gate is in both ends.** `place_materialize` refuses an
inbound entry name containing `[[:cntrl:]]`, and `place_snapshot` refuses to
publish one, beside the gates each already carried. Neither of the existing
gates could see one: the plain-name test looks for separators, `valid-relpath`
checks segments, and realpath containment is satisfied by a name that stays in
the directory.

Pinned in both directions:

- `case_place_refuses_a_control_character_in_a_materialized_name` seeds a
  destination branch whose single entry carries a newline. `mktree` is
  line-oriented and cannot express such a name, so the fixture uses its `-z`
  form — which is what makes the point: git itself is content with the name, and
  only jim's own gates are asked to reject it.
- `case_place_refuses_to_publish_a_control_character_name` drives a wrapped
  command that creates one. Before the fix this case **published the name to the
  destination branch at rc 0**, which is the outbound half this issue predicted.

Both proven by neutering their gate and watching the case go red.

**What this does and does not close.** The two-phase base snapshot is still a
line-oriented `sha\tname` round trip, and `index.sh`'s row set is still built by
a reader that would be confused by such a name. Neither is reachable any more,
because no such name can now enter the collection or leave it — the gate is what
makes those readers safe rather than each reader being hardened. That is the
same argument the leading-dash gate rests on.

Suite **1376 → 1383**.
