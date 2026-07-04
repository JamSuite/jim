> This document is generated and maintained by `/jim:blueprint`. Edit via
> the skill to preserve the partition's coherence.

# Blueprint — {project}

*Axis: {vertical|layered} · Territory: {directory|declared-paths|none}*
*Last updated: {YYYY-MM-DD} (via /jim:blueprint)*

*The project-tier context map: the declared partition of this project into
spec groups, each a deliberate context boundary. Current state only — the
authoritative intent that the group blueprints sit beneath and that
`/jim:spec`'s assignment advisor consumes. The cross-group contract graph is
derived from the group blueprints' provides/requires faces; it is never
re-declared here.*

## Context Map

| Group | Role | Purpose | Relations |
| :--- | :--- | :--- | :--- |
| {group} | {domain\|platform\|layer} | {one line} | {requires ← peer · provides → peer} |

## Groups

### {group}

- **Purpose:** {1–2 sentences — what this context owns.}
- **Role:** {domain | platform | layer}
- **Boundary rationale:** {why this is its own context — distinct domain
  language, change isolation, ownership. For role `platform`: the explicit
  justification of its shared surface.}
- **Relations:** {requires `{other-group}` ({guarantee leaned on});
  provider to `{other-group}`. Reference the faces in the group
  blueprints — never restate their content.}
- **Territory:** {relative paths, each validated via `jimfile.sh
  valid-relpath`. Omit this line under territory mode `none`; leave empty
  when not yet known (greenfield).}
- **Blueprint:** {specs}/{group}/000-blueprint/

## Contract Graph

*Derived from the group blueprints' provides/requires faces — regenerated
on every blueprint write; do not edit. Last reconciled: {ts from
`jimfile.sh now`} (via /jim:blueprint)*

| Consumer | Relies on | Provider |
| :--- | :--- | :--- |
| {group} | {relied-on provides entry, named short} | {group} |

{With fewer than two blueprint-bearing groups, replace the table with:
*Nothing to reconcile — fewer than two groups have blueprints.*}
