---
id: 20260805-retire-the-four-stale-doc-sites-the-emission-cluster-left-behind
num: 231
title: "Retire the four stale doc sites the emission cluster left behind"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [docs, workflow]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T01:53:46Z
updated: 2026-08-05T12:55:00Z
origin: "20260805-b-prime-review.md (retired; see 5e712bf)"
---

## Description

## Description

Issue #211's stated disposition — every site retired except
`docs/features/blueprints.md`, held for `feat/blueprints` — is false. Three more
sites survive, and two of them are missed siblings of sites that were fixed.

| site | status |
| :--- | :--- |
| `ARCHITECTURE.md:395` | **named by #211 and claimed fixed** — `fd423e9` edited this line (appending a retirement marker) and left the stale `merge-map … <start> taken verbatim from next-id` clause on it. `jimfile.sh next-id spec platform` → rc 2, "answers for issues only". |
| `README.md:62` | "Two registry-integrity verbs", over a 2-row table with no `lift` row. Missed sibling of site 15, which *was* fixed at `:199-215`. |
| `ARCHITECTURE.md:393` | present-tense "widens `vacated-max` … to read `op=merge` events" — the only unmarked `vacated-max` in the file. #211 filed it under "verified correct, needing no change". |
| `docs/features/blueprints.md` | declared survivor; also carries a second stale claim at `:152` ("renumber-append past a floored maximum"). |

Beyond #211's list:

- **`README.md:62`'s in-page anchor is dead.** `43c946e` renamed the heading to
  `### Registry integrity — jimalloc.sh sweep / catch-up / lift` (`:199`) and left
  the link target `#registry-integrity--jimallocsh-sweep--catch-up`. The commit
  that fixed the named site created this.
- **`WORKFLOW.md` contains zero occurrences of `lift`.** The registry-integrity
  table at `:89-92` lists only `sweep` and `catch-up`; the prose at `:386`
  describes only those two. `lift` shipped in `blueprint/025` and changed twice
  more since. #211 cleared WORKFLOW.md with "carries no occurrence of any retired
  symbol" — a check structurally incapable of noticing a *missing new* verb.
- **`ARCHITECTURE.md` was not regenerated in `175047c..HEAD`** (header still reads
  `Last updated: 2026-08-03`). So `:282` and `:395` both document
  `renumber-map <old> <targets-csv> <assign-file>` with "a fresh child densifies to
  `001..N`" — an invocation that now fails at arity (rc 2) since `d872159` made
  `<child>=<start>` required. `:390` also still asserts the exact sentence issue
  #212 was filed to falsify: "the two files agree by convention with no test
  asserting it — the one place in the ordinal machinery where a divergence would
  not be caught structurally."
- `ARCHITECTURE.md:391`'s `lift` description predates the reserved-ordinal gate,
  the in-batch duplicate guard, and cross-run recorded-rename indexing —
  incomplete rather than false.

## Proposed action

Retire the three surviving sites and fix the dead anchor. Add `lift` to
`WORKFLOW.md`'s registry-integrity table and prose, and correct `README.md:62`'s
count.

Run `/jim:arch` so `ARCHITECTURE.md:282`, `:390`, `:391`, `:393` and `:395` catch
up — the file was not refreshed in the range, so both the manual surfaces and the
auto-refreshed one drifted together.

Note for future doc sweeps: a clearing check of the form "carries no occurrence of
any retired symbol" cannot see an added verb. Retirement and introduction need
separate checks.

## Provenance

Post-build review of the B-prime hardening cluster
(`docs/notes/20260805-b-prime-review.md`, Finding 9).

## Resolution (2026-08-05)

Audited every site before editing, because this issue was filed against an older
tree. **Three of its claims had already been fixed** and were left alone: the
`vacated-max` mentions all carry a retirement marker or stand in past tense, and
`docs/features/blueprints.md`'s "renumber-append past a floored maximum" lost its
floor clause in an earlier restructure. Correcting a corrected thing is its own
kind of drift.

**What was genuinely still stale, and is fixed:** `README.md`'s "Two
registry-integrity verbs" over a two-row table, its dead in-page anchor (the very
commit that renamed the heading to include `lift` left the link pointing at the
old target), `WORKFLOW.md`'s complete absence of `lift` — zero occurrences, in
both the table and the prose, which framed `catch-up` as *the* repair half —
and `blueprints.md` explaining what a partition does to ids while naming neither
verb that makes a moved id still resolve.

`ARCHITECTURE.md` was regenerated through `/jim:arch`. Its stalest claim was one
this cluster made false rather than one it inherited: the ordinal section named
the width seam as "the one place a divergence would not be caught structurally",
which stopped being true when the guard gained a test — and that test then caught
a real escape during the same session's verification run.

**The durable half is `tests/docsurfaces.sh`**, which mechanises this issue's own
closing note. Retirement and introduction are separate sweeps because they fail
in opposite directions: a "carries no occurrence of any retired symbol" check —
the one that ran here — is structurally incapable of noticing a **missing new**
verb, which is exactly how `lift` shipped and stayed absent from an operator
surface while every retirement check passed. A third sweep resolves in-page
anchors, since a link broken by a heading rename is how the earlier fix created
this defect. Six mutations, all red.
