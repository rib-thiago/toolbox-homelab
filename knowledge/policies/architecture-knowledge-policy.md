# Architecture Knowledge Policy

This policy defines how agents and operators should maintain architecture knowledge in the Toolbox knowledge layer.

It applies to ChatGPT-assisted work, Codex/local-agent work, future automation agents, human operators, scripts, diagnostics, documentation changes, ADR preparation, graph-related work, and knowledge maintenance.

This policy governs:

* `knowledge/architecture/historical-operational-lessons.md`
* `knowledge/architecture/open-questions.md`
* future ADR documents under `knowledge/architecture/`
* architecture-related updates proposed from diagnostics, inventories, graph generation, reports, TSVs, service maps, and operator review

This policy must be read together with:

* `knowledge/context/agent-entrypoint.md`
* `knowledge/context/homelab-context.md`
* `knowledge/context/toolbox-context.md`
* `knowledge/services/README.md`
* `knowledge/architecture/historical-operational-lessons.md`
* `knowledge/architecture/open-questions.md`
* `knowledge/policies/agent-safety-policy.md`
* `knowledge/policies/change-management-policy.md`
* `knowledge/policies/reporting-policy.md`
* `knowledge/policies/filesystem-safety-policy.md`
* `knowledge/policies/media-curation-policy.md`
* `docs/operations/toolbox_architecture_reconciliation.md`
* `docs/operations/toolbox_output_destinations_policy.md`

## Primary principle

Architecture knowledge must capture what cannot be safely inferred from observed state alone.

Agents must not invent historical rationale, architectural intent, unresolved decisions, or operational lessons.

When intent is unclear, agents must ask the operator or propose a bounded diagnostic.

## Architecture knowledge boundaries

The knowledge layer separates different kinds of information.

`/srv/toolbox/shared/inventory/` contains observed state collected by diagnostics.

`knowledge/graph/` contains relationship and dependency data produced by diagnostic/modeling work.

`knowledge/services/` contains human-readable operational maps for selected services, subsystems, and infrastructure layers.

`knowledge/policies/` contains rules and behavioral constraints that have already been decided.

`knowledge/architecture/` contains historical lessons, open questions, ADRs, structural explanations, and human-confirmed rationale.

Agents must not mix these layers silently.

## Architecture knowledge artifact classification

Architecture knowledge artifacts must be classified before they are created, updated, promoted, or resolved.

Agents must classify a finding into one of the following artifact types:

| Artifact type                 | Destination                                                                      | Purpose                                                                                                                          |
| ----------------------------- | -------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| historical operational lesson | `knowledge/architecture/historical-operational-lessons.md`                       | Record a real problem, workaround, adopted solution, and operational lesson learned through prior work.                          |
| open question                 | `knowledge/architecture/open-questions.md`                                       | Record an unresolved question, pending decision, deferred idea, or uncertainty that must not be inferred automatically.          |
| candidate ADR                 | `knowledge/architecture/open-questions.md` first; future ADR file after approval | Mark an unresolved question that may require a stable Architecture Decision Record.                                              |
| ADR                           | future ADR file under `knowledge/architecture/`                                  | Record a stable decision, alternatives considered, tradeoffs, consequences, and related evidence.                                |
| inventory finding             | `/srv/toolbox/shared/inventory/` or a generated report/TSV                       | Record observed state at a point in time.                                                                                        |
| graph relation                | `knowledge/graph/` after graph-generation workflow exists                        | Record relationships between services, scripts, paths, artifacts, policies, inventories, reports, workflows, and other entities. |
| service-map update            | `knowledge/services/`                                                            | Update human-readable operational context for a selected service, subsystem, or infrastructure layer.                            |
| policy update                 | `knowledge/policies/`                                                            | Update a rule, safety boundary, behavioral constraint, or required workflow.                                                     |
| report or TSV only            | `/srv/toolbox/shared/`                                                           | Preserve diagnostic evidence without turning it into architecture knowledge.                                                     |
| no architecture update        | none                                                                             | Use when a finding is temporary, already covered, not recurring, or not architecturally meaningful.                              |

Agents must not create architecture knowledge merely because a diagnostic found a matching keyword.

A finding should become architecture knowledge only when it preserves operational memory, records unresolved intent, or prevents future human or agent error.

## Historical operational lesson classification

A finding may be classified as a historical operational lesson only when it satisfies all of the following:

* it comes from real work, a real incident, a real workaround, or a real operational discovery;
* it explains a problem or failure mode that should not be forgotten;
* it records what was done or learned;
* it has future operational consequences;
* it is not merely a rule already defined in policy;
* it is not merely current observed state;
* it is not merely a service description;
* it is not merely a dependency relation.

A historical operational lesson should use this template:

### HNNN — Short descriptive title

Domain:

Type: historical lesson

Problem:

Resolution or workaround:

Lesson:

Operational consequence:

Related artifacts:

The `Problem` field should describe what happened or what risk was discovered.

The `Resolution or workaround` field should describe what was actually adopted, not an abstract recommendation.

The `Lesson` field should explain the generalizable learning.

The `Operational consequence` field should explain how humans, ChatGPT, Codex/local agents, scripts, or future automation should behave differently because of the lesson.

The `Related artifacts` field may reference service maps, policies, scripts, reports, TSVs, docs, or future ADRs.

Do not record a historical lesson if the item only says that agents must ask for approval, produce reports, or follow existing policy. Those rules belong in policy.

## Open question classification

A finding may be classified as an open question when it satisfies at least one of the following:

* it requires operator intent;
* it requires diagnosis before a decision;
* it represents an idea discussed but not implemented;
* it captures a deferred workfront;
* it identifies a boundary that is not yet settled;
* it may become an ADR;
* it affects more than one service, workflow, policy, graph relation, or operational domain;
* it should not be silently decided by ChatGPT, Codex/local agents, scripts, or future automation.

An open question should use this template:

### ONNN — Short descriptive title

Status:

Question:

Why open:

Needed diagnosis:

Candidate ADR:

Related domains:

The `Status` field must use one of:

* `open`
* `needs diagnosis`
* `needs operator decision`
* `candidate ADR`
* `deferred`
* `resolved`

The `Question` field must be phrased as an actual question.

The `Why open` field should explain why the issue has not been resolved yet.

The `Needed diagnosis` field should state what must be inspected, tested, compared, or confirmed before resolving the question.

The `Candidate ADR` field should be `Yes`, `Maybe`, or `No`.

The `Related domains` field should name the relevant areas, such as Codex, graph, inventory, backup, Docker, music staging, Beets, Stockhausen, Navidrome, Samba, FileBrowser, or Toolbox scripts.

Do not record an open question if the answer is already established in a policy, service map, script, report, or committed decision.

## Candidate ADR classification

An open question should be marked as `candidate ADR` when the eventual answer is likely to define a durable decision.

A topic is likely a candidate ADR when it involves:

* long-term architecture;
* cross-service boundaries;
* security or exposure;
* backup and restore strategy;
* graph and inventory model;
* run-job or pipeline scope;
* media lifecycle;
* staging/import semantics;
* public versus private access;
* data preservation or deletion;
* toolchain strategy;
* future agent authority.

A candidate ADR must first exist as an open question unless the operator explicitly asks to create the ADR directly.

Agents may propose ADR promotion, but must not finalize the ADR without operator approval.

## ADR artifact template

Future ADRs should use a stable template.

Recommended ADR template:

### ADR-NNNN — Short decision title

Status:

Date:

Context:

Decision:

Alternatives considered:

Consequences:

Evidence:

Related historical lessons:

Related open questions:

Related services:

Related policies:

Related graph or inventory artifacts:

The `Status` field should use values such as:

* `proposed`
* `accepted`
* `superseded`
* `deprecated`

The `Context` field should explain why the decision exists.

The `Decision` field should state what was chosen.

The `Alternatives considered` field should record meaningful options, including rejected options when relevant.

The `Consequences` field should explain operational tradeoffs.

The `Evidence` field should point to reports, TSVs, scripts, service maps, diagnostics, or operator-confirmed history.

The `Related historical lessons` field should link to lessons that motivated the decision.

The `Related open questions` field should link to questions resolved or affected by the ADR.

## Classification workflow

When an agent finds a possible architecture-knowledge item, it must classify it in this order:

1. Is it current observed state?

   * If yes, it belongs in inventory, report, TSV, or graph input, not directly in architecture knowledge.

2. Is it a relationship between entities?

   * If yes, it belongs in `knowledge/graph/` after graph-generation workflow exists.

3. Is it a human-readable description of a service or subsystem?

   * If yes, it belongs in `knowledge/services/`.

4. Is it a rule, constraint, or required behavior?

   * If yes, it belongs in `knowledge/policies/`.

5. Is it a real problem, workaround, or lesson learned from previous work?

   * If yes, it may belong in `historical-operational-lessons.md`.

6. Is it unresolved, deferred, dependent on operator intent, or a possible future decision?

   * If yes, it may belong in `open-questions.md`.

7. Is it a stable architectural decision with alternatives and consequences?

   * If yes, it may become an ADR after operator approval.

8. Is it temporary, already covered, low-value, or not recurring?

   * If yes, do not create architecture knowledge.

Agents must explain the classification when proposing updates to architecture knowledge.

## Required review before updating architecture artifacts

Before adding a historical lesson, agents must check whether the same lesson already exists.

Before adding an open question, agents must check whether the same question or decision already exists.

Before marking an open question as resolved, agents must identify the artifact that resolved it.

Before proposing a candidate ADR, agents must explain why the question is not merely a policy update, service-map update, graph relation, report, or simple task.

Before creating or updating an ADR, agents must ask for operator approval.

## Resolution template for open questions

When an open question is resolved, preserve the item and update it instead of deleting it immediately.

A resolved open question should include:

Status: `resolved`

Resolution:

Resolved by:

Date:

Follow-up:

The `Resolution` field should state the answer.

The `Resolved by` field should reference the ADR, policy, service-map update, script, report, commit, or operator decision that resolved the question.

The `Follow-up` field should state whether further action is needed.

Resolved questions may later be moved to a `Resolved questions` section if the file becomes too large.

## Historical operational lessons

Historical operational lessons belong in:

* `knowledge/architecture/historical-operational-lessons.md`

A historical operational lesson should be proposed when work reveals:

* a real problem that occurred;
* a workaround or solution that was adopted;
* an operational failure mode that should not be repeated;
* a tool-specific lesson learned through actual use;
* a collection-specific lesson that generalizes to future work;
* a recurring pattern that affects safety, quality, reliability, or maintainability.

A historical lesson should explain:

* the problem;
* the adopted solution or workaround;
* the operational lesson;
* the consequence for future human or agent work;
* related documents, scripts, reports, services, or policies when useful.

Historical lessons must not be used to restate policies already defined elsewhere.

Historical lessons must not become a full chronological history of the homelab.

Historical lessons must not replace service maps, inventories, graph relations, reports, TSVs, or ADRs.

## Open questions

Open questions belong in:

* `knowledge/architecture/open-questions.md`

An open question should be proposed when work reveals:

* a decision that has not been made;
* an idea discussed but not implemented;
* a recurring uncertainty;
* a gap that requires operator intent;
* a topic that requires diagnosis before action;
* a possible future ADR;
* an unresolved boundary between policies, services, graph, inventory, scripts, or workflows.

Open questions should include:

* status;
* question;
* why it remains open;
* needed diagnosis;
* whether it is a candidate ADR;
* related domains.

Valid statuses are:

* `open`
* `needs diagnosis`
* `needs operator decision`
* `candidate ADR`
* `deferred`
* `resolved`

Agents must not silently resolve open questions by guessing.

When an open question is resolved, the resolution should point to the resulting ADR, policy, service-map update, script, report, or other durable artifact.

## Candidate ADRs

An open question may be marked as `candidate ADR` when it involves:

* a durable architectural decision;
* a cross-service or cross-domain tradeoff;
* a decision with long-term operational consequences;
* a security, backup, storage, graph, service, or workflow boundary;
* a choice that future agents are likely to misunderstand if undocumented.

Agents may propose that a topic become an ADR, but must not create or finalize ADRs without operator approval.

An ADR should explain:

* context;
* decision;
* alternatives considered;
* consequences;
* related evidence;
* related open questions or historical lessons.

## What must not be recorded as architecture knowledge

Agents should not add items to `knowledge/architecture/` when the item is only:

* current observed host state;
* a command output;
* a temporary diagnostic result;
* a simple task;
* a bug already fixed with no recurring lesson;
* a policy already defined in `knowledge/policies/`;
* a service description that belongs in `knowledge/services/`;
* a dependency relationship that belongs in `knowledge/graph/`;
* a generated artifact that belongs under `/srv/toolbox/shared/`;
* a personal memory not relevant to homelab or Toolbox operation.

## Relationship with diagnostics

Diagnostics may reveal candidates for architecture knowledge, but diagnostics do not automatically create architecture knowledge.

A diagnostic result may lead to:

* no documentation change;
* a report or TSV only;
* a service-map update;
* a policy update;
* a historical lesson;
* an open question;
* a candidate ADR;
* a graph or inventory update.

Agents must classify diagnostic findings before proposing documentation changes.

## Relationship with graph and inventory

Inventory describes what exists or was observed at a point in time.

Graph describes how entities connect.

Architecture knowledge explains why decisions exist, what has been learned, and what remains unresolved.

If graph or inventory data is missing, stale, or incomplete, agents must identify the gap and propose read-only diagnostics.

Agents must not manually duplicate detailed graph relationships inside historical lessons or open questions.

## Update workflow

Before proposing updates to architecture knowledge, agents should inspect:

* `knowledge/architecture/historical-operational-lessons.md`
* `knowledge/architecture/open-questions.md`
* relevant service maps under `knowledge/services/`
* relevant policies under `knowledge/policies/`
* relevant operational docs under `docs/`
* relevant scripts and reports when applicable
* latest inventories or graph files when available

For simple documentation-only updates, agents may propose a direct patch.

For updates derived from host state, scripts, services, media paths, backups, Docker, networking, or generated artifacts, agents must prefer read-only diagnostics first.

For high-impact decisions, agents should propose an open question or candidate ADR rather than embedding the decision directly into prose.

## Duplicate control

Agents must avoid duplicating the same lesson or question across multiple files.

If a topic already exists:

* update the existing item;
* refine its status;
* add a reference;
* or ask whether it should be promoted to ADR.

Agents must not create multiple open questions for the same unresolved decision unless the distinction is explicit.

## Operator confirmation

Operator confirmation is required when:

* the historical cause of a decision is unclear;
* the proposed lesson depends on memory rather than evidence;
* the question implies a future architectural direction;
* a candidate ADR is being created or resolved;
* an item should be marked as resolved;
* a topic crosses into security, backup, storage, media deletion, public exposure, credentials, or service disruption.

## Examples

A Samba permission incident that led to UID/GID and mask normalization may become a historical operational lesson.

A future decision about whether FileBrowser should be exposed through Tailscale Serve may become an open question or candidate ADR.

A current list of Docker containers belongs in inventory, not architecture knowledge.

A relation such as Navidrome mounting `/srv/media/music` belongs in graph, not historical lessons.

A rule requiring human approval belongs in policy, not historical lessons.

A recurring failure mode in Stockhausen metadata normalization belongs in historical lessons.

A not-yet-decided Beets plugin profile model belongs in open questions.

## Validation

Architecture knowledge files must be included in the main knowledge validation workflow.

Policy consistency validation should include this policy once it exists.

Agents must run relevant validators before committing architecture knowledge changes.

At minimum, run:

* `validate-toolbox-knowledge-context.sh`
* `scripts/admin/system/validate-toolbox-knowledge-policies-consistency.sh`
* `scripts/admin/system/validate-toolbox-knowledge-services-consistency.sh`

## Related documents

* `knowledge/context/agent-entrypoint.md`
* `knowledge/context/homelab-context.md`
* `knowledge/context/toolbox-context.md`
* `knowledge/services/README.md`
* `knowledge/architecture/historical-operational-lessons.md`
* `knowledge/architecture/open-questions.md`
* `knowledge/policies/agent-safety-policy.md`
* `knowledge/policies/change-management-policy.md`
* `knowledge/policies/reporting-policy.md`
* `knowledge/policies/filesystem-safety-policy.md`
* `knowledge/policies/media-curation-policy.md`
* `docs/operations/toolbox_architecture_reconciliation.md`
* `docs/operations/toolbox_output_destinations_policy.md`
