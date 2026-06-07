# Codex Operating Model

This runbook defines the practical operating model for using Codex in the Toolbox and homelab workflow.

It does not replace:

* `knowledge/context/agent-entrypoint.md`;
* `knowledge/policies/agent-safety-policy.md`;
* `knowledge/policies/change-management-policy.md`;
* `knowledge/policies/filesystem-safety-policy.md`;
* `knowledge/policies/reporting-policy.md`;
* `knowledge/runbooks/codex-read-only-first-run.md`.

It consolidates how those documents should be used in day-to-day Codex-assisted work.

## 1. Purpose

Codex is used to reduce manual copy/paste, terminal scrollback dependency, repeated uploads, and ad hoc context transfer between the homelab, ChatGPT, and the operator.

Codex should act as a local evidence-producing agent.

Its job is to inspect approved local files, produce durable evidence, identify gaps, raise questions, propose bounded changes, and generate handoff material for ChatGPT and the operator.

Codex must not become an autonomous operator of the homelab.

## 2. Roles

### Operator

The operator decides:

* task priority;
* approved scope;
* whether a patch may be created;
* whether a change may be applied;
* whether a commit may be created;
* whether a push may be performed;
* whether an open question becomes a decision;
* whether an ADR is needed;
* whether runtime validation is acceptable.

The operator is the final authority for intent.

### ChatGPT

ChatGPT is used for:

* planning;
* prompt design;
* review of Codex handoffs;
* interpretation of evidence;
* comparison of options;
* architecture reasoning;
* deciding whether a Codex proposal is safe or complete;
* helping the operator transform findings into open questions, policies, runbooks, ADR candidates, or backlog items.

ChatGPT should not be treated as the sole source of truth for current host state.

### Codex

Codex is used for:

* reading approved repository files;
* reading approved generated evidence;
* producing handoffs and live-logs;
* running approved read-only commands;
* generating reports or inventories when explicitly approved;
* preparing patches when explicitly approved;
* running narrow validation commands when approved;
* using Git helpers only after explicit operator approval.

Codex must report uncertainty instead of guessing.

### Toolbox

Toolbox provides:

* source code and documentation under `/srv/toolbox/app`;
* generated evidence under `/srv/toolbox/shared`;
* operational scripts;
* reports;
* TSVs;
* inventories;
* live-logs;
* runbooks;
* policies;
* service maps;
* architecture notes.

Toolbox is the persistent coordination layer between the operator, ChatGPT, and Codex.

## 3. Source of truth hierarchy

Codex must treat information according to its source.

Highest-trust sources:

1. explicit operator instruction in the current task;
2. Git-tracked policies and runbooks under `knowledge/`;
3. current command output from approved read-only commands;
4. generated evidence under `/srv/toolbox/shared`;
5. committed source code under `/srv/toolbox/app`.

Lower-trust sources:

* model memory;
* chat history;
* old terminal scrollback;
* stale generated reports;
* path names alone;
* comments alone;
* heredoc text alone;
* inferred intent.

Codex must distinguish:

* observed fact;
* source-body interpretation;
* runtime validation;
* human decision;
* architectural intent;
* open question;
* relation candidate;
* accepted relationship.

## 4. Required preflight

Before any Codex task, the operator or Codex should establish:

* active task;
* active mode;
* allowed paths;
* forbidden paths;
* whether generated evidence writes are allowed;
* whether repository patches are allowed;
* whether Git operations are allowed;
* whether runtime scripts may be executed;
* whether a live-log is required;
* current Git status;
* current Codex usage status when available.

Minimum preflight commands when appropriate:

```bash
cd /srv/toolbox/app || exit 1
git status --short
```

For longer Codex sessions, also run inside Codex:

```text
/status
```

## 5. Operating modes

### Strict read-only mode

Codex may read approved files and run approved read-only commands.

No writes are allowed.

Use for:

* first inspection;
* architecture review;
* source reading;
* report reading;
* service-map review;
* open-question analysis.

Strict read-only mode must not write reports, TSVs, inventories, handoffs, patches, or logs.

### Evidence-writing diagnostic mode

Codex may read approved files and write generated evidence under `/srv/toolbox/shared`.

Allowed evidence may include:

* reports;
* TSVs;
* inventories;
* handoffs;
* live-logs;
* briefs.

This mode does not authorize:

* repository patches;
* service changes;
* media changes;
* configuration changes;
* permission changes;
* secrets access;
* backup repository changes;
* graph changes;
* commits;
* pushes.

Use for:

* inventory generation;
* semantic inventory generation;
* long-session handoffs;
* report generation;
* ChatGPT briefs.

### Controlled patch mode

Codex may modify explicitly approved repository files.

Controlled patch mode requires:

* narrow scope;
* explicit allowed file list;
* no hidden broad rewrites;
* no generated graph unless approved;
* no commit;
* no push.

After patching, Codex should run only approved checks such as:

```bash
git diff --check
git status --short
```

Other checks must be explicitly approved.

### Commit/push mode

Commits and pushes require explicit operator approval.

The standard commit helper is:

```bash
apply-toolbox-git-stage-check-commit.sh \
  -m "commit message" \
  -- \
  path/to/file1 \
  path/to/file2
```

The operator must type:

```text
COMMIT
```

Pushes must use:

```bash
apply-toolbox-git-post-commit.sh --push
```

The operator must type:

```text
PUSH
```

Codex must not invent alternate Git helper interfaces.

### Apply/runtime mode

Apply/runtime mode includes any operation that changes live host state, media, services, permissions, backup behavior, firewall behavior, Docker runtime, metadata, files outside approved repository paths, or operational configuration.

This mode requires a separate plan, explicit operator approval, and validation criteria.

Apply/runtime mode is not implied by any other mode.

## 6. Usage budget and stopping rules

Codex usage limits are operational constraints.

Before long tasks, run:

```text
/status
```

Record relevant values in the live-log when available:

* 5h limit remaining;
* weekly limit remaining;
* context window remaining.

### Budget rules

If the 5h limit is below 25%:

* do not start broad source-reading passes;
* do not start large patch tasks;
* do not start multi-block reruns;
* prefer handoff, summary, or stopping.

If the 5h limit is below 15%:

* only update or create a live-log/handoff;
* stop before patching;
* do not commit unless the commit is already prepared and the operator explicitly approves.

If the weekly limit is below 40%:

* prefer small, high-value Codex tasks;
* move reasoning and planning to ChatGPT;
* avoid exploratory broad passes.

If the weekly limit is below 25%:

* avoid non-urgent Codex work;
* use manual shell commands and ChatGPT review where possible;
* preserve remaining usage for essential repository/local-file operations.

### Rerun economy

During calibration, run only the affected scope.

Example:

```bash
scripts/admin/system/generate-toolbox-script-semantics-inventory.sh --scope block4-media-library-soulseek
```

Do not rerun all scopes during every micro-calibration.

Run all scopes only:

* before commit when required;
* after commit for final clean evidence;
* when a shared classifier change could affect previous scopes.

### Prompt economy

Prompts should reference existing runbooks and policies instead of repeating all rules.

A preferred prompt shape is:

```text
Read:
- knowledge/context/agent-entrypoint.md
- knowledge/runbooks/codex-operating-model.md
- relevant policy/runbook/report

Active mode:
- controlled patch, no commit

Scope:
- approved paths only

Task:
- specific bounded change

Return:
- short structured result
```

### Stop conditions

Codex must stop when:

* scope is ambiguous;
* Git state is unexpected;
* a command would leave the approved scope;
* a task requires a mode not approved by the operator;
* evidence contradicts the prompt;
* usage budget is too low for safe continuation;
* a patch would require broad design decisions;
* open questions would be silently resolved;
* runtime validation would be required but was not approved.

## 7. Live-log and handoff rules

A durable live-log or handoff should be created under:

```text
/srv/toolbox/shared/reports/system/
```

Use a descriptive filename with timestamp and workfront.

Examples:

```text
codex_block4_semantics_scope_handoff_YYYYMMDD-HHMMSS.md
codex_block3_semantics_scope_closure_log_YYYYMMDD-HHMMSS.md
toolbox_codebase_block5_stockhausen_handoff_YYYYMMDD-HHMMSS.md
```

A live-log should record:

* active mode;
* scope;
* files inspected;
* commands run;
* generated artifacts;
* validation results;
* operator checkpoints;
* approvals given;
* Git helper artifacts;
* final Git status;
* warnings;
* uncertainty;
* next step.

A live-log is generated evidence only.

It does not authorize source changes, service changes, media changes, configuration changes, permission changes, secrets access, backup changes, graph changes, commits, or pushes.

## 8. Briefs for ChatGPT

When the operator needs to bring results back to ChatGPT, Codex should prefer a concise brief or handoff over raw terminal output.

A good brief includes:

* task;
* active mode;
* files inspected;
* commands run;
* artifacts generated;
* summary of findings;
* risks;
* uncertainties;
* decisions needed;
* proposed next step;
* paths to full reports.

The brief should be short enough to paste into ChatGPT without terminal scrollback problems.

The full evidence should remain in `/srv/toolbox/shared`.

## 9. Open questions and ADR candidates

Codex must not silently resolve open questions.

When work touches `knowledge/architecture/open-questions.md`, Codex should:

1. identify the relevant open question;
2. inspect approved related evidence;
3. summarize what is known;
4. summarize what remains unknown;
5. propose whether the question should remain open, be updated, or become an ADR candidate;
6. wait for operator decision.

An ADR should not be created only because Codex found a pattern.

An ADR should represent a stable human architectural decision.

## 10. Inventory and semantic inventory

Inventory artifacts record observed evidence.

Semantic inventory records controlled source-body interpretation.

Neither is runtime validation.

Relation candidates are not graph edges.

Codex must preserve these distinctions:

```text
raw script inventory
-> toolbox_inventory_v0
-> raw script semantics TSV
-> normalized script semantics inventory
-> graph candidates
-> reviewed graph
```

Graph generation remains blocked until promotion rules, provenance, confidence, freshness, and review workflow are defined.

## 11. Runtime validation

Runtime validation is separate from source reading.

Codex must not mark behavior as runtime-validated unless there is explicit execution evidence or a validation report.

Source-body semantics can support:

* classification;
* warnings;
* relation candidates;
* modernization candidates;
* open questions.

It cannot prove:

* successful execution;
* safety;
* correctness of live behavior;
* current service state;
* current media state;
* backup integrity;
* firewall state.

## 12. Parallel work

During long-running workfronts, parallel work must follow `knowledge/runbooks/codex-parallel-work.md`.

Default rule:

* do not start parallel repository changes while the main workfront has uncommitted changes.

If parallel work is necessary, use a clean branch or a documented stash strategy.

## 13. Standard Codex task lifecycle

A normal Codex task should follow:

1. preflight;
2. mode declaration;
3. bounded inspection;
4. evidence summary;
5. patch only if approved;
6. validation only if approved;
7. handoff/live-log;
8. commit/push only if approved;
9. final clean status;
10. ChatGPT/operator review.

## 14. Minimal prompt template

```text
Read first:
- knowledge/context/agent-entrypoint.md
- knowledge/runbooks/codex-operating-model.md
- [relevant policy/runbook/report]

Active mode:
[read-only | evidence-writing diagnostic | controlled patch | commit/push]

Scope:
[allowed files/paths]

Task:
[specific bounded task]

Forbidden:
[explicit exclusions]

Return only:
1. files inspected
2. files modified, if any
3. commands run
4. artifacts generated
5. validation result
6. git status
7. warnings or uncertainties
8. recommended next step

Do not commit.
Do not push.
```

## 15. Relationship to other documents

This runbook is an operating model.

It does not replace:

* `knowledge/context/agent-entrypoint.md`;
* `knowledge/policies/agent-safety-policy.md`;
* `knowledge/policies/change-management-policy.md`;
* `knowledge/policies/reporting-policy.md`;
* `knowledge/runbooks/codex-read-only-first-run.md`;
* `docs/operations/toolbox_script_semantics_inventory.md`.

If this runbook conflicts with a stricter policy, the stricter policy wins.
