# Toolbox Script Semantics Inventory

## 1. Purpose

`toolbox_script_semantics_inventory_v0` defines a controlled source-body interpretation layer for Toolbox scripts, commands, helpers, libraries, pipelines, workflows, and legacy scripts.

It records what a script appears to implement from its source code without executing it and without claiming runtime validation.

## 2. Position in the evidence pipeline

The intended evidence pipeline is:

```text
raw script inventory
-> toolbox_inventory_v0
-> raw script semantics TSV
-> normalized script semantics inventory
-> graph candidates
-> reviewed graph
```

Graph generation remains blocked until semantic inventory and graph promotion rules exist.

## 3. Relationship to raw script inventory

The raw script inventory records broad static facts such as path, domain, filename phase, shebang, executable bit, line count, and simple text feature flags.

It does not decide what the script actually does.

## 4. Relationship to `toolbox_inventory_v0`

`toolbox_inventory_v0` is a broad normalized inventory derived from raw script inventory.

`toolbox_script_semantics_inventory_v0` is a separate source-body interpretation layer. It must not be collapsed into `toolbox_inventory_v0` too early.

Later graph generation may consume both.

## 5. Raw output artifact model

The raw semantic diagnostic TSV should be written under:

```text
/srv/toolbox/shared/library-db/raw/system/toolbox_script_semantics_inventory_YYYYMMDD-HHMMSS.tsv
```

This TSV should preserve per-script source-body observations and diagnostic fields.

## 6. Normalized output artifact model

The normalized semantic inventory should be written under:

```text
/srv/toolbox/shared/inventory/toolbox/toolbox_script_semantics_inventory_YYYYMMDD-HHMMSS.tsv
```

This artifact should use schema name:

```text
toolbox_script_semantics_inventory_v0
```

It should normalize raw semantic rows into stable entity-like records for later graph candidate generation.

## 7. Report artifact model

The human report should be written under:

```text
/srv/toolbox/shared/reports/system/toolbox_script_semantics_inventory_report_YYYYMMDD-HHMMSS.txt
```

The report should summarize scope, counts, confidence levels, placeholder rows, warnings, and graph-readiness blockers.

## 8. Initial v0 scope

Initial implementation should focus on core and high-risk scripts:

* inventory and generator scripts;
* `bin/run-job`;
* non-empty pipelines;
* empty pipeline placeholders as explicit placeholder cases;
* `scripts/lib` modules;
* `scripts/helpers/job-inspect.sh`;
* Git workflow helpers.

This initial family matches the first semantic analysis batch. It is intentionally narrow for v0, but it must not constrain later full coverage.

## 9. Eventual full-coverage goal

The initial v0 scope is only the first batch.

The long-term goal is full semantic coverage of all Toolbox scripts, commands, helpers, libraries, pipelines, workflows, and legacy scripts.

The schema must support incremental expansion without changing the meaning of existing fields.

## 10. Proposed raw TSV schema

Suggested raw TSV fields:

```text
semantic_schema_version
timestamp
path
scope_batch
source_body_read
source_line_count
path_entity_type
raw_phase
raw_kind
semantic_entity_type
semantic_runtime
semantic_automation_type
source_body_summary
implemented_contracts
entrypoint_style
argument_contract
reads_paths
writes_paths
evidence_outputs
uses_libraries
calls_toolbox_commands
calls_external_commands
calls_git
uses_run_job_contract
pipeline_contract_status
job_root_contract_status
input_work_output_status
status_file_behavior
log_behavior
side_effect_class
confirmation_gate
placeholder_status
relation_candidate_types
relation_candidate_targets
relation_candidate_basis
semantic_confidence
runtime_validated
runtime_validation_evidence
warnings
source_inventory
source_report
source_tsv
repo_root
git_commit
git_status
```

## 11. Proposed normalized inventory schema

Suggested normalized inventory fields:

```text
inventory_schema_version
timestamp
domain
subdomain
entity_type
entity_id
path
name
semantic_entity_type
semantic_runtime
semantic_automation_type
status
placeholder_status
implemented_contracts
semantic_summary
relation_candidate_type
related_entity_type
related_entity_id
related_path
relation_basis
relation_confidence
runtime_validated
runtime_validation_evidence
evidence_type
confidence
source_semantics_tsv
source_semantics_report
source_inventory
source_report
source_tsv
generator_script
repo_root
git_branch
git_commit
git_status
```

For v0, the normalized semantic inventory should use one normalized row per script. Separate relation-candidate rows may be designed later, but they are not part of the v0 row model.

## 12. Required versus optional fields

Required fields:

```text
semantic_schema_version
timestamp
path
source_body_read
path_entity_type
semantic_entity_type
semantic_runtime
semantic_automation_type
source_body_summary
semantic_confidence
runtime_validated
source_inventory
source_report
source_tsv
git_commit
git_status
```

Optional or conditional fields:

```text
implemented_contracts
argument_contract
reads_paths
writes_paths
evidence_outputs
uses_libraries
calls_toolbox_commands
calls_external_commands
calls_git
relation_candidate_targets
runtime_validation_evidence
warnings
```

## 13. Classification rules

Path is only a hint.

Rules:

* `bin/run-job` is a run-job entrypoint only when the body creates job structure and dispatches pipeline scripts.
* `scripts/pipelines/*.sh` is a semantic pipeline only when it implements the `JOB_ROOT`, input, work, output, status, and log contract.
* empty `scripts/pipelines/*.sh` files are placeholders, not semantic pipelines.
* `scripts/lib/*.sh` files are sourced library modules when they define reusable functions and avoid source-time side effects.
* `scripts/helpers/*.sh` files are helper tools when they are executable and user-facing.
* Git helpers with staging, checks, confirmation, reports, TSVs, commit, or push behavior are Git workflows.
* inventory scripts that transform evidence into generated inventory artifacts are generators.
* diagnostics inspect and report without applying changes.

## 14. Runtime classes

Allowed runtime classes:

```text
host
container
hybrid
source_only
unknown
```

Runtime class is source-body semantics, not proof of successful execution.

## 15. Automation type classes

Allowed automation types:

```text
atomic command
diagnostic
generator
validator
planner
apply workflow
git workflow
pipeline
run-job entrypoint
helper executable
sourced library
placeholder
unknown
```

## 16. Confidence model

Confidence values:

```text
path_low
static_hint_low
source_body_medium
source_contract_high
runtime_validated
operator_confirmed
```

`runtime_validated` must not be emitted by this layer unless separate execution evidence or validation reports are referenced.

For v0, most rows should be `source_body_medium` or `source_contract_high`.

Source-body interpretation should use a mixed approach: rule-based initial detection plus manual review. It is not automatically authoritative for graph edges.

## 17. Placeholder and empty script handling

Empty files and placeholders must be explicit rows.

Suggested values:

```text
semantic_entity_type=placeholder
semantic_runtime=unknown
semantic_automation_type=placeholder
source_body_read=yes
source_line_count=0
placeholder_status=empty_file
semantic_confidence=source_body_medium
runtime_validated=no
```

Path-intended role should remain separate from semantic role.

## 18. Relation candidate rules

Semantic inventory may propose relation candidates. It must not emit accepted graph edges.

Higher-confidence candidates:

* run-job dispatches pipeline scripts by job type;
* pipeline uses public Toolbox commands;
* script sources library modules;
* Git workflow writes Git report and TSV artifacts;
* generator consumes source TSV and writes normalized inventory/report artifacts;
* helper inspects job status, logs, and output paths.

Low-confidence hints only:

* text mention of `run-job`;
* text mention of `pipeline`;
* report, TSV, log, or snapshot feature flags;
* path-only role;
* empty placeholder files.

Relation target IDs should use path-derived IDs where possible. When the target cannot be resolved, use `unknown` with `related_path` and `relation_basis` preserving the evidence.

## 19. What must not be inferred

This layer must not infer:

* runtime success;
* live service state;
* media behavior;
* backup behavior;
* graph edges;
* operator intent;
* validated dependencies;
* safety of running a script;
* correctness of output paths;
* that path category equals semantic behavior;
* that static text mention equals dependency.

Runtime validation is a future separate evidence layer. This semantic inventory should normally emit `runtime_validated=no` unless external execution evidence is explicitly referenced.

## 20. Validation rules

Future validation should check:

* every scoped path has one raw semantic row;
* every normalized semantic row has a stable entity ID;
* schema version is present;
* required fields are non-empty;
* `runtime_validated=no` unless external evidence is referenced;
* placeholder rows cannot claim pipeline contract success;
* semantic pipeline rows must show `JOB_ROOT` and input/work/output/status/log behavior;
* relation candidates include basis and confidence;
* source inventory/report/TSV paths are recorded;
* Git commit and Git status are recorded;
* no accepted graph edges are emitted.

## 21. Expansion strategy from v0 core scope to all scripts

Expansion should be batch-based.

Suggested batches:

1. core/high-risk scripts;
2. all `bin` commands;
3. all `scripts/lib` and `scripts/helpers`;
4. all `scripts/pipelines`;
5. administrative diagnostics and validators;
6. Git, backup, storage, network, Docker, and firewall workflows;
7. media and archive workflows;
8. legacy or low-confidence scripts.

Each batch should preserve the same schema and record scope in `scope_batch`.

## 22. Open questions before implementation

Open questions:

* What exact path list defines the initial core/high-risk v0 batch?
* What separate artifact will record runtime validation evidence?
* How should semantic inventory interact with future graph candidate generation?

Operator decisions already recorded for v0:

* initial scope is core/high-risk first, using the same initial family already analyzed: inventory/generator scripts, `bin/run-job`, pipelines including empty placeholders, `scripts/lib` modules, `scripts/helpers/job-inspect.sh`, and Git workflow helpers;
* eventual target remains all scripts;
* source-body interpretation uses a mixed approach: rule-based initial detection plus manual review;
* semantic findings are not automatically authoritative for graph edges;
* normalized semantic inventory uses one row per script in v0;
* relation candidate target IDs use path-derived IDs where possible, otherwise `unknown` plus `related_path` and `relation_basis`;
* runtime validation is a future separate evidence layer, and this layer normally emits `runtime_validated=no`.

## 23. Recommended implementation sequence

Recommended sequence:

1. Freeze the initial v0 path list.
2. Freeze raw TSV and normalized inventory fields.
3. Define classification vocabularies.
4. Define confidence and placeholder rules.
5. Implement read-only source-body analysis for the initial scope.
6. Emit raw TSV, normalized semantic inventory, and report.
7. Review results before any graph candidate generation.
