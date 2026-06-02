Navidrome

Purpose

Navidrome is the main music library server of the homelab.

It provides browser and client access to the curated music library, especially the canonical library under /srv/media/music.

Navidrome is not the place where music is initially curated. It should primarily expose material that has already passed through the appropriate staging, metadata, import, and validation workflows.

Service type

technical_service

Navidrome is a technical service because it is a deployed music server/container that indexes and serves the curated music library.

It is also operationally related to music staging, media curation, metadata policy, transcoding, Docker, networking, FileBrowser, Samba, and client playback behavior.

Current role in the homelab

Navidrome currently acts as the main music server for the curated music collection.

Its role includes:

* indexing /srv/media/music;
* serving the music library to browser and app clients;
* supporting lightweight client access through Feishin and Amperfy;
* supporting on-demand transcoding for playback compatibility when configured;
* exposing the effects of metadata quality, album organization, artwork, and import decisions;
* validating whether curated music appears correctly after import;
* helping detect metadata problems such as fragmented artists, inconsistent album artist tags, bad album grouping, missing artwork, or incorrect track organization.

Navidrome must be understood together with music staging, metadata policy, Beets/MusicBrainz workflows, FileBrowser, Samba, Docker bind mounts, Nginx Proxy Manager, Tailscale, and the private-first access model.

Important paths

Main music library:

* /srv/media/music

Music staging root:

* /srv/media/music-staging

Likely Navidrome Compose and configuration paths include:

* /srv/compose/navidrome
* service-specific Navidrome data/configuration paths under its Compose directory, if present;
* Navidrome data volume or bind-mounted data path, if configured.

Toolbox source and knowledge paths:

* /srv/toolbox/app
* /srv/toolbox/app/knowledge
* /srv/toolbox/app/docs
* /srv/toolbox/app/scripts/media/library
* /srv/toolbox/app/scripts/media/stockhausen
* /srv/toolbox/app/scripts/admin/docker
* /srv/toolbox/app/scripts/admin/network
* /srv/toolbox/app/scripts/admin/storage
* /srv/toolbox/app/scripts/admin/system

Generated Navidrome and music-library evidence should be stored under:

* /srv/toolbox/shared/reports/media
* /srv/toolbox/shared/reports/media/staging
* /srv/toolbox/shared/reports/media/stockhausen
* /srv/toolbox/shared/reports/docker
* /srv/toolbox/shared/reports/network
* /srv/toolbox/shared/reports/system
* /srv/toolbox/shared/library-db/raw/media
* /srv/toolbox/shared/library-db/raw/media/staging
* /srv/toolbox/shared/library-db/raw/media/stockhausen
* /srv/toolbox/shared/library-db/raw/docker
* /srv/toolbox/shared/library-db/raw/network
* /srv/toolbox/shared/library-db/raw/system
* /srv/toolbox/shared/logs/media
* /srv/toolbox/shared/logs/docker
* /srv/toolbox/shared/inventory/media

Current library path, container mounts, Navidrome data path, transcoding configuration, clients, and access model must be verified from the host before making changes.

Related services

Navidrome is related to:

* music staging;
* Toolbox;
* Docker;
* networking;
* Nginx Proxy Manager;
* Samba;
* FileBrowser;
* backup;
* slskd/Soulseek;
* media curation workflows;
* Stockhausen workflows;
* Beets;
* MusicBrainz;
* Feishin;
* Amperfy;
* future Codex/local-agent workflows.

Feishin and Amperfy are client applications and do not need separate service maps at this stage. They are relevant here because they expose playback, metadata, artwork, transcoding, and library-navigation issues.

Navidrome is related to music staging because staging determines what should eventually enter /srv/media/music.

Navidrome is related to Samba and FileBrowser because both provide human access to files that may later appear in the Navidrome library.

Related scripts and workflows

Navidrome-related scripts and workflows may be found under:

* scripts/media/library
* scripts/media/stockhausen
* scripts/admin/docker
* scripts/admin/network
* scripts/admin/storage
* scripts/admin/system
* scripts/admin/backup

The Toolbox script inventory should be consulted before proposing new Navidrome, music-library, metadata, import, Docker, networking, or storage command sequences.

Agents must not assume that Navidrome knowledge is isolated in one script directory. Navidrome behavior is affected by library files, metadata, import workflows, Docker mounts, networking, client settings, transcoding configuration, and service data.

Relevant workflow families include:

* music library inventory generation;
* music library SQLite initialization;
* music-staging diagnostics;
* music-staging transition workflows;
* controlled FLAC metadata write workflows;
* Beets/MusicBrainz diagnostics and dry-runs;
* tagging audit diagnostics;
* plugin readiness diagnostics;
* Stockhausen metadata normalization workflows;
* Stockhausen Navidrome album-count diagnostics;
* import validation workflows;
* Docker diagnostics;
* network and exposure diagnostics;
* storage and permission diagnostics;
* knowledge/service documentation validation.

Navidrome work should follow the standard workflow:

* diagnose;
* plan;
* apply;
* validate.

Library and metadata policy

Navidrome should primarily index the curated main library, not unreviewed staging material.

Music should enter the Navidrome library through controlled import workflows.

Metadata quality matters because Navidrome reflects tags and file organization.

Important metadata concerns include:

* ALBUM;
* ALBUMARTIST;
* ARTIST;
* COMPOSER;
* TITLE;
* TRACKNUMBER;
* DISCNUMBER;
* DATE;
* GENRE;
* MusicBrainz identifiers when available;
* artwork;
* folder structure;
* file names.

For curated composer or special-collection workflows, such as Stockhausen, collection-specific metadata policy must be respected.

Agents must not “fix Navidrome” by directly editing music tags or moving library files without following the media curation and music-staging policies.

Import readiness

Material should be considered ready for Navidrome only after the relevant workflow has checked the required items.

Depending on the album or collection, import readiness may include:

* technical file integrity;
* metadata consistency;
* album completeness;
* duplicate checks;
* artwork readiness;
* MusicBrainz or manual metadata review;
* filesystem permissions;
* target path review;
* import plan;
* post-import validation.

A successful Navidrome scan or visible album does not prove that curation is complete.

A missing album in Navidrome may indicate metadata, path, permission, container mount, scan, cache, or service configuration issues.

Transcoding and playback policy

The homelab preference is to preserve archival masters and use on-demand transcoding for playback compatibility when appropriate.

Navidrome transcoding is part of the playback layer, not a reason to create duplicate canonical files by default.

Transcoding-related work may include:

* verifying ffmpeg availability;
* checking Navidrome transcoding configuration;
* checking player/backend behavior;
* checking Feishin settings;
* checking Amperfy behavior;
* testing a problematic album or codec;
* distinguishing server-side transcoding issues from client playback issues.

Agents must not transcode, replace masters, create derivative libraries, or delete originals without explicit approval.

Clients

Known relevant clients include:

* Feishin on Windows;
* Amperfy on iPhone;
* Navidrome browser UI.

Client behavior must not be confused with server truth.

A playback issue may be caused by:

* Navidrome server configuration;
* ffmpeg/transcoding configuration;
* codec compatibility;
* client backend settings;
* browser limitations;
* file corruption;
* metadata problems;
* network access differences;
* Tailscale or LAN route differences.

Client-specific troubleshooting should start with diagnosis and avoid changing the library prematurely.

Related reports, TSVs, inventories, and logs

Navidrome-related evidence should be stored under /srv/toolbox/shared.

Likely destinations include:

* /srv/toolbox/shared/reports/media
* /srv/toolbox/shared/reports/media/staging
* /srv/toolbox/shared/reports/media/stockhausen
* /srv/toolbox/shared/reports/docker
* /srv/toolbox/shared/reports/network
* /srv/toolbox/shared/reports/system
* /srv/toolbox/shared/library-db/raw/media
* /srv/toolbox/shared/library-db/raw/media/staging
* /srv/toolbox/shared/library-db/raw/media/stockhausen
* /srv/toolbox/shared/library-db/raw/docker
* /srv/toolbox/shared/library-db/raw/network
* /srv/toolbox/shared/library-db/raw/system
* /srv/toolbox/shared/logs/media
* /srv/toolbox/shared/logs/docker
* /srv/toolbox/shared/inventory/media

Useful evidence may include:

* library inventory;
* artist/album count reports;
* album path reports;
* metadata consistency reports;
* duplicate and missing reports;
* import validation reports;
* Navidrome container status;
* container bind-mount inventory;
* transcoding configuration notes;
* ffmpeg availability notes;
* client playback notes;
* bounded Navidrome logs;
* network access notes;
* Nginx Proxy Manager routing notes;
* Tailscale access notes.

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
* knowledge/services/filebrowser.md
* knowledge/services/backup.md
* knowledge/services/music-staging.md

Important operational documentation:

* docs/operations/toolbox_architecture_reconciliation.md
* docs/operations/toolbox_output_destinations_policy.md
* docs/operations/toolbox_reports_policy.md
* docs/operations/toolbox_logging_policy.md
* docs/operations/toolbox_script_conventions.md
* docs/operations/toolbox_storage_policy.md
* docs/operations/toolbox_runtime_profiles.md
* docs/media/stockhausen_metadata_policy.md
* docs/media/stockhausen_gold_model_stimmung.md

Future or related service documents may include:

* knowledge/services/slskd.md
* knowledge/services/monitoring.md

Sensitive operations

Sensitive Navidrome operations include:

* changing the Navidrome library path;
* changing Docker bind mounts;
* changing Navidrome data/configuration;
* changing transcoding configuration;
* changing ffmpeg/transcoding behavior;
* changing network exposure;
* changing Nginx Proxy Manager routing;
* restarting or recreating Navidrome;
* forcing rescans without understanding impact;
* changing file ownership or permissions under /srv/media/music;
* moving files into or out of /srv/media/music;
* editing tags in the main library;
* deleting albums or tracks from the main library;
* changing client-facing access behavior;
* changing backup assumptions for Navidrome configuration or library metadata.

These operations require an explicit plan and approval.

Extra-sensitive operations include:

* bulk retagging of the main library;
* bulk renaming inside /srv/media/music;
* changing canonical artist/album metadata without collection policy;
* changing transcoding in a way that breaks clients;
* changing library mounts;
* deleting music;
* exposing Navidrome outside the approved private-first model;
* treating Navidrome display problems as proof that files should be rewritten.

Read-only inspection allowed

Read-only Navidrome inspection is allowed when bounded and relevant.

Allowed read-only inspection may include:

* reading Navidrome-related service maps;
* reading media, Docker, networking, storage, and Toolbox docs;
* reading media, Docker, network, storage, and system scripts;
* inspecting existing reports and TSVs;
* checking Git status before editing tracked docs or scripts;
* listing known Compose directories under /srv/compose;
* inspecting generated inventories;
* reading bounded Navidrome or container logs;
* checking container status and bind mounts;
* reading selected music metadata;
* reading selected file paths and permissions;
* checking client-facing notes from prior reports.

Read-only commands may include, when appropriate:

* docker ps
* docker compose ls
* docker inspect for selected targets;
* bounded docker logs --tail;
* find with bounded depth;
* ls;
* stat;
* ffprobe;
* metaflac --list;
* ss -tulpn;
* ufw status.

Read-only inspection must not be confused with approval to edit tags, move files, delete files, restart Navidrome, change transcode settings, change mounts, change network exposure, or change client behavior.

Read-only collection plan

A local agent may collect the following in read-only mode:

* Navidrome Compose path and service name;
* Navidrome container status;
* Navidrome published ports;
* Navidrome bind mounts;
* Navidrome network attachments;
* Navidrome data/configuration path notes;
* library path and selected directory summaries;
* selected metadata summaries;
* existing artist/album count reports;
* latest Toolbox script inventory report and TSV;
* Navidrome-related rows from the script inventory;
* music-library-related rows from the script inventory;
* music-staging-related rows from the script inventory;
* Stockhausen-related rows from the script inventory when relevant;
* Docker-related rows from the script inventory;
* network-related rows from the script inventory;
* storage-related rows from the script inventory;
* existing media, staging, Docker, network, system, and storage reports;
* references to Navidrome, Feishin, Amperfy, transcoding, ffmpeg, music library, metadata, artwork, and import validation across knowledge/, docs/, and scripts/.

A local agent must not in read-only mode:

* edit Navidrome configuration;
* restart or recreate Navidrome;
* change bind mounts;
* change published ports;
* change Nginx Proxy Manager routing;
* change transcoding configuration;
* move files;
* delete files;
* rename files;
* write metadata;
* remove metadata;
* import into /srv/media/music;
* transcode or replace masters;
* modify FileBrowser or Samba access;
* modify client configuration;
* commit or push changes.

Non-trivial Navidrome inspection should generate a report and TSV.

Actions requiring approval

The following require explicit approval:

* editing Navidrome configuration;
* changing Docker Compose files;
* changing bind mounts;
* changing published ports;
* changing Docker network membership;
* changing Nginx Proxy Manager routing;
* changing Tailscale or LAN access assumptions;
* restarting or recreating Navidrome;
* changing transcoding configuration;
* running broad rescans or cache-affecting operations;
* changing ownership or permissions under /srv/media/music;
* moving, deleting, renaming, or retagging music in the main library;
* importing new music into /srv/media/music;
* changing Feishin or Amperfy configuration when troubleshooting;
* changing backup assumptions for Navidrome data/configuration;
* committing or pushing Navidrome-related documentation or script changes.

Approval must be specific to the path, service, client, configuration, library effect, and expected result.

A general instruction to continue is not approval for unrelated Navidrome, media, or filesystem changes.

Known historical lessons

Navidrome has accumulated important operational lessons through codec/playback troubleshooting, Feishin backend configuration, Amperfy playback behavior, transcoding validation, Stockhausen album-count validation, metadata normalization, music staging, and main-library import workflows.

Service-specific lessons should be summarized here only when they directly affect Navidrome operation.

Detailed historical lessons should be consolidated under:

* knowledge/architecture/historical-operational-lessons.md

Until that document exists, agents must treat Navidrome lessons mentioned in context, policies, service maps, reports, and validated scripts as operationally relevant.

Open questions

Navidrome has open architectural and operational questions that should be resolved incrementally.

This service map should list only open questions that directly affect Navidrome as the music server.

Broader open questions should be consolidated under a future architecture document, such as:

* knowledge/architecture/open-questions.md

Current known areas for future clarification include final import validation criteria, client troubleshooting runbooks, transcoding profiles, artwork behavior, artist normalization policy across non-Stockhausen collections, Navidrome backup coverage, and future Codex/local-agent read-only inspection boundaries.

Source of truth

Stable source and knowledge:

* /srv/toolbox/app

Main music library:

* /srv/media/music

Music staging root:

* /srv/media/music-staging

Generated operational evidence:

* /srv/toolbox/shared

Current host state must be verified from the host when accuracy matters.

Examples of current Navidrome state that must be verified include:

* running container;
* Compose project path;
* published ports;
* bind mounts;
* library path;
* data/configuration path;
* transcoding configuration;
* ffmpeg availability;
* current logs;
* current scan behavior;
* artist and album counts;
* selected metadata;
* current imported albums;
* current FileBrowser/Samba access;
* current Nginx Proxy Manager routing;
* current Tailscale or LAN access behavior;
* current client behavior in Feishin, Amperfy, and browser UI.

Agents must not treat memory, old reports, or chat history as proof of current Navidrome state.
