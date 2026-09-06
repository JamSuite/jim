---
# id — the bound identity; the prefix comes from the configured scheme
# (default `YYYYMMDD-`). Keep notes on their own line: everything after the
# colon is the value, so a comment left beside it becomes part of the identity.
id: {prefix}-{slug}
num: {num}
title: "{title}"
# status — open (not started), active (underway), closed (finished).
status: open
priority: {priority}
# type — issue, or epic for an umbrella that other issues declare membership in.
type: issue
# filed-by — the identity resolved from the environment at capture; written by
# the emitter, never by hand. claimed-by is the current holder, empty when the
# issue is unheld.
filed-by: "{filed-by}"
claimed-by: ""
# outcome — how the issue was most recently finished: done, wontfix, duplicate,
# or obsolete. Empty until the issue has been closed at least once, and kept
# through a reopen, so an open issue carrying one has been closed before.
outcome: ""
labels: [{labels}]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  # part-of — umbrella slugs this issue belongs to, stored on the member only;
  # an umbrella's roster is derived when one is needed.
  part-of: []
created: {YYYY-MM-DDThh:mm:ssZ}
updated: {YYYY-MM-DDThh:mm:ssZ}
origin: "{origin}"
---

{body — prose only. The emitter opens the body with `## Description`, so a
caller that repeats the heading here files it twice. May reference other issues
via [[other-issue-slug]] wikilinks. Body content is parsed line-orientedly by
skills/issue/scripts/index.sh; only structured wikilinks become graph edges,
malformed link content is treated as prose (AC-I4).}
