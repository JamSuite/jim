---
id: 20260807-placeholder-substitution-corrupts-issue-titles-and-durable-ids
num: 270
title: "Placeholder substitution corrupts issue titles and durable ids"
status: open
priority: critical
labels: [issue, placement, data-integrity]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T11:43:20Z
updated: 2026-08-07T11:43:20Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`place_substitute` (`skills/issue/scripts/place.sh`) does an unconditional
`${a//\{\}/$dir}` and `${a//\{token\}/$token}` over **every** forwarded
argument. `new.sh` is the only entry script that forwards free-form user text,
so any `--title`, `--labels`, or `--origin` containing the two characters `{}`
is silently rewritten.

Reproduced under `issue_placement = "jim/issues"`:

```
--title 'Fix the {} placeholder in output'
  -> title: "Fix the /tmp/tmp.P6mm4tbCV4/collection placeholder in output"
  -> slug:  20260807-fix-the-tmp-tmp-p6mm4tbcv4-collection-placeholder-in-output
--labels 'a{}b'                -> labels: [a-tmp-tmp-9ocdwewkkd-collectionb]
--origin 'docs/{token}/x.md'   -> origin: docs/tmp.9OCdWeWkkd/x.md
```

Default placement is unaffected — the control run stores the title verbatim.

## Why this is worse than a display bug

The slug is the **durable id**. It is written to `issues.log` on the
coordination branch, which is append-only: the corruption cannot be corrected by
any later append. `jimfile.sh slug` truncates at 64 characters, so the injected
temp path evicts the real tail of the title. And because the injected value is a
fresh `mktemp` basename every run, the same title filed twice yields two
unrelated ids and the allocator's dedup scan can never match.

`{}` in a developer-tool issue title is ordinary: `interface{}`,
`map[string]interface{}`, an empty JSON literal, a template snippet.

## Proposed action

Substitute only arguments that are **exactly** `{}` or `{token}`, rather than
replacing substrings. Every current caller passes them as whole arguments
(`--dir '{}'`, `--place-token '{token}'`, the trailing dir positional), so the
change is behavior-preserving for legitimate input.

The better shape, if the churn is acceptable: stop putting placeholders in argv
at all — have `place.sh run` take the dir and token as explicit options and pass
them to the wrapped command through the environment. That removes the class
rather than escaping one instance of it.

Add a test with a `{}`-bearing title; no test currently exercises one.
