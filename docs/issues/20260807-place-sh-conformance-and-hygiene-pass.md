---
id: 20260807-place-sh-conformance-and-hygiene-pass
num: 269
title: "place.sh conformance and hygiene pass"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, refactor]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-07T11:43:58Z
updated: 2026-08-12T11:40:00Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

A bundle of small conformance and hygiene gaps in `place.sh`, each individually
minor. Grouped because they are one pass over one file.

**Header inaccuracies.** The header claims the commit is built with `mktree`;
the code uses a scratch `GIT_INDEX_FILE` + `update-index` + `write-tree`, and
`mktree` appears nowhere (`ARCHITECTURE.md` describes it correctly, so the
header is the copy that drifted). The `CLI SUMMARY` documents only `mode` and
`run`, omitting `begin`/`commit`/`abort` — the three verbs the skill body
actually calls and the only ones with `allowed-tools` clauses. `cmd_mode`'s
comment calls itself "the only place the config gate is evaluated" when three
other functions call `place_destination`. "Parses with grep/sed only" omits
`awk`, `tr`, and `read`. The `run` synopsis implies `--verb` is always required;
it is optional on a read-only run, which three callers rely on.

**`place_shown` diverges from the house sanitizer.** The established form is
`tr -d '\000-\037\177' | cut -c1-512` (four scripts). `place_shown` uses
`tr -d '[:cntrl:]'` and drops the length cap, so an uncapped branch-supplied
filename can flood a terminal. It is also applied at only one of three sites
that print a tree-supplied name — the graft conflict message and the snapshot
refusal print raw.

**New portability floor, undocumented.** `place.sh` is the first script in the
corpus to use namerefs (`local -n`), raising the bash floor from 4.0 to 4.3, and
introduces three new non-POSIX constructs (`grep -m1`, `find -mindepth`,
`find -print0`). Each is GNU+BSD and the floor was already above stock macOS
bash 3.2 via `declare -A`, so the marginal cost is small — but nothing records
the new floor.

**Third spelling of a constant.** `jim/registry` now has three production
spellings: jimconf's `default_for` (authoritative) plus dead-code fallbacks in
`jimalloc.sh` and now `place.sh`. Changing the default takes three edits.

**Inline charset regex where a verb exists.** `place_handle_dir` inlines
`^[A-Za-z0-9][A-Za-z0-9._-]*$` — the id boundary's charset, minus its length cap
and `..` rejection — for a caller-supplied value that composes a filesystem
path. `place.sh` already calls `jimfile.sh valid-id` twice, and the tokens it
mints pass it unchanged, so the swap is behavior-preserving. As written it is a
fourth spelling of a boundary the triplicate-identical fixture cannot see.

**Deliberate duplicates without the house marker.** `place_valid_branch` is
byte-identical to `alloc_valid_branch`, and `place_handle_root`'s containment
check is a near-copy of `alloc_write_contained` (place's is tighter). Extracting
a shared verb was deliberately deferred, but the precedent's *other* half was not
adopted: `is_valid_id` and `is_prov_token` each carry a `SYNC:` comment naming
every copy plus a byte-agreement fixture. Neither of these pairs has either.

**Missing `--end-of-options`.** Four git calls interpolate a derived argument
without it: `merge-base --is-ancestor`, `ls-tree -r -z`, `read-tree`, and
`update-ref`. Each is safe by construction today (the values are git's own hex
output or already gated), but the stated discipline is "every git call taking a
derived argument".

**`place_prefix` normalization.** `issues_path = "./"` yields prefix `.`, making
the repo root the collection — it fails closed, but on a message about entry
names rather than about the config. `"././docs/issues"` strips only one `./`, so
reads work and writes fail with the opaque "could not build the destination
tree". A loop, or rejecting any `.` segment at the gate, closes both with an
accurate message.

**`place_conf` fails open.** It discards jimconf's exit status, so an unreachable
resolver yields empty and `place_destination` falls through to `branch` — a
fail-*open* on the infrastructure path, three lines below a comment promising no
silent fallback. Requires a broken plugin tree, so it is an integrity concern
rather than an attacker path.

## Proposed action

One pass: correct the header, adopt the house sanitizer with its cap and apply
it at all three sites, delegate the token check to `jimfile.sh valid-id`, add
`SYNC:` comments plus a byte-agreement fixture for the two duplicated functions,
add the four missing `--end-of-options`, tighten `place_prefix`'s normalization,
and check `place_conf`'s rc. Record the bash 4.3 floor wherever the corpus
records its portability assumptions.

## Resolution (2026-08-12)

Fixed in `c250c6b`, all nine items in one pass over the file.

**Two changed behavior rather than presentation.**

`place_conf` discarded jimconf's exit status, so a broken plugin tree produced an
empty value indistinguishable from an unset key — and every caller reads unset as
a default. On `issue_placement` that default is `branch`, so an infrastructure
failure silently stopped centralizing and landed the write on the working branch.
Proven against the prior code rather than argued: with the resolver unreadable it
printed `direct` at rc 0; it now refuses at rc 2 naming the key. The
discrimination is exact — jimconf applies defaults at rc 0, so an absent config
file or an unset key still resolves normally, and only a genuine resolver failure
refuses.

`place_prefix` stripped one leading `./` and admitted a bare `.`. Both are pinned:
a dot segment refuses naming the setting, and `././docs/issues` normalizes and
lands. Each goes red when its guard is neutered.

**Seven were conformance.** `place_shown` adopts the corpus form
(`tr -d '\000-\037\177' | cut -c1-512`) and now reaches the snapshot refusal and
the graft-conflict message, which printed a branch-supplied name raw. The handle
token clears `jimfile.sh valid-id` rather than an inline charset — that charset
minus its length cap and its `..` rejection — and every token this script mints
passes it unchanged, so the swap is behavior-preserving. Four git calls taking a
derived argument gained `--end-of-options`. `place_coord_branch` lost its local
`jim/registry` fallback, so the default lives only where jimconf declares it. The
header no longer claims `mktree` (which appears nowhere — the tree is built
through a scratch index because the destination must keep every path outside the
collection as the tip holds it), documents all five verbs rather than two, marks
`--verb` optional on a read run, names the parsing tools it actually uses, and
records the bash floor this script raised to **4.3** by being the corpus's first
nameref user.

**The two knowing duplicates now carry the house marker.** `place_valid_branch`
and `alloc_valid_branch` have reciprocal `SYNC(valid-branch)` comments and a
byte-agreement fixture that fails if either drifts — the precedent `is_valid_id`
and `is_prov_token` already set. `place_handle_root` carries a
`SYNC(write-contained)` note recording that it is the deliberately *tighter* of
the pair, permitting one fixed subdirectory rather than an arbitrary path, so the
two are not interchangeable.

Suite 1319 → 1322.

## Correction (2026-08-12)

The Resolution above is more complete than the change was. Three of the items it
lists did not land, and a later review found them still standing:

- **"names the parsing tools it actually uses"** — the line still omitted `head`
  (which selects the remote name) and `cut` (which truncates in the display
  sanitizer).
- **"Four git calls taking a derived argument gained `--end-of-options`"** — the
  sweep was not complete. Two `git cat-file blob` calls did not have it. Both
  arguments are git's own hex output, so a leading `-` was unreachable, but the
  file is otherwise uniform on this and the note claimed the sweep was done.
- **"marks `--verb` optional on a read run"** — the header did; `usage()` went on
  printing it as required.

Also unlanded from this package: the plan item requiring git's stderr to be
captured in the publish loop, which both landing calls still discarded.

A fourth item was never in this issue's own list but its wording was named in the
review: `cmd_mode`'s docstring claiming to be "the only place the config gate is
evaluated", which three other functions falsify.

All five are closed under
`20260812-place-sh-header-and-usage-still-misdescribe-the-script`. This section
exists because a resolution note is the durable record: one that outruns its
change hands the next reader a false clean.
