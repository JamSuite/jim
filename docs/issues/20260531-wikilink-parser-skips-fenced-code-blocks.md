---
id: 20260531-wikilink-parser-skips-fenced-code-blocks
title: "Wikilink Parser Should Skip Fenced Code Blocks"
status: open
priority: low
labels: [issues-system, index-graph, parser, refinement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-05-31
updated: 2026-05-31
origin: conversation
---

## Description

### The bug

`parse_wikilinks_from_body` in `skills/issues/scripts/index.sh` extracts
wikilink candidates from the entire issue body, including content inside
fenced code blocks. Any double-bracket token in a code example then
fails slug validation and emits a `malformed wikilink ... ignored`
integrity warning — false positives that surface as graph-noise in the
generated INDEX.md.

### Reproduction

The closed issue
`20260531-typed-frontmatter-relations-absorb-same-target-body-wikilinks.md`
contains code-fenced examples like:

````
```bash
if [[ "$type" != "related-to" ]]; then
  typed_target_for["$slug|$target"]=1
fi
```

```
# Before
A --blocks--> B
A --related-to--> B          ← from [[B]] in A's body
```
````

Running `index.sh` over `docs/issues/` after that file landed produced
12 Integrity Warnings — eleven `[[B]]` matches plus the shell
conditional `[[ "$type" != "related-to" ]]` matched because the wikilink
regex `\[\[[^][]+\]\]` allows arbitrary non-bracket interior, and the
bash conditional happens to contain no `[` or `]` between its outer
delimiters.

### Desired behavior

Wikilink extraction should treat content inside fenced code blocks as
non-prose — neither matched as wikilink candidates nor warned about.
Body wikilinks remain valid in non-fenced prose.

### Implementation sketch

In the awk that extracts the body (after the second `^---$`), track
whether the current line is inside a fenced code block delimited by
either ```` ``` ```` or `~~~`. The fence delimiter is the first
non-whitespace content on the line. When `in_fence` is set, suppress
the line from the wikilink-candidate stream.

```awk
/^---$/ {
  count++
  if (count >= 2) { in_body = 1; next }
}
in_body {
  if (match($0, /^[[:space:]]*(```|~~~)/, m)) {
    in_fence = !in_fence
    next
  }
  if (in_fence) next
  print
}
```

The `match` form may not be portable across all awk variants; if
needed, fall back to two `/.../ { ... }` rules with explicit toggle
logic.

Edge cases to consider:

- **Nested or unbalanced fences.** Unbalanced opens (no close) should
  fail closed — better to suppress the rest of the body than to emit
  false positives. Acceptable.
- **Indented fences.** Markdown allows up to 3 leading spaces;
  indented further is a code block by indent rule, not a fence. Either
  form should suppress wikilinks. The 4-space indent code block case
  is a follow-on if it matters; the existing test corpus does not
  exercise it.
- **Inline code spans.** `` `[[X]]` `` would still match today.
  Suppressing within inline backticks is a stricter version of the
  same fix; consider in a follow-on if it surfaces.

### Tests to add (jim:meta-test)

1. Issue body contains `[[B]]` inside a ```` ``` ```` fenced block →
   no graph edge, no malformed-wikilink warning.
2. Issue body contains `[[B]]` inside a `~~~` fenced block → same.
3. Issue body contains `[[B]]` in normal prose AND `[[C]]` inside a
   fence → only `[[B]]` produces an edge; `[[C]]` is silent.
4. Issue body contains a shell `[[ "$x" != "y" ]]` inside a fence →
   no warning.
5. Existing wikilink tests still pass (prose-grain wikilinks unaffected).

### Tradeoffs

**For:**

- Removes false-positive integrity warnings that surfaced immediately
  when dogfooding the system to capture its own design discussions.
- Aligns with the spirit of AC-I4 (malformed link content is treated
  as plain prose) — code-fenced content isn't prose at all, so it
  should not be tested for link validity.

**Against:**

- Modestly grows the awk state machine. Still bash + POSIX, still no
  third-party deps.
- A wikilink that the author legitimately wants to render inside a
  fenced code example (e.g., documenting wikilink syntax itself) will
  be silenced — but that is also the desired behavior: those tokens
  are examples, not graph claims.

### Origin context

Surfaced 2026-05-31 during the commit immediately after the typed
absorption change ([[20260531-typed-frontmatter-relations-absorb-same-target-body-wikilinks]]).
Regenerating INDEX.md against the project's own `docs/issues/` produced
12 false-positive warnings, all sourced from code-fenced content in
the absorption issue file. Visible in the commit working tree before
this issue was filed.

### Sequencing

Independent. No blockers. Self-contained change to
`parse_wikilinks_from_body` plus tests and a regen of `docs/issues/INDEX.md`
once the parser fix lands.
