# Samba

## Purpose

Samba provides SMB file-sharing access between the homelab and client machines, especially Windows clients.

It is a central file-access service for media libraries, staging areas, PDFs, photos, ebooks, videos, and operational workflows that benefit from comfortable desktop access.

Samba is not merely a convenience layer. It directly affects media curation, Windows workflows, permissions, ownership, file moves, staging review, backups, FileBrowser usage, and service interoperability.

## Service type

`technical_service`

Samba is a technical service because it is a deployed file-sharing service/container that exposes selected host directories through SMB.

It is also closely related to filesystem safety, media curation, backup, Docker, networking, and Windows client workflows.

## Current role in the homelab

Samba currently provides private LAN access to selected `/srv/media` paths and related collections.

Its role includes:

* exposing curated and staging media directories to Windows clients;
* supporting music download, review, tagging, movement, and curation workflows;
* supporting access to photos, videos, ebooks, PDFs, and other media directories;
* enabling comfortable desktop access to homelab files without making those paths public;
* working alongside FileBrowser as a complementary file access layer;
* preserving a stable ownership and permission model for files accessed by containers and host scripts;
* supporting Windows drive mappings used in daily workflows.

Samba must be understood together with Docker bind mounts, host UID/GID ownership, `/srv/media` permissions, FileBrowser access, backup scope, media services, and networking policy.

## Important paths

Likely Samba Compose and configuration paths include:

* `/srv/compose/samba`
* service-specific Samba configuration under the Samba Compose directory, if present;
* host paths exported by Samba.

Important exported or related media paths may include:

* `/srv/media/music`
* `/srv/media/music-staging`
* `/srv/media/photos`
* `/srv/media/photos-raw`
* `/srv/media/videos`
* `/srv/media/calibre-library`
* `/srv/media/pdfs-raw`
* `/srv/media/pdfs`

Toolbox source and knowledge paths:

* `/srv/toolbox/app`
* `/srv/toolbox/app/knowledge`
* `/srv/toolbox/app/docs`
* `/srv/toolbox/app/scripts/admin/network`
* `/srv/toolbox/app/scripts/admin/storage`
* `/srv/toolbox/app/scripts/admin/docker`
* `/srv/toolbox/app/scripts/admin/system`
* `/srv/toolbox/app/scripts/media`

Generated Samba and filesystem evidence should be stored under:

* `/srv/toolbox/shared/reports/storage`
* `/srv/toolbox/shared/reports/network`
* `/srv/toolbox/shared/reports/docker`
* `/srv/toolbox/shared/reports/system`
* `/srv/toolbox/shared/reports/media`
* `/srv/toolbox/shared/library-db/raw/storage`
* `/srv/toolbox/shared/library-db/raw/network`
* `/srv/toolbox/shared/library-db/raw/docker`
* `/srv/toolbox/shared/library-db/raw/system`
* `/srv/toolbox/shared/library-db/raw/media`
* `/srv/toolbox/shared/logs/storage`
* `/srv/toolbox/shared/inventory/storage`

Current exported paths, share names, Windows mappings, Compose paths, ownership, masks, and permissions must be verified from the host before making changes.

## Related services

Samba is related to:

* networking;
* Docker;
* FileBrowser;
* backup;
* music staging;
* Navidrome;
* Jellyfin;
* Immich;
* Calibre-Web;
* Kavita;
* slskd;
* Toolbox;
* Windows clients;
* future Codex/local-agent workflows.

Samba is especially related to services and workflows that read or write shared media paths.

Samba does not replace FileBrowser. Samba is primarily desktop/SMB file access; FileBrowser is browser-based file access and is central to ChatGPT-assisted artifact workflows.

## Related scripts and workflows

Samba-related scripts and workflows may be found under:

* `scripts/admin/storage`
* `scripts/admin/network`
* `scripts/admin/docker`
* `scripts/admin/system`
* `scripts/admin/backup`
* `scripts/media/library`
* `scripts/media/stockhausen`

The Toolbox script inventory should be consulted before proposing new Samba, storage, permission, ownership, filesystem, or media command sequences.

Agents must not assume that Samba knowledge is isolated in one script directory. Samba behavior is distributed across Docker Compose configuration, networking, firewall rules, storage diagnostics, filesystem permissions, media workflows, backup assumptions, and Windows client mappings.

Relevant workflow families include:

* storage diagnostics;
* permissions and ownership audits;
* Samba recycle or cleanup audits;
* media staging diagnostics;
* music library diagnostics;
* backup diagnostics where Samba-exported paths are relevant;
* Docker bind-mount diagnostics;
* network and firewall diagnostics;
* service access validation;
* knowledge/service documentation validation.

Samba work should follow the standard workflow:

* diagnose;
* plan;
* apply;
* validate.

## Related reports, TSVs, inventories, and logs

Samba-related evidence should be stored under `/srv/toolbox/shared`.

Likely destinations include:

* `/srv/toolbox/shared/reports/storage`
* `/srv/toolbox/shared/reports/network`
* `/srv/toolbox/shared/reports/docker`
* `/srv/toolbox/shared/reports/system`
* `/srv/toolbox/shared/reports/media`
* `/srv/toolbox/shared/library-db/raw/storage`
* `/srv/toolbox/shared/library-db/raw/network`
* `/srv/toolbox/shared/library-db/raw/docker`
* `/srv/toolbox/shared/library-db/raw/system`
* `/srv/toolbox/shared/library-db/raw/media`
* `/srv/toolbox/shared/logs/storage`
* `/srv/toolbox/shared/inventory/storage`

Useful evidence may include:

* share inventory;
* exported path inventory;
* ownership and permission inventory;
* UID/GID mapping notes;
* mount and filesystem notes;
* Windows drive mapping notes;
* container bind-mount relationship notes;
* Samba log excerpts when bounded;
* recycle-bin or deleted-file diagnostics;
* media path access checks;
* backup coverage notes.

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
* `knowledge/services/nginx-proxy-manager.md`

Important operational documentation:

* `docs/operations/toolbox_architecture_reconciliation.md`
* `docs/operations/toolbox_output_destinations_policy.md`
* `docs/operations/toolbox_reports_policy.md`
* `docs/operations/toolbox_logging_policy.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_storage_policy.md`
* `docs/operations/toolbox_runtime_profiles.md`

Future or related service documents may include:

* `knowledge/services/backup.md`
* `knowledge/services/filebrowser.md`
* `knowledge/services/music-staging.md`
* `knowledge/services/navidrome.md`

## Sensitive operations

Sensitive Samba operations include:

* changing Samba shares;
* creating or deleting shares;
* changing exported host paths;
* changing Samba user, force user, or force group behavior;
* changing UID/GID assumptions;
* changing create masks or directory masks;
* changing oplocks or locking behavior;
* changing recycle-bin behavior;
* changing read/write settings;
* changing Samba published ports;
* changing firewall rules for SMB ports;
* changing Docker Compose configuration for Samba;
* restarting or recreating the Samba container;
* changing ownership or permissions under `/srv/media`;
* moving, deleting, renaming, or mass-modifying files exposed through Samba;
* changing Windows drive mappings or documented share names;
* changing backup assumptions for Samba-exported paths.

These operations require an explicit plan and approval.

Extra-sensitive operations include:

* recursive `chown`;
* recursive `chmod`;
* deleting `.deleted`, recycle, staging, or media directories;
* changing ownership away from the established homelab user/group model;
* exposing SMB outside the intended LAN/private network;
* changing SMB access in a way that breaks Windows mappings;
* modifying media files through Samba while services or scripts may also be using them;
* changing shares that are used by daily workflows.

## Read-only inspection allowed

Read-only Samba inspection is allowed when bounded and relevant.

Allowed read-only inspection may include:

* reading Samba-related service maps;
* reading storage, filesystem, Docker, networking, and media docs;
* reading storage, network, Docker, system, backup, and media scripts;
* inspecting existing reports and TSVs;
* checking Git status before editing tracked docs or scripts;
* listing known Compose directories under `/srv/compose`;
* inspecting generated inventories;
* reading bounded Samba or container logs;
* checking current share, path, ownership, and permission state with read-only commands when explicitly requested.

Read-only commands may include, when appropriate:

* `ls -ld` on selected paths;
* `find` with bounded depth;
* `stat` on selected paths;
* `id`;
* `getent passwd`;
* `getent group`;
* `docker ps`;
* `docker compose ls`;
* `docker inspect` for selected targets;
* bounded `docker logs --tail`;
* `ss -tulpn`;
* `ufw status`.

Read-only inspection must not be confused with approval to edit shares, restart Samba, change permissions, change ownership, expose SMB, delete files, or modify media paths.

## Read-only collection plan

A local agent may collect the following in read-only mode:

* Samba Compose path and service name;
* Samba container status;
* Samba published ports;
* Samba network attachments;
* configured or documented share names;
* exported host paths;
* selected ownership and permission summaries;
* UID/GID and user/group references;
* Windows mapping notes from docs or reports;
* references to Samba, SMB, shares, UID/GID, permissions, masks, oplocks, recycle, and Windows mappings across `knowledge/`, `docs/`, and `scripts/`;
* latest Toolbox script inventory report and TSV;
* Samba-related rows from the script inventory;
* storage-related rows from the script inventory;
* network-related rows from the script inventory;
* Docker-related rows from the script inventory;
* existing storage, network, Docker, system, backup, and media reports;
* bounded logs when explicitly useful;
* notes distinguishing Samba access, FileBrowser access, Docker bind mounts, and service-local access.

A local agent must not in read-only mode:

* create, edit, or delete Samba shares;
* change Samba configuration;
* change ownership;
* change permissions;
* change create or directory masks;
* change recycle behavior;
* restart or recreate Samba;
* change Docker networks;
* change published ports;
* edit Compose files;
* change firewall rules;
* expose SMB outside the approved network;
* move, delete, or rename media files;
* modify service configuration;
* commit or push changes.

Non-trivial Samba, storage, or permissions collection should generate a report and TSV.

## Actions requiring approval

The following require explicit approval:

* editing Samba configuration;
* creating shares;
* deleting shares;
* changing exported paths;
* changing force user or force group behavior;
* changing UID/GID assumptions;
* changing masks;
* changing oplocks;
* changing recycle behavior;
* changing Samba Docker Compose files;
* changing Docker network membership for Samba;
* changing published ports;
* changing firewall rules related to SMB;
* restarting or recreating Samba;
* changing ownership or permissions under `/srv/media`;
* moving, deleting, renaming, or mass-modifying files exposed by Samba;
* changing Windows mapping conventions;
* committing or pushing Samba-related documentation or script changes.

Approval must be specific to the share, path, ownership/permission behavior, and expected effect.

A general instruction to continue is not approval for unrelated Samba or filesystem changes.

## Known historical lessons

Samba has accumulated important operational lessons through prior homelab work involving Windows access, Dockerized Samba, media paths, ownership, permissions, UID/GID consistency, move errors, recycle directories, and service interoperability.

Service-specific lessons should be summarized here only when they directly affect Samba operation.

Detailed historical lessons should be consolidated under:

* `knowledge/architecture/historical-operational-lessons.md`

Until that document exists, agents must treat Samba lessons mentioned in context, policies, service maps, reports, and validated scripts as operationally relevant.

## Open questions

Samba has open architectural and operational questions that should be resolved incrementally.

This service map should list only open questions that directly affect Samba as the SMB file-sharing layer.

Broader open questions should be consolidated under a future architecture document, such as:

* `knowledge/architecture/open-questions.md`

Current known areas for future clarification include share inventory, Windows mapping documentation, permissions validation, Samba backup coverage, recycle behavior, FileBrowser/Samba boundary, media staging interaction, and future Codex/local-agent read-only inspection boundaries.

## Source of truth

Stable source and knowledge:

* `/srv/toolbox/app`

Compose and service configuration:

* `/srv/compose`

Generated operational evidence:

* `/srv/toolbox/shared`

Current host state must be verified from the host when accuracy matters.

Examples of current Samba state that must be verified include:

* running container;
* Compose project path;
* published SMB ports;
* share names;
* exported host paths;
* user and group mappings;
* create masks;
* directory masks;
* recycle behavior;
* locking behavior;
* ownership and permissions;
* Windows mappings;
* Docker network membership;
* firewall interaction;
* relation between Samba access, FileBrowser access, and service-local access.

Agents must not treat memory, old reports, or chat history as proof of current Samba state.
