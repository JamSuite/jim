---
spec: "docs/specs/issue/011-issue-placement/spec.md"
reviewed_phases: [spec, plan]
status: Needs Plan Review
date: "2026-08-06"
---

# Security Review: Issue placement — configurable issue content location

## Summary

**Findings:** 1 Critical · 3 Notable · 6 Advisory all-time — **open: 1 Critical · 1 Notable · 2 Advisory** (Findings 7–10, this run)

Second pass 2026-08-06: dual lens over `spec.md` + `plan.md`. All six spec-phase findings are resolved — Findings 1–2 as spec ACs #12/#13, Findings 3–6 by the plan's design (DD 1/3/10 and the structural CWD decision). The plan-phase pass adds four: the Critical is a path-containment gate the materialization step must carry before any extracted destination content touches the filesystem. Finding numbers are stable across runs (spec ACs cite them); new findings append rather than re-sort by severity.

## Coverage

- spec.md — reviewed 2026-08-06 (requirements-gap lens)
- plan.md — reviewed 2026-08-06 (design-flaw lens, artifact-misalignment check)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | Yes | Indirect — issue bodies are developer-authored free text and can embed names, emails, or customer fragments (e.g. pasted error logs) despite the filing scrub gate; this feature widens and accelerates their publication |
| Credentials | No | The filing scrub gate excludes them from bodies by convention; git push auth is ambient and never read, stored, or echoed by the feature |
| Session data | No | None handled |
| Internal-only | Yes | Issue bodies, ordinals/durable ids, INDEX.md — project-internal by design |
| Public | No | Repo-scoped; no public exposure surface |

## Findings

### 1. A destination-branch history rewrite silently un-publishes mutations

- **Severity:** Notable
- **Description:** The registry's erosion guard does not transfer to the placement branch: `specs.log`/`issues.log` are append-only, so a byte-prefix growth check screams on force-push — but issue content is legitimately edited, so no growth invariant exists. A force-push (or deletion/re-creation) of the destination branch silently drops filings, closes, and edits for every reader; AC #6's fetch-before-read then serves the rewritten collection with full confidence. Tampering is undetectable and the audit trail (git history, the collection's only record) is erased in the same act.
- **Suggestion:** Add an AC: a non-fast-forward movement of the destination tip relative to the last-seen state is detected and disclosed on read (an ancestry check against a locally recorded tip — cheap, no new state class; the allocator already records last-seen tips). Pair it with the force-push-deny branch-protection profile documented under the existing team-setup issue (#118) — detection here, prevention there.
- **Route:** Spec
- **Relates to:** AC #5, AC #6, AC #7
- **Disposition (2026-08-06, plan pass):** Resolved — spec AC #12; plan DD 5 (bookmark ancestry check) + task 6 implement it.

### 2. Quiet auto-filing plus centralized placement publishes bodies with no human gate

- **Severity:** Notable
- **Description:** Under `auto_issue_file = "true"`, candidate batches file silently — today that is safe because content lands on the *working branch*, where it still passes human eyes before a merge or PR publishes it. Under a branch-name placement with auto-commit and push (AC #3/#4/#7), an unscrubbbed body — a raw error log, a customer fragment, an internal path — is on the shared remote seconds after an agent generated it, with no human having seen it. Recall means rewriting a shared branch, which Finding 1 argues readers must treat as an alarm; practically, publication is irreversible. The spec 017 AC-C2 scrub moment is the collection's one privacy gate, and this combination routes around it.
- **Suggestion:** Define the interaction in the spec: under a non-`branch` placement, the auto-file path still surfaces the pre-publication scrub moment (per-batch confirm), or the configuration itself must carry an explicit acknowledgment that auto-filed content publishes immediately and irreversibly. Silence on this interaction will be resolved ad hoc at build time.
- **Route:** Spec
- **Relates to:** AC #3, AC #4; spec 017 AC-C2; spec 018 WS-7
- **Disposition (2026-08-06, plan pass):** Resolved — spec AC #13; plan DD 9 (§7a rule + `issue_placement_ack`) + task 11 implement it.

### 3. Retry must reapply the mutation, never re-push the built tree

- **Severity:** Advisory
- **Description:** AC #7's "reapplied and retried" is satisfiable by an implementation that, after losing the race and fetching, re-pushes the tree it built *before* the fetch — erasing the concurrent mutation it lost to, at rc 0, with the push succeeding and nothing "silently lost" by the implementation's own accounting. File-level last-writer-wins over a fetched tip is the same defect with a merge step.
- **Suggestion:** The plan should adopt the registry's builder-per-attempt contract (`alloc_publish`: recompute the change from the fresh tip on every attempt), so a retry re-applies the *mutation* onto the winner's state rather than restoring the loser's snapshot.
- **Route:** Plan
- **Relates to:** AC #7
- **Disposition (2026-08-06, plan pass):** Resolved — plan DD 3 goes further than the suggestion: per-file graft + INDEX regeneration, never re-running the wrapped command (avoiding the double-allocation the literal builder-per-attempt would cause) and never re-pushing a stale tree.

### 4. Read-path availability: non-interactive git, timeouts, bounded retries

- **Severity:** Advisory
- **Description:** Fetch-per-read makes every read verb network-dependent. A remote that *hangs* (interactive auth prompt, slow network) is not "unreachable" — it stalls `list`/`show` indefinitely and never reaches AC #6's disclosed-degradation path. `GIT_TERMINAL_PROMPT=0` is currently set only in `jimalloc.sh:51`; nothing bounds a placement write's retry loop yet.
- **Suggestion:** Plan adopts the allocator's posture for every placement git call: non-interactive git, converting hangs into the degrade path, and a bounded jittered retry (registry precedent: 5 attempts + sub-second backoff).
- **Route:** Plan
- **Relates to:** AC #6, AC #7
- **Disposition (2026-08-06, plan pass):** Resolved at allocator parity — plan DD 10 (`GIT_TERMINAL_PROMPT=0`, 5-attempt jittered retry, deferred-push disclosure). Residual: no explicit `timeout(1)`; deliberately coupled to #139's suite-wide decision, named in the plan's Open Questions.

### 5. Temp materialization hygiene

- **Severity:** Advisory
- **Description:** Worktree or temp-dir designs materialize the collection outside the repo tree; a crashed run leaves that copy on disk (issue bodies included) and stale worktree metadata that can block future `worktree add` invocations.
- **Suggestion:** Cleanup traps on every materialization (the emitter's `trap 'rm -f …' EXIT INT TERM` pattern at `new.sh:185-211`) plus stale-worktree handling (`git worktree prune` or plumbing-only designs that materialize nothing).
- **Route:** Plan
- **Relates to:** AC #3
- **Disposition (2026-08-06, plan pass):** Resolved — plan DD 1 eliminates worktrees entirely (no stale-worktree class exists); task 3 carries the cleanup traps. Residual: a crash between `begin` and `commit` (DD 8) strands one temp dir — disclosed by design, cleaned by `abort`.

### 6. Orphan destination resolves default config inside the worktree

- **Severity:** Advisory
- **Description:** An orphan destination branch carries no `jimconf.toml`; any script invoked with the worktree as `$PWD` resolves default config (project-root-as-CWD invariant, `jimconf.sh:324-327`). A project with a custom `issues_path` would have its writes land at an unintended path *and then publish that misplacement on the shared branch* at rc 0.
- **Suggestion:** Plan must pin config resolution to the primary checkout (resolve before entering any materialized context, or close the `-c` seam in the four issue scripts that lack it) and decide the collection's canonical path inside the destination tree explicitly.
- **Route:** Plan
- **Relates to:** AC #8
- **Disposition (2026-08-06, plan pass):** Resolved structurally — plan DD 1 runs every wrapped command with CWD = primary checkout; no config is ever resolved inside a materialized context. DD 7 pins the collection's canonical path (configured `issues_path`, mirrored).

### 7. Materialization must contain every extracted path

- **Severity:** Critical
- **Description:** `place.sh` materializes destination-branch tree content onto the local filesystem (plan DD 1, task 3). Branch content is untrusted data (the spec-026 stance: git history can carry attacker-influenced content; anyone with repo push access can commit to the destination). A naive extraction — `git archive | tar -x`, or blind `cat-file` writes keyed on tree paths — will honor a crafted tree entry carrying a traversal path, writing **outside the temp dir** at read time: an arbitrary file write at user privilege, triggered by running `list`. The plan does not currently name a containment gate on this step.
- **Suggestion:** Task 3 must gate every extracted entry: enumerate via `git ls-tree -r`, validate each path through the `valid-relpath` boundary (no absolute, no `..` segment) **and** a `realpath -m`-style containment check against the temp root before any write (the `alloc_write_contained` / `commit-map` precedent); refuse the whole materialization on the first non-conforming entry, naming it. Add a crafted-tree fixture (the `tests/issues.sh:2478-2481` plumbing seam can plant one) asserting the refusal.
- **Route:** Plan
- **Relates to:** plan DD 1, task 3; spec AC #3, AC #5

### 8. The graft engine must replay deletions and renames

- **Severity:** Notable
- **Description:** Plan DD 3's per-file replay is stated over modified/created files. `migrate.sh prefix` (and any future rename mutation) *deletes* old filenames; if the changed-set diff captures only additions and modifications, a graft retry after a lost race silently resurrects the deleted file on the merged tree — two files for one issue, duplicate ordinals in the regenerated INDEX, at rc 0.
- **Suggestion:** Define the changed set as additions + modifications + **deletions** (a rename = delete + create pair); replay deletions under the same rule (upstream unchanged since base → delete; upstream modified → rc 3 conflict). Add a rename-under-race fixture to task 9's tests.
- **Route:** Plan
- **Relates to:** plan DD 3, tasks 5 and 9

### 9. Direct mode must not sweep dirty collection state into its commit

- **Severity:** Advisory
- **Description:** Plan DD 6's path-scoped `git add -- <paths>` / `commit -- <paths>` on the checked-out destination will include any uncommitted developer edits already sitting at those paths — silently publishing half-finished manual edits inside a mutation's commit.
- **Suggestion:** Before the path-scoped commit, check the target paths for uncommitted changes (`git status --porcelain -- <paths>`, the `migrate.sh:151-157` precedent) and disclose or refuse rather than absorbing them.
- **Route:** Plan
- **Relates to:** plan DD 6

### 10. Harden the self-route sentinel against inherited environment

- **Severity:** Advisory
- **Description:** `JIM_PLACE_ACTIVE=1` (plan DD 2) suppresses placement routing. A stale or accidentally exported variable in the developer's environment would silently disable centralization — writes land on the working branch at rc 0, re-creating the divergence this feature exists to kill, with no error to notice.
- **Suggestion:** Make the sentinel run-scoped rather than boolean: `place.sh` sets it to a per-run token (e.g. the temp-dir basename) and the entry scripts honor it only when it matches a value `place.sh` itself passes; any other value is ignored and disclosed.
- **Route:** Plan
- **Relates to:** plan DD 2

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | No | No new identity surface — the ceiling is the repo's existing push-access boundary; commit authorship remains the ambient git convention, unchanged by this feature |
| Tampering | Yes | Findings 1, 3, 7, 8 |
| Repudiation | Yes | Finding 1 — git history is the collection's only audit trail, and the rewrite that tampers is the rewrite that erases it |
| Information Disclosure | Yes | Finding 2 |
| Denial of Service | Yes | Finding 4 |
| Elevation of Privilege | Yes | Finding 7 — a crafted tree entry escalates repo push access into an arbitrary file write at the reading user's privilege |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | No | Bodies already carry `origin:`/authorship links; placement changes visibility timing (covered by Finding 2), introducing no new cross-context join |
| Identifying | N/A | The collection makes no anonymization claims to defeat |
| Non-repudiation | No | Permanent attribution of filings on a shared branch is the repo's existing commit convention; no privacy expectation of deniability exists here |
| Detecting | N/A | No subject-presence inference surface |
| Data Disclosure | Yes | Finding 2 |
| Unawareness & Unintervenability | Yes | Finding 2 — a third party named in a pasted body (e.g. a customer in an error log) gains wider, faster exposure with no awareness; the scrub moment is the only intervention point, and Finding 2 shows the path around it |
| Non-compliance | N/A | No stated privacy policy governs the collection |

## Artifact Misalignment

None identified. One reading checked and cleared: spec AC #7's "reapplied and retried rather than lost" vs plan DD 3's conflict-refusal — a same-file race ends in a *named* rc-3 refusal with state preserved, which satisfies "never silently lost"; the spec's wording does not promise unconditional eventual landing, and the plan's bound is the honest one.

## Routing Recommendations

### Spec amendments
- Finding 1: add a non-fast-forward detection/disclosure AC for the destination tip (read-time ancestry check against last-seen state). *Applied 2026-08-06 as AC #12 ("Rewrite detection").*
- Finding 2: add an AC or explicit config acknowledgment governing the `auto_issue_file` × non-`branch` placement interaction, preserving a pre-publication scrub moment. *Applied 2026-08-06 as AC #13 ("Auto-filing keeps a scrub moment") — degrades to interactive confirm unless explicitly acknowledged in config.*

### Plan amendments
- Findings 3–6: **discharged by the plan as drafted** (see per-finding dispositions) — DD 3 (graft retry), DD 10 (network posture), DD 1 (no worktrees, CWD pinned), DD 7 (canonical path).
- Finding 7 (**Critical**): add the extraction containment gate to task 3 — per-entry `valid-relpath` + temp-root containment before any write, refuse-on-first-violation, crafted-tree fixture. *Applied 2026-08-06 — DD 1 § Containment; task 3 rewritten with the `ls-tree -z` enumeration and the traversal-refusal fixture.*
- Finding 8: extend DD 3 / tasks 5 & 9 — deletions in the changed set, rename-under-race fixture. *Applied 2026-08-06 — DD 3 changed set now adds/mods/deletes; fixtures in tasks 5 (engine) and 9 (migrate rename).*
- Finding 9: extend DD 6 — dirty-path check before the direct-mode commit. *Applied 2026-08-06 — DD 6 § Dirty-path guard (rc 2, paths named); new task 6a fixtures direct mode and the refusal.*
- Finding 10: extend DD 2 — token-valued sentinel instead of `1`. *Applied 2026-08-06 — DD 2 § Sentinel shape; `JIM_PLACE_TOKEN` + `--place-token` must match; stale-token fixture in task 2.*

### Candidate issues
No findings route to Issue this run — Finding 1's prevention half (branch-protection profile) rides the existing #118 rather than a new issue.
