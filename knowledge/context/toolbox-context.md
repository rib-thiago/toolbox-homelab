# Toolbox Context

This file provides the minimum stable context an AI agent needs before working on the Toolbox.

It is not a full inventory of scripts. Current script lists, Git state, reports, and generated artifacts must be verified from the host before operational decisions.

## Purpose

The Toolbox is the operational automation, documentation, and workflow system for the homelab.

It exists to make homelab work more repeatable, auditable, scriptable, and agent-readable.

The Toolbox should not be treated as a random script directory. It is a Unix-like operational environment with conventions, runtime modes, reports, pipelines, manpages, shell helpers, and Git-based change tracking.

## Primary locations

Stable, versioned Toolbox source:

* `/srv/toolbox/app/`

Generated Toolbox artifacts:

* `/srv/toolbox/shared/`

Runtime job areas:

* `/srv/toolbox/jobs/`
* other Toolbox job or shared job directories when explicitly configured

Important source subdirectories:

* `bin/`
* `scripts/`
* `scripts/admin/`
* `scripts/helpers/`
* `scripts/lib/`
* `scripts/media/`
* `scripts/pipelines/`
* `docs/`
* `docs/man1/`
* `docs/man7/`
* `knowledge/`

## Core philosophy

The Toolbox follows a Unix-like philosophy:

* small tools with clear responsibilities;
* composable commands;
* explicit inputs and outputs;
* scripts that can be inspected and reused;
* pipelines for multi-step processing;
* structured jobs for encapsulated work;
* reports and TSVs for auditability;
* manpages for command and concept documentation;
* Git history for durable change tracking;
* conservative execution with validation.

Agents must respect this philosophy and must not replace it with ad hoc hidden automation.

## Runtime model

The Toolbox is hybrid.

Host-mode is used for operations that must inspect the live homelab state, such as Docker, firewall, storage, Git, backup, media staging, and service diagnostics.

Container-mode is used for encapsulated processing, especially document/media processing and reproducible pipelines.

Agents must not assume all Toolbox work runs in one runtime. The correct runtime depends on the task.

## Standard workflow

The standard operational workflow is:

1. Diagnose
2. Plan
3. Apply
4. Validate

This pattern is central.

Diagnostic scripts should inspect and report without changing state.

Plan scripts should describe intended changes, risks, inputs, outputs, and validation criteria.

Apply scripts should perform approved changes only.

Validate scripts should confirm the result and produce evidence.

Agents must not skip directly to apply.

## Scripts layout

Administrative scripts are organized under:

* `scripts/admin/backup/`
* `scripts/admin/docker/`
* `scripts/admin/firewall/`
* `scripts/admin/git/`
* `scripts/admin/network/`
* `scripts/admin/storage/`
* `scripts/admin/system/`

Media and library scripts are organized under:

* `scripts/media/library/`
* `scripts/media/soulseek/`
* `scripts/media/stockhausen/`

Reusable shell library code belongs under:

* `scripts/lib/`

Helper implementations may exist under:

* `scripts/helpers/`

Pipelines belong under:

* `scripts/pipelines/`

Agents must respect the existing layout and must not create new script areas without explaining function, destination, relationship with existing structure, and redundancy risk.

## Existing scripts and workflows

The Toolbox already contains many operational scripts, helpers, libraries, and workflows created through prior work.

Before proposing a new script, new workflow, or long ad hoc command sequence, agents must inspect whether an existing Toolbox script, helper, library function, runbook, plan/apply/validate workflow, `run-job` pipeline, or generated report already covers the task.

Existing scripts may be used when appropriate, but they must still be reviewed before execution, especially when they affect sensitive paths, services, media, backups, Git, or operational configuration.

Agents should prefer:

- existing validated scripts over new scripts;
- existing scripts over manual command sequences;
- existing shared library functions over script-local utility functions;
- existing reports and TSVs over repeated raw terminal inspection.

If no suitable existing workflow exists, the agent may propose a new one, but must explain why existing assets are insufficient.


## Script conventions

Toolbox shell scripts should generally follow these conventions:

* use Bash intentionally;
* prefer `set -u`;
* check `scripts/lib/` before creating new helper functions;
* reuse existing library functions whenever they already solve the problem;
* add new shared functions to `scripts/lib/` only when there is a clear reuse case;
* avoid duplicating logic that already exists in the Toolbox libraries;
* use `log()` and `fail()` patterns where available;
* write reports and TSVs to `/srv/toolbox/shared/`;
* avoid hidden destructive behavior;
* separate diagnose, plan, apply, and validate phases when risk justifies it;
* produce human-readable reports for review;
* produce structured TSVs when useful;
* use snapshots or backups before risky changes;
* preserve idempotence where practical.

Important principle:

* agents should prefer using and extending the existing Toolbox libraries rather than creating script-local utility functions;
* new helper functions should be justified by reuse, not by convenience within a single script;
* `scripts/lib/` is the canonical location for shared shell functionality.

Syntax validation should use the established shell workflow.

Known shell helper:

* `mkxcheck`

`mkxcheck` should be preferred when validating executable shell scripts interactively, because it preserves the user's established shell ergonomics.

## Long-running commands and logs

Long-running commands must not be treated as ordinary foreground terminal commands when they may take significant time, produce substantial output, or risk being interrupted by a terminal/session disconnect.

For long-running Toolbox work, agents should prefer an explicit execution and logging strategy.

Known principles:

* use `nohup`, `nf`, `nflog`, `tblive`, `tail -f`, or equivalent established shell helpers when appropriate;
* create the log directory before starting long-running commands;
* write logs under an appropriate path in `/srv/toolbox/shared/`;
* make logs easy to follow during execution;
* avoid losing output in the interactive terminal scrollback;
* avoid embedding `tee` inside scripts unless it is a deliberate design choice;
* prefer external redirection/log capture for ad hoc long-running operations;
* prefer `run-job` when the task has structured inputs, work directories, logs, outputs, and repeatable pipeline semantics.

Agents must not launch long-running apply or processing tasks without explaining:

* expected command;
* output/log path;
* how progress will be monitored;
* how success or failure will be validated;
* what should happen if the terminal disconnects or the process is interrupted.

For long-running work, the operational goal is not only to run the command, but to make the execution observable, recoverable, and auditable.

## Reports, TSVs, snapshots, and artifacts

Generated artifacts do not belong in the source tree unless explicitly intended as fixtures or documentation.

Generated reports usually belong under:

* `/srv/toolbox/shared/reports/`

Generated TSVs and raw structured outputs usually belong under:

* `/srv/toolbox/shared/library-db/raw/`

Snapshots usually belong under:

* `/srv/toolbox/shared/library-db/snapshots/`
* other explicit snapshot directories under `/srv/toolbox/shared/`

Agent-generated reports and ChatGPT briefs should also go under `/srv/toolbox/shared/`, using an explicit domain path.

The source tree should contain the method. The shared tree should contain the evidence.

## run-job and pipelines

`run-job` is part of the Toolbox execution model.

It exists to run structured jobs with isolated job directories, logs, metadata, inputs, work areas, and outputs.

Pipelines are used for composed processing workflows.

Important principle:

* not every script must use `run-job`;
* workflows with structured inputs, work directories, outputs, logs, or repeatable processing are good candidates for `run-job`;
* host-state diagnostics may remain plain scripts when that is safer and clearer.

Agents must not ignore `run-job` or pipelines when designing new repeatable workflows.

Agents must also not force `run-job` into simple administrative diagnostics where it would add unnecessary complexity.

## Manpages and documentation

The Toolbox uses Unix manpage-style documentation.

Known manpage areas:

* `docs/man1/`
* `docs/man7/`

Manpages document commands and broader concepts.

The host-side manpage access workflow has been treated as part of the Toolbox architecture.

Agents should preserve the manpage/groff direction and avoid replacing it with scattered Markdown-only help when command-style documentation is appropriate.

Long-form human documentation may live under `docs/`.

Agent-oriented operational context belongs under `knowledge/`.

## Git workflow

The Toolbox source tree is Git-tracked.

When working inside `/srv/toolbox/app`, agents must inspect Git state before changes.

Preferred status alias or command may be user-specific, but scripts must not depend on shell aliases.

The preferred commit helper is:

```
apply-toolbox-git-stage-check-commit.sh \
  -m "commit message" \
  -- \
  path/to/file1 \
  path/to/file2
```

When the intended routine includes pushing to the remote, use:

```
apply-toolbox-git-post-commit.sh --push
```

The agent must not invent a different interface for these helpers.

The helper prompts for explicit confirmation before committing or pushing.

Git reports and TSVs are generated under `/srv/toolbox/shared/`.

## Shell ergonomics

The user has established shell helpers and aliases for Toolbox work.

Relevant helpers include:

* `mkxcheck`
* `latest-file`
* `tsvless`
* `tsvlatest`
* `rptless`
* `rptlatest`
* `tblatest`
* `nflog`
* `tblive`

Agents may refer to these helpers in interactive guidance when appropriate.

Scripts themselves should not depend on interactive shell aliases unless deliberately designed as shell-environment helpers.

## Important Toolbox domains

The Toolbox currently supports or has supported work in these domains:

* Docker and homelab service diagnostics;
* firewall and network diagnostics;
* backup and restore routines;
* storage and ATA/disk health diagnostics;
* Git workflow automation;
* media library inventory;
* music staging and Beets workflows;
* Soulseek/slskd staging support;
* Stockhausen metadata normalization and preservation;
* artwork cold archive workflows;
* document/OCR/media processing through Unix-like commands and pipelines;
* operational context and agent-readiness work.

Agents must not treat these domains as isolated unless the task explicitly is isolated.

## Music and media workflows

Music and media workflows are sensitive.

Known principles:

* preserve archival masters where possible;
* avoid uncontrolled duplicate compatibility libraries;
* use staging before import;
* treat metadata writes as sensitive;
* validate before moving or importing;
* preserve important auxiliary material through cold archive workflows when appropriate;
* use reports, TSVs, and snapshots for traceability.

The music staging state model includes curated transitions such as reviewing, tagging, ready, and imported.

Agents must not bypass staging or write metadata without an approved plan.

## Stockhausen workflow

The Stockhausen workflow is a major historical Toolbox case study.

Important lessons include:

* do not trust corrupted or displaced tags blindly;
* infer canonical models from filesystem and validated references when necessary;
* use `metaflac` for reliable FLAC Vorbis tag writing when appropriate;
* preserve MusicBrainz identifiers when available;
* distinguish performers from composer/artist fields;
* use cold archive workflows for heavy artwork and auxiliary assets;
* validate before purge or cleanup;
* use block-based normalization, reports, TSVs, and snapshots;
* avoid scope drift into enrichment, dashboards, or unrelated work unless explicitly approved.

Detailed Stockhausen context belongs in `knowledge/services/stockhausen-workflow.md` or architecture records, not in this entry file.

## Agent-assisted operation

The Toolbox is being prepared for agent-assisted workflows.

The agent must work inside the existing Toolbox model:

* read `knowledge/context/agent-entrypoint.md` before any task;
* read `knowledge/` before acting;
* use read-only diagnostics first;
* generate plans before changes;
* ask for approval before apply;
* generate reports and briefs under `/srv/toolbox/shared/`;
* use existing helpers and conventions;
* avoid creating parallel systems;
* avoid relying on chat memory as the source of truth.

The intended direction is not to replace ChatGPT or human review.

The intended direction is to let local agents inspect files, commands, reports, and outputs directly, then generate concise briefs for ChatGPT or human strategic review.

## What must be verified

Before operational decisions, agents must verify from the host:

* current Git status;
* current script layout;
* current helper availability;
* current reports and TSV locations;
* current shared directory structure;
* current Docker/service state when relevant;
* current media staging state when relevant;
* current backup and storage state when relevant.

Do not assume current host state from memory alone.

## Human decision required

Human approval is required before:

* creating new top-level Toolbox structures;
* changing script layout conventions;
* changing `run-job` or pipeline conventions;
* changing report, TSV, or snapshot conventions;
* running apply scripts;
* changing files under `/srv/media`;
* writing music metadata;
* changing backup, firewall, Docker, Samba, FileBrowser, Tailscale, or reverse proxy configuration;
* committing or pushing changes;
* installing, removing, or upgrading packages.

## Anti-drift rule

Agents must not introduce new structures, naming schemes, workflows, or abstractions merely because they are common in generic agent projects.

Every proposed addition must explain:

* function;
* destination;
* relationship with the existing Toolbox;
* risk of redundancy;
* validation method;
* rollback or cleanup path.
