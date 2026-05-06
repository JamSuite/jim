# Brainstorm: Modularizing tests/run.sh

*2026-05-04*

## Seed (user)

`tests/run.sh` ballooned from ~100 lines (spec 007) to 700+ lines after spec 008
extended it with `case_jimfile_*` cases. The current shape doesn't scale: every
new script under test means appending another ~30-case block to the same file.

User's starting hypothesis:

- Split test cases into per-script files (e.g. `tests/jimconf.sh`,
  `tests/jimfile.sh`).
- Extract a generic `tests/runner.sh` and `tests/reporter.sh`.
- Hard constraint: zero third-party dependencies (inherits from spec 007 §4).

## What's actually in the 700 lines (anatomy)

Rough size budget of the current `tests/run.sh`:

| Section                     | Approx. lines | Reusable? |
| :-------------------------- | :------------ | :-------- |
| File header docblock        | ~35           | Per-file (each split would want its own) |
| Globals (TMP_BASE, OUT/ERR/RC, counters, FILTER) | ~25 | Yes — generic |
| Assert helpers (eq/match/exit/nonempty)          | ~50 | Yes — generic |
| Setup helpers (fixture, empty_dir)               | ~25 | Yes — generic |
| `run` (jimconf invoker)                          | ~10 | Per-script |
| `run_jimfile` (jimfile invoker)                  | ~10 | Per-script |
| `case_*` (jimconf, 12 cases)                     | ~140 | Per-script |
| `case_jimfile_*` (31 cases)                      | ~290 | Per-script |
| TESTS=( ... ) array                              | ~45  | Per-script |
| Reporter loop + summary + exits                  | ~30  | Yes — generic |
| Maintenance notes block                          | ~30  | Generic (or per-file) |

So the *truly* per-script content is the cases + the `run_*` invoker + the
TESTS list. Everything else is reusable.

## Sketch — four split shapes to compare

### Option A — User's proposal: shared lib + per-script test files + thin entry

```
tests/
  run.sh                 # entry point: discovers test files, prints grand summary
  lib/
    runner.sh            # globals, asserts, fixture/empty_dir, reporter loop
  jimconf.sh             # case_* + TESTS + run() invoker; sources lib/runner.sh
  jimfile.sh             # case_jimfile_* + TESTS + run_jimfile(); sources lib/runner.sh
```

Each per-script file is **also runnable standalone** (`bash tests/jimconf.sh`)
because its tail block detects `BASH_SOURCE[0] == $0` and runs its own TESTS.
When invoked from `tests/run.sh`, the entry point sources them in order and
runs everything as one batch.

- **Pros:** Clear 1-to-1 mapping (script-under-test ↔ test file). Standalone
  runnability is a developer-experience win — `bash tests/jimfile.sh` is the
  natural drill-down. Library is generic and small (~120 lines). Per-script
  files shrink dramatically (~150 lines each, mostly just cases).
- **Cons:** Two indirection levels — a contributor must follow `source` to find
  the asserts. Need a small "either sourced or run-direct" idiom in each test
  file (well-trodden bash pattern but not zero-cost).

### Option B — Single entry, cases sourced as plain "case packs"

```
tests/
  run.sh                 # holds globals + asserts + fixture + reporter (all-in-one)
  cases/
    jimconf.sh           # only case_* functions + TESTS array; not standalone
    jimfile.sh           # only case_jimfile_* + TESTS; not standalone
```

`run.sh` sources every `tests/cases/*.sh` after defining helpers, then runs
the union of all TESTS arrays.

- **Pros:** Lowest abstraction. `run.sh` stays as the obvious entry. Case files
  are *very* small — they're just lists of functions. No "is this sourced or
  run direct?" detection logic.
- **Cons:** No standalone runnability for a single script's tests except via
  the existing `bash tests/run.sh <pattern>` filter. The one-place-for-helpers
  is a feature *and* a limitation.

### Option C — Per-script files, no shared lib (full duplication)

```
tests/
  run.sh                 # tiny dispatcher: invokes each test file as subprocess
  jimconf.sh             # full self-contained: asserts + cases + reporter
  jimfile.sh             # same
```

Each file ships its own copy of asserts/fixture/reporter.

- **Pros:** Maximum isolation. No source-chain to follow. Each file is
  truly readable end-to-end.
- **Cons:** ~100 lines of duplicated infra per file — the *exact* problem
  spec 007 §4 was avoiding ("readable, reviewable, single source of truth").
  Bug fixes to asserts have to be done N times. Rejected by gut feel.

### Option D — Convention-over-configuration: discovery, no TESTS array

```
tests/
  run.sh                 # entry: sources lib, sources each test file, discovers case_*
  lib/runner.sh          # asserts + reporter
  jimconf.sh             # only case_* function defs (no TESTS=, no boilerplate)
  jimfile.sh             # only case_jimfile_* defs
```

The runner uses `declare -F | awk '$3 ~ /^case_/'` to discover registered
cases after sourcing. Adding a new test = define one function. The 3-step
recipe in `tests/run.sh` becomes a 2-step recipe.

- **Pros:** Lowest boilerplate per case. No "remember to add to TESTS array"
  trap (the failure mode of forgetting which silently drops a test).
- **Cons:** A pinch of magic — readers can no longer scan the TESTS array to
  see what runs. Test order becomes definition order, which is fine but worth
  calling out. Filter still works (regex on function name).

## Cross-cutting design questions

1. **Discovery vs explicit `TESTS=()`?** Auto-discovery (Option D) is less
   boilerplate; explicit registration (Options A, B) is what the existing
   maintenance notes already document. Hybrid: discover by default, allow a
   `TESTS=(..)` override for ordered subsets.

2. **Per-test-file standalone runnability?** `bash tests/jimconf.sh` is a
   nice DX win when iterating on one script's tests — fast feedback, no
   filter argument to remember. Trade-off: every per-script file needs the
   `[[ ${BASH_SOURCE[0]} == "$0" ]] && run_tests` idiom.

3. **Naming / extension?**
   - `tests/jimconf.sh` (1:1 with script-under-test name) — clean.
   - `tests/jimconf.test.sh` (Mocha/Jest-flavored) — signals intent but adds
     a dot.
   - `tests/cases/jimconf.sh` (subdirectory) — pairs well with Option B.

4. **Library structure — one file or many?**
   - One `tests/lib/runner.sh` with all infra → simplest, mirrors `jimconf.sh`'s
     "one file per concern" discipline.
   - Split into `asserts.sh` / `fixtures.sh` / `reporter.sh` → premature for
     ~120 lines; revisit if it grows.

5. **Where do `run` / `run_jimfile` invokers live?** They're per-script
   bash-fu (which script to invoke and how to capture its output). They belong
   *in* the per-script test file, not the lib. The lib stays generic.

6. **Reporter output when running multiple files?**
   - One grand summary: `Ran N tests across M files: P passed, F failed`.
   - Or per-file headers + grand total at the end.
   - When running standalone, just that file's summary (no change from today).

7. **Filter argument semantics?** Today: `bash tests/run.sh <pat>` filters
   case names. After split: filter could mean either (a) "only run test files
   matching <pat>" (file-level), or (b) "only run cases matching <pat>"
   (case-level, today's behavior), or (c) both. Today's case-level is more
   useful in practice.

8. **Maintenance notes split?**
   - Framework-level gotchas (set -u, trap, subshell cd) → live in
     `tests/lib/runner.sh` header.
   - Per-test-file gotchas (e.g., "this script needs jimconf.sh sibling at
     ../conf/scripts/") → live in that file's header.

## Strawperson recommendation (if the user wants one)

**Option A with a touch of Option D.** Per-script test files (`tests/jimconf.sh`,
`tests/jimfile.sh`), shared `tests/lib/runner.sh`, standalone-runnable, and
an *optional* TESTS array (auto-discover if absent). This:

- Honors the user's intuition (1:1 file mapping).
- Keeps the standalone-run DX win.
- Keeps the explicit TESTS array as the documented default (matches the
  existing maintenance notes), but doesn't *require* it for new files.
- Lib stays one file (~120 lines), per-script files are ~150 lines each
  — back inside the "readable in one sitting" budget.

## Things to validate before committing

- How does `set -uo pipefail` interact across `source` boundaries? (It
  inherits, which is fine, but worth a smoke test.)
- The "either sourced or run-direct" idiom — is the
  `[[ ${BASH_SOURCE[0]} == "${0}" ]]` form portable across bash versions
  the project supports?
- Does the existing 3-step recipe in the file header docblock need to move
  to the lib? Or split — generic recipe in lib, "where to put the case" in
  per-script header?
- Is there a future `/jim:meta-test` skill (deferred from spec 007 Decision
  5) that this split makes easier or harder? Probably easier — discovery
  becomes "list every `case_*` across `tests/*.sh`", trivial.

## Open follow-on questions for the user

(captured for the routing step at end of session — not needed to commit
to a direction now)

- Do you want the test files standalone-runnable, or is `bash tests/run.sh
  jimconf` enough?
- Strict TESTS array, or auto-discovery, or hybrid?
- `tests/lib/` or `tests/_lib/` or `tests/_runner.sh` (single hidden file)
  for the shared infra?
- Any appetite to defer the maintenance-notes documentation discipline (per
  spec 007 §4) for the new lib, or do we hold the same bar?

## User direction (2026-05-04)

Decisions taken in conversation, with reasoning:

1. **Standalone runnability — YES, it's a feature.** The existing
   `bash tests/run.sh jimfile` filter is functionally sufficient, BUT if a file
   exists at `tests/jimfile.sh`, the user expects it to be directly executable
   and run all tests for the `jim:file` feature. That intuition (filename =
   runnable target) is itself a DX win worth keeping.

2. **Shape: A with a touch of D.** Per-script test files + shared lib +
   standalone-runnable per file. No auto-discovery magic from D — see #3.

3. **Test discovery: EXPLICIT, but via function-naming convention, not
   `TESTS=()` array.** User's framing: explicit > implicit, but clearly-named
   bash functions (`case_*` / `case_jimfile_*` / etc.) are *already* explicit
   enough. This matches typical unit-test framework conventions (pytest's
   `test_*`, Go's `TestX`, etc.). So: drop the `TESTS=(..)` boilerplate,
   discover `case_*` functions by name. The function name itself is the
   registration. **This is a touch of D — the only one we keep.**

4. **Naming: `tests/jimconf.sh` and `tests/jimfile.sh` (no `.test.` infix).**
   The 1:1 mapping with the script-under-test name is the point — and the
   files being directly executable reinforces that. The `.test.sh` infix was
   only attractive when files were NOT standalone-runnable; that constraint
   is now gone.

## Resolved shape

```
tests/
  run.sh                 # entry: sources testlib + every tests/*.sh, runs all
  testlib.sh             # globals + asserts + fixture/empty_dir + reporter (~120 lines)
  jimconf.sh             # executable: case_* defs + run() invoker; tail runs if direct
  jimfile.sh             # executable: case_jimfile_* defs + run_jimfile(); tail runs if direct
```

- `bash tests/jimconf.sh` → runs only jimconf cases.
- `bash tests/jimfile.sh` → runs only jimfile cases.
- `bash tests/run.sh` → runs every `tests/*.sh` (excluding `run.sh` itself
  and `testlib.sh`).
- `bash tests/run.sh jimfile` → existing filter still works (matches at the
  file level, the case level, or both — TBD in the plan).
- No `TESTS=()` arrays anywhere — discovery via `declare -F | awk '/^declare -f case_/'`
  after sourcing.

### Decision: single `testlib.sh`, not a `lib/` folder

User raised the right question: flatten to `tests/testlib.sh`, OR split into
`tests/lib/{globals,asserts,fixture,reporter}.sh`?

Math on the split: the reusable infra is ~120 lines total, broken down as
~25 (globals) + ~50 (asserts) + ~25 (fixture/empty_dir) + ~30 (reporter).
A 4-file split puts ~30 lines per file — each file becomes a stub with more
header docblock than code. The "one folder of several files" pattern earns its
keep when each file has real weight (50-150+ lines); here it would be ceremony.

The goal is "no single 700-line file for tests" — that is fully achieved by
moving cases out into `tests/jimconf.sh` and `tests/jimfile.sh`. The lib being
one file at ~120 lines isn't the problem.

**Choice: `tests/testlib.sh` (single file).** Revisit splitting into a `lib/`
folder *if* the infra grows past ~250-300 lines (e.g., when `/jim:meta-test`
lands and adds new helpers, or when a third script-under-test arrives with
new fixture types). Easy to refactor later — sourced files don't care about
their on-disk layout.

Ready to route to `/jim:spec` whenever you are.
