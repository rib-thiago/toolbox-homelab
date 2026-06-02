# Toolbox Knowledge Base

The `knowledge/` directory is the central operational context layer of the Toolbox.

It exists so that humans, ChatGPT, Codex, and future AI agents can understand the homelab, plan changes, assess impact, and perform diagnostics without depending on long chat histories.

This directory does not replace scripts, reports, or long-form documentation. It organizes stable operational knowledge needed for agent-assisted work.

## Core principles

- `knowledge/` contains stable operational context.
- `scripts/` contains executable automation.
- `docs/` contains complementary human-oriented documentation.
- `/srv/toolbox/shared/` contains generated artifacts: reports, inventories, TSVs, snapshots, logs, and briefs.
- Agents must consult `knowledge/` before inspecting or modifying the environment.
- Agents must not depend on chat memory as the primary source of truth.
- Generated inventories must not be confused with architectural decisions.
- Architectural decisions must not be inferred only from observed system state.

## Structure

### `context/`

Minimal entrypoint for agents.

This directory contains short files that explain the environment, the Toolbox, global rules, and the operational starting point.

Typical files:

- `agent-entrypoint.md`
- `homelab-context.md`
- `toolbox-context.md`

### `graph/`

Structured map of entities and relationships.

This directory contains entities, dependencies, exposure paths, storage relationships, backup relationships, network relationships, criticality, and impact information.

Typical files:

- `entities.yaml`
- `relations.yaml`

### `architecture/`

Human architectural decisions.

This directory contains ADRs and records explaining why important choices were made.

Examples:

- Docker-first and private-first operation.
- Toolbox operational model.
- Agent-assisted workflow.
- Backup and restore decisions.
- Media curation decisions.

### `services/`

Operational context by service, domain, or component.

Each file should be short, practical, and agent-oriented.

Examples:

- `toolbox.md`
- `docker-platform.md`
- `networking.md`
- `backup.md`
- `navidrome.md`
- `music-staging.md`
- `stockhausen-workflow.md`

### `policies/`

Mandatory rules.

Policies define what is allowed, what is forbidden, what requires human approval, and how work must be recorded.

Examples:

- Agent safety policy.
- Change management policy.
- Filesystem safety policy.
- Git policy.
- Backup policy.
- Reporting policy.
- Media curation policy.

### `runbooks/`

Reusable procedures.

Runbooks explain how to perform specific tasks safely.

Examples:

- Diagnose host in read-only mode.
- Diagnose a Docker service.
- Prepare a safe change.
- Validate after a change.
- Generate a ChatGPT brief.
- Review a music-staging album.

## Agent usage

Before any task, an agent must:

1. Read `knowledge/context/agent-entrypoint.md`.
2. Read the applicable context files.
3. Consult `knowledge/graph/` for impact and dependencies.
4. Consult `knowledge/policies/` for restrictions.
5. Consult `knowledge/services/` for component-specific context.
6. Consult `knowledge/runbooks/` for existing procedures.
7. Produce a plan before any change.
8. Request human approval before executing changes.
9. Record generated artifacts under `/srv/toolbox/shared/`.

## Separation rule

Stable and normative knowledge belongs in `knowledge/`.

Observed and dated evidence belongs in `/srv/toolbox/shared/`.

Executable automation belongs in `scripts/`.

Long-form, narrative, explanatory, or historical documentation belongs in `docs/`.

## Anti-redundancy rule

Do not duplicate in `knowledge/` information that can be obtained automatically by command, unless it is necessary to guide agents.

Bad example:

- Manually listing all current containers and ports in long prose.

Good example:

- Recording that Navidrome is the main music service, depends on `/srv/media/music`, is exposed through Nginx Proxy Manager and Tailscale, and requires care around metadata and transcoding.

## Confidence rule

Every piece of information should be classifiable as one of:

- human decision;
- operational policy;
- observed state;
- inference;
- pending validation.

Observed state should point to inventories or reports under `/srv/toolbox/shared/`.
