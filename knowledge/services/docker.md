# Docker

## Purpose

Docker is the main service runtime layer of the homelab.

It provides containerized execution for most self-hosted services, including media services, administrative services, dashboards, reverse proxying, file access, photo management, ebook access, monitoring, and future Toolbox runtime profiles.

Docker is central to the homelab’s architecture, but it is not the only operational layer. Some workflows intentionally remain host-mode when they need direct filesystem awareness, system diagnostics, Git operations, backup operations, shell ergonomics, or careful media curation.

## Service type

`technical_service`

Docker is a technical service because it provides the runtime for containers and compose-managed services.

It also acts as an infrastructure dependency for several operational subsystems.

## Current role in the homelab

Docker supports the homelab’s Docker-first architecture.

Its current role includes:

* running most self-hosted services;
* isolating service runtime environments;
* providing bind mounts into `/srv`;
* supporting Docker Compose service definitions under `/srv/compose`;
* supporting private-first service exposure through LAN, Nginx Proxy Manager, Tailscale, and firewall policy;
* supporting service networks such as shared proxy networks and service-specific networks;
* enabling controlled service deployment and reconfiguration;
* supporting future Toolbox runtime profiles.

Docker is important, but not every task belongs inside Docker.

Host-mode remains appropriate for:

* storage diagnostics;
* Git routines;
* backup checks;
* filesystem-sensitive operations;
* Samba permission diagnosis;
* media curation;
* scripts that need direct host context.

Container-mode remains appropriate for:

* long-running encapsulated processing;
* reproducible document/media pipelines;
* service runtime isolation;
* future Toolbox profiles such as `toolbox-base`, `toolbox-docs`, `toolbox-media`, and `toolbox-nlp`.

## Important paths

Primary compose directory:

* `/srv/compose`

Toolbox source tree:

* `/srv/toolbox/app`

Toolbox generated evidence:

* `/srv/toolbox/shared`

Toolbox job directories:

* `/srv/toolbox/jobs`
* `/toolbox/jobs`

Important media bind-mount roots:

* `/srv/media`
* `/srv/media/music`
* `/srv/media/music-staging`
* `/srv/media/photos`
* `/srv/media/photos-raw`
* `/srv/media/videos`
* `/srv/media/calibre-library`
* `/srv/media/pdfs-raw`

Common service data and configuration paths may exist under:

* `/srv/compose/<service>`
* `/srv/data/<service>`
* service-specific bind mount paths declared in Compose files.

Current paths must be verified from the host before making changes.

## Related services

Docker is related to:

* Toolbox;
* networking;
* Nginx Proxy Manager;
* Samba;
* backup;
* FileBrowser;
* Navidrome;
* music staging;
* Jellyfin;
* Immich;
* Calibre-Web;
* Kavita;
* slskd;
* Portainer;
* Homepage;
* monitoring;
* future Codex/local-agent workflows.

Docker is also related to firewall and network exposure because Docker networking can bypass simple host assumptions if not understood correctly.

## Related scripts and workflows

Docker-related scripts and workflows may be found under:

* `scripts/admin/docker`
* `scripts/admin/network`
* `scripts/admin/firewall`
* `scripts/admin/system`
* `scripts/admin/storage`
* `scripts/admin/backup`

Agents must inspect existing scripts, reports, TSVs, and docs before proposing new Docker commands or Compose changes.

Relevant workflow families include:

* Docker diagnostics;
* Docker network diagnostics;
* service exposure audits;
* DOCKER-USER hardening diagnostics or validation;
* service inventory;
* storage pressure diagnostics;
* backup diagnostics where bind mounts or service data are relevant;
* knowledge/service documentation validation.

Docker work should follow the standard workflow:

* diagnose;
* plan;
* apply;
* validate.

## Related reports, TSVs, inventories, and logs

Docker-related evidence should be stored under `/srv/toolbox/shared`.

Likely destinations include:

* `/srv/toolbox/shared/reports/docker`
* `/srv/toolbox/shared/reports/network`
* `/srv/toolbox/shared/reports/firewall`
* `/srv/toolbox/shared/reports/system`
* `/srv/toolbox/shared/reports/storage`
* `/srv/toolbox/shared/library-db/raw/docker`
* `/srv/toolbox/shared/library-db/raw/network`
* `/srv/toolbox/shared/library-db/raw/firewall`
* `/srv/toolbox/shared/library-db/raw/system`
* `/srv/toolbox/shared/library-db/raw/storage`
* `/srv/toolbox/shared/logs/docker`
* `/srv/toolbox/shared/inventory/docker`

Docker logs from the Docker engine or containers are operational evidence, but raw logs do not replace reports or TSVs.

For destination rules, consult:

* `docs/operations/toolbox_output_destinations_policy.md`
* `knowledge/policies/reporting-policy.md`

## Related policies and docs

Required context:

* `knowledge/context/agent-entrypoint.md`
* `knowledge/context/homelab-context.md`
* `knowledge/context/toolbox-context.md`

Required policies:

* `knowledge/policies/agent-safety-policy.md`
* `knowledge/policies/change-management-policy.md`
* `knowledge/policies/reporting-policy.md`
* `knowledge/policies/filesystem-safety-policy.md`
* `knowledge/policies/media-curation-policy.md`

Relevant service maps:

* `knowledge/services/README.md`
* `knowledge/services/toolbox.md`

Important operational documentation:

* `docs/operations/toolbox_architecture_reconciliation.md`
* `docs/operations/toolbox_runtime_profiles.md`
* `docs/operations/toolbox_storage_policy.md`
* `docs/operations/toolbox_output_destinations_policy.md`
* `docs/operations/toolbox_reports_policy.md`
* `docs/operations/toolbox_logging_policy.md`
* `docs/operations/toolbox_script_conventions.md`

Future or related service documents may include:

* `knowledge/services/networking.md`
* `knowledge/services/nginx-proxy-manager.md`
* `knowledge/services/samba.md`
* `knowledge/services/backup.md`
* `knowledge/services/filebrowser.md`
* `knowledge/services/navidrome.md`

## Sensitive operations

Sensitive Docker operations include:

* editing Compose files;
* creating, removing, or renaming containers;
* recreating services;
* changing bind mounts;
* changing volume mounts;
* changing network attachments;
* changing exposed ports;
* changing restart policies;
* changing environment variables;
* changing container users or permissions;
* changing privileged mode, capabilities, or host network mode;
* running containers with broad host access;
* changing Docker firewall behavior;
* modifying DOCKER-USER rules;
* deleting volumes;
* pruning images, containers, networks, or volumes;
* changing service data directories;
* changing services used by media libraries, backup, Samba, or reverse proxying.

These operations require an explicit plan and approval.

Destructive Docker operations require extra care, especially:

* `docker system prune`;
* `docker volume prune`;
* `docker compose down -v`;
* removing named volumes;
* removing bind-mounted data;
* recreating services with changed mounts or users;
* changing network exposure.

## Read-only inspection allowed

Read-only Docker inspection is allowed when bounded and relevant.

Allowed read-only inspection may include:

* reading Compose files;
* listing Docker-related scripts;
* reading Docker-related docs;
* inspecting existing Docker reports and TSVs;
* checking Git status before editing tracked docs or scripts;
* listing known service directories under `/srv/compose`;
* inspecting generated inventories;
* reading container logs when bounded;
* checking current Docker state with read-only commands when explicitly requested.

Read-only commands may include, when appropriate:

* `docker ps`
* `docker compose ls`
* `docker network ls`
* `docker volume ls`
* `docker system df`
* `docker inspect` for selected targets
* `docker logs --tail`

Read-only inspection must not be confused with approval to restart, recreate, prune, remove, or reconfigure services.

## Read-only collection plan

A local agent may collect the following in read-only mode:

* list of Compose project directories under `/srv/compose`;
* Compose file paths and service names;
* service-to-network relationships;
* service-to-bind-mount relationships;
* exposed ports;
* restart policies;
* container names;
* image names and tags;
* container health status when available;
* references to Docker across `knowledge/`, `docs/`, and `scripts/`;
* existing Docker reports, TSVs, inventories, and logs;
* references to Docker networks such as proxy networks or service-specific networks;
* references to sensitive bind mounts under `/srv/media`, `/srv/toolbox`, and `/srv/compose`.

A local agent must not in read-only mode:

* edit Compose files;
* run `docker compose up`, `down`, `restart`, or `pull`;
* run prune commands;
* remove containers, images, networks, or volumes;
* change exposed ports;
* change Docker networks;
* change firewall rules;
* change bind mounts;
* change service permissions;
* modify service data.

Non-trivial Docker collection should generate a report and TSV.

## Actions requiring approval

The following require explicit approval:

* editing Docker Compose files;
* running `docker compose up`;
* running `docker compose down`;
* restarting containers;
* recreating containers;
* pulling or changing images;
* adding or removing networks;
* changing published ports;
* changing bind mounts;
* changing volumes;
* changing environment variables;
* changing container user IDs;
* changing service privileges or capabilities;
* changing host network mode;
* changing DOCKER-USER rules;
* pruning Docker resources;
* deleting Docker volumes;
* changing services that affect media, backup, reverse proxying, Samba, or FileBrowser.

Approval must be specific to the operation, service, and expected effect.

A general instruction to continue is not approval for unrelated Docker changes.

## Known historical lessons

Docker is central to the homelab, but Docker behavior must be interpreted together with host networking, firewall rules, bind mounts, permissions, backup paths, and service dependencies.

Important lessons should be summarized here only when they directly affect Docker operation.

Detailed historical lessons should be consolidated under:

* `knowledge/architecture/historical-operational-lessons.md`

Until that document exists, agents must treat Docker lessons mentioned in context, policies, service maps, reports, and validated scripts as operationally relevant.

## Open questions

Docker has open architectural and operational questions that should be resolved incrementally.

This service map should list only open questions that directly affect Docker as a service layer.

Broader open questions should be consolidated under a future architecture document, such as:

* `knowledge/architecture/open-questions.md`

Current known areas for future clarification include Docker service inventory, runtime profiles, Compose normalization, service hardening, image update policy, backup coverage for service data, and how Docker should interact with future Codex/local-agent workflows.

## Source of truth

Stable source and knowledge:

* `/srv/toolbox/app`

Compose and service configuration:

* `/srv/compose`

Generated operational evidence:

* `/srv/toolbox/shared`

Current host state must be verified from the host when accuracy matters.

Examples of current Docker state that must be verified include:

* running containers;
* stopped containers;
* Compose project list;
* image versions;
* exposed ports;
* network membership;
* bind mounts;
* named volumes;
* container users;
* health status;
* logs;
* service data paths;
* firewall interaction.

Agents must not treat memory, old reports, or chat history as proof of current Docker state.
