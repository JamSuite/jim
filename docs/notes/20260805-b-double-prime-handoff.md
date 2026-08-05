# Handoff — #188 landed, B″ is next

**Written:** 2026-08-05 · **Branch:** `feat/id-coordination` · **HEAD:** `8779c52`
· tree clean · suite **1140/1140** (1137 baseline + 3 new cases)

**What this is.** A short primer written at the point where #188 is done and B″
has not started. It deliberately does **not** restate what the repo already
carries — read those first and do not re-derive them:

- `docs/notes/20260728-id-coordination-issue-grouping.md` § *Sequence* steps 6–8
  is the authority on what B″ is, its two pre-code forks, and the door-ordered
  pass list. It is current as of this date.
- `docs/issues/20260801-…-named-degradation.md` § *Resolution* records exactly
  what #188 shipped and the two things it deliberately left.
- `docs/notes/20260805-b-prime-review.md` is the primary source for #220–#234.

What follows is only the material that lives nowhere in the repo: findings that
cost a fan-out to establish, and traps this session actually sprang.

---

## 1. The ledger's mechanical contract — established, do not re-investigate

This governs any future counter work and is written down nowhere else.

| Fact | Anchor |
| :--- | :--- |
| **The write path is entirely unvalidated.** `cmd_event` joins `"$@"` with `;` and appends. No key allowlist, no `k=v` shape check, no charset gate, no sanitizer | `jimledger.sh:758` |
| The append primitive's only guard is *directory exists*; `$kv` goes straight into `printf` | `jimledger.sh:78` |
| **A new counter key therefore needs no script change** — this is why #188's `undelegated=` is pure SKILL.md prose | — |
| `events` re-emits field 5 verbatim, unparsed → a new key **displays** | `jimledger.sh:781` |
| `metrics` iterates a **fixed code-literal stage list** and never reads field 5 → a new key is **silently invisible** | `jimledger.sh:896` |
| Only two payload keys in the whole ledger reach `metrics`, each an explicit lift + shape validation: `review_alignment`, `review_findings` | `jimledger.sh:933` |
| **A test pins that an unlisted key stays out of `metrics`** — extend it deliberately if you ever want one in, do not trip over it | `tests/jimledger.sh:1088` |
| The one existing hard key whitelist (the shape to copy if a counter must be validated on read) is the reconcile contract | `jimledger.sh:1024` |

**Consequence for #188's counter:** `undelegated=` rides the event and surfaces
through `/jim:ledger events`. It was **deliberately kept out of `metrics`**,
whose fixed shape-validated key set exists to keep hand-editable ledger text out
of mined values. That was a decision, not an oversight — revisit it only with
that rationale in hand.

Note also: `checked`, `holds`, `violated`, `failed`, `unconfigured`, `skipped`,
`inchange`, `preexisting`, `edges_checked`, `edge_violations` are **all** prose-only
in SKILL.md and pinned by nothing. `tests/fanoutdisclosure.sh` now pins
`undelegated=` alone, by rule. The others remain unpinned.

## 2. The delegation inventory — classified, reusable

Five contract-critical surfaces (the delegation *is* the contract), all now
carrying the disclosure rule:

| Surface | Dispatch sites | Remedy shipped |
| :--- | :--- | :--- |
| `/jim:verify` judges | `SKILL.md:233` (group / `--from-review` / `--since` share one) · `contracts-methodology.md:152` (C5) · `retirement-methodology.md:184` (R4) | `failed` + reason `undelegated`; `inconclusive` in retirement |
| `/jim:review` investigators | `SKILL.md:102` | named coverage + ledger counter |
| `/jim:issue insights` analyst | `SKILL.md:229` | **refuses** — see below |
| `/jim:partition` gatherers | `SKILL.md:109`, `:292`, `:362`, `:419` | withholds gatherer-marked invariants |
| `/jim:research` Explore | `SKILL.md:75` | **none — out of scope by decision**: a cost lever with no independence claim to lose |

Routing surfaces (persona spawns) already name a fallback and were left alone —
`meta-skill`, `meta-agent`, `meta-test`; `plan` was the one gap and is fixed.

**The `insights` case is the sharpest thing this pass found and is worth
remembering as a class.** The `issue` blueprint declares
`insights-capability-boundary` (`high`): synthesis happens only in the write-free
analyst, and the main agent reads no bodies. So a suppressed dispatch there does
not degrade quality — it **violates a declared invariant**. That is why it alone
refuses instead of naming-and-continuing. Any future "the fan-out didn't run"
reasoning must first ask whether the delegation is a *quality lever* or a
*capability boundary*; they take opposite remedies.

## 3. Traps this session sprang

1. **The full suite takes roughly ten minutes.** Background it
   (`bash skills/meta-test/scripts/run.sh > log 2>&1 &`) and poll the log for
   `^Ran [0-9]+ tests`; a foreground run trips the 600s timeout. The prior
   handoffs' warning still holds and was confirmed again here.
2. **Mutation-test by targeted file backup, never `git stash`.** With a
   many-file working tree, stash moves edits you did not mean to move. The
   harness that worked: `cp` the one file aside, `sed` the mutation, run the one
   filtered case, `cp` back. Scratchpad, not the repo.
3. **`assert_eq` is the only equality helper and there is no `assert_ne` /
   `assert_contains`.** The house idiom for absence is
   `assert_eq "label" "0" "$(… | grep -c …)"`, and for booleans a `yes`/`no`
   string through `assert_eq`. See `testlib.sh` header — it is the canonical
   conventions reference.
4. **`metatest.sh scaffold` writes a script-under-test stub** that a textual-invariant
   test does not want. `tests/scripthygiene.sh` and `tests/gatepresentation.sh`
   are the right shapes to copy for corpus sweeps — no `SCRIPT_*`, no invoker.
5. **The coordination remote is still unreachable from this sandbox.** Reads work
   from the last-seen cache; issue filing mints `P-` provisionals needing
   `/jim:issue reconcile` from the host. The host ran one this session (#220–#234).

## 4. What B″ should know that the cluster note does not spell out

The note's step 7 gives the door-ordered pass list. Two additions:

- **The fixture-blindness batch (#215, #221, #222, #224, #225, #226, #227, #230)
  is the largest single group and its definition of done is per-assertion
  mutation testing**, not per-fixture. Six fixture claims fell in B′'s review for
  exactly this, and every one had a working tested half beside a blind untested
  half. `tests/fanoutdisclosure.sh`'s harness pattern (§3.2) is the cheapest way
  to run it.
- **#229's fork should be settled with #200 in the same conversation.** B′
  refused the contradictions at the emitters and settled no repair path; #229
  refusing a vacated ordinal in `catch-up` leaves the same question standing —
  what repairs a registry that already holds one. The cluster note's *Decisions*
  section has #200's class list.

## 5. Deliberately not done, with reasons

Neither is an oversight; do not "fix" either without re-deciding it.

- **No blueprint invariant for the delegation rule.** The natural one — a phase
  resting on delegated judgment never reports a clean result from inline
  judgment — is worth having. It needs a group-ownership decision (`blueprint`
  owns verify/review/partition doctrine; `issue` owns the capability boundary)
  and a `/jim:blueprint` write, so it belongs in a pass scoped for it.
- **No `/jim:arch` run.** `ARCHITECTURE.md` → Subagent Delegation is three
  bullets that all assume delegation works, and wants a fourth. But the doc is
  already stale on other grounds (stamped 2026-08-03, still documenting the
  retired `renumber-map` arity) and its regeneration is scheduled in B″'s docs
  pass. Running it now would regenerate against a tree B″ then changes again.
- **`review_fanout_cap` is still unset** in `jimconf.toml` (defaults to 10; B′'s
  review needed 17). Raising it is a cost lever and the operator's call.

## 6. The standing observation

#188 is closed, and the thing it was about is not solved and cannot be. The code
now *names* a suppressed fan-out; it cannot *summon* the authorization that
prevents one. This session ran its investigators on Opus 5 — the model the
directive targets — and they ran only because the operator authorized them
unprompted, in the opening message. That is the fourth consecutive instance where
a person, not a mechanism, is what made the fan-out happen.

So the operating rule for any session doing review-, verify-, or partition-shaped
work here: **say the authorization phrase up front**, before the phase that needs
it, and check that the investigators actually ran rather than trusting a clean
report. `WORKFLOW.md` → Operating Notes carries the phrase.
