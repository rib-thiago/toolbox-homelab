# Networking

## Purpose

Networking is the homelab infrastructure layer that controls how services communicate internally, how users access services, and how exposure is limited.

It includes LAN access, Tailscale access, DNS/MagicDNS behavior, reverse proxy routing, firewall policy, Docker networking, Samba exposure, and private-first service access.

Networking is not a single service. It is a cross-cutting layer that affects Docker, Nginx Proxy Manager, Samba, FileBrowser, media services, backup workflows, monitoring, and future Codex/local-agent usage.

## Service type

`infrastructure_layer`

Networking is an infrastructure layer because it affects multiple services and defines access boundaries, trust zones, routing paths, and exposure rules.

## Current role in the homelab

Networking currently supports a private-first homelab model.

Its role includes:

* keeping services private by default;
* exposing browser services through Nginx Proxy Manager and `*.lab` names on the LAN;
* supporting mobile or remote access through Tailscale and MagicDNS;
* supporting Samba access from Windows clients;
* allowing controlled Docker service communication through Docker networks;
* reducing direct LAN port exposure where possible;
* preserving UFW and DOCKER-USER hardening assumptions;
* separating administrative access, media access, and file-sharing access;
* supporting future read-only agent inspection without granting network mutation rights.

Networking must be understood together with Docker, Nginx Proxy Manager, Samba, FileBrowser, backup, media services, and the Toolbox.

## Important paths

Networking-related source and documentation may be found under:

* `/srv/toolbox/app`
* `/srv/toolbox/app/knowledge`
* `/srv/toolbox/app/docs`
* `/srv/toolbox/app/scripts/admin/network`
* `/srv/toolbox/app/scripts/admin/firewall`
* `/srv/toolbox/app/scripts/admin/docker`
* `/srv/toolbox/app/scripts/admin/system`

Service configuration and infrastructure paths may include:

* `/srv/compose`
* `/srv/compose/npm`
* `/srv/compose/samba`
* service-specific Compose directories under `/srv/compose/<service>`

Generated networking evidence should be stored under:

* `/srv/toolbox/shared/reports/network`
* `/srv/toolbox/shared/reports/firewall`
* `/srv/toolbox/shared/reports/docker`
* `/srv/toolbox/shared/reports/system`
* `/srv/toolbox/shared/library-db/raw/network`
* `/srv/toolbox/shared/library-db/raw/firewall`
* `/srv/toolbox/shared/library-db/raw/docker`
* `/srv/toolbox/shared/library-db/raw/system`
* `/srv/toolbox/shared/logs/network`
* `/srv/toolbox/shared/inventory/network`

Current host paths must be verified from the host when accuracy matters.

## Related services

Networking is related to:

* Docker;
* Nginx Proxy Manager;
* Samba;
* FileBrowser;
* backup;
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
* Toolbox;
* future Codex/local-agent workflows.

Networking is also related to host firewall behavior, Docker firewall behavior, DNS behavior, Tailscale behavior, and LAN client behavior.

## Related scripts and workflows

Networking-related scripts and workflows may be found under:

* `scripts/admin/network`
* `scripts/admin/firewall`
* `scripts/admin/docker`
* `scripts/admin/system`
* `scripts/admin/storage`
* `scripts/admin/backup`

The Toolbox script inventory should be consulted before proposing new networking scripts or command sequences.

The current script inventory shows dedicated network scripts under `scripts/admin/network`, firewall scripts under `scripts/admin/firewall`, Docker-related diagnostics under `scripts/admin/docker`, and additional network-relevant scripts under system, storage, and backup domains.

Agents must not assume that networking knowledge is isolated under `scripts/admin/network`.

Relevant workflow families include:

* network diagnostics;
* Avahi and mDNS diagnostics;
* firewall diagnostics;
* UFW configuration and validation;
* DOCKER-USER hardening and validation;
* Docker network diagnostics;
* Docker exposure audits;
* service inventory;
* Samba exposure checks;
* storage and media path checks when network services depend on mounts or permissions;
* knowledge/service documentation validation.

Networking work should follow the standard workflow:

* diagnose;
* plan;
* apply;
* validate.

## Related reports, TSVs, inventories, and logs

Networking-related evidence should be stored under `/srv/toolbox/shared`.

Likely destinations include:

* `/srv/toolbox/shared/reports/network`
* `/srv/toolbox/shared/reports/firewall`
* `/srv/toolbox/shared/reports/docker`
* `/srv/toolbox/shared/reports/system`
* `/srv/toolbox/shared/library-db/raw/network`
* `/srv/toolbox/shared/library-db/raw/firewall`
* `/srv/toolbox/shared/library-db/raw/docker`
* `/srv/toolbox/shared/library-db/raw/system`
* `/srv/toolbox/shared/logs/network`
* `/srv/toolbox/shared/inventory/network`

Useful evidence may include:

* interface inventory;
* IP address inventory;
* listening-port inventory;
* Docker network inventory;
* published-port inventory;
* firewall rule inventory;
* UFW status;
* DOCKER-USER rule status;
* Tailscale status;
* DNS/MagicDNS notes;
* Nginx Proxy Manager routing notes;
* Samba exposure notes;
* service access matrix.

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
* `knowledge/services/docker.md`

Important operational documentation:

* `docs/operations/toolbox_architecture_reconciliation.md`
* `docs/operations/toolbox_output_destinations_policy.md`
* `docs/operations/toolbox_reports_policy.md`
* `docs/operations/toolbox_logging_policy.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_storage_policy.md`
* `docs/operations/toolbox_runtime_profiles.md`

Future or related service documents may include:

* `knowledge/services/nginx-proxy-manager.md`
* `knowledge/services/samba.md`
* `knowledge/services/backup.md`
* `knowledge/services/filebrowser.md`
* `knowledge/services/navidrome.md`

## Sensitive operations

Sensitive networking operations include:

* changing UFW rules;
* changing DOCKER-USER rules;
* changing Docker networks;
* changing published ports;
* changing Nginx Proxy Manager proxy hosts;
* changing DNS or host resolution behavior;
* changing Tailscale configuration;
* enabling public exposure;
* changing Samba exposure;
* changing service bind addresses;
* changing container network attachments;
* changing reverse proxy routing;
* changing host firewall defaults;
* changing IPv6 behavior;
* restarting network-critical containers;
* disabling or enabling services that affect access.

These operations require an explicit plan and approval.

Extra-sensitive operations include:

* opening ports to broader networks;
* exposing services publicly;
* weakening firewall policy;
* bypassing Nginx Proxy Manager access assumptions;
* bypassing Tailscale/private-first access assumptions;
* changing Docker firewall behavior without validation;
* changing Samba availability from Windows clients;
* changing routing for media services used by clients.

## Read-only inspection allowed

Read-only networking inspection is allowed when bounded and relevant.

Allowed read-only inspection may include:

* reading networking-related service maps;
* reading networking-related docs;
* reading networking, firewall, Docker, and system scripts;
* inspecting existing reports and TSVs;
* checking Git status before editing tracked docs or scripts;
* listing known service directories under `/srv/compose`;
* inspecting generated inventories;
* reading bounded logs;
* checking current network state with read-only commands when explicitly requested.

Read-only commands may include, when appropriate:

* `ip addr`
* `ip route`
* `ss -tulpn`
* `ufw status`
* `docker network ls`
* `docker ps`
* `docker compose ls`
* `docker inspect` for selected targets
* `tailscale status`
* bounded `docker logs --tail`

Read-only inspection must not be confused with approval to restart, reconfigure, expose, block, open, close, or reroute services.

## Read-only collection plan

A local agent may collect the following in read-only mode:

* current interface and IP summary;
* current route summary;
* current listening ports;
* current UFW status;
* current DOCKER-USER rule status;
* current Docker networks;
* current Docker published ports;
* current Compose project list;
* service-to-network relationships;
* service-to-published-port relationships;
* references to networking across `knowledge/`, `docs/`, and `scripts/`;
* latest Toolbox script inventory report and TSV;
* network-related rows from the script inventory;
* firewall-related rows from the script inventory;
* Docker-network-related rows from the script inventory;
* existing network, firewall, Docker, and system reports;
* Nginx Proxy Manager service references;
* Samba service references;
* Tailscale and MagicDNS notes.

A local agent must not in read-only mode:

* change firewall rules;
* change Docker networks;
* restart containers;
* change published ports;
* change Nginx Proxy Manager hosts;
* change DNS or hosts files;
* change Tailscale configuration;
* open services to the public internet;
* modify Compose files;
* modify service configuration;
* change Samba shares;
* change network-related scripts;
* commit or push changes.

Non-trivial networking collection should generate a report and TSV.

## Actions requiring approval

The following require explicit approval:

* editing networking-related scripts;
* editing firewall scripts;
* editing Docker Compose files;
* changing UFW rules;
* changing DOCKER-USER rules;
* changing Docker networks;
* changing published ports;
* changing Nginx Proxy Manager hosts;
* changing Tailscale configuration;
* changing DNS or host resolution;
* changing Samba exposure;
* restarting network-critical containers;
* exposing a service outside the private-first model;
* disabling a security boundary;
* committing or pushing networking-related documentation or script changes.

Approval must be specific to the operation, service, and expected effect.

A general instruction to continue is not approval for unrelated networking changes.

## Known historical lessons

Networking has accumulated important operational lessons through Docker networking, Nginx Proxy Manager, Tailscale, UFW, DOCKER-USER, Samba, and service exposure work.

Service-specific lessons should be summarized here only when they directly affect networking operation.

Detailed historical lessons should be consolidated under:

* `knowledge/architecture/historical-operational-lessons.md`

Until that document exists, agents must treat networking lessons mentioned in context, policies, service maps, reports, and validated scripts as operationally relevant.

## Open questions

Networking has open architectural and operational questions that should be resolved incrementally.

This service map should list only open questions that directly affect networking as an infrastructure layer.

Broader open questions should be consolidated under a future architecture document, such as:

* `knowledge/architecture/open-questions.md`

Current known areas for future clarification include service access inventory, internal DNS strategy, Tailscale access patterns, DOCKER-USER review, IPv6 review, FileBrowser access model, monitoring exposure, and future Codex/local-agent network inspection boundaries.

## Source of truth

Stable source and knowledge:

* `/srv/toolbox/app`

Compose and service configuration:

* `/srv/compose`

Generated operational evidence:

* `/srv/toolbox/shared`

Current host state must be verified from the host when accuracy matters.

Examples of current networking state that must be verified include:

* IP addresses;
* routes;
* interfaces;
* listening ports;
* UFW rules;
* DOCKER-USER rules;
* Docker networks;
* Docker published ports;
* Nginx Proxy Manager hosts;
* Tailscale status;
* DNS/MagicDNS behavior;
* Samba exposure;
* service bind addresses;
* firewall interaction;
* remote access behavior.

Agents must not treat memory, old reports, or chat history as proof of current networking state.
