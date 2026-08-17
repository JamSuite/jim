---
num: 8
id: 20260620-extract-duplicated-candidate-batch-block-into-a-shared-contract
title: "Extract duplicated candidate-batch block into a shared contract"
status: closed
priority: medium
labels: [refactor, candidate-batch, consistency]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-20T07:17:42Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/issue/008-issue-pipeline-ownership/research.md
---

## Description

The end-of-phase candidate-batch step — candidate materialization, the
Resolution and Actionability filters, and the interactive/auto-file paths
(~60 lines) — is copy-pasted across all seven surfacing skills (`/jim:spec`,
`/jim:research`, `/jim:plan`, `/jim:build`, `/jim:brainstorm`, `/jim:debug`,
`/jim:sec`), with `/jim:sec` carrying a partial variant. This contradicts the
meta-skill validation anti-pattern at `skills/meta-skill/SKILL.md:114` ("same
instructions in 3+ places → extract to a shared skill").

Spec 024 (issue-pipeline-ownership) adds a third filter to the same block but
does not pay down the underlying duplication. Extract the shared batch logic
into a single contract — for example the spec 018 § Security and Safety
contract, which already single-sources the untrusted-content rule — that the
surfacing skills reference, rather than maintaining seven near-identical copies.

**Related consideration — unify the "fileable" bar.** The interactive `/jim:issue add`
verb (`skills/issue/SKILL.md`) applies a stricter actionability gate than the candidate
batches (the "two different bars" gap surfaced in spec 024). When the shared batch
contract is extracted, consider whether `/jim:issue add` should reference the same
"is this fileable?" bar so both entry points converge — or document why they intentionally
diverge. Reconciling the two is nearly free once the shared contract exists; doing it
separately means touching the eight scattered sites independently.

Surfaced during spec 024 research (`docs/specs/issue/008-issue-pipeline-ownership/research.md`).
