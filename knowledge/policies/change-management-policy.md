# Change Management Policy

This policy defines how changes must be proposed, approved, applied, validated, recorded, and reviewed in the Toolbox and homelab.

It applies to human-assisted work, ChatGPT-assisted work, Codex/local-agent work, scripts, documentation changes, service changes, media workflows, and operational automation.

This policy must be read together with:

* `knowledge/context/agent-entrypoint.md`
* `knowledge/context/homelab-context.md`
* `knowledge/context/toolbox-context.md`
* `knowledge/policies/agent-safety-policy.md`

## Primary principle

Changes must be deliberate, reviewable, reversible where practical, and supported by evidence.

The standard workflow is:

1. Diagnose
2. Plan
3. Apply
4. Validate

The workflow must not skip directly to apply when the task may affect services, configuration, data, media files, backups, firewall rules, metadata, Git-tracked source, or operational conventions.

## Related Toolbox policies

This policy does not replace existing Toolbox policies, conventions, or operational documentation.

Agents and operators must consult applicable Toolbox documents before planning or applying changes.

Authoritative related documents include:

* `docs/operations/toolbox_architecture_reconciliation.md`
* `docs/operations/toolbox_git_routine.md`
* `docs/operations/toolbox_logging_policy.md`
* `docs/operations/toolbox_manpages_policy.md`
* `docs/operations/toolbox_reports_policy.md`
* `docs/operations/toolbox_runtime_profiles.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_scripts_lib_policy.md`
* `docs/operations/toolbox_shell_environment.md`
* `docs/operations/toolbox_storage_policy.md`
* `docs/media/stockhausen_metadata_policy.md`
* `docs/media/stockhausen_gold_model_stimmung.md`

Additional Toolbox documentation that may be relevant includes:

* `docs/toolbox_cli_conventions.md`
* `docs/toolbox_design_rationale.md`
* `docs/toolbox_development_guide.md`
* `docs/toolbox_directory_layout.md`
* `docs/toolbox_environment_spec.md`
* `docs/toolbox_operator_guide.md`
* `docs/toolbox_pipeline_spec.md`
* `docs/toolbox_roadmap.md`
* `docs/man7/toolbox.7`

If a conflict exists between this policy and an older document, the operator or agent must stop and ask for human review instead of choosing one silently.

If a document appears stale, incomplete, or inconsistent with observed host state, the inconsistency must be reported and reviewed.

## Change classes

Changes are classified into five classes:

1. Documentation-only changes
2. Script or tooling changes
3. Generated-artifact changes
4. Operational configuration changes
5. Data or media changes

When uncertain, classify the change at the higher-risk level.

## Documentation-only changes

Documentation-only changes include edits to:

* `knowledge/`
* `docs/`
* manpages;
* policy files;
* runbooks;
* architecture records;
* Markdown context files.

Documentation-only changes may still require review when they alter operational rules, safety rules, naming conventions, directory conventions, agent behavior, or workflow semantics.

Documentation changes should be validated with appropriate checks before commit.

## Script or tooling changes

Script or tooling changes include edits to:

* `bin/`
* `scripts/`
* `scripts/admin/`
* `scripts/media/`
* `scripts/lib/`
* `scripts/helpers/`
* `scripts/pipelines/`

Before proposing a new script or manual command sequence, agents must inspect whether an existing Toolbox script, helper, shared library function, runbook, plan/apply/validate workflow, `run-job` pipeline, report, or TSV already covers the task.

Existing scripts may be reused when appropriate, but execution must still follow the applicable safety level, approval rule, and validation path.

These changes require syntax checks and, when practical, test execution or dry-run validation.

For shell scripts, use the established validation workflow.

Known interactive helper:

* `mkxcheck`

Scripts must follow Toolbox conventions:

* prefer `set -u`;
* use `log()` and `fail()` patterns where available;
* check `scripts/lib/` before creating new helper functions;
* reuse existing libraries when appropriate;
* write generated reports and TSVs under `/srv/toolbox/shared/`;
* separate diagnose, plan, apply, and validate phases when risk justifies it.

## Generated-artifact changes

Generated artifacts include:

* reports;
* TSVs;
* logs;
* snapshots;
* inventories;
* temporary outputs;
* ChatGPT briefs.

Generated artifacts belong under `/srv/toolbox/shared/`.

Generated artifacts should not normally be committed to the Toolbox source tree unless explicitly intended as fixtures, examples, or documentation.

## Operational configuration changes

Operational configuration changes include changes to:

* Docker Compose files;
* container configuration;
* Nginx Proxy Manager;
* Tailscale;
* Samba;
* FileBrowser;
* firewall, UFW, or DOCKER-USER rules;
* systemd services or timers;
* backup configuration;
* monitoring configuration;
* mounted storage or external disks;
* package installation or removal.

These changes require an explicit plan, human approval, validation steps, and a rollback or recovery strategy where practical.

Operational configuration changes must not be performed as casual ad hoc edits.

## Data or media changes

Data or media changes include changes to:

* `/srv/media/`;
* music libraries;
* music staging;
* photos;
* raw photos;
* videos;
* ebooks;
* PDFs;
* metadata;
* cold archives;
* imported or curated collections.

These changes are high sensitivity.

Agents and operators must not delete, move, rename, retag, rewrite, transcode in place, purge, or bulk-transform data or media without an explicit approved plan and validation path.

Metadata writes are treated as data changes.

Music-staging transitions must preserve the curated workflow and must not be bypassed.

## Required diagnose phase

The diagnose phase must identify the current state before proposing changes.

Depending on the task, diagnosis may include:

* Git status;
* existing Toolbox scripts or workflows that may already cover the task;
* affected files;
* affected services;
* current containers;
* current logs;
* current reports or TSVs;
* current staging state;
* current backup state;
* current disk and mount state;
* current configuration files;
* current relevant documentation.

Diagnosis must distinguish between:

* stable knowledge;
* observed state;
* inference;
* pending validation;
* human decision.

## Required plan phase

A plan must explain:

* goal;
* reason for change;
* affected paths;
* affected services;
* affected data;
* risk level;
* expected files or configuration changes;
* generated artifacts;
* validation method;
* rollback or cleanup path;
* whether human approval is required.

For sensitive changes, the plan must be explicit enough that the operator can reject, revise, or approve it before apply.

## Required apply phase

The apply phase may happen only after approval when approval is required.

Apply steps must follow the approved plan.

If the apply phase deviates from the approved plan, the operator or agent must stop and report the deviation.

Apply scripts must not hide destructive behavior.

Long-running apply or processing tasks require an execution and logging strategy.

## Required validate phase

The validate phase must confirm whether the change achieved its goal.

Validation may include:

* script syntax checks;
* report inspection;
* TSV inspection;
* Git diff checks;
* Git status checks;
* service health checks;
* log inspection;
* file count checks;
* metadata checks;
* backup checks;
* restore checks;
* sample playback or reader checks;
* human review.

Validation must produce evidence when practical.

Evidence should be stored under `/srv/toolbox/shared/`.

## Git and source control

Changes under `/srv/toolbox/app` must use the Toolbox Git workflow.

Before changes, inspect Git status.

The preferred commit helper is:

```
apply-toolbox-git-stage-check-commit.sh \
  -m "commit message" \
  -- \
  path/to/file1 \
  path/to/file2
```

When pushing is intended, use:

```
apply-toolbox-git-post-commit.sh --push
```

The operator must type the required confirmation prompts.

Agents must not invent a different helper interface.

Agents must not use raw `git add`, `git commit`, or `git push` as the default path when Toolbox helpers are available.

## Reports, TSVs, and evidence

Operational changes should generate evidence.

Evidence may include:

* reports;
* TSVs;
* logs;
* snapshots;
* validation summaries;
* before/after comparisons;
* ChatGPT briefs.

Evidence belongs under `/srv/toolbox/shared/`.

The source tree should contain the method. The shared tree should contain the evidence.

## Long-running changes

Long-running changes must not be launched as ordinary foreground commands unless explicitly approved.

Before starting long-running work, the plan must specify:

* command;
* expected duration or uncertainty;
* log path;
* output path;
* progress monitoring method;
* validation method;
* interruption behavior;
* whether `nohup`, `nf`, `nflog`, `tblive`, external redirection, or `run-job` should be used.

For repeatable structured workflows, consider `run-job` or a pipeline.

For simple host-state diagnostics, a plain script may be safer and clearer.

## Rollback and recovery

For changes with meaningful risk, the plan must explain rollback or recovery.

Rollback may include:

* Git restore or revert;
* restoring a configuration file;
* reverting a Docker Compose change;
* restoring from backup;
* using a snapshot;
* reversing a metadata operation from a saved report;
* moving files back from a staged location;
* disabling a new service;
* reverting a firewall or proxy rule.

If rollback is not practical, the plan must say so explicitly and explain the risk.

## Approval rules

Human approval is required before:

* applying operational configuration changes;
* modifying `/srv/media/`;
* changing backup behavior;
* changing firewall or network exposure;
* changing Docker service configuration;
* changing Samba, FileBrowser, Tailscale, or reverse proxy behavior;
* writing media metadata;
* running apply scripts;
* launching long-running processing jobs;
* committing or pushing changes;
* installing, removing, or upgrading packages;
* changing Toolbox structure or conventions.

Approval must be specific to the proposed action.

A general instruction to “continue” is not approval for unrelated changes.

## ChatGPT handoff

When work is handed from a local agent back to ChatGPT, the handoff should use a concise brief instead of raw logs.

A good brief includes:

* task;
* context files read;
* files inspected;
* commands run;
* reports generated;
* relevant findings;
* risks;
* decisions needed;
* proposed next step;
* paths to full evidence.

The goal is to reduce upload and copy/paste while preserving review quality.

## Error handling

If a change fails, the operator or agent must stop and report:

* attempted action;
* failure point;
* observed error;
* affected files or services;
* whether state may be partially changed;
* generated logs or reports;
* safest next diagnostic step.

Do not continue blindly after errors in apply, Git, backup, firewall, Docker, service, filesystem, media, or metadata operations.

## Anti-drift rule

Changes must not introduce new structures, naming schemes, workflows, or abstractions merely because they are common in generic agent projects.

Every proposed addition must explain:

* function;
* destination;
* relationship with the existing Toolbox;
* risk of redundancy;
* validation method;
* rollback or cleanup path.

The change-management process must adapt to the Toolbox, not replace it.
