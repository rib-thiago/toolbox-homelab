# Codex Read-Only First Run

This runbook defines the first controlled read-only exercise for Codex/local-agent use in the homelab and Toolbox environment.

It does not replace policies, service maps, architecture documents, graph artifacts, inventories, reports, TSVs, or operator review.

This first run is intentionally limited. Its goal is to test whether Codex can read the existing knowledge layer, inspect selected repository artifacts, identify gaps, ask useful questions, and avoid unsafe action.

For the general day-to-day Codex operating model, including roles, modes, usage budget, stopping rules, live-logs, briefs, patch authority, commits, and task lifecycle, use:

* `knowledge/runbooks/codex-operating-model.md`

For parallel work, dirty worktrees, stashes, branches, and unfinished long-running workfronts, use:

* `knowledge/runbooks/codex-parallel-work.md`

This runbook remains focused on the first controlled read-only and evidence-writing Codex exercise.

## Purpose

The purpose of this runbook is to define a safe first Codex/local-agent exercise and its immediate follow-up mode.

The first run is split into two modes:

1. Strict read-only mode.
2. Evidence-writing diagnostic mode.

Strict read-only mode verifies that Codex can:

* read the knowledge entrypoint;
* follow policy and service-map boundaries;
* inspect repository structure;
* inspect existing documentation and scripts;
* distinguish observation from interpretation;
* identify missing inventory or graph artifacts;
* identify questions that require operator intent;
* return findings in a structured format;
* avoid unsafe action.

Evidence-writing diagnostic mode verifies that Codex can run existing Toolbox validators and diagnostics while writing only generated evidence under `/srv/toolbox/shared`.

This runbook does not treat generated reports, TSVs, and logs as service changes, repo changes, media changes, configuration changes, or Git changes.

Generated evidence is allowed only when explicitly entering evidence-writing diagnostic mode.

## Non-goals

This runbook does not:

* redefine safety policy;
* enumerate all read-only commands allowed in the homelab;
* authorize writes, patches, commits, pushes, restarts, rebuilds, deletes, moves, or metadata changes;
* inspect live services unless explicitly approved later;
* create graph artifacts;
* create inventory artifacts;
* create ADRs;
* resolve open questions;
* continue the service-map lote 2;
* replace ChatGPT or operator review.

This is a first controlled read-only exercise only.

## Required reading order

Codex must read the following files before making recommendations.

Primary entrypoint:

* `knowledge/context/agent-entrypoint.md`

Core context:

* `knowledge/context/homelab-context.md`
* `knowledge/context/toolbox-context.md`

Policies:

* `knowledge/policies/agent-safety-policy.md`
* `knowledge/policies/change-management-policy.md`
* `knowledge/policies/reporting-policy.md`
* `knowledge/policies/filesystem-safety-policy.md`
* `knowledge/policies/media-curation-policy.md`
* `knowledge/policies/architecture-knowledge-policy.md`

Service-map guidance:

* `knowledge/services/README.md`
* `knowledge/services/toolbox.md`
* `knowledge/services/docker.md`
* `knowledge/services/networking.md`
* `knowledge/services/nginx-proxy-manager.md`
* `knowledge/services/samba.md`
* `knowledge/services/backup.md`
* `knowledge/services/filebrowser.md`
* `knowledge/services/music-staging.md`
* `knowledge/services/navidrome.md`

Architecture context:

* `knowledge/architecture/historical-operational-lessons.md`
* `knowledge/architecture/open-questions.md`

Operational documentation:

* `docs/operations/toolbox_output_destinations_policy.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_architecture_reconciliation.md`

## Scope of this first run

For this first run, Codex may inspect only repository and generated-evidence areas related to the knowledge layer.

Allowed repository areas for this run:

* `/srv/toolbox/app/knowledge`
* `/srv/toolbox/app/docs`
* `/srv/toolbox/app/scripts`
* `/srv/toolbox/app/bin`

Allowed generated-evidence areas for this run:

* `/srv/toolbox/shared/reports/system`
* `/srv/toolbox/shared/library-db/raw/system`
* `/srv/toolbox/shared/reports/git`
* `/srv/toolbox/shared/library-db/raw/git`

Codex must not inspect media collections, backup repositories, live service data, secrets, private credentials, or unrelated user files during this first run.

## Allowed actions for this first run

This runbook does not define the global read-only permission model.

For this first exercise, there are two allowed modes.

### Mode 1 — strict read-only

Codex may:

* list files under the allowed repository areas;
* read Markdown files under `knowledge/` and selected `docs/`;
* inspect shell scripts under `scripts/` and `bin/`;
* inspect already-existing reports and TSVs under the allowed generated-evidence areas;
* report findings, questions, and suggested next diagnostics.

Codex must not run validators or diagnostics that create reports, TSVs, temp files, logs, or other generated artifacts while in strict read-only mode.

### Mode 2 — evidence-writing diagnostic mode

Codex may run existing Toolbox validators and diagnostics if, and only if, the operator explicitly approves evidence-writing diagnostic mode.

In evidence-writing diagnostic mode, the only permitted writes are generated evidence under:

* `/srv/toolbox/shared/reports/`
* `/srv/toolbox/shared/library-db/raw/`
* `/srv/toolbox/shared/logs/`, when a script already uses that location
* temporary files created and removed by existing Toolbox scripts under `/srv/toolbox/shared/`

Codex must not modify:

* `/srv/toolbox/app`
* `/srv/media`
* `/srv/compose`
* service configuration
* Docker state
* Git state
* permissions
* secrets
* credentials
* shell configuration
* media files
* backup repositories

Generated evidence writes do not authorize patches, commits, service changes, media changes, or configuration changes.

## Forbidden actions for this first run

Codex must not:

* patch files;
* edit Markdown;
* edit scripts;
* run apply workflows;
* run repair workflows;
* run import workflows;
* run cleanup workflows;
* commit;
* push;
* restart containers;
* rebuild containers;
* change permissions;
* move, rename, delete, or copy media files;
* inspect secrets;
* inspect live service state outside the allowed scope;
* generate graph artifacts;
* generate inventory artifacts outside existing diagnostics;
* mark open questions as resolved;
* create ADRs.

In strict read-only mode, Codex must not write any file.

In evidence-writing diagnostic mode, Codex may write only generated evidence under `/srv/toolbox/shared` using existing Toolbox validators and diagnostics.

A general instruction to proceed is not approval for evidence-writing diagnostic mode.

A general instruction to proceed is not approval for any forbidden action.

## First-run command set

### Mode 1 — strict read-only command set

Repository status:

    cd /srv/toolbox/app || exit 1
    git status --short

Knowledge tree inspection:

    find knowledge -maxdepth 3 -type f | sort

Existing evidence lookup without shell helpers:

    find /srv/toolbox/shared/reports/system -type f -name '*knowledge_context_validation*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1
    find /srv/toolbox/shared/reports/system -type f -name '*knowledge_policies_consistency*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1
    find /srv/toolbox/shared/reports/system -type f -name '*knowledge_services_consistency*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1
    find /srv/toolbox/shared/reports/system -type f -name '*toolbox_script_inventory_report*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1
    find /srv/toolbox/shared/reports/system -type f -name '*knowledge_architecture_candidates_report*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1

Codex may read the latest report paths found by these commands.

### Mode 2 — evidence-writing diagnostic command set

Mode 2 requires explicit operator approval.

Core validators:

    validate-toolbox-knowledge-context.sh
    scripts/admin/system/validate-toolbox-knowledge-policies-consistency.sh
    scripts/admin/system/validate-toolbox-knowledge-services-consistency.sh

Existing diagnostics:

    diagnose-toolbox-script-inventory.sh
    scripts/admin/system/diagnose-knowledge-architecture-candidates.sh

Post-diagnostic status:

    git status --short

Codex must not expand beyond the active mode command set without operator approval.

## Expected output from Codex

Codex must return its result in this structure:

1. Scope actually inspected
2. Validators and diagnostics run
3. Findings
4. Questions for operator
5. Classification summary
6. Recommended next step

Codex must clearly distinguish:

* observed state;
* interpretation;
* uncertainty;
* operator decision needed;
* candidate graph work;
* candidate inventory work;
* candidate historical lesson;
* candidate open question;
* candidate ADR;
* no-action findings.

Codex must not produce patches during this first run unless the operator explicitly asks after reviewing findings and questions.

## Finding template

Each finding should use this template.

### FNNN — Short title

Type:

Confidence:

Evidence:

Observation:

Interpretation:

Risk:

Recommended next step:

Requires approval before action:

Valid finding types:

* `observed_state`
* `inconsistency`
* `missing_artifact`
* `stale_reference`
* `possible_graph_relation`
* `possible_inventory_gap`
* `possible_open_question`
* `possible_historical_lesson`
* `possible_candidate_ADR`
* `validation_gap`
* `script_or_workflow_gap`
* `no_action`

Valid confidence values:

* `high`
* `medium`
* `low`

The `Evidence` field should cite the file, report, TSV, script, validator output, or command result inspected.

The `Observation` field should state only what Codex actually saw.

The `Interpretation` field should explain what the observation may mean.

The `Risk` field should explain why the finding matters.

The `Recommended next step` field should use one of:

* `no action`
* `ask operator`
* `run read-only diagnostic`
* `update service map`
* `update open questions`
* `update historical lessons`
* `propose ADR`
* `propose graph work`
* `propose inventory work`
* `propose patch after approval`

The `Requires approval before action` field must be `yes` or `no`.

## Question template

Each operator question should use this template.

### QNNN — Short question title

Question:

Why Codex cannot infer this:

Related finding:

Related artifact:

Possible outcomes:

Urgency:

The `Question` field must be phrased as an actual question.

The `Why Codex cannot infer this` field should explain why repository state, scripts, reports, service maps, policies, graph files, inventories, or existing docs are insufficient.

The `Related finding` field should reference a finding ID when applicable.

The `Related artifact` field may reference a service map, policy, architecture document, script, report, TSV, graph candidate, inventory candidate, or validator.

Valid possible outcomes:

* `document answer in open-questions.md`
* `promote to candidate ADR`
* `update service map`
* `update policy`
* `generate inventory`
* `generate graph`
* `run another diagnostic`
* `no action`

Valid urgency values:

* `now`
* `before next phase`
* `deferred`

## Classification of findings

Codex must classify findings according to:

* `knowledge/policies/architecture-knowledge-policy.md`

The first-run output should not directly update:

* `knowledge/architecture/historical-operational-lessons.md`
* `knowledge/architecture/open-questions.md`
* future ADRs
* `knowledge/graph/`
* `/srv/toolbox/shared/inventory/`

Instead, Codex should identify candidate updates and wait for operator review.

## Completion criteria

Strict read-only mode is complete when Codex has produced:

* the actual inspected scope;
* existing evidence inspected, if available;
* structured findings;
* structured questions for the operator;
* a classification summary;
* recommended next step;
* no file modifications;
* no generated evidence;
* no service modifications;
* no Git changes.

Evidence-writing diagnostic mode is complete when Codex has produced:

* validator results;
* diagnostic results;
* generated reports and TSVs only under `/srv/toolbox/shared`;
* a live-log or handoff Markdown under `/srv/toolbox/shared/reports/system/` when the work has multiple phases, operator checkpoints, generated evidence writes, long outputs, resume risk, commit/push decisions, or high-risk domains;
* structured findings;
* structured questions for the operator;
* a classification summary;
* recommended next step;
* no repo modifications;
* no service modifications;
* no media modifications;
* no Git changes.

## Human review

After the first run, the operator and ChatGPT should review the findings and questions.

Possible follow-up outcomes include:

* accept no changes;
* ask Codex for a narrower diagnostic;
* create or update an open question;
* create or update a historical lesson;
* propose a candidate ADR;
* design the first inventory command;
* design the first graph-generation command;
* create a more general Codex runbook;
* approve a patch in a separate step.

No follow-up action is authorized by this runbook alone.

## Related documents

* `knowledge/context/agent-entrypoint.md`
* `knowledge/context/homelab-context.md`
* `knowledge/context/toolbox-context.md`
* `knowledge/policies/agent-safety-policy.md`
* `knowledge/policies/change-management-policy.md`
* `knowledge/policies/reporting-policy.md`
* `knowledge/policies/filesystem-safety-policy.md`
* `knowledge/policies/media-curation-policy.md`
* `knowledge/policies/architecture-knowledge-policy.md`
* `knowledge/services/README.md`
* `knowledge/architecture/historical-operational-lessons.md`
* `knowledge/architecture/open-questions.md`
* `docs/operations/toolbox_output_destinations_policy.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_architecture_reconciliation.md`
