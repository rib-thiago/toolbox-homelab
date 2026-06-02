# Filesystem Safety Policy

This policy defines safety rules for filesystem operations in the Toolbox and homelab.

It applies to human-assisted work, ChatGPT-assisted work, Codex/local-agent work, scripts, diagnostics, validation routines, media workflows, backup-related work, and any operation that reads, writes, moves, renames, deletes, copies, synchronizes, or changes permissions on files or directories.

This policy must be read together with:

* `knowledge/context/agent-entrypoint.md`
* `knowledge/context/homelab-context.md`
* `knowledge/context/toolbox-context.md`
* `knowledge/policies/agent-safety-policy.md`
* `knowledge/policies/change-management-policy.md`
* `knowledge/policies/reporting-policy.md`

## Primary principle

Filesystem operations must be deliberate, bounded, reviewable, and reversible where practical.

Read-only inspection is allowed by default.

Filesystem modification requires planning and, when sensitive paths or bulk operations are involved, explicit human approval.

The agent or operator must distinguish between:

* listing;
* diagnosing;
* planning;
* staging;
* applying;
* validating;
* cleaning up.

These phases must not be collapsed when the operation may affect user data, media libraries, backups, service configuration, or Toolbox structure.

## Existing Toolbox workflows

The Toolbox already contains many operational scripts, helpers, libraries, runbooks, pipelines, reports, TSVs, and validated workflows created through prior work.

Before proposing ad hoc filesystem commands, agents must inspect whether an existing Toolbox script, helper, shared library function, runbook, plan/apply/validate workflow, `run-job` pipeline, report, TSV, or inventory already covers the task.

Existing scripts may be used when appropriate, but they must still be reviewed before execution, especially when they affect sensitive paths, services, media, backups, Git, permissions, ownership, cold archives, or operational configuration.

Agents should prefer existing validated workflows over manual filesystem commands when operating on sensitive paths.

If no suitable existing workflow exists, the agent may propose a new script or workflow, but must explain why existing assets are insufficient.

## Related Toolbox policies

This policy does not replace existing Toolbox policies, conventions, or operational documentation.

Agents and operators must consult applicable Toolbox documents before planning or applying filesystem changes.

Authoritative related documents include:

* `docs/operations/toolbox_storage_policy.md`
* `docs/operations/toolbox_reports_policy.md`
* `docs/operations/toolbox_logging_policy.md`
* `docs/operations/toolbox_output_destinations_policy.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_scripts_lib_policy.md`
* `docs/operations/toolbox_git_routine.md`
* `docs/media/stockhausen_metadata_policy.md`
* `docs/media/stockhausen_gold_model_stimmung.md`

If a conflict exists between this policy and an older document, the operator or agent must stop and ask for human review instead of choosing one silently.

If a document appears stale, incomplete, or inconsistent with observed host state, the inconsistency must be reported and reviewed.

## Sensitive paths

The following paths are sensitive:

* `/srv/media/`
* `/srv/media/music/`
* `/srv/media/music-staging/`
* `/srv/media/photos/`
* `/srv/media/photos-raw/`
* `/srv/media/videos/`
* `/srv/media/calibre-library/`
* `/srv/media/pdfs`
* `/srv/media/pdfs-raw/`
* `/srv/compose/`
* `/srv/toolbox/app/`
* `/srv/toolbox/shared/`
* `/srv/toolbox/jobs/`
* `/srv/toolbox/secrets/`
* mounted backup media;
* Restic repositories;
* cold archive directories;
* Samba-exported directories;
* Docker bind-mounted directories.

Sensitivity does not prohibit read-only inspection.

Sensitivity means modification requires a plan, approval, and validation.

## High-risk operations

The following operations are high risk:

* recursive deletion;
* bulk deletion;
* recursive moves;
* bulk renames;
* bulk metadata writes;
* recursive permission changes;
* recursive ownership changes;
* `rsync --delete`;
* `find ... -delete`;
* `find ... -exec rm`;
* `xargs rm`;
* shell globs that match many files;
* scripts that derive deletion targets dynamically;
* operations crossing filesystem boundaries;
* operations involving symlinks;
* operations on mounted backup media;
* operations inside media libraries;
* operations inside music staging;
* operations inside cold archives;
* operations inside service configuration paths.

High-risk operations require explicit human approval.

## Forbidden default behavior

Agents must not run destructive filesystem commands as a default action.

Agents must not use these patterns without explicit approved plan:

* `rm -rf`
* `rm -r`
* `find ... -delete`
* `find ... -exec rm`
* `xargs rm`
* `rsync --delete`
* recursive `chmod`
* recursive `chown`
* bulk `mv`
* bulk `rename`
* bulk metadata rewrite
* unbounded shell globs in sensitive paths

If an operation resembles one of these patterns, the agent must stop and ask for human review.

## Read-only inspection

Read-only inspection may include:

* `ls`;
* `find` without delete or exec mutation;
* `stat`;
* `du`;
* `df`;
* `mount`;
* `tree` when available;
* `git status`;
* checksums;
* metadata reads;
* report reads;
* TSV reads;
* inventory reads;
* bounded log reads.

Read-only inspection should still be bounded.

Agents should avoid scanning very large trees unnecessarily.

When a read-only scan may be expensive, the agent should explain the scope before running it.

## Dry-run requirement

Dry-run is required whenever the tool supports it and the operation may modify many files.

Examples:

* `rsync --dry-run`
* plan scripts before apply scripts;
* preview TSVs before metadata writes;
* generated move plans before moving files;
* generated delete plans before deletion;
* report review before cleanup.

A dry-run must show what would change.

A dry-run that only says “success” without listing affected targets is insufficient for risky operations.

## Plan files and target lists

Bulk operations should use explicit plan files or target lists.

Preferred pattern:

1. Diagnose current state.
2. Generate a report and TSV.
3. Generate a plan file listing exact targets.
4. Review the plan.
5. Apply only the reviewed targets.
6. Validate results.

For risky filesystem operations, target lists should include:

* source path;
* destination path, when applicable;
* action;
* reason;
* status;
* validation note.

Avoid deriving destructive targets only at apply time.

## Deletion policy

Deletion is the highest-risk filesystem operation.

Deletion under sensitive paths requires:

* explicit plan;
* exact target list;
* human approval;
* validation that targets are correct;
* backup, snapshot, or recovery strategy when practical;
* post-delete validation.

Deletion must not be based only on vague patterns.

Deletion must not be based only on age, extension, or name pattern in sensitive paths unless the rule has been reviewed and validated.

Prefer quarantine, staging, or `.deleted`-style holding areas when appropriate, but do not create such areas without considering storage pressure and cleanup policy.

## Move and rename policy

Move and rename operations can be destructive when they overwrite, break references, or disrupt services.

Bulk moves or renames require:

* plan;
* source and destination listing;
* collision detection;
* existence checks;
* validation after apply;
* rollback strategy where practical.

In media workflows, moves and renames must preserve staging semantics and library integrity.

Do not move material into the main music library without approved import workflow.

## Copy and rsync policy

Copy operations can consume significant disk space.

Before large copies, agents must consider:

* available disk space;
* destination filesystem;
* expected size;
* duplicate risk;
* whether hardlinks or reflinks are appropriate;
* whether a cold archive or export destination is more appropriate;
* cleanup expectations.

`rsync --delete` is high risk and requires explicit approval.

For large copies, use logs and reports when appropriate.

## Permission and ownership policy

Permission and ownership changes are sensitive.

Recursive `chmod` and `chown` can break services, Samba access, Docker bind mounts, backups, and media workflows.

Permission or ownership changes require:

* affected path;
* current ownership and mode sample;
* intended ownership and mode;
* reason;
* scope;
* validation;
* rollback or repair strategy.

Historical lessons about Samba, UID/GID ownership, media permissions, Docker bind mounts, and service access must be preserved in `knowledge/architecture/` and consulted when available.

Until those lessons are formally consolidated, agents must treat broad permission or ownership changes as high risk and request human review.

Do not normalize permissions recursively across broad trees without an explicit plan.

## Symlink policy

Symlinks require care.

Before following or modifying symlinks, agents must identify:

* whether the path is a symlink;
* target path;
* whether the target is inside or outside the expected tree;
* whether deletion affects link or target;
* whether copy tools will follow or preserve symlinks.

Agents must not assume that a path is a regular file or directory.

## Globbing and xargs policy

Shell globs can expand unexpectedly.

Agents must avoid destructive commands with unreviewed globs in sensitive paths.

Examples of risky patterns:

* `rm *.flac`
* `rm -rf */Artwork`
* `mv * destination/`
* `chmod -R ... *`
* `find ... | xargs rm`

For operations involving many files, use explicit target lists and review them before apply.

Use null-delimited patterns when handling arbitrary filenames:

* `find ... -print0`
* `xargs -0`

But null safety does not remove the need for approval when the operation is destructive.

## Metadata and extended attributes

Metadata operations can be filesystem operations and data operations.

Agents must treat the following as sensitive:

* FLAC tags;
* ID3 tags;
* embedded artwork;
* filesystem timestamps;
* extended attributes;
* checksums;
* sidecar files;
* cue/log files;
* cover images;
* manifests.

Metadata writes require approved workflows and validation.

## Backups and snapshots

Before risky filesystem changes, agents must consider whether backup or snapshot evidence is required.

Possible evidence includes:

* Restic snapshot;
* filesystem snapshot;
* generated manifest;
* metadata dump;
* file listing;
* checksum list;
* TSV target plan;
* report;
* cold archive validation report.

Backup existence must not be assumed.

When backup status matters, it must be verified from the host.

## Cold archive safety

Cold archives preserve material outside hot libraries.

Agents must not purge hot-library material merely because a cold archive path exists.

Cold archive cleanup requires:

* archive existence check;
* manifest or file listing;
* validation;
* report;
* human approval;
* cleanup plan;
* post-cleanup validation.

Cold archive paths must not be treated as temporary trash.

## Staging safety

Staging areas are operationally meaningful.

Music staging, tagging, ready, imported, incoming, and downloading areas must preserve workflow semantics.

Agents must not bypass staging states.

Agents must not move material from staging to the main library without approved import workflow.

Agents must not clean staging merely because files appear duplicated or old.

## Toolbox source tree safety

`/srv/toolbox/app` is Git-tracked source.

Changes under this path should be made through normal source-control workflow.

Generated artifacts do not belong in `/srv/toolbox/app` unless deliberately intended as documentation, fixtures, examples, test data, or stable knowledge.

Before editing `/srv/toolbox/app`, inspect Git status.

After editing, validate and use the approved Git helpers.

## Shared artifact tree safety

`/srv/toolbox/shared` stores generated artifacts and operational evidence.

It may contain reports, TSVs, snapshots, logs, inventories, manifests, outputs, workdirs, cold archives, and briefs.

Agents must not casually delete old shared artifacts.

Cleanup of `/srv/toolbox/shared` requires retention or cleanup policy.

Large files in shared should be diagnosed before deletion.

## Long-running filesystem operations

Long-running filesystem operations require logging and monitoring strategy.

Examples:

* large copy;
* archive build;
* compression;
* checksum scan;
* metadata scan;
* media split;
* OCR batch;
* cold archive build;
* backup check;
* import or export.

Before starting long-running filesystem work, the plan must specify:

* command;
* expected duration or uncertainty;
* log path;
* output path;
* progress monitoring method;
* validation method;
* interruption behavior;
* whether `nohup`, `nf`, `nflog`, `tblive`, external redirection, `run-job`, or a pipeline should be used.

## Validation after filesystem changes

After filesystem changes, validation should confirm:

* expected files exist;
* unexpected files were not removed;
* counts match plan;
* sizes are plausible;
* permissions are correct;
* ownership is correct where relevant;
* symlinks are intact where relevant;
* services can still access required paths;
* media libraries remain usable where relevant;
* reports and TSVs were generated;
* Git state is clean when source files were changed.

Validation should be recorded when practical.

## Error handling

If a filesystem operation fails, the operator or agent must stop and report:

* command attempted;
* path affected;
* error message;
* partial changes;
* whether retry is safe;
* whether rollback is needed;
* safest next diagnostic step.

Do not continue blindly after partial filesystem changes.

## Anti-drift rule

Agents must not introduce new filesystem structures, staging areas, archive paths, or output locations merely because they are convenient.

Every new filesystem destination must explain:

* function;
* owner or domain;
* relationship with existing Toolbox paths;
* risk of redundancy;
* retention or cleanup expectation;
* validation method;
* rollback or removal path.

Filesystem organization must adapt to the Toolbox, not replace it.
