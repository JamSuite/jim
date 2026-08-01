# Handoff — C′-fix shipped, review findings discharged

**Written:** 2026-08-01 · **Second revision** · **Branch:** `feat/id-coordination`
· **Session base:** `8a3650b` · tree clean · suite **971/971**

Counts below **include this note's own commit**, so they match what you see on
arrival — the previous revision's did not, and cost a reconciliation step.

The first revision of this note carried 21 unfiled review findings and an
undecided split. **That is now resolved** — §4 records the disposition. Nothing
in this note is perishable in the way that section was; the state it describes
lives in git and in `docs/issues/`.

Anchors below are as of this date. Two of the files named here move often
(`skills/spec/scripts/reconcile.sh`, `skills/file/scripts/jimfile.sh`) —
re-verify a line number before planning against it.

---

## 1. Where things stand, in one paragraph

The id-coordination cluster's step 3a (**C′-fix**) is **done**: all sixteen of
its issues closed, plus #151 and #134 which were held open waiting on it, and
`sdlc/018`'s AC 12 now holds. Six issues were filed and realized (#184–#189).
The grouping note is at its fifth revision and is current. The review that
C′-fix never got — it ran as a build, with no spec directory — surfaced 21
findings, nine of them regressions from that same build; **those have now been
discharged**: five fixed, seven filed as #190–#196, six deliberately left
unfiled (§4). The suite went 969 → 971 on two new mutation-tested cases.

**Next in the sequence:** step 4, **Spec E** (registry integrity).

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
| **C′-fix** | build @ `4427f0d` | The chain terminated (18 → 16 → 6 issues) |
| **C′-fix review** | `bbbffd5..b939407` (6 commits) | New lesson in §6: a finding can under-scope itself the same way code does |

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

## 4. The review findings — disposition

Five `jim:investigator` agents reviewed the sdlc/issue-territory changes and
produced 21 findings. The chosen split was **fix the five worst, file the
substantive rest**. All anchors were re-verified against the tree before acting;
all held.

### Fixed (five findings, four commits)

| Finding | Commit | What shipped |
| :--- | :--- | :--- |
| **H1** map path hardcoded | `6be4ac9` | `review/SKILL.md` resolves the map via `jimfile.sh get blueprint` |
| **H2** rc 2 conflated four conditions | `6be4ac9` | Keys on outcome, not rc; adds the absent-map degradation clause |
| **T1** trailing comment on the id line | `4b0d105` | `issue-template.md` note moved to its own line |
| **T2** two unguarded awk installs | `8f1fb6d` | `jimpartition.sh` installs only on a clean awk exit |
| **T3** retired group in live examples | `998156a` | Thirteen references repointed |

Three things about those fixes the next session should know:

- **H1 was invisible from inside this project.** The hardcoded `BLUEPRINT.md` is
  byte-identical to what the resolver returns here, so the defect was a no-op
  locally and fired only elsewhere. See §6.
- **H2's exit codes were established empirically**, not read off the source: rc 0
  = live (**including empty stdout**, a live group declaring no territory); rc 2
  conflates not-in-map, invalid slug, and map-not-found. The fix keys on the
  `group not in map` message.
- **T3's own scope was too narrow.** The finding named nine hits under `agents/`;
  a wider sweep found four more on live skill surfaces (`roadmap/SKILL.md`,
  `roadmap-template.md`, `spec-check/SKILL.md`,
  `meta-matrix-skill-invocation/SKILL.md`). All thirteen are fixed. Frozen specs,
  research, and notes keep the old paths as correct provenance.

Two corrections were folded in while the surrounding code was open: the liveness
rule gained the Validation Checklist entry it lacked, and `jimpartition.sh`'s
header now documents rc 1, which five existing sites already returned.

### Filed (seven issues, #190–#196)

Realized in one host batch — contiguous from 189, no gap, no collision, index
regenerates to a no-op.

| # | Finding | Priority |
| :--- | :--- | :--- |
| **#190** | N1 · sweep exits 0 after dropping a content root | high |
| **#191** | N2 · sweep installer discards `cat`'s exit status | high |
| **#192** | P1 · `index.sh` publishes a truncated INDEX.md as success | high |
| **#193** | P2 · realize occupancy gate reads the configured specs dir, not its root | low |
| **#194** | N4+N5 · spec skill's realize-failure guidance is stale in two directions | high |
| **#195** | N3 · sweep and reconcile disagree on worktree-top normalization | medium |
| **#196** | P3 · uncommitted-sweep containment guard lost its only coverage | medium |

N4 and N5 are merged: same paragraph, same line, one edit closes both.

**Each body separates what was re-confirmed in source from what remains the
investigator's unreproduced reasoning.** That distinction is load-bearing —
every anchor was verified, but the runtime consequences (ENOSPC truncation, the
symlinked-worktree no-op, `scan_pending`'s blind spot) were reasoned from control
flow, not reproduced. Do not treat them as established.

### Still unfiled — six, deliberately

Judged lower-confidence or lower-stakes and not worth tracking overhead. All six
anchors re-verified 2026-08-01:

- `spec/reconcile.sh:281` — mktemp branch reaches the post-rename residue with a
  message naming neither identity nor residue
- `issue/reconcile.sh:243` — count and mapping listing disagree when one file fails
- `spec/reconcile.sh:667` — `own_dirs` awk truncates a specs root containing a space
- `agents/pm.md:49` — teaches the retired `jim` group as a canonical example (the
  T3 class; the T3 sweep keyed on `docs/specs/jim`, which this bare mention evades)
- `agents/security.md:54` — plan path admits only the ordinal state
- `review/SKILL.md` — the liveness rule does not cover a rule declared *only* in
  retired blueprints

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
personas. It cost real defects in the C′-fix session (§6).

**The workaround is in-band:** the directive is self-limiting. An explicit request
satisfies it. Say once per session: *"invoking a jim skill authorizes the agents
that skill prescribes."* Confirmed working — the review session opened with
exactly that authorization. Tracked as **#188**, whose actionable half is that jim
should *name* a suppressed fan-out as a degradation rather than reporting a clean
result.

---

## 6. What went wrong, and what the fix session added

**From the C′-fix build — three mechanisms found defects, none of them the author
re-reading their own work:**

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

3. **The review found nine regressions from that build**, including three
   "fixed one, missed the twin."

**The generalization, now in the grouping note as practice 6:** every practice
this cluster adopted detects something about the *code*; none detects **its own
absence**. A suppressed practice is indistinguishable from a satisfied one.

**Two things the fix session added:**

4. **A finding can under-scope itself exactly the way code does.** T3 was the
   *twin-miss* finding — its whole subject was "fixed one, missed the sibling" —
   and its own stated scope (nine hits under `agents/`) missed four more on live
   skill surfaces. The recursion is the point: the pass that catches an
   incomplete sweep can itself sweep incompletely. Re-derive a finding's scope
   before acting on it; do not inherit the reporter's grep.

5. **A project cannot detect its own unrepresentativeness.** H1's hardcoded
   `BLUEPRINT.md` equals the resolved value *here*, so it was a no-op in every
   local check and broke only on projects configured differently — the
   un-partitioned majority. No test, review, or run against this repo could have
   surfaced it. When a skill hardcodes a value the resolver would return, the
   defect is invisible from inside.

**On fixtures:** the #178 prefix-overlap fixture passed against a matcher with its
boundary check removed, which only mutation testing revealed. The two cases added
for T2 were therefore mutation-tested *before* being trusted — guards neutered,
both fail on all four assertions, fixture file genuinely truncates. Do this for
new guard fixtures rather than after.

**Two recommendations made and withdrawn in the C′-fix session**, both toward
doing less work, both correctly rejected by the developer: keeping dead code
(`mv-spec`) to avoid a blueprint run, and accepting the suppressed fan-out as
merely a named degradation rather than challenging it.

---

## 7. Path ahead

1. **Step 4 — Spec E** (registry integrity): the only-door sweep (#116), the
   catch-up verb (#130, whose `low` priority the grouping note argues is
   demonstrably wrong on three independent grounds), duplicate detection (#136),
   and #185 (the origin registry tip reaching git unvalidated). Two obligations
   carry in from practice 6: E ships two *detectors*, so each must report what it
   did **not** cover as loudly as what it found.
2. **Consider #190–#192 before or with E.** All three are `high`, all three are
   the same shape — a write whose failure reports as success — and #192
   (`index.sh`) sits directly under E's registry-integrity surface. They would
   fold into E's build cheaply, or into the hardening build.
3. **Watch #138.** It was a tidy-up item; C′-fix made it a sixth inlined site and
   a judge scored `ordinal-single-source` **partial** on exactly that. It is the
   one seam in the ordinal machinery where a divergence would not be caught
   structurally.

**Free-floating:** B, D, F, the hardening build (14), #118, #139, the #122
refactor, and the six unfiled items in §4.

---

## 8. Reference

**Verify the state you inherit:**

```bash
bash skills/meta-test/scripts/run.sh              # expect 971/971
git log --oneline 8a3650b..HEAD | wc -l           # expect 48
git status --short                                # expect clean
```

HEAD should be this note's own commit, the 48th.

**Conventions that bit these sessions:**

- `local a=1 b="$a"` does **not** work — `local` expands every argument before
  assigning any, so `b` sees an unbound `a` under `set -u`. Split the statement.
- Issue ordinals realize from the host; this sandbox has no coordination
  credentials, so new issues get `P-` provisional ids and settle later. That path
  has now had five clean production runs.
- A realization diff should be **`num:` only**. Body, `id:`, or timestamp churn
  means something re-emitted rather than realized.
- `ARCHITECTURE.md` is only ever written through `/jim:arch`; group blueprints and
  the map only through `/jim:blueprint`. The targeted `--since` adapter makes an
  out-of-pipeline blueprint refresh cheap, so "it would need a blueprint run" is
  never a reason to leave code wrong.
- Commit trailers: `Issue: <num>/<id>`, `Spec: <group>/<NNN>`. IDs go in trailers,
  never in the header. No spec IDs in *script* comments (docs notes are fine).
