---
id: {prefix}-{slug}   # prefix from the configured scheme (default YYYYMMDD-; spec 021)
num: {num}
title: "{title}"
status: open
priority: {priority}
labels: [{labels}]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: {YYYY-MM-DDThh:mm:ssZ}
updated: {YYYY-MM-DDThh:mm:ssZ}
origin: {origin}
---

## Description

{body — may reference other issues via [[other-issue-slug]] wikilinks. Body content is parsed line-orientedly by skills/issue/scripts/index.sh; only structured wikilinks become graph edges, malformed link content is treated as prose (AC-I4).}
