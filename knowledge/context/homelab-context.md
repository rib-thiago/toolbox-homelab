# Homelab Context

This file provides the minimum stable context an AI agent needs before working on the homelab.

It is not a full inventory. Current observed state must be collected through read-only diagnostics and stored under `/srv/toolbox/shared/`.

## Purpose

This homelab is a private, Docker-first personal infrastructure environment.

It supports media services, document and library services, backup routines, monitoring, operational automation, and experimentation with agent-assisted workflows.

The environment is designed to remain private-first and VPN-first. Public exposure is not part of the default operating model.

## Primary host

The main homelab host is an Ubuntu Linux notebook used as the central server.

Most operational data, service configuration, media libraries, and Toolbox assets are organized under `/srv`.

Important roots:

* `/srv/compose/`
* `/srv/media/`
* `/srv/toolbox/`

## Operating philosophy

The homelab should be operated conservatively.

Default assumptions:

* Docker-first for services.
* Private-first and VPN-first for access.
* No public exposure unless explicitly planned and approved.
* Prefer reversible changes.
* Prefer Git-tracked configuration where practical.
* Prefer diagnostics before changes.
* Prefer reports, TSVs, snapshots, logs, and validation artifacts for operational traceability.

The standard workflow is:

1. Diagnose
2. Plan
3. Apply
4. Validate

## Toolbox philosophy

The Toolbox is not only a collection of scripts. It is the operational automation and documentation system for this homelab.

It follows a Unix-like philosophy:

* small tools with clear responsibilities;
* composable scripts;
* explicit pipelines;
* structured jobs;
* reports and TSVs as operational artifacts;
* manpage-style documentation;
* Git-tracked operational knowledge.

Important Toolbox concepts include:

* public commands under `bin/`;
* helper implementations under `scripts/helpers/`;
* reusable shell library code under `scripts/lib/`;
* pipelines under `scripts/pipelines/`;
* structured pipeline execution through `run-job`;
* job directories under Toolbox job areas;
* manpages under `docs/man1/` and `docs/man7/`;
* host/container hybrid operation.

`run-job`, pipelines, manpages, and Unix-style composability are central to the Toolbox model and must not be ignored when planning agent workflows.

## Core service domains

The homelab includes these major domains:

* reverse proxy and internal web access;
* Docker service hosting;
* VPN/tailnet access;
* media streaming;
* music library curation;
* photo management;
* ebook and PDF access;
* web-based file access;
* Samba shares;
* backup and restore;
* monitoring, metrics, dashboards, and diagnostics;
* Toolbox automation;
* agent-assisted operation.

## Key services

Known important services include:

* Nginx Proxy Manager for internal reverse proxy access.
* Homepage as the central dashboard.
* Portainer for Docker management.
* FileBrowser for web-based file access and daily operational workflows.
* Navidrome for music streaming.
* Jellyfin for video/media streaming.
* Immich for photo management.
* Kavita for reading/PDF access.
* Calibre-Web for ebook access.
* slskd for Soulseek downloads.
* Samba for LAN file shares.
* Restic and Backrest for backup routines.
* Tailscale for VPN/tailnet access.
* Prometheus for metrics collection.
* Grafana for metrics visualization.
* cAdvisor for container metrics.

Current service state, ports, container names, compose paths, and health must be verified from the host before acting.

Do not assume a monitoring tool is installed or active only because it appears in older planning notes. Current monitoring tools must be verified from the host.

## Network model

The network model is private-first.

Known access layers include:

* local LAN access;
* Tailscale/MagicDNS access;
* Nginx Proxy Manager for internal `*.lab` style access;
* UFW and Docker-related firewall controls.

Firewall, reverse proxy, Tailscale, Samba, and Docker networking changes are sensitive and require explicit human approval.

## Operational access model

The homelab is commonly operated through:

* SSH;
* Toolbox scripts;
* Git workflows;
* browser-based dashboards;
* FileBrowser;
* Samba shares;
* generated reports and TSVs;
* ChatGPT and agent-assisted review.

FileBrowser is part of the practical daily workflow and may be used to inspect, download, or bridge artifacts between the homelab and external tools.

Any change to FileBrowser exposure, bind address, reverse proxy integration, permissions, or Tailscale access requires explicit planning and approval.

## Monitoring and diagnostics

Monitoring and diagnostics are part of the operational model.

Known monitoring components include:

* Prometheus;
* Grafana;
* cAdvisor;
* Homepage dashboard visibility;
* host-level terminal tools such as `htop`;
* Docker and system diagnostic commands;
* Toolbox-generated diagnostic reports.

Specific currently installed terminal monitoring tools must be verified from the host before being documented as active components.

Agents should prefer read-only diagnostics first and should store generated diagnostic artifacts under `/srv/toolbox/shared/`.

## Storage and media

Media collections are stored under `/srv/media/`.

Important media areas include:

* music library;
* music staging;
* photos;
* raw photos;
* videos;
* ebook libraries;
* PDFs.

Anything under `/srv/media/` must be treated as high-sensitivity user data.

Agents must not delete, move, rename, retag, rewrite metadata, transcode in place, or bulk-transform media files without an explicit approved plan.

## Media preservation and cold archive

The homelab may use cold-archive workflows for preservation of heavy auxiliary material, artwork, intermediate assets, or non-hot-library artifacts.

Cold archives are used to preserve material while keeping hot libraries clean and operationally efficient.

Cold-archive operations must be planned, validated, and traceable.

Agents must not purge hot-library material based on the existence of a cold archive unless validation has been explicitly performed and approved.

## Music library policy

The music library favors archival master files and controlled metadata workflows.

Known principles:

* preserve archival FLAC masters where possible;
* avoid duplicate compatibility libraries unless deliberately planned;
* use on-demand transcoding for playback compatibility when appropriate;
* treat metadata writes as sensitive operations;
* use staged review workflows before import;
* validate before moving material into the main library;
* preserve important auxiliary material through controlled archive workflows when appropriate.

The music-staging workflow is a curated process and should not be bypassed.

## Backup model

Backups are handled through Restic-based routines, with Backrest available as a UI/management layer.

Backup configuration, retention, restore procedures, backup media, and backup schedules are sensitive.

Agents must not change backup behavior, retention policies, repositories, credentials, timers, or restore paths without explicit approval.

## Security model

The homelab should be operated with a conservative security posture.

Sensitive areas include:

* firewall rules;
* UFW;
* DOCKER-USER rules;
* Nginx Proxy Manager configuration;
* Tailscale configuration;
* Samba shares and permissions;
* FileBrowser exposure and permissions;
* backup secrets;
* Docker Compose files;
* exposed ports;
* anything under `/srv/media/`.

Changes in these areas require a plan, risk explanation, and human approval.

## Toolbox relationship

The agent must treat `/srv/toolbox/app` as the stable, versioned source for Toolbox code, documentation, policies, runbooks, and operational knowledge.

The agent must treat `/srv/toolbox/shared` as the destination for generated reports, TSVs, snapshots, inventories, logs, and ChatGPT briefs.

The Toolbox is expected to mediate repeatable operational work through scripts, runbooks, reports, and versioned knowledge rather than ad hoc terminal commands whenever practical.

## Agent behavior

Before working on a homelab task, an agent must:

1. Read `knowledge/context/agent-entrypoint.md`.
2. Read this file.
3. Read `knowledge/context/toolbox-context.md`, when available.
4. Identify affected services, paths, and risks.
5. Consult relevant policies, services, graph, architecture records, and runbooks.
6. Prefer read-only diagnostics first.
7. Produce a plan before changes.
8. Request human approval before applying changes.
9. Store generated artifacts under `/srv/toolbox/shared/`.

## What must be verified

The following must be verified from the host before operational decisions:

* current running containers;
* current Docker Compose files;
* current exposed ports;
* current firewall rules;
* current Tailscale state;
* current Samba shares;
* current FileBrowser exposure and permissions;
* current backup timers and repositories;
* current disk and mount state;
* current service health;
* current monitoring stack state;
* current Toolbox job/pipeline state when relevant;
* current Git status of `/srv/toolbox/app`.

Do not assume current state from memory alone.

## Human decision required

Human approval is required before:

* modifying service configuration;
* changing network exposure;
* changing firewall behavior;
* changing backup behavior;
* changing FileBrowser access or permissions;
* writing media metadata;
* moving or deleting user data;
* running apply scripts;
* committing or pushing changes;
* installing, removing, or upgrading packages;
* changing Toolbox structure, job conventions, pipeline conventions, or knowledge-base conventions.
