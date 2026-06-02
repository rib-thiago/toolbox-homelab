FileBrowser

Purpose

FileBrowser provides browser-based file access to selected homelab paths.

It is central to the user’s daily workflow with ChatGPT because it allows comfortable access to generated artifacts, reports, TSVs, documents, media-adjacent files, and operational evidence without relying only on terminal output or SMB mounts.

FileBrowser is not just a generic file manager. In this homelab, it is part of the human-in-the-loop workflow for inspecting, selecting, downloading, uploading, and reviewing files that are later discussed with ChatGPT or used in Toolbox operations.

Service type

technical_service

FileBrowser is a technical service because it is a deployed application/container that exposes selected filesystem paths through a browser UI.

It is also operationally related to Toolbox, Samba, backup, Docker, networking, media curation, reports, TSVs, and future ChatGPT/Codex workflows.

Current role in the homelab

FileBrowser currently acts as a browser-based file access layer for selected homelab files and artifacts.

Its role includes:

* providing daily human access to reports, TSVs, and generated artifacts;
* supporting ChatGPT-assisted workflows where files are downloaded, uploaded, inspected, or shared;
* complementing Samba by providing browser-based access where SMB is less convenient;
* helping inspect /srv/toolbox/shared outputs;
* helping inspect media-adjacent files and operational artifacts;
* supporting review of generated reports without requiring every interaction to happen in the terminal;
* preserving a private-first access model rather than exposing file access publicly.

FileBrowser must be understood together with Docker bind mounts, filesystem permissions, Samba, backup, networking, Toolbox output destinations, and sensitive media paths.

Important paths

Likely Compose and configuration paths include:

* /srv/compose/filebrowser
* service-specific FileBrowser configuration or database paths under its Compose directory, if present;
* host paths mounted into the FileBrowser container.

Important paths that may be accessed through FileBrowser include:

* /srv/toolbox/shared
* /srv/toolbox/shared/reports
* /srv/toolbox/shared/library-db/raw
* /srv/toolbox/shared/library-db/snapshots
* /srv/toolbox/shared/logs
* /srv/toolbox/shared/briefs
* /srv/media
* /srv/media/music-staging
* /srv/media/pdfs-raw
* /srv/media/photos
* /srv/media/photos-raw

Toolbox source and knowledge paths:

* /srv/toolbox/app
* /srv/toolbox/app/knowledge
* /srv/toolbox/app/docs
* /srv/toolbox/app/scripts

Generated FileBrowser-related evidence should be stored under:

* /srv/toolbox/shared/reports/system
* /srv/toolbox/shared/reports/docker
* /srv/toolbox/shared/reports/network
* /srv/toolbox/shared/reports/storage
* /srv/toolbox/shared/library-db/raw/system
* /srv/toolbox/shared/library-db/raw/docker
* /srv/toolbox/shared/library-db/raw/network
* /srv/toolbox/shared/library-db/raw/storage
* /srv/toolbox/shared/logs/system
* /srv/toolbox/shared/inventory/system

Current mount paths, exposed paths, access model, bind addresses, permissions, and FileBrowser configuration must be verified from the host before making changes.

Related services

FileBrowser is related to:

* Toolbox;
* Docker;
* networking;
* Nginx Proxy Manager;
* Samba;
* backup;
* music staging;
* Navidrome;
* media curation;
* storage;
* ChatGPT-assisted workflows;
* future Codex/local-agent workflows.

FileBrowser and Samba are complementary.

Samba provides SMB access, especially for Windows desktop workflows and mapped drives.

FileBrowser provides browser-based access, especially for inspecting and retrieving Toolbox artifacts, reports, TSVs, generated documents, and files that may be shared with ChatGPT.

Related scripts and workflows

FileBrowser-related scripts and workflows may be found under:

* scripts/admin/system
* scripts/admin/docker
* scripts/admin/network
* scripts/admin/storage
* scripts/admin/backup

The Toolbox script inventory should be consulted before proposing new FileBrowser, file-access, artifact-access, Docker, networking, or permissions command sequences.

Agents must not assume that FileBrowser knowledge is isolated in one script directory. FileBrowser behavior is distributed across Docker Compose configuration, bind mounts, networking, firewall policy, storage layout, permissions, backup coverage, and Toolbox output-destination policy.

Relevant workflow families include:

* Toolbox report and TSV generation;
* artifact inspection and handoff workflows;
* Docker diagnostics;
* network exposure diagnostics;
* storage and permissions diagnostics;
* backup diagnostics where generated artifacts are relevant;
* service access validation;
* knowledge/service documentation validation.

FileBrowser work should follow the standard workflow:

* diagnose;
* plan;
* apply;
* validate.

Related reports, TSVs, inventories, and logs

FileBrowser-related evidence should be stored under /srv/toolbox/shared.

Likely destinations include:

* /srv/toolbox/shared/reports/system
* /srv/toolbox/shared/reports/docker
* /srv/toolbox/shared/reports/network
* /srv/toolbox/shared/reports/storage
* /srv/toolbox/shared/reports/backup
* /srv/toolbox/shared/library-db/raw/system
* /srv/toolbox/shared/library-db/raw/docker
* /srv/toolbox/shared/library-db/raw/network
* /srv/toolbox/shared/library-db/raw/storage
* /srv/toolbox/shared/library-db/raw/backup
* /srv/toolbox/shared/logs/system
* /srv/toolbox/shared/inventory/system

Useful evidence may include:

* FileBrowser container status;
* bind-mount inventory;
* exposed path inventory;
* permission summaries;
* service access notes;
* network exposure notes;
* Tailscale or LAN access notes;
* backup coverage notes;
* report/TSV artifact access notes;
* bounded FileBrowser container logs.

For destination rules, consult:

* docs/operations/toolbox_output_destinations_policy.md
* knowledge/policies/reporting-policy.md

Related policies and docs

Required context:

* knowledge/context/agent-entrypoint.md
* knowledge/context/homelab-context.md
* knowledge/context/toolbox-context.md

Required policies:

* knowledge/policies/agent-safety-policy.md
* knowledge/policies/change-management-policy.md
* knowledge/policies/reporting-policy.md
* knowledge/policies/filesystem-safety-policy.md
* knowledge/policies/media-curation-policy.md

Relevant service maps:

* knowledge/services/README.md
* knowledge/services/toolbox.md
* knowledge/services/docker.md
* knowledge/services/networking.md
* knowledge/services/nginx-proxy-manager.md
* knowledge/services/samba.md
* knowledge/services/backup.md

Important operational documentation:

* docs/operations/toolbox_architecture_reconciliation.md
* docs/operations/toolbox_output_destinations_policy.md
* docs/operations/toolbox_reports_policy.md
* docs/operations/toolbox_logging_policy.md
* docs/operations/toolbox_script_conventions.md
* docs/operations/toolbox_storage_policy.md
* docs/operations/toolbox_runtime_profiles.md

Future or related service documents may include:

* knowledge/services/music-staging.md
* knowledge/services/navidrome.md

Sensitive operations

Sensitive FileBrowser operations include:

* changing FileBrowser bind mounts;
* changing exposed host paths;
* changing FileBrowser users or permissions;
* changing authentication settings;
* changing FileBrowser database or configuration;
* changing Docker Compose configuration;
* changing published ports;
* changing bind addresses;
* changing Nginx Proxy Manager routing for FileBrowser;
* changing Tailscale or LAN access model;
* restarting or recreating FileBrowser;
* exposing FileBrowser outside the approved private-first model;
* changing access to /srv/toolbox/shared;
* changing access to /srv/media;
* deleting, moving, renaming, uploading, or overwriting files through FileBrowser;
* changing backup assumptions for FileBrowser-accessible paths.

These operations require an explicit plan and approval.

Extra-sensitive operations include:

* exposing FileBrowser publicly;
* granting broad write access to sensitive paths;
* mounting /srv broadly without review;
* giving FileBrowser write access to source-controlled paths without strict boundaries;
* deleting generated evidence under /srv/toolbox/shared;
* deleting media files through the browser UI;
* weakening authentication or network boundaries;
* confusing FileBrowser convenience access with approval to mutate files.

Read-only inspection allowed

Read-only FileBrowser inspection is allowed when bounded and relevant.

Allowed read-only inspection may include:

* reading FileBrowser-related service maps;
* reading Docker, networking, storage, backup, and Toolbox docs;
* reading system, Docker, network, storage, and backup scripts;
* inspecting existing reports and TSVs;
* checking Git status before editing tracked docs or scripts;
* listing known Compose directories under /srv/compose;
* inspecting generated inventories;
* reading bounded FileBrowser or container logs;
* checking current bind mounts and access model with read-only commands when explicitly requested.

Read-only commands may include, when appropriate:

* docker ps
* docker compose ls
* docker inspect for selected targets;
* bounded docker logs --tail;
* ss -tulpn;
* ufw status;
* findmnt;
* ls -ld on selected mounted paths;
* stat on selected paths.

Read-only inspection must not be confused with approval to edit configuration, restart FileBrowser, change bind mounts, change access paths, delete files, upload files, overwrite files, change permissions, or expose the service.

Read-only collection plan

A local agent may collect the following in read-only mode:

* FileBrowser Compose path and service name;
* FileBrowser container status;
* FileBrowser published ports;
* FileBrowser bind mounts;
* FileBrowser network attachments;
* FileBrowser access model notes;
* FileBrowser references across knowledge/, docs/, and scripts/;
* latest Toolbox script inventory report and TSV;
* FileBrowser-related rows from the script inventory;
* Docker-related rows from the script inventory;
* network-related rows from the script inventory;
* storage-related rows from the script inventory;
* backup-related rows from the script inventory;
* existing system, Docker, network, storage, and backup reports;
* bounded logs when explicitly useful;
* notes distinguishing FileBrowser access, Samba access, service-local access, and terminal access.

A local agent must not in read-only mode:

* change FileBrowser configuration;
* change authentication;
* change users or permissions;
* change bind mounts;
* change exposed paths;
* restart or recreate FileBrowser;
* change Docker networks;
* change published ports;
* edit Compose files;
* change firewall rules;
* expose FileBrowser publicly;
* move, delete, upload, overwrite, or rename files;
* modify source-controlled files;
* modify media files;
* modify generated evidence;
* commit or push changes.

Non-trivial FileBrowser inspection should generate a report and TSV.

Actions requiring approval

The following require explicit approval:

* editing FileBrowser configuration;
* changing users, permissions, or authentication;
* changing bind mounts;
* changing exposed paths;
* changing Docker Compose files;
* changing Docker network membership for FileBrowser;
* changing published ports;
* changing firewall rules related to FileBrowser;
* changing Nginx Proxy Manager routing for FileBrowser;
* changing Tailscale access model for FileBrowser;
* restarting or recreating FileBrowser;
* exposing FileBrowser beyond the approved private-first model;
* deleting, moving, uploading, overwriting, or renaming files through FileBrowser;
* committing or pushing FileBrowser-related documentation or script changes.

Approval must be specific to the path, access model, permission behavior, network exposure, and expected effect.

A general instruction to continue is not approval for unrelated FileBrowser or filesystem changes.

Known historical lessons

FileBrowser has accumulated operational lessons through daily ChatGPT-assisted workflows, generated artifact review, Docker bind mounts, private-first access, Samba/FileBrowser boundary decisions, and Toolbox output-destination policy.

Service-specific lessons should be summarized here only when they directly affect FileBrowser operation.

Detailed historical lessons should be consolidated under:

* knowledge/architecture/historical-operational-lessons.md

Until that document exists, agents must treat FileBrowser lessons mentioned in context, policies, service maps, reports, and validated scripts as operationally relevant.

Open questions

FileBrowser has open architectural and operational questions that should be resolved incrementally.

This service map should list only open questions that directly affect FileBrowser as the browser-based file access layer.

Broader open questions should be consolidated under a future architecture document, such as:

* knowledge/architecture/open-questions.md

Current known areas for future clarification include Tailscale access model, read-only versus write access boundaries, exact mounted path inventory, backup coverage for FileBrowser configuration, artifact handoff workflow, Samba/FileBrowser boundary, and future Codex/local-agent read-only inspection boundaries.

Source of truth

Stable source and knowledge:

* /srv/toolbox/app

Compose and service configuration:

* /srv/compose

Generated operational evidence:

* /srv/toolbox/shared

Current host state must be verified from the host when accuracy matters.

Examples of current FileBrowser state that must be verified include:

* running container;
* Compose project path;
* published ports;
* bind mounts;
* exposed host paths;
* user and permission configuration;
* authentication settings;
* Docker network membership;
* Nginx Proxy Manager routing;
* Tailscale or LAN access model;
* firewall interaction;
* relation between FileBrowser access, Samba access, and terminal access;
* backup coverage for FileBrowser configuration and accessible artifacts.

Agents must not treat memory, old reports, or chat history as proof of current FileBrowser state.
