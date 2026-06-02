# Services Knowledge Layer

This directory documents central operational units in the homelab and Toolbox.

In this knowledge base, a “service” is not limited to a Docker container. A service is any operational unit with its own role, paths, dependencies, workflows, risks, inspection methods, and approval boundaries.

This layer is intended for ChatGPT, Codex/local agents, future automation agents, and human operators.

## Required context and policies

Before using or editing service documents, agents and operators must read the central context and policy layer.

Required context documents:

- `knowledge/context/agent-entrypoint.md`
- `knowledge/context/homelab-context.md`
- `knowledge/context/toolbox-context.md`

Required policy documents:

- `knowledge/policies/agent-safety-policy.md`
- `knowledge/policies/change-management-policy.md`
- `knowledge/policies/reporting-policy.md`
- `knowledge/policies/filesystem-safety-policy.md`
- `knowledge/policies/media-curation-policy.md`

Service documents must follow these policies and must not override them.

## Purpose

`knowledge/services/` provides stable operational maps for important homelab subsystems.

Each service document should help an agent or operator understand:

* what the service is;
* why it matters;
* where it lives;
* what data or configuration it uses;
* what other services depend on it;
* which scripts, reports, TSVs, inventories, and runbooks are relevant;
* what can be inspected in read-only mode;
* what requires explicit approval;
* what historical lessons or open questions are relevant.

Service documents are not runbooks.

Service documents are not raw inventories.

Service documents are not replacements for Docker Compose files, operational policies, reports, TSVs, or service-specific documentation.

## Relationship with other knowledge layers

The `knowledge/` structure separates responsibilities:

* `knowledge/context/` gives broad context for agents.
* `knowledge/policies/` defines mandatory rules.
* `knowledge/services/` maps concrete operational units.
* `knowledge/runbooks/` should contain step-by-step procedures.
* `knowledge/architecture/` should contain decisions, ADRs, historical lessons, and structural explanations.
* `knowledge/graph/` should contain relationship data or graph-oriented representations.

A service document may point to all of these, but it should not duplicate them unnecessarily.

## Relationship with `docs/`

Human-facing operational documentation remains under `docs/`.

Service documents may summarize the role of a service, but detailed policies and explanations should remain in the relevant documents under `docs/operations/`, `docs/media/`, or other `docs/` paths.

The rule is:

* `knowledge/services/` summarizes and points.
* `docs/` explains in detail.
* `scripts/` automates.
* `/srv/toolbox/shared/` stores generated evidence.

## Service types

Each service document must declare one `service_type`.

Allowed service types are:

* `technical_service`
* `operational_subsystem`
* `workflow`
* `infrastructure_layer`

### `technical_service`

A technical service is a concrete deployed service, daemon, container, or application.

Examples:

* Docker
* Navidrome
* FileBrowser
* Samba
* Nginx Proxy Manager
* Jellyfin
* Immich
* Calibre-Web
* Kavita
* slskd
* Backrest

### `operational_subsystem`

An operational subsystem is a recurring operational area made of scripts, paths, policies, conventions, and evidence.

Examples:

* Toolbox
* backup
* music staging
* media curation
* reporting
* script inventory

### `workflow`

A workflow is a structured process with stages, evidence, review points, and safety rules.

Examples:

* music-staging review/import
* Stockhausen metadata normalization
* cold archive build
* Git checkpoint routine

### `infrastructure_layer`

An infrastructure layer is a cross-cutting system that affects multiple services.

Examples:

* networking
* Docker networking
* firewall
* reverse proxy
* Tailscale access
* storage layout

## Selection rule

`knowledge/services/` is selective.

It should document central operational units, not every installed container, client, folder, script, or collection.

A new service document should be created only when the unit has at least several of the following:

* recurring operational importance;
* sensitive paths or data;
* service dependencies;
* recurring diagnostics;
* existing scripts or workflows;
* approval boundaries;
* historical lessons;
* relevance to ChatGPT/Codex workflows;
* relationship to backup, networking, media, or security;
* need for read-only inspection guidance.

## First service batch

The first batch of service documents is:

* `knowledge/services/toolbox.md`
* `knowledge/services/docker.md`
* `knowledge/services/networking.md`
* `knowledge/services/nginx-proxy-manager.md`
* `knowledge/services/samba.md`
* `knowledge/services/backup.md`
* `knowledge/services/filebrowser.md`
* `knowledge/services/music-staging.md`
* `knowledge/services/navidrome.md`

A script inventory should also be created during this phase:

* `scripts/admin/system/diagnose-toolbox-script-inventory.sh`

The script inventory is not itself a service document, but it supports the `toolbox.md` service map and future agent workflows.

## Later service candidates

Later service documents may include:

* `knowledge/services/jellyfin.md`
* `knowledge/services/immich.md`
* `knowledge/services/calibre-web.md`
* `knowledge/services/kavita.md`
* `knowledge/services/slskd.md`
* `knowledge/services/monitoring.md`
* `knowledge/services/portainer.md`
* `knowledge/services/homepage.md`

These should be created only when they become operationally relevant to the current phase.

## Standard service document template

Each service document should follow this template unless there is a strong reason to deviate:

```text
# <Service Name>

## Purpose

## Service type

## Current role in the homelab

## Important paths

## Related services

## Related scripts and workflows

## Related reports, TSVs, inventories, and logs

## Related policies and docs

## Sensitive operations

## Read-only inspection allowed

## Read-only collection plan

## Actions requiring approval

## Known historical lessons

## Open questions

## Source of truth
```

Sections may be short.

A service document should be useful, not exhaustive.

## Read-only collection plan

Each service document should include a `Read-only collection plan`.

This section defines what a local agent may inspect without changing state.

Examples of read-only collection targets:

* relevant files under `/srv/toolbox/app`;
* related scripts under `scripts/`;
* related docs under `docs/`;
* related policies under `knowledge/policies/`;
* existing reports, TSVs, inventories, logs, and briefs under `/srv/toolbox/shared/`;
* relevant Compose files or service configuration paths when explicitly provided;
* references to the service across `knowledge/`, `docs/`, and `scripts/`.

The read-only collection plan must not authorize modification.

It must not authorize package installation, service restart, file moves, permission changes, metadata writes, backup changes, firewall changes, or Git operations.

## Existing scripts and workflows

The Toolbox already contains many scripts, helpers, libraries, runbooks, pipelines, reports, TSVs, and validated workflows.

Before proposing a new script or manual command sequence, agents must inspect whether existing Toolbox assets already cover the task.

Service documents should point agents toward relevant existing assets.

Agents should prefer:

* existing validated scripts over new scripts;
* existing scripts over manual command sequences;
* existing shared library functions over script-local utility functions;
* existing reports and TSVs over repeated raw terminal inspection.

If no suitable existing workflow exists, the agent may propose a new one, but must explain why existing assets are insufficient.

## Approval boundaries

Each service document must clearly identify actions requiring explicit approval.

Common approval-required actions include:

* modifying service configuration;
* restarting, stopping, recreating, or removing containers;
* changing network exposure;
* changing reverse proxy behavior;
* changing firewall behavior;
* changing Samba shares or permissions;
* changing backup behavior;
* modifying `/srv/media/`;
* modifying metadata;
* moving, deleting, or renaming files in sensitive paths;
* running apply scripts;
* launching long-running processing jobs;
* committing or pushing Git changes.

When a service-specific policy is stricter than this README, the stricter rule applies.

## Source of truth

Service documents must distinguish between stable knowledge and observed state.

Stable knowledge may include:

* architecture decisions;
* path conventions;
* approved policies;
* service role;
* historical lessons;
* known workflows.

Observed state must be verified from the host when current accuracy matters.

Examples of observed state:

* running containers;
* open ports;
* mounted filesystems;
* current firewall rules;
* current backups;
* current service logs;
* current Compose configuration;
* current script inventory;
* current reports and TSVs.

Agents must not treat old memory as proof of current host state.

## Anti-drift rule

Service documents must adapt to the existing homelab and Toolbox.

Agents must not introduce new service categories, naming schemes, service documents, or operational abstractions merely because they are common in generic infrastructure projects.

Every new service document must explain:

* function;
* service type;
* relationship with existing services;
* relationship with existing policies and docs;
* risk of redundancy;
* read-only inspection method;
* approval boundaries.
