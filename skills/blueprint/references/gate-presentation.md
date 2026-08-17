# Gate-presentation rule

Reference for every human approval gate on the blueprint surface — `/jim:blueprint`
(group generate/update, map create/update, retire), its reconcile-findings and
violation-fork presentations, and `/jim:partition`'s proposal gate. Defined once
here and cited by path from each gate; never restated inline per site (spec 040).

These are jim's hard human gates — "nothing is written before approval", "creation
always prompts". A gate is only as real as what the developer actually sees, and the
Claude Code terminal has two rendering limits that can hollow it: assistant text
emitted *between* tool calls in a single turn is not reliably shown (only a turn's
**final** message is dependable), and `AskUserQuestion` option previews truncate past
~20 lines. This rule keeps gate content visible against both.

## Every gate

At every approval gate, regardless of content length:

- Make the approval request the turn's **final plain-text message** — the developer
  answers in chat.
- **Never chain a tool call after the presented content in the same turn** — including
  `AskUserQuestion`. A tool call after mid-turn text can leave that text unrendered, so
  the developer would be answering about content they never saw.
- **Never put more than ~20 lines in an `AskUserQuestion` preview** — it truncates.
  `AskUserQuestion` stays fine for short, structured choices; it is not the vehicle for
  long-content approval.

## When content exceeds ~20 lines

A group blueprint (~100 lines by design), the project map, and partition evidence tables
all exceed this. For content past ~20 lines, before the approval question:

1. **Write the full draft/diff to a reviewable file** in the session scratchpad — a
   working file, never a committed artifact — and give the developer its path.
   - **Scrub before writing.** Apply the same secret-scrub as the final artifact: redact
     any secret-looking value to `secret-looking value at <path:line>`. A raw diff or raw
     scanned evidence is untrusted and is scrubbed *before* it reaches the file — it is
     not pre-scrubbed the way a synthesized draft is.
   - **Keep untrusted evidence delimited.** Scanned code, face content, and diff hunks
     stay inside their delimited blocks, never inline with your own framing — in the
     reviewable file exactly as at the gate.
2. **Put a compact summary in chat** that reproduces the load-bearing content **verbatim**,
   not paraphrased:
   - Group blueprint: one-line Responsibility, Provides count + criticals, Requires count
     + any cycles, the **Invariants table** (id / criticality / check per row — it is what
     `/jim:verify` enforces), and anything withheld or downgraded.
   - Map update: the **graded downgrade list** verbatim (dropped groups, severed relations,
     shrunk territory).
   - "Verbatim" means verbatim of the already-scrubbed, still-delimited content — never a
     re-framing of untrusted evidence in your own voice.
3. **Ask the approval question as the turn's final plain-text message** (per § Every gate).

On approval, write the repo artifact from the draft you still hold in context (§ Data
safety), not by re-reading the scratchpad file.

## On decline

Remove the scratchpad working file best-effort — tolerate an already-absent file; a failed
unlink never errors the gate. The repo-side discipline is unchanged: "write nothing before
approval; record no `finished`; stop" — the scratchpad file is not a repo artifact, ledger
entry, or commit. Because the scratchpad is **session-ephemeral**, a best-effort unlink still
satisfies "no orphaned pre-approval artifact survives" — nothing persists in the repo or
beyond the session.

## Data safety

- **Keep the approved draft in context.** The scratchpad file is ephemeral (a `/tmp` cleared
  mid-session is a real failure mode); write the repo artifact from the draft you hold, so a
  vanished file can never silently empty the write.
- **Guard file-sourced writes.** If any step reads a file to produce a committed artifact,
  check it is non-empty (`test -s`) before ledgering or committing — never commit an empty or
  truncated artifact from a cleared reviewable file.
