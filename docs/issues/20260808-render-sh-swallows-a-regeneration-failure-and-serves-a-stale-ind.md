---
id: 20260808-render-sh-swallows-a-regeneration-failure-and-serves-a-stale-ind
num: 294
title: "render.sh swallows a regeneration failure and serves a stale index"
status: open
priority: medium
labels: [issue, invariant]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:49:43Z
updated: 2026-08-08T18:49:43Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`render.sh` establishes that the index is stale, attempts to regenerate, and then
**serves the known-stale view anyway at rc 0** when the regeneration fails. It is
the one read surface in the group that treats this failure quietly.

## Mechanism

`skills/issue/scripts/render.sh:89-95`:

```bash
ensure_index() {
  local dir="$1"
  index_is_stale "$dir" "$dir/$INDEX_FILENAME" || return 0
  if [[ -x "$INDEX_SCRIPT" || -r "$INDEX_SCRIPT" ]]; then
    bash "$INDEX_SCRIPT" "$dir" >/dev/null 2>&1 || true
  fi
}
```

`index.sh` returns 1 on an unwritable collection directory, a failed `mktemp`, a
short compose, or a failed rename (`index.sh:520-574`). All four are swallowed —
stdout and stderr discarded, `|| true` — and `cmd_stats` / `cmd_list` / `cmd_show`
/ `cmd_insights_graph` then parse the stale `INDEX.md` and exit 0.

The staleness was already *established* by `index_is_stale` one line earlier, so
this is not "we could not tell" — it is "we could tell, we failed to fix it, and
we served it without saying so."

## Contrast within the group

Both siblings treat the identical failure as loud:

- `place_reindex` returns 1 and fails the run (`place.sh:1007-1013`).
- `reconcile.sh:246-249` prints an error and carries a non-zero rc, specifically
  so it does not exit 0 on a stale index.

## Relationship to the placement read path

There is a separate open issue arguing the *opposite* direction — that
`place.sh`'s strict `|| return 1` on a placed read diverges from `render.sh`'s
tolerance. These two should be resolved together as one decision about the
group's read-failure posture, not independently. The point common to both is that
the group currently has two postures and did not choose either deliberately.

If tolerance is kept here, the fallback should at least be disclosed on stderr
rather than silent, so "never serve a stale view" is not quietly false.

## Test

Not covered. A case with an unwritable collection directory would pin whichever
posture is chosen.
