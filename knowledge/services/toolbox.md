# Toolbox

## Purpose

Toolbox is the operational and curatorial subsystem of the homelab.

It provides scripts, workflows, documentation, evidence generation, validation routines, structured job execution, pipeline automation, and agent-facing knowledge for administrative tasks, media curation, document processing, reporting, and future agent-assisted operations.

Toolbox is not just a collection of scripts. It is the local operating layer that connects human decisions, ChatGPT guidance, Codex/local-agent inspection, shell workflows, generated evidence, Git-tracked knowledge, host-mode diagnostics, and container-mode reproducible processing.

## Service type

`operational_subsystem`

Toolbox is an operational subsystem because it combines:

* source-controlled scripts;
* shared generated artifacts;
* policies;
* documentation;
* shell conventions;
* validation routines;
* `run-job` structured execution;
* pipeline concepts;
* host-mode operational workflows;
* container-mode processing workflows.

## Current role in the homelab

Toolbox is the main structured workspace for operational engineering in the homelab.

Its current role includes:

* documenting the homelab and operational conventions;
* creating and validating scripts;
* producing reports, TSVs, logs, snapshots, inventories, manifests, and ChatGPT briefs;
* supporting Docker, network, firewall, storage, Git, backup, and system diagnostics;
* supporting structured `run-job` and pipeline execution for encapsulated processing tasks;
* preserving the distinction between host-mode operational workflows and container-mode reproducible processing workflows;
* supporting music curation, Beets/MusicBrainz workflows, Stockhausen workflows, staging workflows, and media-library operations;
* preserving operational evidence under `/srv/toolbox/shared`;
* maintaining stable source and knowledge under `/srv/toolbox/app`;
* preparing for controlled Codex/local-agent usage.

Toolbox follows the standard workflow:

* diagnose;
* plan;
* apply;
* validate.

## Important paths

Primary source tree:

* `/srv/toolbox/app`

Generated artifacts and operational evidence:

* `/srv/toolbox/shared`

Host-side job directories:

* `/srv/toolbox/jobs`

Container/runtime job directories may appear as:

* `/toolbox/jobs`

Secrets:

* `/srv/toolbox/secrets`

Models and future local model assets:

* `/srv/toolbox/models`

Important source subdirectories:

* `/srv/toolbox/app/scripts`
* `/srv/toolbox/app/scripts/admin`
* `/srv/toolbox/app/scripts/media`
* `/srv/toolbox/app/scripts/lib`
* `/srv/toolbox/app/scripts/helpers`
* `/srv/toolbox/app/scripts/pipelines`
* `/srv/toolbox/app/bin`
* `/srv/toolbox/app/docs`
* `/srv/toolbox/app/docs/operations`
* `/srv/toolbox/app/docs/media`
* `/srv/toolbox/app/docs/man`
* `/srv/toolbox/app/docs/man1`
* `/srv/toolbox/app/docs/man7`
* `/srv/toolbox/app/knowledge`

Important shared subdirectories include:

* `/srv/toolbox/shared/reports`
* `/srv/toolbox/shared/library-db/raw`
* `/srv/toolbox/shared/library-db/snapshots`
* `/srv/toolbox/shared/logs`
* `/srv/toolbox/shared/inventory`
* `/srv/toolbox/shared/manifests`
* `/srv/toolbox/shared/briefs`
* `/srv/toolbox/shared/artwork-cold-archive`
* `/srv/toolbox/shared/cold-archive`

Generated artifacts belong under `/srv/toolbox/shared`, not under `/srv/toolbox/app`, unless they are deliberately committed as documentation, examples, fixtures, tests, runbooks, policies, or stable knowledge.

## Related services

Toolbox relates to many services and subsystems, including:

* Docker;
* networking;
* Nginx Proxy Manager;
* Samba;
* backup;
* FileBrowser;
* music staging;
* Navidrome;
* Stockhausen workflows;
* media curation;
* Git;
* shell environment;
* future Codex/local-agent workflows.

Toolbox is not isolated from the rest of the homelab. Scripts, workflows, and pipelines may inspect or affect Docker services, media paths, backup paths, configuration paths, generated evidence, and service-facing data.

## Related scripts and workflows

Toolbox scripts are organized by domain.

Administrative scripts include:

* `scripts/admin/backup`
* `scripts/admin/docker`
* `scripts/admin/firewall`
* `scripts/admin/git`
* `scripts/admin/network`
* `scripts/admin/storage`
* `scripts/admin/system`

Media scripts include:

* `scripts/media/library`
* `scripts/media/soulseek`
* `scripts/media/stockhausen`

Shared libraries and helper areas include:

* `scripts/lib`
* `scripts/helpers`
* `scripts/pipelines`

The Toolbox already contains many validated scripts, helpers, libraries, host-mode workflows, `run-job` workflows, and pipeline workflows.

Toolbox automation is not limited to standalone scripts. It includes:

* host-mode scripts for diagnostics, administration, Git routines, media curation, validation, and reporting;
* shared helper code under `scripts/lib`;
* implementation helpers under `scripts/helpers`;
* pipeline definitions under `scripts/pipelines`;
* `run-job` as a structured execution mechanism for encapsulated jobs;
* job directories under `/toolbox/jobs` or `/srv/toolbox/jobs`, depending on runtime context;
* generated job artifacts such as input, work, output, logs, status, and metadata;
* container-mode processing for reproducible document and media pipelines;
* host-mode operation for filesystem-aware diagnostics, curation, service inspection, and administration.

Before proposing a new script, new pipeline, new `run-job` workflow, or manual command sequence, agents must inspect existing scripts, helpers, shared libraries, runbooks, reports, TSVs, inventories, pipelines, and job conventions.

Important validated workflow families include:

* knowledge/context validation;
* knowledge/policies consistency validation;
* services knowledge-layer planning;
* Git stage/check/commit helpers;
* Git post-commit/push helper;
* storage and ATA/pressure diagnostics;
* Docker and network diagnostics;
* firewall diagnostics and hardening routines;
* backup and restore validation workflows;
* `run-job` structured execution for encapsulated processing;
* pipeline execution under `scripts/pipelines`;
* `pdf-ocr` pipeline;
* `image-ocr-translate` pipeline;
* document-processing helpers such as OCR, translate, PDF text extraction, PDF image extraction, image conversion, and ExifTool inspection;
* music-staging diagnostics;
* Beets/MusicBrainz dry-run workflows;
* controlled FLAC metadata write workflows;
* music-staging transition workflows;
* plugin readiness and tagging-audit diagnostics;
* Stockhausen metadata normalization workflows;
* Stockhausen artwork and cold-archive workflows.

## Run-job and pipeline model

`run-job` is the structured job execution model used by Toolbox for encapsulated processing tasks.

It creates job directories and separates operational concerns such as:

* input;
* work;
* output;
* logs;
* status;
* metadata.

Pipelines under `scripts/pipelines/` may use `run-job` when the task benefits from structured execution, reproducibility, isolated work directories, and durable job artifacts.

Known validated pipeline examples include:

* `pdf-ocr`;
* `image-ocr-translate`.

`run-job` is important, but it is not the universal default for every Toolbox task.

Host-mode scripts remain appropriate for:

* diagnostics;
* validation;
* Git routines;
* service inspection;
* filesystem-aware administration;
* media curation workflows;
* reporting and inventory generation.

Container-mode pipelines are appropriate when the task benefits from:

* reproducibility;
* isolated work directories;
* clear input/work/output separation;
* durable job artifacts;
* encapsulated processing dependencies;
* pipeline-style execution.

Agents must decide between plain script, workflow, pipeline, and `run-job` based on task risk, runtime needs, reproducibility, artifact structure, and whether the operation belongs to host-mode or container-mode.

## Related reports, TSVs, inventories, and logs

Toolbox-generated evidence is stored under `/srv/toolbox/shared`.

Common evidence locations include:

* `/srv/toolbox/shared/reports/system`
* `/srv/toolbox/shared/reports/git`
* `/srv/toolbox/shared/reports/storage`
* `/srv/toolbox/shared/reports/network`
* `/srv/toolbox/shared/reports/docker`
* `/srv/toolbox/shared/reports/media`
* `/srv/toolbox/shared/reports/media/staging`
* `/srv/toolbox/shared/reports/media/stockhausen`
* `/srv/toolbox/shared/library-db/raw/system`
* `/srv/toolbox/shared/library-db/raw/git`
* `/srv/toolbox/shared/library-db/raw/media`
* `/srv/toolbox/shared/library-db/raw/media/staging`
* `/srv/toolbox/shared/library-db/snapshots`

Reports and TSVs are not secondary byproducts. They are part of the operational memory of the Toolbox.

The current observed script inventory is generated by:

* `scripts/admin/system/diagnose-toolbox-script-inventory.sh`

The script inventory produces a human report and a TSV under:

* `/srv/toolbox/shared/reports/system/`
* `/srv/toolbox/shared/library-db/raw/system/`

Agents should consult the latest script inventory before proposing new scripts, new workflows, new pipelines, new `run-job` usage, or manual command sequences.

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

Important operational documentation:

* `docs/operations/toolbox_architecture_reconciliation.md`
* `docs/operations/toolbox_git_routine.md`
* `docs/operations/toolbox_logging_policy.md`
* `docs/operations/toolbox_manpages_policy.md`
* `docs/operations/toolbox_output_destinations_policy.md`
* `docs/operations/toolbox_reports_policy.md`
* `docs/operations/toolbox_runtime_profiles.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_scripts_lib_policy.md`
* `docs/operations/toolbox_shell_environment.md`
* `docs/operations/toolbox_storage_policy.md`

Additional Toolbox docs may include:

* `docs/toolbox_cli_conventions.md`
* `docs/toolbox_design_rationale.md`
* `docs/toolbox_development_guide.md`
* `docs/toolbox_directory_layout.md`
* `docs/toolbox_environment_spec.md`
* `docs/toolbox_operator_guide.md`
* `docs/toolbox_pipeline_spec.md`
* `docs/toolbox_roadmap.md`
* `docs/man7/toolbox.7`

Media-specific documents include:

* `docs/media/stockhausen_metadata_policy.md`
* `docs/media/stockhausen_gold_model_stimmung.md`

## Sensitive operations

Sensitive Toolbox operations include:

* changing files under `/srv/toolbox/app`;
* creating new script directories;
* changing script conventions;
* changing `scripts/lib`;
* changing `run-job` behavior;
* changing pipeline behavior under `scripts/pipelines`;
* changing host-mode/container-mode boundaries;
* changing output destinations;
* changing validation rules;
* changing Git workflow helpers;
* changing policies under `knowledge/policies`;
* changing service maps under `knowledge/services`;
* modifying generated evidence under `/srv/toolbox/shared`;
* deleting old reports, TSVs, logs, snapshots, inventories, manifests, job outputs, or pipeline outputs;
* running apply scripts;
* running long jobs;
* running `run-job` jobs that modify files or produce large outputs;
* modifying media metadata or media files through Toolbox scripts;
* modifying Docker, firewall, Samba, backup, or networking through Toolbox scripts.

Sensitive operations require the applicable diagnose, plan, apply, validate workflow.

## Read-only inspection allowed

Read-only inspection is allowed by default when bounded and relevant.

Allowed read-only actions include:

* listing Toolbox source files;
* reading `knowledge/`, `docs/`, and script files;
* checking Git status;
* inspecting existing reports and TSVs;
* inspecting generated validation reports;
* searching for references across `knowledge/`, `docs/`, and `scripts/`;
* reading script headers and comments;
* checking whether scripts use `set -u`, `log()`, `fail()`, reports, TSVs, and shared libraries;
* inspecting `scripts/pipelines`;
* inspecting references to `run-job`;
* inspecting documented job directory conventions;
* inspecting manpage locations;
* inspecting known generated evidence paths.

Read-only inspection must not be confused with authorization to edit, execute apply scripts, run mutation pipelines, delete artifacts, or change host state.

## Read-only collection plan

A local agent may collect the following information in read-only mode:

* directory layout under `/srv/toolbox/app`;
* list of scripts under `scripts/`;
* list of pipeline definitions under `scripts/pipelines/`;
* list of docs under `docs/`;
* list of knowledge files under `knowledge/`;
* references between `knowledge/`, `docs/`, and `scripts/`;
* references to `run-job` across scripts, docs, and knowledge files;
* existing job conventions and documented job directory structure;
* previous reports or docs describing pipeline execution;
* available reports and TSVs under `/srv/toolbox/shared`;
* Git status;
* script metadata such as executable bit, phase prefix, domain, and use of common helpers;
* references to reports, TSVs, snapshots, logs, manifests, job outputs, pipeline outputs, and briefs;
* references to sensitive paths such as `/srv/media`, `/srv/compose`, and `/srv/toolbox/shared`;
* latest Toolbox script inventory report and TSV.

A local agent must not in read-only mode:

* modify files;
* stage or commit Git changes;
* run apply scripts;
* launch `run-job` tasks;
* run pipelines;
* change permissions;
* delete generated artifacts;
* move reports or TSVs;
* change service configuration;
* change media files or metadata;
* start long-running jobs.

Read-only collection should produce a report and TSV when the inspection is non-trivial.

## Actions requiring approval

The following require explicit approval:

* editing files under `/srv/toolbox/app`;
* creating new scripts;
* creating new pipeline definitions;
* creating new `run-job` workflows;
* creating new service documents;
* creating new policies;
* changing validation scripts;
* changing output destinations;
* changing `scripts/lib`;
* changing job directory conventions;
* running apply scripts;
* launching long-running jobs;
* launching `run-job`;
* launching pipelines;
* deleting or cleaning `/srv/toolbox/shared`;
* changing Git-tracked files;
* committing changes;
* pushing changes;
* installing or removing packages;
* changing Docker, network, firewall, Samba, backup, or media behavior through Toolbox.

Approval must be specific to the proposed action.

A general instruction to continue is not approval for unrelated changes.

## Known historical lessons

Toolbox has accumulated important operational lessons through prior homelab, media, Stockhausen, Git, shell, filesystem, Docker, Samba, backup, and reporting work.

Service-specific lessons should be summarized here only when they directly affect Toolbox operation.

Detailed historical lessons should be consolidated under:

- `knowledge/architecture/historical-operational-lessons.md`

Until that document exists, agents must treat historical lessons mentioned in context, policies, service maps, reports, and validated scripts as operationally relevant and must not ignore them.

## Open questions

Toolbox has open architectural and operational questions that should be resolved incrementally.

This service map should list only open questions that directly affect the Toolbox service itself.

Broader open questions should be consolidated under a future architecture document, such as:

- `knowledge/architecture/open-questions.md`

Current known areas for future clarification include Codex/local-agent usage, script inventory maintenance, ChatGPT briefs, `scripts/lib` evolution, `run-job` scope, service-specific runbooks, knowledge graph representation, and historical lessons consolidation.

## Source of truth

Stable source and knowledge:

* `/srv/toolbox/app`

Generated operational evidence:

* `/srv/toolbox/shared`

Structured job execution may use:

* `/srv/toolbox/jobs`
* `/toolbox/jobs`

Current host state must be verified from the host when accuracy matters.

Examples of current state that must be verified include:

* existing scripts;
* existing pipelines;
* Git status;
* latest reports;
* latest TSVs;
* active containers;
* active mounts;
* current permissions;
* current backup status;
* current network exposure;
* current media staging state;
* current job directories;
* current pipeline behavior.

Agents must not treat memory, old reports, or chat history as proof of current host state.
