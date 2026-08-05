# Handoff — B″ shipped, its review is the open question

**Written:** 2026-08-05 · **Branch:** `feat/id-coordination` · **HEAD:** `e94c6ca`
· tree clean · suite **1182/1182** · issues **80 open / 158 closed**

**What this is.** Written at the point where B″ is fully shipped and its review
has deliberately *not* been run. It does not restate what the repo carries —
read these first and do not re-derive them:

- `docs/notes/20260728-id-coordination-issue-grouping.md` § *Sequence* step 7 is
  the authority on what B″ did, its disposition arithmetic, and the lesson it
  produced. Step 8 is what comes next.
- Each closed issue's § *Resolution* records what shipped and, where a proposed
  action was **not** taken, why. Several were not taken; those paragraphs are the
  point.
- `docs/notes/20260805-b-double-prime-handoff.md` is the entry handoff. Its § 1
  (the ledger's mechanical contract) and § 2 (the delegation inventory) are still
  current and still worth not re-investigating.

---

## 1. The one open decision

**B″'s review has not run.** Step 7 ends "run the review deliberately at the end,
method-not-artifact as B′'s was". It was left to the operator on purpose, and the
reasoning should be inherited rather than re-litigated:

- **For running it:** it is the planned close, and landing #188 first was
  justified precisely so this review would disclose an undispatched fan-out.
- **Against:** a `/jim:verify --since 8c7d0d6 platform` already ran over exactly
  this change range with **nine judges**, and found three real defects. B′'s
  review was valuable partly *because* nothing verified that build; that is not
  true here, so a full review would re-read code the judges just cleared.

**The recommendation on the table** was a scoped review — the doc surfaces, the
issue resolutions' accuracy against what actually shipped, and the commit-by-commit
story — rather than re-reading the allocator. Roughly a third of the spend for
most of the value. The operator stopped the session before choosing; nothing
depends on the choice, and B″ is complete either way.

If a review does run, note it would review **this session's own work**, so the
independence lives entirely in the investigator fan-out. Say the authorization
phrase up front (`WORKFLOW.md` → Operating Notes) and check the investigators
actually ran rather than trusting a clean Coverage section.

## 2. Four provisional issues need a host reconcile

The coordination remote is unreachable from the sandbox, so four issues carry
`P-` ordinals and need `/jim:issue reconcile` **from the host**:

| slug | status |
| :--- | :--- |
| `20260805-refuse-a-renamed-away-group-in-catch-up-instead-of-…` | closed |
| `20260805-read-the-spent-set-the-lift-already-fills` | closed |
| `20260805-reconcile-a-review-s-finding-count-against-its-disposition-count` | **open** |
| `20260805-purge-artifact-citations-from-script-comments-and-sweep-for-them` | **open** |

The two closed ones were filed and fixed in the same pass — deliberately, so the
cluster's accounting stays stated in issue numbers. Until the host reconciles,
the cluster note's step-7 table names them by slug rather than ordinal.

## 3. The two issues this session filed and left open

Both are scoped, both have full inventories in their bodies, neither is started.

- **Practice 10's gate** — reconcile a review's finding count against its
  disposition count. The tenth adopted practice and the only one whose check is
  arithmetic rather than judgment. It touches `/jim:review`'s body, its template,
  and its ledger event; the "left" disposition needs a decision about how much
  reason is enough. Note `cmd_event` needs no script change for a new counter,
  but the `metrics` channel will silently drop one — entry handoff § 1.
- **95 artifact citations in script comments** — a live `CLAUDE.md` violation
  across nine scripts, 43 of them in `jimverify.sh`. The body carries the
  per-file counts and the exemption that must survive (`skills/meta-test/scripts/`
  describes the `# AC:` convention for *generated* files; that is not a
  violation). **The sweep cannot land before the rewrite** — it would fail on all
  95 — which is why it is one issue and not two.

## 4. What comes next in the sequence

Step 8: **the sdlc pass**, and it is the highest-criticality open work in the
collection — #161, #162, #163 (critical), #164–#167 (high), open since
2026-07-31 and untouched through six builds, plus #204's one-line
`/jim:blueprint sdlc` run riding along. The pre-cluster #52 and #53 are also
critical and also open. The cluster note scheduled these *after* B″ and *before*
D specifically because every B-cycle generates enough residue to defer them
another round — which has now happened six times.

## 5. Traps this session sprang that the repo does not record

The entry handoff's five still hold. These are new:

1. **Do NOT anchor `meta-test`'s runner glob or scaffold target at `REPO_ROOT`.**
   It reads as strictly safer and breaks the harness two different ways — it
   wrote a file into the production `tests/` directory, and it recursed to 31
   processes. Both sites now carry the reasoning in-source; read it before
   "fixing" either. The residual risk is closed at the write verbs instead
   (they refuse inside a discovery root).
2. **`assert_match` is ERE, so `(foo)` is a capture group, not literal parens.**
   A pattern like `… (truncated)` silently matches `… truncated` and fails
   against output that contains the parens. Use `.truncated.` or drop them.
3. **`bash tests/metatest.sh` standalone takes minutes**, because its `run` cases
   invoke the aggregate runner. Filter through `run.sh <pattern>` instead, or
   background it.
4. **`grep -o` with wide context on `ARCHITECTURE.md` gets OOM-killed** — that
   file's prose lines are thousands of characters. Use `awk` with `split()` on
   the search term, or `sed -n` by line number.
5. **`bash skills/issue/scripts/index.sh` fails after a `cd docs/issues`** in the
   same compound command — it is repo-root-relative. Run it as its own step.

## 6. The lesson, and where it lives

Recorded in the cluster note's step 7, but worth carrying in the reader's head
because it changes how to read a green suite:

Three of B″'s twelve findings came from the verify judges, and **all three were
gaps in sweeps this same session wrote and mutation-tested**: `scripts/` unswept
for the locale export, stray detection blind to nested paths, the width sweep
rooted at one production root.

Mutation testing proves an assertion **discriminates**. It cannot tell you the
**corpus was too small**. A sweep that is green because it looked in too few
places is indistinguishable, from the inside, from one that is green because the
corpus is clean — and every one of these had passed its own mutation audit hours
earlier. Only a reader who does not share the author's map of where to look tells
those apart.

That is the concrete form of the argument #188 was making in the abstract, and it
is the reason to keep paying for the fan-out.

## 7. Deliberately not done

- **`review_fanout_cap` is still unset** in `jimconf.toml` (defaults to 10). B′'s
  review needed 17. A cost lever and the operator's call — unchanged from the
  entry handoff.
- **`ARCHITECTURE.md`'s spec-narrative voice was left alone.** Much of it reads
  "spec 047 adds X" — provenance the blueprint surface's own present-tense rule
  would forbid. Six targeted drift corrections landed; rewriting the voice is a
  different and much larger job, and it should be decided as one.
- **The width guard does not sweep `tests/`,** and the blueprint sentence now
  says so rather than claiming "any script". The restoration target and why it is
  not simply "sweep tests/ too" are recorded on the width-guard issue's § *Fold
  record*, per practice 11.
