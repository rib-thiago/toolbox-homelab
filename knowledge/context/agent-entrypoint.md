# Agent Entrypoint

This is the first file an AI agent must read before working on the Toolbox or the homelab.

The purpose of this file is to define the minimum operating contract for agent-assisted work. It does not replace human approval, operational policies, runbooks, scripts, reports, or observed inventories.

## Primary rule

The agent must treat `knowledge/` as the central operational context layer.

The agent must not treat chat history, model memory, terminal output, or generated reports as the sole source of truth.

## Required reading order

Before starting any task, the agent must read:

1. `knowledge/context/agent-entrypoint.md`
2. `knowledge/context/homelab-context.md`, when it exists
3. `knowledge/context/toolbox-context.md`, when it exists
4. Relevant files under `knowledge/policies/`
5. Relevant files under `knowledge/services/`
6. Relevant files under `knowledge/runbooks/`.
   For Codex-assisted work, read `knowledge/runbooks/codex-operating-model.md`.
   For first-run or strict read-only Codex work, read `knowledge/runbooks/codex-read-only-first-run.md`.
   For parallel work, dirty worktrees, stashes, or branches, read `knowledge/runbooks/codex-parallel-work.md`.
7. Relevant graph files under `knowledge/graph/`, when impact or dependencies matter
8. Relevant architecture records under `knowledge/architecture/`, when decisions or tradeoffs matter

If an expected file does not exist yet, the agent must explicitly report that it is missing and continue with the available context.

## Operating model

The default workflow is:

1. Diagnose
2. Plan
3. Apply
4. Validate

The agent must not skip directly to apply.

For any task that may change files, services, data, configuration, permissions, metadata, firewall rules, Docker networking, backup behavior, or media library content, the agent must first produce a plan and wait for human approval.

## Default safety mode

The default mode is read-only.

In read-only mode, the agent may inspect files, list directories, read reports, inspect Git state, and suggest commands.

The agent must not modify files, install packages, restart services, stop services, delete files, move files, change permissions, change metadata, run destructive commands, or alter system configuration unless an apply step has been explicitly approved.

## Source locations

Stable, versioned operational knowledge belongs in:

* `/srv/toolbox/app/knowledge/`

Executable automation belongs in:

* `/srv/toolbox/app/scripts/`

Complementary human-oriented documentation belongs in:

* `/srv/toolbox/app/docs/`

Generated artifacts belong in:

* `/srv/toolbox/shared/`

Generated artifacts include reports, inventories, TSVs, snapshots, logs, temporary outputs, and ChatGPT briefs.

## Evidence and confidence

The agent must distinguish between:

* human decision;
* operational policy;
* observed state;
* inference;
* pending validation.

Observed state should refer to current command output or generated artifacts under `/srv/toolbox/shared/`.

Architectural intent should refer to `knowledge/architecture/`, `knowledge/policies/`, or human confirmation.

## Human approval gates

Human approval is required before:

* modifying files outside clearly approved paths;
* changing anything under `/srv/media`;
* changing Docker Compose files or container configuration;
* changing firewall, UFW, DOCKER-USER, Samba, Tailscale, Nginx Proxy Manager, backup, or restore behavior;
* writing or rewriting media metadata;
* deleting, moving, renaming, or bulk-transforming files;
* running scripts with apply semantics;
* committing or pushing changes;
* installing, removing, or upgrading packages.

## Git rules

When working inside `/srv/toolbox/app`, the agent must respect the Toolbox Git workflow.

The preferred commit helper is:

```
apply-toolbox-git-stage-check-commit.sh \
  -m "commit message" \
  -- \
  path/to/file1 \
  path/to/file2
```

When the intended routine includes pushing to the remote, the post-commit helper must be used with `--push`:

```
apply-toolbox-git-post-commit.sh --push
```

The agent must not invent a different interface for these helpers.

## Reporting rules

For operational work, the agent should prefer structured outputs under `/srv/toolbox/shared/`.

For ChatGPT handoff, the agent should generate a concise brief instead of dumping raw logs or large reports into a chat.

A good ChatGPT brief should include:

* task;
* files inspected;
* commands run;
* relevant outputs summarized;
* decisions needed;
* risks;
* proposed next step;
* links or paths to full reports.

## Anti-drift rule

The agent must not introduce new top-level structures, policies, workflows, or naming conventions without explaining:

* function;
* destination;
* relationship with the existing Toolbox;
* risk of redundancy;
* migration or cleanup implications.

## Failure behavior

When uncertain, the agent must stop and explicitly state what is uncertain.

The agent should classify uncertainty as one or more of:

* known from stable knowledge;
* derived from observed state;
* inferred;
* needs host verification;
* needs internet verification;
* needs human decision.

The agent must not hide uncertainty behind confident language.
