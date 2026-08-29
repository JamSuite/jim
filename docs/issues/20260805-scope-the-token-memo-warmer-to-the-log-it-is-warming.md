---
id: 20260805-scope-the-token-memo-warmer-to-the-log-it-is-warming
num: 233
title: "Scope the token memo warmer to the log it is warming"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, registry, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T01:53:42Z
updated: 2026-08-05T10:21:33Z
origin: "20260805-b-prime-review.md (retired; see 5e712bf)"
---

## Description

## Description

`alloc_warm_token_memo` applies the full cross-kind grammar case-list to both
logs, so records whose kind cannot belong to the log they sit in — inert to every
consumer — still cost one `bash jimfile.sh valid-id` fork per distinct token.

`alloc_log_file:111-116` pins `spec|group → specs.log` and `issue → issues.log`.
A `issue allocate` row sitting in `specs.log` is therefore read by nothing. The
warmer at `:190-208` does not know that, and crosses the id boundary for every
token in it.

Measured differentially against a `git archive 175047c` worktree, counting forks
rather than wall time alone:

| input | pre (`175047c`) | HEAD |
| :--- | :--- | :--- |
| 600 legitimate spec rows | 1m56s · 2417 forks | 0m41s · 1217 forks (the intended win) |
| 600 `issue allocate` rows in `specs.log` | 2.3s · 17 forks | **17.2s · 617 forks** |
| 600 `spec allocate` rows in `issues.log` | 1.2s | **20.1s** |
| 2000 crafted rows | ~0.2s | **61s** |

Linear and unbounded — roughly 30 ms of serialized subprocess per crafted record,
in the sweep's own shell. So the optimization made `sweep` ~1.5x faster on honest
input and arbitrarily slower on hostile input.

The coordination branch is push-writable and the file's own header at `:79-82`
declares its contents untrusted, so this is reachable by anyone who can push. It
is equally reachable by accident: any tool that writes a wrong-kind record makes
the sweep mysteriously slow with no other symptom.

The function's docstring reasons only about the under-coverage direction — "a
missed field only costs speed, never correctness" — and it is **over**-coverage
that is exploitable. The docstring is true and its converse is the bug.

Blast radius is availability only: it wedges the read-only integrity verb for
every clone. No data is compromised and no answer changes.

## Proposed action

Scope the warmer's case list to the log being warmed — the caller already knows
which log it is passing, since `cmd_sweep:2890-2891` warms them separately.

Extend the docstring to state the over-coverage direction, since the current
sentence reads as covering the memo generally.

Fixture: the existing crossing-count case runs over a 7-token fixture; add a
wrong-kind record and assert the warmer does not cross it.

## Provenance

Post-build review of the B-prime hardening cluster
(`docs/notes/20260805-b-prime-review.md`, Finding 3). Surfaced by the security
regression sweep; introduced by `0167f7d`.

## Resolution (2026-08-05)

Fixed as proposed. The log being warmed is now an argument (`specs` | `issues`)
rather than an assumption, and the case list is keyed on it, so a record whose
kind cannot live in the log it sits in is never crossed. An unrecognised scope
warms nothing and returns non-zero, so a mis-wired call site fails loudly rather
than quietly going cold.

The docstring's converse is stated where the docstring was: **the two coverage
directions are not symmetric.** Under-coverage stays advisory — a missed field
costs speed only, since the consumer validates it cold and correctly.
Over-coverage is the liability, because it spends a subprocess per distinct token
on a branch anyone who can push can lengthen. The note now says to widen the list
only within the named log's own kinds.

The fixture measures the property mechanically rather than by timing: a
wrong-kind record is planted in each log and the boundary-crossing probe asserts
**zero** crossings for its tokens. Un-scoping the warmer turns it red.

Its sibling item rode the same pass, in the order this issue asked for — the
amplification was narrowed before any new call site was warmed.
