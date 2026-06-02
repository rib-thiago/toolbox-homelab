# Reporting Policy

This policy defines how agents, scripts, and operators should produce, store, name, review, and hand off operational evidence in the Toolbox and homelab.

It applies to human-assisted work, ChatGPT-assisted work, Codex/local-agent work, scripts, diagnostics, validation routines, media workflows, Git routines, long-running operations, and generated handoff artifacts.

This policy must be read together with:

* `knowledge/context/agent-entrypoint.md`
* `knowledge/context/homelab-context.md`
* `knowledge/context/toolbox-context.md`
* `knowledge/policies/agent-safety-policy.md`
* `knowledge/policies/change-management-policy.md`

## Primary principle

Operational work should produce durable evidence.

The source tree should contain the method.

The shared tree should contain the evidence.

Stable, versioned source belongs under:

* `/srv/toolbox/app/`

Generated operational artifacts belong under:

* `/srv/toolbox/shared/`

Agents and scripts must not treat chat history, terminal scrollback, or model memory as the durable record of operational work.

## Related Toolbox policies

This policy does not replace existing Toolbox policies, conventions, or operational documentation.

Agents and operators must consult applicable Toolbox documents before changing reporting, logging, destination, storage, script, or Git conventions.

Authoritative related documents include:

* `docs/operations/toolbox_reports_policy.md`
* `docs/operations/toolbox_logging_policy.md`
* `docs/operations/toolbox_output_destinations_policy.md`
* `docs/operations/toolbox_git_routine.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_scripts_lib_policy.md`
* `docs/operations/toolbox_storage_policy.md`
* `docs/operations/toolbox_shell_environment.md`
* `docs/operations/toolbox_runtime_profiles.md`
* `docs/media/stockhausen_metadata_policy.md`
* `docs/media/stockhausen_gold_model_stimmung.md`

If a conflict exists between this policy and an older document, the operator or agent must stop and ask for human review instead of choosing one silently.

If a document appears stale, incomplete, or inconsistent with observed host state, the inconsistency must be reported and reviewed.

## Role of this policy

This policy is agent-facing.

It explains how agents and scripts should think about evidence, reporting, handoff, and generated artifacts.

The canonical human-facing destination map is:

* `docs/operations/toolbox_output_destinations_policy.md`

When deciding where to write a generated artifact, agents must consult the output destinations policy.

This policy summarizes expected behavior but does not replace the detailed destination map.

## Artifact classes

Generated operational artifacts include:

* human-readable reports;
* TSV files;
* logs;
* snapshots;
* inventories;
* validation summaries;
* before/after comparisons;
* manifests;
* ChatGPT briefs;
* temporary work outputs;
* job outputs;
* pipeline outputs;
* cold-archive artifacts.

Not every task needs every artifact type.

The artifact type must match the task.

## Reports

Reports are human-readable summaries of operational work.

Reports should be generated when a task involves:

* diagnostics;
* validation;
* planning;
* readiness checks;
* policy checks;
* Git routines;
* media/library analysis;
* service health analysis;
* backup or restore analysis;
* storage or disk analysis;
* security or network analysis;
* agent handoff.

Reports should include:

* title;
* timestamp;
* task or scope;
* relevant paths;
* commands or scripts used;
* key findings;
* warnings;
* failures;
* next steps;
* paths to related TSVs, logs, snapshots, manifests, inventories, or briefs.

Reports belong under the appropriate domain path in `/srv/toolbox/shared/reports/`.

Agents must consult `docs/operations/toolbox_output_destinations_policy.md` for the canonical destination rules.

## TSV files

TSV files are structured evidence.

TSVs should be generated when a task produces rows, checks, entities, files, albums, services, paths, packages, ports, dependencies, or validation results.

A TSV should usually include:

* timestamp;
* status;
* check or entity identifier;
* path or target;
* detail or value.

TSVs are preferred over prose when data needs to be filtered, compared, sorted, imported into spreadsheets, or used by scripts.

TSVs belong under the appropriate domain path in `/srv/toolbox/shared/library-db/raw/`.

Agents must consult `docs/operations/toolbox_output_destinations_policy.md` for the canonical destination rules.

## Logs

Logs capture execution output, especially for long-running commands or commands where terminal scrollback is not a reliable record.

Logs should be used when:

* the command may take significant time;
* the command produces substantial output;
* the terminal may disconnect;
* progress needs to be followed;
* failure analysis may require full output;
* the command is part of a long-running apply or processing task.

Logs should be stored under the appropriate domain path in `/srv/toolbox/shared/logs/`, unless they are internal `run-job` logs or another documented exception applies.

For long-running commands, agents and operators should consider:

* `nohup`;
* `nf`;
* `nflog`;
* `tblive`;
* `tail -f`;
* external redirection;
* `run-job`;
* pipeline job logs.

Avoid embedding `tee` inside scripts unless it is a deliberate design choice.

Prefer external logging for ad hoc long-running operations.

## Snapshots

Snapshots preserve state before or during risky work.

Snapshots should be considered before:

* metadata writes;
* media moves;
* staged imports;
* bulk renames;
* cold-archive cleanup;
* hot-library purge;
* configuration changes;
* backup or restore changes;
* filesystem-sensitive operations.

Snapshots may be filesystem snapshots, structured file snapshots, reports, TSV exports, metadata dumps, manifests, or other before-state captures.

Snapshots belong under the appropriate domain path in `/srv/toolbox/shared/library-db/snapshots/`, unless a more specific destination is documented.

Snapshots should be named and documented so they can support rollback or audit.

## Inventories

Inventories describe observed state at a point in time.

Inventories are not architectural decisions.

Inventories should be stored under `/srv/toolbox/shared/inventory/`, not treated as permanent truth inside `knowledge/`.

Inventories may describe:

* host state;
* Docker state;
* service state;
* network exposure;
* storage state;
* backup state;
* media library state;
* Toolbox script state;
* agent readiness state.

When stable decisions are derived from inventories, the decision belongs in `knowledge/architecture/` or `knowledge/policies/`, and the inventory remains supporting evidence.

## Manifests

Manifests describe sets of files, packages, outputs, archives, or generated artifacts.

Manifests should be used when a workflow needs to preserve or validate a collection of artifacts.

Manifests may support:

* cold archives;
* artwork archives;
* output packages;
* job outputs;
* pipeline outputs;
* validation of file sets;
* before/after comparisons;
* restore or rollback planning.

Manifest destinations must follow `docs/operations/toolbox_output_destinations_policy.md`.

## ChatGPT briefs

ChatGPT briefs are concise handoff artifacts.

They exist to reduce raw upload, copy/paste, and terminal-output dumping into ChatGPT.

A ChatGPT brief should include:

* task;
* context files read;
* files inspected;
* commands or scripts run;
* reports generated;
* TSVs generated;
* logs generated;
* manifests or snapshots generated;
* key findings;
* warnings;
* failures;
* decisions needed;
* proposed next step;
* paths to full evidence.

Briefs should be short enough to paste into ChatGPT while preserving enough context for review.

Briefs should not replace full reports, TSVs, logs, manifests, snapshots, or inventories.

Briefs should usually belong under:

* `/srv/toolbox/shared/briefs/chatgpt/`

unless a more specific destination is documented.

## Source tree rule

Generated artifacts do not belong in `/srv/toolbox/app/` unless explicitly intended as:

* documentation;
* examples;
* fixtures;
* test data;
* templates;
* policy text;
* runbooks;
* architecture records;
* stable knowledge.

The source tree should not accumulate dated reports, temporary outputs, raw logs, generated TSVs, ad hoc inventories, or transient job outputs.

If a generated artifact must be committed, the reason must be explicit.

## Naming rules

Artifact names should be predictable and include enough information to identify:

* domain;
* task;
* artifact type;
* timestamp.

Preferred timestamp format should follow existing Toolbox conventions.

Examples:

* `toolbox_knowledge_context_validation_<timestamp>.txt`
* `toolbox_knowledge_context_validation_<timestamp>.tsv`
* `toolbox_git_stage_check_commit_report_<timestamp>.txt`
* `music_staging_tagging_audit_report_<timestamp>.txt`
* `stockhausen_artwork_cold_archive_manifest_<timestamp>.tsv`

Avoid vague names such as:

* `output.txt`
* `log.txt`
* `report.txt`
* `notes.md`
* `temp.tsv`
* `result.txt`

## Report and TSV pairing

When a task produces both human-readable and structured evidence:

* the report should point to the TSV;
* the TSV should contain structured rows;
* both should share a timestamp or clear correlation key.

This pairing is preferred for validation scripts, diagnostics, audits, readiness checks, inventories, and policy checks.

## Status conventions

Where practical, structured outputs should use clear status values.

Recommended values:

* `OK`
* `WARN`
* `FAIL`
* `INFO`
* `SKIP`

The meaning of each status should be clear in the report or script.

For validation routines:

* `FAIL` should indicate a blocking problem;
* `WARN` should indicate a non-blocking issue or expected pending condition;
* `OK` should indicate a passed check.

## Evidence before commit

For Toolbox source changes, evidence should be produced before commit when practical.

Depending on the change, this may include:

* `mkxcheck`;
* validation script output;
* `git diff --check`;
* generated report;
* generated TSV;
* relevant before/after output;
* policy-reference checks.

Git helper reports and TSVs are also part of the evidence.

## Evidence after commit

After committing and pushing, run validation again when the change affects validation, policy, scripts, or operational behavior.

Post-commit validation should confirm:

* working tree clean;
* expected files present;
* expected checks passing;
* no unexpected warnings;
* reports and TSVs generated.

## Long-running work

Long-running work requires an execution and logging strategy.

Before launching long-running work, an agent or operator should explain:

* command;
* expected duration or uncertainty;
* log path;
* output path;
* progress monitoring method;
* validation method;
* interruption behavior;
* whether `nohup`, `nf`, `nflog`, `tblive`, external redirection, or `run-job` should be used.

Long-running work should not rely on terminal scrollback as the only record.

## Agent behavior

Agents must prefer durable evidence over ephemeral chat output.

Agents should not ask the user to paste large raw logs when a local script can generate a report, TSV, log, inventory, manifest, or brief.

Agents should propose scripts for repeated or long validation sequences.

Agents should avoid scattering outputs across the source tree.

Agents must explain where generated artifacts will be written before running tasks that create them.

Agents must consult `docs/operations/toolbox_output_destinations_policy.md` when choosing artifact destinations.

## Error reporting

When a script or task fails, the report should capture:

* attempted action;
* failure point;
* error message;
* affected path or target;
* partial outputs;
* whether state may be inconsistent;
* safest next diagnostic step.

If the failure occurs before a report can be written, the operator or agent should capture the failure in the next diagnostic report or brief.

## Anti-drift rule

Agents must not invent new artifact locations, naming schemes, or reporting conventions merely because they are common in generic agent projects.

Every new artifact type, directory, or naming convention must explain:

* function;
* destination;
* relationship with existing Toolbox conventions;
* risk of redundancy;
* validation method;
* cleanup or archival path.

The reporting system must adapt to the Toolbox, not replace it.
