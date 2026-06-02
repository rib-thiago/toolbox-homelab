# Nginx Proxy Manager

## Purpose

Nginx Proxy Manager is the homelab reverse proxy and LAN web gateway.

It provides browser-friendly access to selected services through internal hostnames, mainly `*.lab`, while preserving the private-first access model of the homelab.

Nginx Proxy Manager is not a public exposure layer by default. Its role is to centralize internal web routing, reduce direct LAN port exposure, and provide a controlled entry point for HTTP/HTTPS services.

## Service type

`technical_service`

Nginx Proxy Manager is a technical service because it is a deployed application/container that provides reverse proxy routing and web access management.

It is also part of the networking infrastructure because changes to proxy hosts, exposed ports, upstream services, certificates, and access rules can affect service reachability and security boundaries.

## Current role in the homelab

Nginx Proxy Manager currently acts as the main web gateway for LAN browser access.

Its current role includes:

* providing internal browser access through `*.lab` names;
* routing selected web services to their internal container or host ports;
* reducing the need to expose every service directly on the LAN;
* supporting the separation between browser/LAN access and Tailscale/MagicDNS mobile access;
* acting as a controlled front door for administrative and media services;
* working together with Docker networks, service Compose files, UFW, DOCKER-USER rules, and DNS/host resolution assumptions.

Nginx Proxy Manager must be understood together with Docker, networking, service bind addresses, firewall rules, and the private-first access model.

## Important paths

Likely Compose and configuration paths include:

* `/srv/compose/npm`
* `/srv/compose/nginx-proxy-manager`
* service-specific Compose directories under `/srv/compose/<service>`

Toolbox source and knowledge paths:

* `/srv/toolbox/app`
* `/srv/toolbox/app/knowledge`
* `/srv/toolbox/app/docs`
* `/srv/toolbox/app/scripts/admin/network`
* `/srv/toolbox/app/scripts/admin/docker`
* `/srv/toolbox/app/scripts/admin/firewall`
* `/srv/toolbox/app/scripts/admin/system`

Generated Nginx Proxy Manager and reverse-proxy evidence should be stored under:

* `/srv/toolbox/shared/reports/network`
* `/srv/toolbox/shared/reports/docker`
* `/srv/toolbox/shared/reports/system`
* `/srv/toolbox/shared/library-db/raw/network`
* `/srv/toolbox/shared/library-db/raw/docker`
* `/srv/toolbox/shared/library-db/raw/system`
* `/srv/toolbox/shared/logs/network`
* `/srv/toolbox/shared/inventory/network`

Current paths, Compose project names, and data directories must be verified from the host before making changes.

## Related services

Nginx Proxy Manager is related to:

* networking;
* Docker;
* Samba;
* FileBrowser;
* Navidrome;
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

It is especially related to services that are accessed through browser hostnames instead of direct ports.

Nginx Proxy Manager does not replace Tailscale. Some services may still be accessed through `homelab:<port>` over Tailscale or by other private mechanisms when that is the approved access model.

## Related scripts and workflows

Nginx Proxy Manager related scripts and workflows may be found under:

* `scripts/admin/network`
* `scripts/admin/docker`
* `scripts/admin/firewall`
* `scripts/admin/system`

The Toolbox script inventory should be consulted before proposing new reverse-proxy, networking, firewall, or Docker command sequences.

Agents must not assume that Nginx Proxy Manager knowledge is isolated in one script directory. Reverse proxy behavior is distributed across Docker Compose configuration, network policy, service configuration, DNS/host resolution, firewall policy, and service-specific documentation.

Relevant workflow families include:

* network diagnostics;
* Docker diagnostics;
* Docker network diagnostics;
* published-port inventory;
* listening-port inventory;
* service exposure audits;
* firewall diagnostics;
* DOCKER-USER validation;
* service access matrix generation;
* knowledge/service documentation validation.

Nginx Proxy Manager work should follow the standard workflow:

* diagnose;
* plan;
* apply;
* validate.

## Related reports, TSVs, inventories, and logs

Nginx Proxy Manager related evidence should be stored under `/srv/toolbox/shared`.

Likely destinations include:

* `/srv/toolbox/shared/reports/network`
* `/srv/toolbox/shared/reports/docker`
* `/srv/toolbox/shared/reports/system`
* `/srv/toolbox/shared/library-db/raw/network`
* `/srv/toolbox/shared/library-db/raw/docker`
* `/srv/toolbox/shared/library-db/raw/system`
* `/srv/toolbox/shared/logs/network`
* `/srv/toolbox/shared/inventory/network`

Useful evidence may include:

* proxy host inventory;
* upstream target inventory;
* exposed port inventory;
* service access matrix;
* Docker network inventory;
* Nginx Proxy Manager container status;
* proxy logs when bounded;
* firewall status;
* DOCKER-USER rule status;
* DNS or hostname resolution notes;
* Tailscale versus LAN access notes.

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
* `knowledge/services/networking.md`

Important operational documentation:

* `docs/operations/toolbox_architecture_reconciliation.md`
* `docs/operations/toolbox_output_destinations_policy.md`
* `docs/operations/toolbox_reports_policy.md`
* `docs/operations/toolbox_logging_policy.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_storage_policy.md`
* `docs/operations/toolbox_runtime_profiles.md`

Future or related service documents may include:

* `knowledge/services/samba.md`
* `knowledge/services/backup.md`
* `knowledge/services/filebrowser.md`
* `knowledge/services/navidrome.md`
* `knowledge/services/monitoring.md`

## Sensitive operations

Sensitive Nginx Proxy Manager operations include:

* changing proxy hosts;
* creating new proxy hosts;
* deleting proxy hosts;
* changing upstream hostnames or ports;
* changing SSL/certificate settings;
* changing access lists;
* changing custom Nginx configuration;
* changing WebSocket behavior;
* changing HTTP-to-HTTPS behavior;
* changing service exposure from private to broader access;
* changing Docker network attachments used by proxied services;
* changing Nginx Proxy Manager published ports;
* restarting or recreating the Nginx Proxy Manager container;
* changing service Compose files to support proxying;
* changing firewall rules that affect HTTP/HTTPS or the NPM admin UI.

These operations require an explicit plan and approval.

Extra-sensitive operations include:

* exposing a service publicly;
* weakening private-first assumptions;
* routing administrative services without approval;
* opening access to NPM admin UI beyond the approved network;
* changing certificates or TLS behavior without validation;
* bypassing Tailscale or firewall assumptions;
* changing proxy routing for services used daily.

## Read-only inspection allowed

Read-only Nginx Proxy Manager inspection is allowed when bounded and relevant.

Allowed read-only inspection may include:

* reading Nginx Proxy Manager related service maps;
* reading networking and Docker docs;
* reading networking, Docker, firewall, and system scripts;
* inspecting existing reports and TSVs;
* checking Git status before editing tracked docs or scripts;
* listing known Compose directories under `/srv/compose`;
* inspecting generated inventories;
* reading bounded container logs;
* checking current Docker state with read-only commands when explicitly requested.

Read-only commands may include, when appropriate:

* `docker ps`
* `docker compose ls`
* `docker inspect` for selected targets
* bounded `docker logs --tail`
* `ss -tulpn`
* `ufw status`
* `docker network ls`

Read-only inspection must not be confused with approval to edit proxy hosts, restart services, change routes, open ports, expose services, or modify Compose files.

## Read-only collection plan

A local agent may collect the following in read-only mode:

* Nginx Proxy Manager Compose path and service name;
* NPM container status;
* NPM published ports;
* NPM network attachments;
* related Docker networks;
* service-to-proxy relationships when available from docs, reports, or approved read-only exports;
* references to Nginx Proxy Manager, NPM, proxy hosts, `*.lab`, and reverse proxying across `knowledge/`, `docs/`, and `scripts/`;
* latest Toolbox script inventory report and TSV;
* Nginx Proxy Manager related rows from the script inventory;
* network-related rows from the script inventory;
* Docker-related rows from the script inventory;
* existing network, Docker, firewall, and system reports;
* bounded logs when explicitly useful;
* notes distinguishing LAN browser access, Tailscale access, and direct port access.

A local agent must not in read-only mode:

* create, edit, or delete proxy hosts;
* change certificates;
* change access lists;
* change custom Nginx snippets;
* restart or recreate NPM;
* change Docker networks;
* change published ports;
* edit Compose files;
* change firewall rules;
* expose services publicly;
* modify service configuration;
* commit or push changes.

Non-trivial reverse-proxy collection should generate a report and TSV.

## Actions requiring approval

The following require explicit approval:

* editing Nginx Proxy Manager configuration;
* creating proxy hosts;
* deleting proxy hosts;
* changing upstream target ports or hostnames;
* changing certificates or SSL behavior;
* changing access lists;
* adding custom Nginx configuration;
* changing Docker Compose files related to NPM or proxied services;
* changing Docker network membership for NPM or proxied services;
* changing published ports;
* changing firewall rules related to NPM;
* restarting or recreating NPM;
* exposing a service beyond the approved private-first model;
* committing or pushing NPM-related documentation or script changes.

Approval must be specific to the service, route, hostname, upstream, and expected access behavior.

A general instruction to continue is not approval for unrelated reverse proxy changes.

## Known historical lessons

Nginx Proxy Manager has accumulated operational lessons through the homelab move toward private-first access, LAN `*.lab` routing, Docker networking, UFW, DOCKER-USER, Tailscale, and service exposure reduction.

Service-specific lessons should be summarized here only when they directly affect Nginx Proxy Manager operation.

Detailed historical lessons should be consolidated under:

* `knowledge/architecture/historical-operational-lessons.md`

Until that document exists, agents must treat reverse-proxy lessons mentioned in context, policies, service maps, reports, and validated scripts as operationally relevant.

## Open questions

Nginx Proxy Manager has open architectural and operational questions that should be resolved incrementally.

This service map should list only open questions that directly affect Nginx Proxy Manager as the reverse proxy layer.

Broader open questions should be consolidated under a future architecture document, such as:

* `knowledge/architecture/open-questions.md`

Current known areas for future clarification include service access inventory, internal DNS strategy, certificate strategy, NPM backup coverage, access list policy, admin UI exposure, and future Codex/local-agent read-only inspection boundaries.

## Source of truth

Stable source and knowledge:

* `/srv/toolbox/app`

Compose and service configuration:

* `/srv/compose`

Generated operational evidence:

* `/srv/toolbox/shared`

Current host state must be verified from the host when accuracy matters.

Examples of current Nginx Proxy Manager state that must be verified include:

* running container;
* Compose project path;
* NPM published ports;
* NPM admin UI access path;
* proxy hosts;
* upstream targets;
* SSL/certificate configuration;
* access lists;
* custom Nginx configuration;
* Docker network membership;
* firewall interaction;
* DNS/hostname resolution behavior;
* relation between LAN access and Tailscale access.

Agents must not treat memory, old reports, or chat history as proof of current Nginx Proxy Manager state.
