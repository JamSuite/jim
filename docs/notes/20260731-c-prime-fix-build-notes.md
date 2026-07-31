# C′-fix — build notes

**Created:** 2026-07-31 · **Shape:** hardening build, no spec

Closes the four defects that leave `sdlc/018`'s AC 12 unmet, plus that spec's
review residue and its build's candidate batch — sixteen issues, #168–#183.
Step 3a of `20260728-id-coordination-issue-grouping.md`.

Runs as a build rather than a spec against that note's three criteria. Two were
re-checked here and one of them was found to be a false alarm:

- **No security regressions to gate.** `/jim:build`'s security gate keys on
  `security.md` inside a spec directory (`skills/build/SKILL.md:46`), so a
  spec-less build has nothing to key on. That makes "build" a decision to forgo
  the gate, not evidence none is needed — so it is worth stating what is actually
  in scope: every security-adjacent change here is a **narrowing** (a symlink
  skip, a refusal where the code currently proceeds). A narrowing cannot widen
  exposure.
- **Forks settle in a sentence.** Five were found rather than the two budgeted,
  and all five settled before any code — recorded below.
- **No blueprint write.** *This was a false alarm and is withdrawn.* The `sdlc`
  blueprint states the invariant as a **property** — "either a 3-digit
  zero-padded ordinal unique within its group, or a reserved provisional token
  pending realization" — and says nothing about which paths enforce it. Recording
  enforcement scope is therefore a code-docstring matter, not a blueprint edit.

## Settled forks

**1 · The nesting guard's ambiguous case (#171).** After a successful `mv`, two
states are indistinguishable: a *race plus copy-fallback* (a racer created the
target, `mv` copied the source inside it) and a *clean copy-fallback whose moved
directory legitimately contains a child named like its own former basename*.
Both present as: target inode ≠ source inode, `<target>/<basename>` present with
a third inode. No portable tell separates them.

**Resolved toward detection** — restore and fail. The cost is a spec directory
containing a subdirectory named `P-<8digits>-<slug>`, which would mean a
provisional spec directory nested inside another spec directory. The benefit is
that a genuine race on the filesystem jim actually runs on stays caught.

This narrows the stated intent of the existing "passes a real rename" fixture:
it still passes, because a same-filesystem `mv` exits at the inode check, but its
premise becomes conditional on the filesystem preserving inodes. That conditional
is now in the docstring rather than implied.

**2 · `--apply` from a subdirectory (#172).** Deriving the relative form against
`$PWD` is not merely the weaker option — it is foreclosed. It yields
`../docs/specs`, and `jimfile.sh valid-relpath` rejects any `..` segment, which
is the boundary the citation sweep runs every target through. **Resolved: refuse
when `$PWD` is not the worktree top.** Preview stays ungated; it mutates nothing,
and a preview followed by a named refusal restores the contract rather than
breaking it.

**3 · Realizer batch semantics (#174).** **Both realizers accumulate per-item
failure and continue, and the terminal index regeneration always runs.** Each
realized ordinal is already durably published, so aborting a batch strands more
work than it saves.

Taken with it: the spec side stops dropping a **renamed-but-not-rewritten**
identity from `applied`, so the sweep and the ledger row cover the directory that
actually moved. Leaving it out preserves a documented half-applied state — moved
directory, dead citations, no ledger row.

**4 · The ordinal-width narrowing (#175).** **Deliberate.**
`ALLOC_MAX_ORD_DIGITS` exists because recoverability was the requirement, so an
ordinal wider than it is one the registry could not be rebuilt from, and
`resolve` must not return an id the seed cannot reproduce. All three divergences
get fixtures; the policy goes in the docstring and in the error message, which
currently says only "invalid spec id".

The gate's **joint** application — an over-wide rename *source* killing the
establishing record of a representable *destination* — is not settled here. It is
rename-record semantics, both live logs hold zero rename records, and it must be
decided alongside the existing "does a rename source count as known" question.
Recorded on #113.

**5 · Invariant edges (#181).** *Width:* `cmd_next_id` skips over-wide tokens,
matching `spec_ordinal_holder`. The predicate cannot compare >15-digit tokens
safely, so it must skip; coherence then requires `next-id` to skip too, since a
token the numbering system cannot represent should not move the floor.

*Move primitives:* `move-spec-dir` is gated on `spec-ordinal-holder`;
`rename-tracked` is left generic. `rename-tracked` renames group directories and
arbitrary tracked paths — a spec-ordinal gate does not belong on it.
`move-spec-dir` is spec-specific, and its exactly-3-digit shape means it cannot
land a *padding* variant at all; what it can land is a same-ordinal
different-slug twin (`018-beta` beside `018-alpha`), since `[[ -e "$dst" ]]`
catches only an exact path.

**6 · Retiring `mv-spec` (decided mid-build).** The verb had zero callers —
established exhaustively, not carried forward from the review's assertion: one
dispatch entry, no internal caller, no skill/agent/script, static `case` dispatch
in all three CLIs so no constructed-verb path, no non-ASCII hyphen spellings.
Only its own fixtures reached it.

**Retire.** An earlier recommendation to keep it was wrong and is withdrawn: it
rested on retirement requiring a `platform` blueprint write, and therefore
tripping the criterion that sends work to a spec. Declining to run a tool is not
a reason to leave dead code in the tree, and the targeted `--since` adapter
exists precisely so an out-of-pipeline change can refresh a blueprint cheaply.
Both doc surfaces were corrected through their own skills — `/jim:blueprint
platform --since` and `/jim:arch` — rather than by hand.

The retirement's own grounding run corroborated the sweep independently: editing
the Provides face put the **breaking** detector directly over the removed verb,
and it reported zero.

## Guard premises, as claims to check

Every defect this build fixes for AC 12 lives in a guard written fresh, and the
one that cost the most rested on a premise that was false and was never written
down. Each guard this build writes or touches states its premise here, with how
it is checked.

| Guard | Premise | Checked by |
| :--- | :--- | :--- |
| `undo_nested_rename` | A same-filesystem rename preserves the inode; a copy-fallback rename does not, but it nests nothing — so the *absence* of `<target>/<basename>` means the rename landed. **`mv` does not guarantee the inode**, only that the contents arrive. | A fixture that stages `cp -r` + `rm -rf`, which is what `mv` does on `EXDEV`, and a fixture driving the real command surface with `mv` shimmed to that behavior |
| `--apply` CWD refusal | `jimconf.sh` reads `./jimconf.toml` from PWD with no walk-up, and every consumer resolves paths against PWD — so the worktree top is the only CWD at which the configured spelling and its consumers agree | A fixture running `--apply` from a subdirectory and asserting a named refusal, not a no-op |
| `sweep_citations` roots | `git ls-files` emits repo-relative paths regardless of the pathspec spelling, so a raw absolute configured root can never prefix-match its own output | Verified directly against an absolute pathspec; fixtured with an absolute `issues_path` |
| Realized-directory symlink skip | A symlink is never a spec's own body, so skipping one cannot drop real content | A fixture placing a symlink to an in-worktree file inside a realized directory |
| `move-spec-dir` occupancy | Split targets fresh child groups and merge appends above the target's high-water, so no batch flow presents a transient same-ordinal collision the gate would refuse | A fixture landing a same-ordinal different-slug destination |
| Ordinal width policy | An ordinal wider than `ALLOC_MAX_ORD_DIGITS` is one the registry could not be rebuilt from, so no surface should treat it as an ordinal | Fixtures on all three resolve divergences and on `next-id`'s skip |

One premise is **not** front-door checkable and is recorded as such: the callers'
refusal when `dir_inode` yields empty cannot be staged through the CLI, because
any state making `ls -di` fail also fails the `[[ -d "$src" ]]` guard above it.
The function's graceful degradation on an empty inode is fixtured directly
instead.

## Sequence

1. **#171** — nesting guard, with the caller-wiring fixtures that do not exist today
2. **#172** — `--apply` refusal
3. **#173 · #177 · #180** — all three live in `sweep_citations`; one pass
4. **#170 → #174** — index trap before the regen path becomes more reachable, then batch semantics on both sides
5. **#178** — the fixtures the plan named, once rc semantics are final
6. **#175 · #181 width** — one width policy
7. **#181 move primitives** — `move-spec-dir` gate
8. **#182** — issue-side seed padding
9. **#176 · #179 · #183** — help text, template, retired prose
10. **#168 · #169** — agent context blocks, review omission sweep

Closing #151 and #134 falls out of steps 1–4.

Each issue is closed as its fix lands. `sdlc/018` fixed fourteen issues and
closed none — no plan task covered it — and the collection misrepresented the
project's state until its review caught up.
