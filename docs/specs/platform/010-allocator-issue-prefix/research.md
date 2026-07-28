---
spec: "docs/specs/platform/010-allocator-issue-prefix/spec.md"
status: Active
date: "2026-07-28"
---

# Research: Allocator honors the configured issue-id prefix

## Anchors

- `skills/file/scripts/jimalloc.sh` — `alloc_durable_issue_id()` (~:305) is the
  fault site: it builds `base="${date}-${slug}"` from `jimfile.sh date` and runs
  a registry-disambiguation loop, never consulting `issue_id_prefix`. **The
  function to change.** It reads the issues log on stdin and takes only
  `<subject>`; it must additionally take the coordinated `num`.
- `skills/file/scripts/jimalloc.sh` — `alloc_build_issue()` (~:878): computes
  `num` (`alloc_next_num_issue`) **before** `fullid` (`alloc_durable_issue_id`),
  so the ordinal is available to pass in. Confirmed order:
  `num=` then `fullid=` then `date=`.
- `skills/file/scripts/jimalloc.sh` — `alloc_provisional_issue()` (~:940):
  computes the durable id over an *empty* log with no numeric ordinal — the
  branch that must always take the date-slug fallback (AC 2).
- `skills/file/scripts/jimfile.sh` — `cmd_prefix_from()` (:567) is the reuse
  target: `prefix-from <created> <num>` re-derives every scheme's prefix and
  takes the ordinal as an arg. **Input-format constraint** (:572): it validates
  `created` as ISO `^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$`.
- `skills/file/scripts/jimfile.sh` — `resolve_issue_prefix()` (~:540) is what
  `next-id issue` honored (the behavior to restore); `render_template()` renders
  `{date:…}` / `{seq}` / `{seq:NN}` tokens.
- `tests/jimalloc.sh` — `alloc_provisional_repo()` (:562), `run_jimalloc_in`
  (usage :324), and `case_jimalloc_provisional_issue_offline()` (:574): the
  temp-git-repo + `jimconf.toml` + provisional-origin harness. The regression
  test writes `issue_id_prefix = "…"` into `$repo/jimconf.toml` (the same pattern
  as `:497`/`:511`/`:549`) and asserts the durable-id shape.

## Local Patterns

- **`date` vs `now` is forced, not a choice.** `jimfile.sh date` → `20260728`
  (compact); `jimfile.sh now` → `2026-07-28T08:35:41Z` (ISO). `cmd_prefix_from`'s
  regex rejects the compact form, so the allocator **must pass `now`**. Bonus:
  with `now`, the `timestamp` scheme renders real sub-day precision
  (`…T083541`), not the day-start `…T000000` a date-only input would give — so
  passing `now` settles Insight 2 / the Open Question outright.
- **Scheme derivability at allocation time** (real path, num present):

  | scheme | real-path prefix (via `prefix-from now num`) | provisional (no num) |
  |---|---|---|
  | `date` | `YYYYMMDD` | same (num-independent) |
  | `timestamp` | `YYYYMMDDThhmmss` | same (num-independent) |
  | `sequential` | `{seq:04}` = the coordinated ordinal | **fallback → date** |
  | `project` | `issue_id_project` (num-independent) | same |
  | `{…}` template | rendered with num | date if it needs `{seq}`; else same |
  | empty `project` / `{date:…}` | `prefix-from` errors | fallback → date |

  So only the ordinal-dependent schemes (`sequential`, `{seq}` templates) need
  the provisional fallback; the num-independent schemes work identically in both
  paths.
- **`prefix-from` already fails loudly with a reason and non-zero** on every
  un-derivable case (empty project, `{date:…}`, non-numeric num for
  `sequential`). The AC 2 fallback is simply: *any* `prefix-from` non-zero →
  use `${date}-${slug}`. No new failure taxonomy needed.
- **Disambiguation loop is orthogonal.** `alloc_durable_issue_id`'s existing
  suffix loop operates on whatever `base` it computed, so it composes with any
  prefix unchanged. For `sequential` the num-bearing base is already unique, so
  the loop is a no-op there.
- **Test template:** mirror `case_jimalloc_provisional_issue_offline` for the
  provisional-fallback case; for the real-path cases add a plain temp repo (like
  `:324`) with a non-default `issue_id_prefix` in `jimconf.toml`.

## Security & Performance

- **Config value → id is the injection surface** (AC 5): `issue_id_project` and
  `{…}` templates are developer-supplied config that becomes part of a filename
  and a registry token. `cmd_prefix_from` **already** gates its output through
  `is_valid_id` before returning (a non-conforming prefix is rejected, not
  emitted), so reusing it inherits the guard — the allocator must still treat a
  non-zero `prefix-from` as the fallback, never interpolate its stderr, and keep
  the final `base` on the existing `is_valid_id` path. No new boundary, but the
  reuse must not bypass the existing one.
- **Determinism / clock:** `prefix-from`'s `timestamp` and `{date:…}` render
  from the system clock (`date +fmt`) — already true of `resolve_issue_prefix`;
  no new nondeterminism, and record dates remain informational (file order is
  authoritative, `platform/007`).
- **No performance concern:** one extra `jimfile.sh` sub-invocation per
  allocation, same order of magnitude as the existing `date`/`slug` calls.

## Recommendations

1. **Pass `now`, not `date`, to `prefix-from`** — required (format) and it
   resolves the timestamp-granularity open question. Consider computing `now`
   once and threading it so the durable-id prefix and any timestamp use are
   consistent within one allocation.
2. **Change `alloc_durable_issue_id` to take `num`**, call
   `prefix-from now num` for the base, fall back to `${date}-${slug}` on any
   non-zero, then run the existing disambiguation loop unchanged. The provisional
   path passes no usable num, so it always falls back for ordinal schemes.
3. **Frozen-contract check passes:** a non-date durable id (`0042-slug`,
   `myproj-slug`) is just another `<full-id>` token — `alloc_resolve_issue` maps
   num↔full-id via the allocate record with no date-shape assumption, and the
   token clears `is_valid_id`. So AC 4 (default byte-for-byte unchanged) and
   "non-default still resolves" both hold; `platform/007`'s grammar/resolution
   are untouched. This aligns with `ARCHITECTURE.md`'s allocator entry (the
   allocator is the coordinated successor to `next-id`'s derivation) and the
   Scripting Layer's compose-via-`BASH_SOURCE` convention.

## Peer Feedback

*For the PM (minor — the spec is sound):* the spec's Open Question / Insight 2
(timestamp granularity, "date vs now — architect decides") is **not actually a
free choice** — the compact `date` fails `prefix-from`'s input validation, so
`now` is forced. The Open Question can be closed as resolved when the spec is
next touched, and Insight 2 narrowed to "use `now`" rather than a fork.
