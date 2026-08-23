---
id: 20260805-purge-artifact-citations-from-script-comments-and-sweep-for-them
num: 243
title: "Purge artifact citations from script comments and docs, and sweep for them"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [scripts, hygiene, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T12:22:53Z
updated: 2026-08-15T08:14:02Z
origin: "20260728-id-coordination-issue-grouping.md (retired; see 5e712bf)"
---

## Description

`CLAUDE.md` forbids citing a spec / AC / Finding / DD / issue number, or a
cross-file line range, in a code comment under `skills/*/scripts/`. The rule is
violated **95 times across nine scripts**.

| script | hits |
| :--- | ---: |
| `skills/verify/scripts/jimverify.sh` | 43 |
| `skills/conf/scripts/jimconf.sh` | 11 |
| `skills/issue/scripts/index.sh` | 10 |
| `skills/issue/scripts/render.sh` | 10 |
| `skills/issue/scripts/new.sh` | 8 |
| `skills/issue/scripts/migrate.sh` | 6 |
| `skills/issue/scripts/backfill.sh` | 5 |
| `skills/file/scripts/jimalloc.sh` | 1 |
| `skills/issue/scripts/reconcile.sh` | 1 |

Clean: `jimfile.sh`, `jimledger.sh`, `jimpartition.sh`, `skills/spec/scripts/reconcile.sh`,
`skills/review/scripts/*`, `skills/meta-test/scripts/*`.

Not a violation, and must stay: the three `AC`-shaped strings under
`skills/meta-test/scripts/` describe or emit the `# AC: <criterion>` header
convention for generated test files — `run.sh` and `testlib.sh` document it, and
`metatest.sh` emits it as heredoc payload rather than carrying it as its own
comment.

**Why the rule exists, in this codebase specifically.** These scripts' own verbs
renumber the specs an id points at. A comment citing `spec 047` or `AC 11` rots
the moment `rename` or `split` moves the thing it names — and the reader has no
way to tell a stale citation from a live one. The rule's own wording says
comments state current behavior and its rationale, not provenance and not a
change log.

**How it got to 95.** A prior issue named exactly one site —
`jimalloc.sh:3667`, an `AC 5` citation. That site was fixed and the rule was
never swept. It is the same fix-one-miss-the-siblings shape that issue's own
root-cause section describes, and nothing detected it because no check exists:
the rule is stated in `CLAUDE.md` and enforced by attention.

## The doc half

The same rule governs documentation, and nothing says so. `CLAUDE.md` scopes its
wording to code comments under `skills/*/scripts/`, so the doc surfaces were
never covered by the rule or by anything mechanical.

The rot is worse here than in the scripts. A reader of `README.md` cannot open
`spec 028`, cannot tell a live citation from one whose spec a `rename` or
`split` has since renumbered, and has no `git log` habit to fall back on. The
citation buys them nothing and costs them a dead end.

**User-facing surfaces are now clean.** `WORKFLOW.md` carried four — two in the
Stage Ledger row, one on the candidate-batch sentence, one on the plan's
blast-radius advisory — plus a `backfill.sh` paragraph framed as "Spec 019 added
the `num:` ordinal", rewritten to describe the collection state instead.
`README.md` carried four in the permissions section, and four `/jim:file`
examples naming jim's own `platform/003-jimfile` spec by group and ordinal,
genericized to the invented groups the feature docs already use. `README.md`,
`WORKFLOW.md` and `docs/features/*.md` now hold zero.

**The adjacent corpora are far dirtier than the scripts ever were.** Unaudited
matching-line counts over the same citation shapes:

| corpus | files | lines |
| :--- | ---: | ---: |
| `skills/*/SKILL.md` | 18 | 229 |
| `skills/*/references/*.md` | 11 | 192 |
| `agents/*.md` | 5 | 11 |
| `skills/*/assets/*.md` | 3 | 3 |

`skills/partition/references/partition-methodology.md` (90) and
`skills/partition/SKILL.md` (82) are 40% of it between them. Two false-positive
shapes are known to be in these numbers and must be excluded before anyone
treats them as a work estimate: a `spec_migration`-style phrase like "numbered
specs 001+", which names a range rather than a spec, and any line where `spec`
abuts a date (`cart-spec 20260726`).

**Whether that corpus is in scope is the open question**, and it should be
answered deliberately rather than discovered mid-sweep. The case for including
it: a `SKILL.md` body is rendered into the user's conversation verbatim when the
skill is invoked, so "agent-facing" understates who reads it. The case against:
these files are instructions to a model that has the repo, the citation may
still carry rationale for a maintainer, and 435 sites is its own spec, not a
rider on this one.

## Proposed action

Three parts now, and the sweep is still the part that matters.

1. **Rewrite the 95 comments** to state current behaviour and rationale without
   the citation. Most already say the useful thing and merely carry a trailing
   `(spec NNN)` or `(Finding N)`; a few are only a citation and need the
   behaviour written out. Rewriting is per-comment judgment, not a regex.
2. **State the rule for docs.** `CLAUDE.md` says it for script comments; extend
   it to cover user-facing documentation, so the doc half is a written rule
   rather than a reviewer's memory.
3. **Sweep both corpora.** The script corpus belongs in
   `tests/scripthygiene.sh`, the same shape as the sweeps that now hold the
   preamble, the locale, the read-scope and the test-placement rules. The doc
   corpus belongs in `tests/docsurfaces.sh`, which already walks `README.md`,
   `WORKFLOW.md` and `docs/features/*.md` for exactly this class of drift. Both
   must exempt their convention sites by path and reason — the meta-test `AC`
   headers on the script side, the two false-positive shapes above on the doc
   side — and fail closed on an empty corpus.

The script sweep cannot land before the rewrite, since it would fail on all 95.
That ordering is the whole reason this is one issue rather than two. The doc
sweep has no such constraint against the three user-facing surfaces — they are
already clean, so it can land immediately and hold them there.

## Scope note

The script rewrite is a mechanical pass over nine files with no behaviour
change, and it is large enough to deserve its own scoping rather than riding a
pass aimed at something else — `jimverify.sh` alone is 43 of the 95. The
user-facing doc purge is already done and cost a handful of edits. What stays
unsized is the `skills/` + `agents/` corpus, which is why it is posed above as a
question rather than folded into a count.

## Provenance

The documentation audit in B-double-prime's docs pass, which verified all eleven
sites of the emission cluster's retirement issue as already fixed and swept the
rule tree-wide rather than only at the named site.
