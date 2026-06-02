# Agent Safety Policy

This policy defines safety rules for AI agents working on the Toolbox and the homelab.

It applies to Codex, ChatGPT-assisted workflows, local agents, future automation agents, and any tool that can inspect or modify files, commands, services, configuration, or generated artifacts.

This policy must be read together with:

* `knowledge/context/agent-entrypoint.md`
* `knowledge/context/homelab-context.md`
* `knowledge/context/toolbox-context.md`

## Primary principle

The default agent mode is read-only.

An agent must not change the homelab, the Toolbox, user data, service configuration, media files, metadata, firewall rules, backup behavior, or Git history unless the work has moved through an approved plan.

The standard operational workflow is:

1. Diagnose
2. Plan
3. Apply
4. Validate

Skipping directly to apply is not allowed.

## Related Toolbox policies

This policy does not replace existing Toolbox policies, conventions, or operational documentation.

Agents must consult the applicable Toolbox policy documents before planning or applying changes.

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

If a conflict exists between this policy and an older document, the agent must stop and ask for human review instead of choosing one silently.

If a document appears stale, incomplete, or inconsistent with observed host state, the agent must report the inconsistency and request review.

## Safety levels

Agent actions are classified into four safety levels:

1. Allowed read-only actions
2. Planning actions
3. Approval-required actions
4. Forbidden actions

When uncertain, the agent must choose the more restrictive category.

## Allowed read-only actions

The following actions are allowed by default when they do not modify state:

* read files under `/srv/toolbox/app`;
* list files and directories;
* inspect Git status;
* inspect existing reports and TSVs under `/srv/toolbox/shared`;
* inspect Toolbox scripts, helpers, libraries, runbooks, pipelines, and documentation;
* inspect command help output;
* inspect service status with read-only commands;
* inspect Docker state with read-only commands;
* inspect logs with bounded output;
* inspect disk and mount state;
* inspect backup status without modifying repositories;
* generate diagnostic analysis in the chat or in an approved report path.

Read-only commands should still be bounded and intentional.

Agents should avoid dumping excessive logs or large file contents into context.

## Planning actions

The following actions may be proposed in a plan but must not be executed until approved:

* creating or editing files under `/srv/toolbox/app`;
* creating new Toolbox scripts;
* creating new `knowledge/` files;
* changing documentation or policies;
* creating new reports or generated artifacts;
* changing script layout;
* changing pipeline or `run-job` conventions;
* running apply scripts;
* changing Git-tracked files;
* staging, committing, or pushing changes;
* installing, removing, or upgrading packages;
* changing service configuration;
* changing media metadata;
* moving, renaming, deleting, or transforming user data.

A plan must explain:

* goal;
* whether an existing Toolbox script, helper, workflow, report, or TSV already covers the task;
* affected paths;
* affected services;
* expected changes;
* safety level;
* validation method;
* rollback or cleanup path;
* human decision required.

## Approval-required actions

Explicit human approval is required before:

* modifying anything under `/srv/media`;
* writing, rewriting, deleting, moving, renaming, or bulk-transforming media files;
* writing or rewriting music metadata;
* changing music-staging state;
* importing albums into the main music library;
* purging hot-library material after cold-archive creation;
* changing Docker Compose files;
* restarting, stopping, recreating, or removing containers;
* changing Nginx Proxy Manager configuration;
* changing Tailscale configuration;
* changing Samba shares or permissions;
* changing FileBrowser exposure, permissions, or bind address;
* changing firewall, UFW, or DOCKER-USER rules;
* changing backup repositories, schedules, retention, credentials, restore paths, or timers;
* changing systemd services or timers;
* installing, removing, or upgrading packages;
* running apply scripts;
* running long-running processing jobs;
* committing or pushing Git changes.

Approval must be specific to the proposed action. General trust in the agent is not approval.

## Forbidden actions

Agents must not perform the following actions:

* run destructive commands without explicit approved plan;
* run recursive deletion against `/srv`, `/srv/media`, `/srv/toolbox`, `/home`, or system directories;
* wipe disks, partitions, filesystems, repositories, or backup media;
* destroy backups or snapshots;
* modify backup secrets or credentials without explicit approval;
* expose services publicly without explicit architecture review;
* bypass staging workflows for music/media;
* silently rewrite media metadata;
* silently change file ownership or permissions in media libraries;
* force-push Git history;
* commit or push without the approved Toolbox Git helpers;
* create parallel unmanaged structures outside the Toolbox model;
* hide uncertainty;
* continue after a serious error without reporting it.

If an agent proposes an action that resembles a forbidden action, it must stop and ask for human review.

## Sensitive areas

The following areas are sensitive:

* `/srv/media/`
* `/srv/compose/`
* `/srv/toolbox/app/`
* `/srv/toolbox/shared/`
* `/srv/toolbox/secrets/`
* backup repositories and mounted backup media;
* Samba configuration and shares;
* Tailscale configuration;
* Nginx Proxy Manager configuration;
* UFW and DOCKER-USER rules;
* Docker Compose files;
* systemd services and timers;
* music-staging directories;
* cold-archive directories;
* Git remotes and branch history.

Sensitivity does not mean the agent cannot inspect these areas. It means modification requires a plan and approval.

## Long-running work

Long-running commands require an execution and logging strategy.

Before launching long-running work, the agent must explain:

* command to be run;
* expected duration or uncertainty;
* log path;
* output path;
* how progress will be monitored;
* how success will be validated;
* what happens if the terminal disconnects;
* whether `nohup`, `nf`, `nflog`, `tblive`, external redirection, or `run-job` should be used.

The agent must not launch long-running apply or processing jobs as ordinary foreground commands unless explicitly approved.

## Git safety

Inside `/srv/toolbox/app`, agents must inspect Git state before changes.

The approved commit helper is:

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

Agents must not invent a different helper interface.

Agents must not run raw `git add`, `git commit`, or `git push` as the default path when Toolbox helpers are available.

## Reports and briefs

Agents should produce structured evidence for operational work.

Generated reports, TSVs, snapshots, logs, inventories, and ChatGPT briefs belong under `/srv/toolbox/shared/`.

Agents should prefer concise briefs over raw log dumps when handing work back to ChatGPT.

A brief should include:

* task;
* inspected files;
* commands run;
* relevant findings;
* risks;
* decisions needed;
* proposed next step;
* paths to full reports or TSVs.

## Error handling

When an error occurs, the agent must stop and report:

* what was attempted;
* what failed;
* what changed, if anything;
* whether state may be inconsistent;
* where logs or reports are stored;
* safest next diagnostic step.

The agent must not continue blindly after errors in apply, backup, media, filesystem, Git, firewall, Docker, or service operations.

## Uncertainty handling

The agent must classify uncertainty as one or more of:

* known from stable knowledge;
* derived from observed state;
* inferred;
* needs host verification;
* needs internet verification;
* needs human decision.

If a decision depends on uncertain state, the agent must ask for verification or run read-only diagnostics before proceeding.

## Anti-drift rule

Agents must not introduce new structures, naming schemes, workflows, or abstractions merely because they are common in generic agent projects.

Every proposed addition must explain:

* function;
* destination;
* relationship with the existing Toolbox;
* risk of redundancy;
* validation method;
* rollback or cleanup path.

The agent must adapt to the Toolbox, not replace it.
