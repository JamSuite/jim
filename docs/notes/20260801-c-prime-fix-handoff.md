# Handoff — C′-fix shipped, post-review findings undecided

**Written:** 2026-08-01 · **Branch:** `feat/id-coordination` @ `4427f0d` ·
**Session base:** `8a3650b` · 40 commits · tree clean · suite **969/969**

Read this before touching anything. Section 4 is the perishable part — a
five-investigator review produced findings that are **recorded nowhere but
here**, and a decision on them was pending when the session ended.

Anchors below are as of this date. Two of the files named here move often
(`skills/spec/scripts/reconcile.sh`, `skills/file/scripts/jimfile.sh`) —
re-verify a line number before planning against it.

---

## 1. Where things stand, in one paragraph

The id-coordination cluster's step 3a (**C′-fix**) is **done**: all sixteen of
its issues closed, plus #151 and #134 which were held open waiting on it, and
`sdlc/018`'s AC 12 now holds. Six new issues were filed and realized (#184–#189).
The grouping note is at its fifth revision and is current. **Then** a review of
the sdlc/issue-territory changes — which C′-fix never got, because it ran as a
build with no spec directory — surfaced 21 findings, nine of them regressions
introduced during that same build. Those findings are **unfiled and unfixed**.
That is the open item.

**Next in the sequence after that:** step 4, **Spec E** (registry integrity).

---

## 2. Bigger picture — what this cluster is

`docs/notes/20260728-id-coordination-issue-grouping.md` is the tracking document.
Read it; this handoff assumes it. Short version:

`platform/007` built an ID-coordination allocator that emits allocate records
only — no consumers, no seed, no rename records. Turning it into the project's
authoritative, drift-proof ID source generated a 68-issue cluster. The note
groups that work into specs rather than minting one spec per issue.

**The arc, and what each stage taught:**

| Stage | Shipped | Lesson it produced |
| :--- | :--- | :--- |
| **A** | `platform/011` | The cluster's centre of gravity is C and E, not A |
| **C** | `sdlc/017` | The constraint is not which specs to write — it is **whether a spec finishes**. Shipped green, complete and ledger-closed with three criticals and two security regressions inside it |
| **C′** | `sdlc/018` | Refines to: **does what a spec builds *fresh* get the same scrutiny as what it repairs?** Every defect it shipped was in new code written to satisfy an AC |
| **C′-fix** | this build | The chain terminated (18 → 16 → 6 issues). New lesson in §6 |

**Remaining:** B (rename/redirect record emission), **D** (batch-CAS), **E**
(registry integrity — next), **F** (issue_placement), one grouped hardening build
(14 items), one optional refactor.

---

## 3. What C′-fix shipped

A build, not a spec — deliberately. The note's three criteria held: no security
regressions to gate, forks settleable in conversation, no blueprint write
*required* (two turned out to be wanted, and went through their own surfaces).

**AC 12's four defects, all closed:**

- **#171** (critical) — the nesting guard's premise (`mv` preserves the inode)
  was false and unwritten. Inode identity now *proves* a rename landed and never
  disproves it; absence of `<target>/<basename>` is the tell that holds where
  `mv` copies. The premise is now in the docstring as a checkable claim.
- **#172** — `--apply` refuses off the worktree top. The filed fix
  (`$PWD`-relative) was foreclosed: it yields `../docs/specs`, which
  `valid-relpath` rejects.
- **#173** — sweep roots normalize to worktree-relative.
- **#174** — both realizers accumulate-and-continue; index regeneration always
  runs. The spec side also stopped dropping a renamed-but-not-rewritten identity
  from the remap.

Plus #168, #169, #170, #175–#183. `mv-spec` **retired** (zero callers, verified
exhaustively). Blueprint and ARCHITECTURE.md corrected through
`/jim:blueprint platform --since` and `/jim:arch`.

**Decisions recorded in** `docs/notes/20260731-c-prime-fix-build-notes.md` —
six settled forks plus a guard-premise table. Read that before changing any
guard this build wrote.

---

## 4. ⚠ THE OPEN ITEM — 21 review findings, unfiled

Five `jim:investigator` agents reviewed the sdlc/issue-territory changes. **Nine
findings are regressions from this build.** A split was proposed (fix the five
worst, file the rest) and **not answered** — that is the first decision to make.

Findings marked ✅ were verified empirically this session; the rest are
investigator reports I did not independently reproduce.

### HIGH — both in the eleven lines added to `skills/review/SKILL.md`

**H1 · `skills/review/SKILL.md:74` — the map path is hardcoded.** ✅
Written as `territory BLUEPRINT.md <group>`. All seven other skills resolve it
via `jimfile.sh get/path blueprint`; review's own Step 4e does so one line below.
On a project that configures `blueprint` elsewhere — or has no map, the
un-partitioned majority — every group returns rc 2, so the reviewer concludes
nothing is live and excludes every blueprint. **An instruction added to stop one
false positive produces a blanket false negative.** Fix: resolve the path, as
`:125` already does.

**H2 · `skills/review/SKILL.md:77` — rc 2 conflates four conditions.** ✅
Verified: `not-in-map → 2`, `map missing → 2`, `bad slug → 2`, `live group → 0`.
The instruction claims rc 2 means "not live". It also never says what rc 0 means
(a live group with no `Territory:` line returns 0 with **empty stdout**), and has
no degradation clause where `/jim:verify` has one for the same input. Fix: key on
rc 0 vs. the specific `group not in map` message; add the absent-map degradation.

### The three twins — "fixed one, missed the sibling"

**T1 · `skills/issue/assets/issue-template.md:2`** ✅ — the same trailing-comment
trap fixed in the spec and plan templates, on a line parsed by a byte-identical
`field_value`. Verified: `id` parses as
`{prefix}-{slug}   # prefix from the configured scheme (default YYYYMMDD-; spec 021)`.
That line also carries a stale spec-ID reference.

**T2 · `skills/partition/scripts/jimpartition.sh:1773` and `:1890`** ✅ — the same
unguarded awk install fixed in `sweep_citations` (#177). One of three sites was
fixed. The failing-awk shim at `tests/specreconcile.sh` is directly reusable.

**T3 · `agents/meta.md:14`** ✅ — the agent's own *behavioral example* still reads
"locate the spec in `docs/specs/jim/`" — the retired group. Lines 52–53 were
fixed; line 14 was not. **#168's resolution note claims "a grep for the stale
token found the second one; nothing else would have" — that claim is wrong**; a
grep for `docs/specs/jim` under `agents/` returns nine hits across seven files.
Most are illustrative `user:` lines; `meta.md:14` is the assistant's own line and
`ARCHITECTURE.md:366` makes agent-description examples load-bearing for routing.

### NOTABLE — incomplete fixes with the shape they replaced

**N1 · `skills/spec/scripts/reconcile.sh:369`, `:377`** ✅ — a dropped content
root warns and `continue`s **without setting `sweep_failed`**. Some citations
rewritten, others not, `INDEX.md` never regenerated, **exit 0**. Verbatim the
failure shape #173 removed. One-line fix.

**N2 · `skills/spec/scripts/reconcile.sh:513`** — the *installer* is still
unguarded. #177 gated awk's exit status but not `cat -- "$tmp_out" > "$f"`. A
read-only target reports `REWROTE` for a rewrite that did not happen; ENOSPC
mid-`cat` truncates a tracked file unrecoverably. Mirror image of the fix.

**N3 · `skills/spec/scripts/reconcile.sh:351` vs `:607`** — `sweep_citations`
takes `git rev-parse --show-toplevel` raw while `cmd_reconcile` re-normalizes it
through `realpath -m`. On a symlinked worktree all four roots read as outside,
all drop, and `(( ${#roots[@]} )) || return 0` at `:382` returns 0 with nothing
swept — including the own-directory sweep, whose whole purpose is the uncommitted
case.

**N4 · `skills/spec/SKILL.md:387` — now wrong in a dangerous direction.** It
tells the agent rc 1 means "some identity halted… a re-run converges." After
#174's spec-side change rc 1 also covers *moved, swept, recorded, frontmatter
stale* — which `scan_pending` can no longer see, so the re-run exits 0 saying
nothing is pending. Worse, the documented repair (revert the directory, re-run)
is now **destructive**: the sweep already rewrote every citation. The only correct
repair is the one-line frontmatter edit named on stderr.

**N5 · `skills/spec/SKILL.md:387`** — also not updated for #172's new refusal, so
an agent hitting "must run from the worktree top" is told to report
registry-vs-tree drift and stop, and never surfaces `cd`.

### Pre-existing, in-region, worth filing

**P1 · `skills/issue/scripts/index.sh:509-532`** — the write block's exit status
is never checked. ENOSPC mid-write publishes a **truncated INDEX.md** over a good
one and returns 0, contradicting the script's own contract at `:45-46`. Every
sibling guards this (`new.sh:208`, `backfill.sh:135`, `issue/reconcile.sh:182`);
`index.sh` is the only one that does not. Both reconcilers key their "index failed
to regenerate" error off this exit code, so the truncation reads as clean to them.

**P2 · `skills/spec/scripts/reconcile.sh:253`** — the realize path's occupancy
gate calls `jf spec-ordinal-holder` **without** `--root`, so it reads the
configured specs dir rather than the `$root` it is guarding. No live divergence
today — but only because #172's new worktree-top guard forces them equal. That
dependency is unstated, and the sibling caller (`jimledger.sh:629`) does pass
`--root`.

**P3 · `tests/specreconcile.sh:235-248`** — `case_..._uncommitted_sweep_refuses_escape`
now exercises #180's new symlink arm, not the containment guard its AC comment
describes. That guard has silently lost its only own-directory coverage.

### Also reported, lower confidence / lower stakes

`spec/reconcile.sh:281` mktemp branch reaches the post-rename residue with a
message naming neither identity nor residue · `issue/reconcile.sh:243` count and
mapping listing disagree when one file fails · `own_dirs` awk at `:667` truncates
a specs root containing a space · `agents/pm.md:49` teaches the retired group as
the canonical example · `agents/security.md:54` plan path admits only the ordinal
state · `review/SKILL.md` has no Validation Checklist entry for the new rule ·
`review/SKILL.md:77` does not cover a rule declared *only* in retired blueprints.

### What came back sound (do not re-litigate)

The `--apply` guard refuses no legitimate invocation — explicit dir, `-c`,
`git worktree`, symlinked specs dir all traced — and precedes every write on
every path. The `index.sh` trap fix is complete on every reachable exit path and
its fixture genuinely discriminates. Batch rc propagation is correct through both
scripts. `REALIZED` cannot be emitted for a directory that did not move.

---

## 5. ⚠ Operational — the harness suppresses agent delegation on Opus 5

**This will bite you immediately and silently.** Claude Code v2.1.219+ injects a
system-prompt section (`heron_brook`) reading:

    Do not call the AgentTool unless the user requested it
    Do not use workflows or deep-research unless the user requested it

Gated on the `opus_5_prompt_bundle` capability — **Opus 5 only**, not Fable 5.
Present in 2.1.220. Upstream: https://github.com/anthropics/claude-code/issues/80988
(open, no maintainer response). Not in any `CLAUDE.md` or `settings.json`; it
arrives in the system prompt, so from inside a session it is indistinguishable
from something the developer set. **No supported opt-out.**

**Why it matters here:** jim's quality machinery *is* delegation — `/jim:review`'s
investigator fan-out, `/jim:verify`'s judge rung, `/jim:partition`'s gatherer, the
personas. It cost real defects this session (§6).

**The workaround is in-band:** the directive is self-limiting. An explicit request
satisfies it. Say once per session: *"invoking a jim skill authorizes the agents
that skill prescribes."* Tracked as **#188**, whose actionable half is that jim
should *name* a suppressed fan-out as a degradation rather than reporting a clean
result — `/jim:verify` and `/jim:review` already name every degradation they can
see.

---

## 6. What went wrong this session — read this, it is the point

Three mechanisms found defects. **None of them was me re-reading my own work.**

1. **A suppressed judge fan-out reported zero violations over code containing
   two.** The `/jim:verify --since platform` grounding run had its judge rung
   suppressed by §5's directive and ran inline instead. It reported *10
   invariants, 0 violations* — indistinguishable in the artifact from a clean
   run. Re-run with the fan-out it returned two, one a **shipped defect**: the
   `move-spec-dir` occupancy gate passed `--exclude` on cross-parent moves, where
   the predicate matches it against the *destination* group, letting a renumber
   land two directories on one ordinal at rc 0 — one commit after the gate was
   added to prevent exactly that.

2. **The developer caught a half-finished sweep.** A territory gap was found,
   one instance repaired, and the rest **mis-triaged as belonging to other groups
   without checking** — by the same pass whose job was cataloguing territory
   violations. Two more files were unclaimed (#189).

3. **The review in §4 found nine regressions from this build**, including three
   more "fixed one, missed the twin."

**The generalization, now in the note as practice 6:** every practice this cluster
adopted detects something about the *code*; none detects **its own absence**. A
suppressed practice is indistinguishable from a satisfied one. And a fixture that
has never failed proves nothing — the #178 prefix-overlap fixture passed against
a matcher with its boundary check removed, which only mutation testing revealed.

**Two recommendations I made and had to withdraw**, both toward doing less work,
both correctly rejected by the developer: keeping dead code (`mv-spec`) to avoid a
blueprint run, and accepting the suppressed fan-out as merely a named degradation
rather than challenging it.

---

## 7. Path ahead

1. **Decide the §4 findings.** Recommended split: fix H1, H2, T1, T2, T3 now —
   all small, all this-session regressions — and file N1–N5, P1–P3. H1 in
   particular ships a worse failure than the one it replaced.
2. **Then step 4 — Spec E** (registry integrity): the only-door sweep (#116), the
   catch-up verb (#130, whose `low` priority the note argues is demonstrably
   wrong on three independent grounds), duplicate detection (#136), and now #185
   (the origin registry tip reaching git unvalidated). Two obligations carry in
   from practice 6: E ships two *detectors*, so each must report what it did
   **not** cover as loudly as what it found.
3. **Watch #138.** It was a tidy-up item; C′-fix made it a sixth inlined site and
   a judge scored `ordinal-single-source` **partial** on exactly that. It is the
   one seam in the ordinal machinery where a divergence would not be caught
   structurally.

**Free-floating:** B, D, F, the hardening build (14), #118, #139, the #122
refactor.

---

## 8. Reference

**Verify the state you inherit:**

```bash
bash skills/meta-test/scripts/run.sh              # expect 969/969
git log --oneline 8a3650b..HEAD | wc -l           # expect 40
git status --short                                # expect clean
```

**Conventions that bit this session:**

- `local a=1 b="$a"` does **not** work — `local` expands every argument before
  assigning any, so `b` sees an unbound `a` under `set -u`. Split the statement.
- Issue ordinals realize from the host; this sandbox has no coordination
  credentials, so new issues get `P-` provisional ids and settle later. That path
  has now had four clean production runs.
- `ARCHITECTURE.md` is only ever written through `/jim:arch`; group blueprints and
  the map only through `/jim:blueprint`. Both were used this session — the
  targeted `--since` adapter makes an out-of-pipeline blueprint refresh cheap, so
  "it would need a blueprint run" is never a reason to leave code wrong.
- Commit trailers: `Issue: <num>/<id>`, `Spec: <group>/<NNN>`. IDs go in trailers,
  never in the header. No spec IDs in *script* comments (docs notes are fine).
