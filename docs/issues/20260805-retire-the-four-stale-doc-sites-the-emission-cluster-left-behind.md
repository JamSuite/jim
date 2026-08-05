---
id: 20260805-retire-the-four-stale-doc-sites-the-emission-cluster-left-behind
num: 231
title: "Retire the four stale doc sites the emission cluster left behind"
status: open
priority: medium
labels: [docs, workflow]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T01:53:46Z
updated: 2026-08-05T01:53:46Z
origin: docs/notes/20260805-b-prime-review.md
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
