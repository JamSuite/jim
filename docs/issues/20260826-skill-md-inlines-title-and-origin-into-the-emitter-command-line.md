---
id: 20260826-skill-md-inlines-title-and-origin-into-the-emitter-command-line
num: 400
title: "SKILL.md inlines title and origin into the emitter command line"
status: open
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T07:59:56Z
updated: 2026-08-26T07:59:56Z
origin: "docs/specs/issue/000-blueprint/spec.md"
---

## Description

`skills/issue/SKILL.md` documents an asymmetry its own scripts contradict. An
issue body is routed through a temp file specifically so that it never reaches
a shell command line:

> never inline untrusted body into a shell command

The same document's usage templates then place `title`, `labels` and `origin`
directly inside the double-quoted command line the calling agent composes:

```
bash .../new.sh --reviewed \
  --title "<title>" --priority <p> --labels "<csv>" \
  --origin "<origin>" --body-file "<tmp>"
```

`new.sh`'s own security-model comment classifies `origin` — and by direct
implication `title` — as model-produced text of the same trust class as a
title. The candidate-accumulation section of the same document states that such
text may be drawn from tool results, file reads and fetched pages.

## What is and is not affected

The scripts are sound. `new.sh` YAML-encodes every scalar before it reaches
frontmatter, requires `--body-file`, copies the body file-to-file, and the
placement re-exec carries argv as a bash array rather than a rebuilt string.
None of that protects the composition step: the encoding runs after the value
has already travelled through the command line that carried it there.

The exposure is the calling agent building that command line with an
adversarial title or origin in it. This is a documentation-contract defect
rather than a script defect.

## Where

- `skills/issue/SKILL.md` — the two `new.sh` usage templates
- `skills/issue/scripts/new.sh` — the security-model comment naming the trust
  class, and the encoders that run downstream of the gap

## Fix shape

Either route those scalars the way the body is routed, or state the escaping
obligation in the same place the body rule is stated. The second is cheaper and
matches how every other caller-discipline rule in this document is expressed;
the first removes the class rather than documenting around it.

## Related

The same territory carries a smaller, display-only version of the same
inconsistency: the write-path scripts echo raw argv in their unknown-flag
messages, where the read surface sanitizes the same class of token before it
reaches a terminal. Nothing on that path re-enters a shell or a YAML document,
so it breaches nothing — but the posture differs within one group.
