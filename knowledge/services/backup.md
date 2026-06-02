# Backup

## Purpose

Backup is the homelab operational subsystem responsible for preserving recoverable infrastructure, configuration, Toolbox state, selected reports, and other critical non-media assets.

Its purpose is not to duplicate the entire media library. The current backup strategy prioritizes configuration, operational state, scripts, documentation, policies, and recoverability of the homelab itself.

Backup is a safety boundary. It must be understood before making risky changes to Docker services, Toolbox scripts, service configuration, media workflows, filesystem permissions, or generated operational evidence.

## Service type

`operational_subsystem`

Backup is an operational subsystem because it combines:

* host-installed backup tooling;
* encrypted backup repository;
* mounted backup storage;
* scheduled execution;
* retention policy;
* restore validation;
* Backrest UI;
* Toolbox reports and scripts;
* human approval boundaries.

Backup also depends on technical services and host configuration, including storage, systemd, Docker, Backrest, filesystem mounts, and selected `/srv` paths.

## Current role in the homelab

Backup currently protects selected homelab infrastructure and configuration.

Its role includes:

* preserving Docker Compose configuration;
* preserving selected Toolbox source, secrets, and operational documents;
* preserving selected reports or backup-related outputs;
* preserving enough state to rebuild or recover the operational homelab;
* validating that restore works;
* providing scheduled automated backup execution;
* providing a Backrest UI for visibility and management;
* excluding large media libraries from the primary infrastructure backup scope unless explicitly added later.

Backup must be understood together with Docker, Toolbox, Samba, FileBrowser, storage layout, service configuration, and `/srv` organization.

## Important paths

Backup source and configuration paths may include:

* `/srv/compose`
* `/srv/toolbox/app`
* `/srv/toolbox/secrets`
* `/srv/data/homepage`
* `/home/thiago/relatorios-backup`

Backup repository path:

* `/mnt/backup-homelab`

Backup repository storage:

* external USB pendrive formatted as ext4;
* label: `HOMELAB_BKP`;
* UUID recorded in host mount configuration.

Restic password file:

* `~/.restic-password-homelab`

Backup scripts may include:

* `~/backup-homelab.sh`
* `~/prune-backup-homelab.sh`
* Toolbox backup scripts under `scripts/admin/backup`

Systemd automation may include:

* `backup-homelab.service`
* `backup-homelab.timer`

Generated backup evidence should be stored under:

* `/srv/toolbox/shared/reports/backup`
* `/srv/toolbox/shared/reports/storage`
* `/srv/toolbox/shared/reports/system`
* `/srv/toolbox/shared/library-db/raw/backup`
* `/srv/toolbox/shared/library-db/raw/storage`
* `/srv/toolbox/shared/library-db/raw/system`
* `/srv/toolbox/shared/logs/backup`
* `/srv/toolbox/shared/inventory/backup`

Current backup paths, mount state, timer state, repository state, retention state, and script locations must be verified from the host before making changes.

## Related services

Backup is related to:

* Toolbox;
* Docker;
* networking;
* Samba;
* FileBrowser;
* storage;
* Backrest;
* Restic;
* systemd timers;
* media curation;
* music staging;
* Navidrome;
* Nginx Proxy Manager;
* future Codex/local-agent workflows.

Backup is especially related to services whose configuration lives under `/srv/compose` or whose operational state is needed to recover the homelab.

Backup is not a substitute for careful change management. Before risky changes, agents must check whether backup scope, repository availability, and restore strategy are adequate.

## Related scripts and workflows

Backup-related scripts and workflows may be found under:

* `scripts/admin/backup`
* `scripts/admin/storage`
* `scripts/admin/system`
* `scripts/admin/docker`
* `scripts/admin/git`

The Toolbox script inventory should be consulted before proposing new backup, prune, retention, mount, restore, or storage command sequences.

Agents must not assume that backup knowledge is isolated under `scripts/admin/backup`. Backup concerns also appear in storage, system, Docker, Git, service configuration, and media workflows.

Relevant workflow families include:

* backup diagnostics;
* backup repository readiness checks;
* backup execution;
* prune and retention routines;
* restore validation;
* storage pressure diagnostics;
* mount and disk diagnostics;
* Docker configuration preservation;
* Toolbox state preservation;
* Git checkpoint routines before risky changes;
* knowledge/service documentation validation.

Backup work should follow the standard workflow:

* diagnose;
* plan;
* apply;
* validate.

## Related reports, TSVs, inventories, and logs

Backup-related evidence should be stored under `/srv/toolbox/shared`.

Likely destinations include:

* `/srv/toolbox/shared/reports/backup`
* `/srv/toolbox/shared/reports/storage`
* `/srv/toolbox/shared/reports/system`
* `/srv/toolbox/shared/reports/git`
* `/srv/toolbox/shared/library-db/raw/backup`
* `/srv/toolbox/shared/library-db/raw/storage`
* `/srv/toolbox/shared/library-db/raw/system`
* `/srv/toolbox/shared/library-db/raw/git`
* `/srv/toolbox/shared/logs/backup`
* `/srv/toolbox/shared/inventory/backup`

Useful evidence may include:

* backup scope reports;
* exclude-list reports;
* repository status;
* mount status;
* disk usage;
* latest snapshot list;
* restore test notes;
* prune/retention reports;
* timer status;
* Backrest status notes;
* repository health check output;
* backup script inventory;
* backup-related Git checkpoint reports.

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
* `knowledge/services/samba.md`

Important operational documentation:

* `docs/operations/toolbox_architecture_reconciliation.md`
* `docs/operations/toolbox_output_destinations_policy.md`
* `docs/operations/toolbox_reports_policy.md`
* `docs/operations/toolbox_logging_policy.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_storage_policy.md`
* `docs/operations/toolbox_runtime_profiles.md`

Future or related service documents may include:

* `knowledge/services/filebrowser.md`
* `knowledge/services/music-staging.md`
* `knowledge/services/navidrome.md`

## Sensitive operations

Sensitive backup operations include:

* changing backup scope;
* adding or removing included paths;
* adding or removing excluded paths;
* changing Restic repository path;
* changing Restic password handling;
* changing backup repository mount behavior;
* changing systemd backup timers;
* changing retention policy;
* running prune or forget commands;
* deleting snapshots;
* deleting or reinitializing repositories;
* changing Backrest configuration;
* changing backup scripts;
* changing restore scripts;
* changing backup destination storage;
* assuming media is backed up when it is not;
* changing service configuration without confirming backup coverage.

These operations require an explicit plan and approval.

Extra-sensitive operations include:

* `restic forget --prune`;
* repository deletion;
* snapshot deletion;
* changing encryption/password files;
* changing backup scope to include large media libraries;
* changing backup scope to exclude critical configuration;
* reformatting backup drives;
* modifying `/etc/fstab` or mount behavior;
* changing automation that runs unattended;
* treating backup existence as proof of restore readiness without validation.

## Read-only inspection allowed

Read-only backup inspection is allowed when bounded and relevant.

Allowed read-only inspection may include:

* reading backup-related service maps;
* reading backup, storage, Docker, and system docs;
* reading backup, storage, system, Docker, and Git scripts;
* inspecting existing backup reports and TSVs;
* checking Git status before editing tracked docs or scripts;
* listing known backup script paths;
* checking whether the backup mount exists;
* checking timer status;
* checking repository status with non-mutating commands;
* listing snapshots when explicitly useful;
* reading bounded Backrest or backup logs.

Read-only commands may include, when appropriate:

* `mount`
* `findmnt`
* `df -h`
* `lsblk`
* `systemctl status`
* `systemctl list-timers`
* `restic snapshots`
* `restic check` when explicitly approved as read-only and reasonable for the repository size;
* bounded log reads.

Read-only inspection must not be confused with approval to run backup, prune, forget, delete, reinitialize, reformat, remount, or change automation.

## Read-only collection plan

A local agent may collect the following in read-only mode:

* backup scripts and their paths;
* backup include paths;
* backup exclude paths;
* backup repository path;
* backup mount status;
* backup timer status;
* Backrest references;
* Restic version and non-mutating repository information when explicitly requested;
* latest snapshot list when explicitly useful;
* latest Toolbox script inventory report and TSV;
* backup-related rows from the script inventory;
* storage-related rows from the script inventory;
* systemd-related rows from the script inventory;
* Docker-related rows from the script inventory where service configuration backup is relevant;
* existing backup, storage, system, Docker, and Git reports;
* references to backup, Restic, Backrest, prune, restore, retention, repository, and snapshots across `knowledge/`, `docs/`, and `scripts/`.

A local agent must not in read-only mode:

* run backup jobs;
* run prune or forget commands;
* delete snapshots;
* change retention policy;
* change included paths;
* change excluded paths;
* change repository path;
* change password files;
* mount or unmount storage;
* reformat drives;
* edit systemd units;
* edit Backrest configuration;
* edit backup scripts;
* commit or push changes.

Non-trivial backup inspection should generate a report and TSV.

## Actions requiring approval

The following require explicit approval:

* editing backup scripts;
* editing backup service maps or policies;
* changing included paths;
* changing excluded paths;
* changing repository location;
* changing repository password handling;
* changing mount configuration;
* running backup jobs manually;
* changing backup timers;
* changing retention policy;
* running `restic forget`;
* running prune operations;
* deleting snapshots;
* deleting or reinitializing repositories;
* running restore operations;
* changing Backrest configuration;
* changing backup storage devices;
* committing or pushing backup-related documentation or script changes.

Approval must be specific to the operation, scope, repository, source paths, destination path, and expected effect.

A general instruction to continue is not approval for unrelated backup changes.

## Known historical lessons

Backup has accumulated important operational lessons through prior Restic, Backrest, USB mount, restore validation, systemd timer, and homelab recovery work.

Service-specific lessons should be summarized here only when they directly affect backup operation.

Detailed historical lessons should be consolidated under:

* `knowledge/architecture/historical-operational-lessons.md`

Until that document exists, agents must treat backup lessons mentioned in context, policies, service maps, reports, and validated scripts as operationally relevant.

## Open questions

Backup has open architectural and operational questions that should be resolved incrementally.

This service map should list only open questions that directly affect backup as the recovery subsystem.

Broader open questions should be consolidated under a future architecture document, such as:

* `knowledge/architecture/open-questions.md`

Current known areas for future clarification include secondary/offsite backups, media backup policy, FileBrowser artifact access, Backrest documentation, restore runbooks, backup service inventory, and future Codex/local-agent read-only inspection boundaries.

## Source of truth

Stable source and knowledge:

* `/srv/toolbox/app`

Generated operational evidence:

* `/srv/toolbox/shared`

Backup repository path:

* `/mnt/backup-homelab`

Host backup configuration must be verified from the host when accuracy matters.

Examples of current backup state that must be verified include:

* mounted backup repository;
* Restic repository health;
* latest snapshots;
* included paths;
* excluded paths;
* timer state;
* Backrest state;
* password-file path and permissions;
* retention policy;
* restore validation status;
* disk usage;
* repository storage device;
* backup script versions;
* backup coverage for service configuration.

Agents must not treat memory, old reports, or chat history as proof of current backup state.
