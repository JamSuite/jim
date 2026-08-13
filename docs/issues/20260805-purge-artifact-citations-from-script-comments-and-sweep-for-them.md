---
id: 20260805-purge-artifact-citations-from-script-comments-and-sweep-for-them
num: 243
title: "Purge artifact citations from script comments and sweep for them"
status: open
priority: medium
labels: [scripts, hygiene, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T12:22:53Z
updated: 2026-08-05T12:22:53Z
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

## Proposed action

Two halves, and the sweep is the half that matters.

1. **Rewrite the 95 comments** to state current behaviour and rationale without
   the citation. Most already say the useful thing and merely carry a trailing
   `(spec NNN)` or `(Finding N)`; a few are only a citation and need the
   behaviour written out. Rewriting is per-comment judgment, not a regex.
2. **Add a corpus sweep to `tests/scripthygiene.sh`** so the rule is mechanical
   rather than remembered — the same shape as the sweeps that now hold the
   preamble, the locale, the read-scope and the test-placement rules. It must
   exempt the meta-test convention sites by path and reason, and fail closed on
   an empty corpus.

The sweep cannot land before the rewrite, since it would fail on all 95. That
ordering is the whole reason this is one issue rather than two.

## Scope note

This is a mechanical pass over nine files with no behaviour change, and it is
large enough to deserve its own scoping rather than riding a pass aimed at
something else. `jimverify.sh` alone is 43 of the 95.

## Provenance

The documentation audit in B-double-prime's docs pass, which verified all eleven
sites of the emission cluster's retirement issue as already fixed and swept the
rule tree-wide rather than only at the named site.
