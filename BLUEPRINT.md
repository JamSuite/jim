> This document is generated and maintained by `/jim:blueprint`. Edit via
> the skill to preserve the partition's coherence.

# Blueprint — jim

*Axis: vertical · Territory: declared-paths*
*Last updated: 2026-07-05 (via /jim:blueprint)*

*The project-tier context map: the declared partition of this project into
spec groups, each a deliberate context boundary. Current state only — the
authoritative intent that the group blueprints sit beneath and that
`/jim:spec`'s assignment advisor consumes. The cross-group contract graph is
derived from the group blueprints' provides/requires faces; it is never
re-declared here.*

## Context Map

| Group | Role | Purpose | Relations |
| :--- | :--- | :--- | :--- |
| jim | domain | The agentic-SDLC Claude Code plugin — skills, agents, and their deterministic scripting layer | — (single group) |

## Groups

### jim

- **Purpose:** The entire jim plugin: SDLC/strategic/discovery skills, agent
  personas, and the bash scripting layer they compose.
- **Role:** domain
- **Boundary rationale:** Deliberately a single bounded context. The plugin
  shares one domain language (skills, agents, specs, gates, ledger), one
  owner, and one release unit; no internal seam yet justifies a contract
  boundary. Visible future seams — issue tracking (017–025), the review
  pipeline (026–028), the blueprint machinery (029–034), the verification
  engine (035–037) — remain internal clusters until cross-cluster contracts
  would earn their keep.
- **Relations:** — (single group; nothing to relate).
- **Territory:** `skills/`, `agents/`, `tests/`
- **Blueprint:** docs/specs/jim/000-blueprint/

## Contract Graph

*Derived from the group blueprints' provides/requires faces — regenerated
on every blueprint write; do not edit. Last reconciled: 2026-07-13T07:21:43Z
(via /jim:blueprint)*

*Nothing to reconcile — fewer than two groups have blueprints.*
