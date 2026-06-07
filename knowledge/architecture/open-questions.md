# Open Questions

This document records unresolved questions, deferred ideas, and decisions that should not be inferred automatically by ChatGPT, Codex/local agents, scripts, or future automation.

It is not a task tracker, not a policy file, not a service inventory, and not a dependency graph.

Open questions may later become ADRs, policies, service-map updates, scripts, graph schema decisions, runbooks, or backlog items.

## Scope

This document should include:

* questions that need human decision;
* questions that need diagnosis before action;
* ideas discussed but not implemented;
* candidate ADRs;
* deferred fronts that should not be forgotten;
* unresolved operational boundaries.

This document should not duplicate:

* policies already decided;
* service-map content;
* generated reports or TSVs;
* dependency relationships that belong in `knowledge/graph/`;
* observed state that belongs in `/srv/toolbox/shared/inventory/`.

## Status values

Use these statuses:

* `open` — known question, not yet resolved;
* `needs diagnosis` — requires read-only investigation before decision;
* `needs operator decision` — requires human judgment;
* `candidate ADR` — likely needs an Architecture Decision Record;
* `deferred` — valid idea intentionally postponed;
* `resolved` — answered and should point to the resulting document, ADR, script, or policy.

## How agents should use this document

Agents must not silently resolve open questions by guessing.

When work touches an open question, the agent should:

1. identify the relevant question;
2. inspect related docs, services, reports, scripts, and inventories;
3. run bounded read-only diagnostics when needed;
4. ask the operator for missing intent;
5. propose an ADR or document update when the decision becomes stable.

## Open questions

### Codex and local-agent operation

#### O001 — First real Codex/local-agent use

Status: `needs operator decision`

Question: What should be the first real Codex/local-agent task in the homelab?

Why open: The knowledge layer has been prepared, but Codex has not yet been used in the operational workflow.

Needed diagnosis: Confirm installed tooling, repo access, safety boundaries, and first read-only scope.

Candidate ADR: Yes.

Related domains: Codex, Toolbox, knowledge, safety.

#### O002 — Protocol between user, ChatGPT, and Codex

Status: `needs operator decision`

Question: How should Codex report findings, gaps, questions, and patch proposals while preserving the quality of the current collaborative workflow?

Why open: The goal is to reduce copy/paste and uploads without losing review discipline.

Needed diagnosis: A small read-only pilot.

Candidate ADR: Yes.

Related domains: Codex, ChatGPT, reports, briefs, handoff.

#### O003 — Codex patch authority

Status: `needs operator decision`

Question: Should Codex initially be limited to read-only diagnostics, or may it prepare patches for manual review?

Why open: Observing, proposing, editing, committing, and pushing have different risk levels.

Needed diagnosis: Review tool capabilities and safety workflow.

Candidate ADR: Yes.

Related domains: agent safety, change management, Git.

#### O004 — Codex evidence format

Status: `open`

Question: How should Codex cite or reference reports, TSVs, inventories, scripts, graph entries, and file paths in its findings?

Why open: Durable evidence is central to the Toolbox workflow.

Needed diagnosis: Pilot a report format.

Candidate ADR: Maybe.

Related domains: reporting, inventory, graph, handoff.

#### O005 — ChatGPT/Codex handoff briefs

Status: `open`

Question: Should the Toolbox generate handoff briefs or live-log artifacts for ChatGPT/Codex containing Git status, latest reports, graph summary, open questions, operator checkpoints, generated evidence, and current workfront?

Why open: Long chats, mobile terminal scrollback limits, interrupted Codex sessions, and manual context transfer are recurring friction. The Block 3 semantic-inventory closure showed that multi-phase Codex work benefits from a durable live-log under `/srv/toolbox/shared/reports/system/` in addition to any concise ChatGPT brief.

Needed diagnosis: Identify useful inputs, output format, retention expectations, and when a concise brief is enough versus when a live-log/handoff file is required.

Candidate ADR: Maybe.

Related domains: Codex, ChatGPT, reports, Toolbox.

### Inventory and graph

#### O006 — Inventory generation command

Status: `needs diagnosis`

Question: Should there be one unified inventory command or separate inventory diagnostics by domain?

Why open: Inventories are required input for graph generation. `scripts/admin/system/generate-toolbox-inventory.sh` now produces the initial `toolbox_inventory_v0` layer from the Toolbox script inventory, but it does not settle whether future inventory generation should remain domain-specific, become unified, or define shared schemas across domains.

Needed diagnosis: Compare the dated Toolbox script inventory and `toolbox_inventory_v0` output with other candidate inventory domains, then decide the command structure, freshness rules, and common schema requirements.

Candidate ADR: Yes.

Related domains: inventory, graph, Toolbox scripts.

#### O007 — Graph generation command

Status: `needs diagnosis`

Question: What command or workflow will produce `knowledge/graph/entities.yaml` and `knowledge/graph/relations.yaml`?

Why open: The graph model is conceptually defined but not implemented. Inventory must precede graph generation, and graph relations must be derived from dated evidence, inventory rows, relation hints, service maps, policies, and explicit graph-generation rules rather than memory or manually invented assumptions. The first semantic script pass showed that raw script inventory and `toolbox_inventory_v0` are useful but still too shallow for graph generation: path-level classification is not semantic classification, static script text is not runtime-validated behavior, and relation hints are not graph edges.

Needed diagnosis: Define graph inputs, schema, generation process, validation, update policy, and the intermediate semantic inventory layer needed before non-authoritative relation hints or evidence fields can become proposed graph entities and relations. The graph remains blocked until semantic inventory coverage expands beyond the core/high-risk scope, runtime validation evidence is modeled separately, and relation-candidate promotion rules are defined.

Candidate ADR: Yes.

Related domains: graph, Codex, inventory, scripts.

#### O008 — Graph schema

Status: `candidate ADR`

Question: What schema should represent services, scripts, paths, reports, TSVs, Compose projects, mounts, policies, workflows, semantic script classifications, and evidence?

Why open: Without schema, the graph may become arbitrary text. The first script semantics pass showed that `runtime` and `automation_type` cannot be trusted from path or static feature flags alone. For example, `bin/run-job` is semantically a run-job executor, non-empty `scripts/pipelines/*.sh` are semantic pipelines only when they implement the `JOB_ROOT` input/work/output contract, `scripts/lib/*.sh` are sourced modules, `scripts/helpers/*.sh` are executable helpers, Git apply scripts are controlled Git workflows, and `generate-toolbox-inventory.sh` is semantically a generator even when path/phase metadata is shallow.

Needed diagnosis: Sample entities from the lote 1 service maps, raw script inventory, `toolbox_inventory_v0`, and a controlled semantic script inventory pass that distinguishes path-level classification from source-body semantics and runtime-validated behavior. Decide how semantic inventory expansion to all scripts should represent placeholders, legacy scripts, and modernization candidates without turning cleanup findings into graph facts.

Candidate ADR: Yes.

Related domains: graph, architecture, reporting.

#### O009 — Graph storage and Git tracking

Status: `open`

Question: Should graph artifacts be Git-tracked under `knowledge/graph/`, generated under `/srv/toolbox/shared/`, or split into stable and dynamic layers?

Why open: The graph may combine observed state with curated knowledge.

Needed diagnosis: Separate stable relationships from dynamic inventory facts.

Candidate ADR: Yes.

Related domains: graph, Git, inventory.

#### O010 — Relation evidence and confidence

Status: `needs diagnosis`

Question: Should each graph relation include source, confidence, observed time, evidence path, and generating command?

Why open: Relations without evidence can become undocumented assumptions. The first `toolbox_inventory_v0` output records reports and TSVs as evidence fields and explicitly treats relation hints as non-authoritative hints, not graph edges. The semantic script pass reinforced that source-body evidence is stronger than path or text-mention flags, but still weaker than runtime-validated behavior.

Needed diagnosis: Design minimum relation metadata and decide how dated evidence paths, inventory rows, service maps, policies, relation hints, source-body semantics, runtime validation, and explicit generation rules should support confidence and provenance. Define the future runtime-validation evidence layer and the review threshold for promoting relation candidates into accepted graph edges.

Candidate ADR: Yes.

Related domains: graph, reporting, Codex.

### ADR and architecture process

#### O011 — ADR format

Status: `candidate ADR`

Question: What ADR format should the homelab use?

Why open: ADRs are planned but no template exists.

Needed diagnosis: Review current docs such as `docs/toolbox_design_rationale.md` and operations docs.

Candidate ADR: Yes.

Related domains: architecture, documentation.

#### O012 — Open question to ADR threshold

Status: `needs operator decision`

Question: When does an open question become an ADR?

Why open: Too many ADRs create noise; too few lose decisions.

Needed diagnosis: Define criteria for significance, reversibility, cross-service impact, and risk.

Candidate ADR: Yes.

Related domains: architecture.

#### O013 — Historical decisions without invented rationale

Status: `needs operator decision`

Question: How should old decisions be documented when the reason is known from memory but not fully evidenced in repo artifacts?

Why open: Many decisions were made incrementally in chat.

Needed diagnosis: Combine memory, reports, scripts, and operator confirmation.

Candidate ADR: Yes.

Related domains: historical lessons, ADR, knowledge.

### Service maps

#### O014 — Lote 2 timing

Status: `open`

Question: Should lote 2 service maps wait until after the first graph/inventory work?

Why open: Continuing service maps manually may drift from the Codex objective.

Needed diagnosis: Determine what the first Codex pilot needs.

Candidate ADR: No.

Related domains: services, graph, Codex.

#### O015 — Lote 2 scope

Status: `deferred`

Question: Which service maps should be created next, and in what order?

Candidate items: slskd, Immich, Jellyfin, Calibre-Web, Kavita, Homepage, Portainer, monitoring.

Why open: These services matter, but may not block the Codex/graph phase.

Needed diagnosis: Use graph/inventory or first task demand.

Candidate ADR: No.

Related domains: services.

#### O016 — Service maps after graph

Status: `open`

Question: Should service maps be revised after graph generation to remove inferred dependencies or align with graph evidence?

Why open: Service maps are human-readable, while graph will contain relationship data.

Needed diagnosis: Generate initial graph and compare with services.

Candidate ADR: Maybe.

Related domains: services, graph.

### Music staging and media lifecycle

#### O017 — Final `ready` criteria

Status: `candidate ADR`

Question: What exactly must pass before music moves from `tagging` to `ready`?

Why open: Integrity, artwork, replaygain, genre, duplicates, missing checks, metadata review, and Beets plugin stages were discussed but not finalized.

Needed diagnosis: Review tagging audit, plugin readiness, Thembi/Spectrum pilots, and desired operator burden.

Candidate ADR: Yes.

Related domains: music staging, media curation.

#### O018 — Post-import staging policy

Status: `needs operator decision`

Question: After import to `/srv/media/music`, should staging material move to `imported`, `archive`, remain temporarily, or be deleted after validation?

Why open: Storage, backup, rollback, and deduplication depend on this.

Needed diagnosis: Storage pressure, backup scope, restore confidence, and import validation.

Candidate ADR: Yes.

Related domains: music staging, backup, storage.

#### O019 — ReplayGain workflow

Status: `open`

Question: Should ReplayGain be required before `ready`, optional, collection-specific, or post-import?

Why open: ReplayGain was considered useful but not implemented.

Needed diagnosis: Test backend options such as `rsgain` or Beets plugin behavior.

Candidate ADR: Maybe.

Related domains: Beets, music staging.

#### O020 — Artwork workflow

Status: `open`

Question: Should artwork be fetched, embedded, stored as `cover.jpg`, or handled differently by collection?

Why open: Stockhausen, general music, Navidrome, Feishin, and Amperfy may have different needs.

Needed diagnosis: Test fetchart/embedart and client behavior.

Candidate ADR: Yes.

Related domains: media curation, Navidrome, Beets.

#### O021 — Genre and lastgenre policy

Status: `deferred`

Question: How can genre suggestions be used without degrading metadata quality?

Why open: Automatic genres can be noisy and inconsistent.

Needed diagnosis: Candidate-only diagnostic before any apply.

Candidate ADR: Maybe.

Related domains: Beets, metadata.

#### O022 — Lyrics policy

Status: `deferred`

Question: Should lyrics be included at all, and if so, where in the lifecycle?

Why open: Lyrics were considered interesting but low priority.

Needed diagnosis: Plugin test and usefulness review.

Candidate ADR: No.

Related domains: Beets, media.

#### O023 — Convert/export as run-job

Status: `candidate ADR`

Question: How should conversion/export workflows be implemented without affecting archival masters?

Why open: `convert` was approved conceptually as export/run-job, but not implemented.

Needed diagnosis: Design export pipeline and destination rules.

Candidate ADR: Yes.

Related domains: run-job, media, transcoding.

#### O024 — Rewrite/canonicalization as import front

Status: `candidate ADR`

Question: How should rewrite/canonicalization be implemented without mixing it with metadata matching?

Why open: Approved conceptually but not implemented.

Needed diagnosis: Define workflow boundary.

Candidate ADR: Yes.

Related domains: metadata, music import.

### Beets and audio tooling

#### O025 — Beets profiles

Status: `needs diagnosis`

Question: Should Beets have profiles for identification, metadata write, artwork, replaygain, genre, and ready-check stages?

Why open: Plugin readiness exists, but profile design does not.

Needed diagnosis: Review current sandbox config and plugin matrix.

Candidate ADR: Maybe.

Related domains: Beets, music staging.

#### O026 — Additional audio dependencies

Status: `open`

Question: When should optional tools such as `mp3val`, `mp3check`, `rsgain`, and ImageMagick-related tools be installed?

Why open: Readiness diagnostics identify possible dependencies, but installing everything may be overengineering.

Needed diagnosis: Tie dependencies to concrete workflows.

Candidate ADR: No.

Related domains: media tooling.

#### O027 — Avoiding pilot overfit

Status: `open`

Question: How many and what kinds of albums should validate the staging pipeline before general use?

Why open: Thembi and Spectrum are not enough to prove all cases.

Needed diagnosis: Select diverse pilots.

Candidate ADR: Maybe.

Related domains: Beets, music staging.

### Stockhausen

#### O028 — Album 089

Status: `open`

Question: What is the plan for `089 Hoffnung und Glanz`?

Why open: It remains the known missing Stockhausen item.

Needed diagnosis: Locate source, inspect files, plan import.

Candidate ADR: No.

Related domains: Stockhausen.

#### O029 — Stockhausen performer and MBID enrichment

Status: `deferred`

Question: When and how should deferred performer and MBID enrichment be completed?

Why open: Structural normalization was prioritized; enrichment was deferred.

Needed diagnosis: Cross-check official catalog, MusicBrainz, and existing tags.

Candidate ADR: Maybe.

Related domains: Stockhausen, metadata.

#### O030 — Stockhausen-derived TUI/dashboard/search

Status: `deferred`

Question: Which lessons from the Stockhausen workflow should shape future TUI, dashboard, or search features?

Why open: UI ideas were intentionally deferred until lessons were extracted.

Needed diagnosis: Analyze reports, TSVs, script families, and workflow pain points.

Candidate ADR: Maybe.

Related domains: Toolbox UI, Stockhausen.

### Backup, restore, and storage

#### O031 — Large media backup policy

Status: `candidate ADR`

Question: What is the final backup policy for large media collections?

Why open: Configs, metadata, reports, and selected important files are different from large music/video/photo libraries.

Needed diagnosis: Storage, cost, restore time, criticality, and offsite strategy.

Candidate ADR: Yes.

Related domains: backup, storage, media.

#### O032 — Restore testing

Status: `open`

Question: How should restore tests be performed and recorded?

Why open: Backup without restore validation is incomplete.

Needed diagnosis: Define a small safe restore test.

Candidate ADR: Maybe.

Related domains: backup.

#### O033 — Backrest role

Status: `open`

Question: What is the final role of Backrest relative to Restic and existing backup scripts?

Why open: Restic is foundational; Backrest's role needs confirmation from actual use.

Needed diagnosis: Inspect current deployment and workflows.

Candidate ADR: Maybe.

Related domains: backup.

#### O034 — Storage and ATA health monitoring

Status: `open`

Question: Should storage/ATA diagnostics become periodic monitoring or remain on-demand?

Why open: A storage/ATA incident led to a diagnostic script, but no monitoring policy.

Needed diagnosis: Review SMART/storage reports and system capacity.

Candidate ADR: Maybe.

Related domains: storage, monitoring.

### Toolbox evolution

#### O035 — `scripts/lib` evolution

Status: `open`

Question: Which repeated patterns should move into `scripts/lib`, and when should old scripts be migrated?

Why open: Many scripts predate newer conventions.

Needed diagnosis: Script inventory and pattern analysis.

Candidate ADR: Maybe.

Related domains: Toolbox scripts.

#### O036 — Final `run-job` scope

Status: `candidate ADR`

Question: Which tasks belong in `run-job` pipelines and which belong in host workflows?

Why open: The principle is understood, but scope should be formalized as tooling expands.

Needed diagnosis: Review existing pipelines and candidate media/graph/export workflows.

Candidate ADR: Yes.

Related domains: Toolbox, pipelines.

#### O037 — New pipelines

Status: `deferred`

Question: Which new pipelines should be implemented next?

Candidate ideas: media export/convert, graph generation, inventory generation, handoff briefs.

Why open: These are useful but should follow actual need.

Needed diagnosis: Prioritize after Codex pilot and graph schema.

Candidate ADR: No.

Related domains: Toolbox, pipelines.

#### O038 — Script inventory maintenance

Status: `open`

Question: Should script inventory be updated manually, during Git routines, or through periodic validation?

Why open: Script inventory is becoming important for Codex and graph.

Needed diagnosis: Evaluate runtime cost and usefulness.

Candidate ADR: Maybe.

Related domains: Toolbox, Codex, graph.

#### O039 — Graph-aware tooling

Status: `deferred`

Question: Should future tools consult `knowledge/graph` before impact-sensitive changes?

Why open: The graph does not exist yet.

Needed diagnosis: Generate initial graph and validate usefulness.

Candidate ADR: Yes, later.

Related domains: graph, Toolbox.

#### O040 — Python stack hygiene

Status: `deferred`

Question: When should the full pyenv/Poetry/toolbox-media Python hygiene front be opened?

Why open: It was deliberately deferred during Beets setup.

Needed diagnosis: Revisit when CraftText or toolbox-media needs it.

Candidate ADR: No.

Related domains: Python, CraftText, Toolbox.

#### O041 — CraftText integration

Status: `deferred`

Question: How should CraftText relate to Toolbox, homelab, Python stack, and future local AI workflows?

Why open: It is strategically related but outside the current Codex/knowledge phase.

Needed diagnosis: Reopen when current knowledge/Codex base stabilizes.

Candidate ADR: Maybe.

Related domains: CraftText, Python, local AI.

### Other media services

#### O042 — PDFs, Calibre-Web, and Kavita

Status: `deferred`

Question: What is the proper organization model for PDFs, ebooks, Calibre-Web, and Kavita?

Why open: Kavita was not satisfying as an organizer, while Calibre-Web is more canonical for ebooks.

Needed diagnosis: Inspect current library and desired use.

Candidate ADR: Maybe.

Related domains: ebooks, PDFs.

#### O043 — Immich and photos

Status: `deferred`

Question: How should photos, photos-raw, external libraries, backup, and import be handled?

Why open: Immich exists but has not been part of the current knowledge/service phase.

Needed diagnosis: Future service map or graph.

Candidate ADR: Maybe.

Related domains: photos, Immich.

#### O044 — Jellyfin and videos

Status: `deferred`

Question: What is the video library, transcoding, backup, and organization policy?

Why open: Jellyfin exists but has not been part of the current phase.

Needed diagnosis: Future service map or graph.

Candidate ADR: Maybe.

Related domains: video, Jellyfin.

#### O045 — Monitoring

Status: `deferred`

Question: Should monitoring remain lightweight diagnostics/Homepage/Glances, or become a more formal service map with periodic checks?

Why open: Monitoring was planned but not completed as a full front.

Needed diagnosis: Assess current needs and host limits.

Candidate ADR: Maybe.

Related domains: monitoring.

#### O046 — Secrets and credentials

Status: `deferred`

Question: How should secrets, tokens, Compose envs, and agent access be handled?

Why open: Codex/local-agent use makes secrets boundaries more important.

Needed diagnosis: Safe inventory without exposing secret values.

Candidate ADR: Yes.

Related domains: security, Codex, Docker.

#### O047 — slskd and Soulseek

Status: `deferred`

Question: How should slskd be documented and represented in graph relative to music staging?

Why open: slskd is operationally important but was outside service-map lote 1.

Needed diagnosis: Future service map or graph.

Candidate ADR: No.

Related domains: slskd, music staging.

#### O048 — Block 3 infrastructure modernization queue

Status: `needs operator decision`

Question: How should Block 3 infrastructure-admin findings from semantic inventory be turned into a modernization backlog without treating warnings as immediate patches or graph edges?

Why open: The Block 3 semantic inventory identified high-risk and modernization-relevant source-body findings: backup repository backup/prune workflows, block-device formatting, firewall/UFW apply, DOCKER-USER apply/rollback, package cleanup, Snap/Flatpak removal, cache/destructive cleanup, weak or missing typed confirmation on high-risk apply workflows, sensitive path reads, legacy destinations (`$HOME/relatorios-backup`, `$HOME/relatorios-disco`, `/home/thiago/iptables-backups`), and missing canonical report/TSV outputs in some older scripts. `scripts/admin/storage/diagnose-storage-pressure-and-ata-health.sh` is the current canonical shared-report/TSV example. `scripts/admin/storage/investigate-storage-homelab.sh` still has a nonblocking `unknown` summary.

Needed diagnosis: Review the final Block 3 handoff and semantic report, decide which findings are modernization backlog items, which scripts should remain manual-only, whether high-risk apply workflows need a typed-confirmation standard, and whether Block 3 warning categories should influence semantic inventory expansion before graph work.

Candidate ADR: Maybe.

Related domains: Toolbox scripts, infrastructure, backup, Docker, firewall, network, storage, inventory, graph.

## Resolved questions

Resolved questions should be moved here only when a stable decision, ADR, policy, script, or service-map update records the answer.

Current resolved-question index is intentionally empty.

## Related documents

* `knowledge/context/agent-entrypoint.md`
* `knowledge/context/homelab-context.md`
* `knowledge/context/toolbox-context.md`
* `knowledge/services/README.md`
* `knowledge/architecture/historical-operational-lessons.md`
* `knowledge/policies/agent-safety-policy.md`
* `knowledge/policies/change-management-policy.md`
* `knowledge/policies/reporting-policy.md`
* `knowledge/policies/filesystem-safety-policy.md`
* `knowledge/policies/media-curation-policy.md`
* `docs/operations/toolbox_architecture_reconciliation.md`
* `docs/operations/toolbox_output_destinations_policy.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_reports_policy.md`
* `docs/media/stockhausen_metadata_policy.md`
* `docs/media/stockhausen_gold_model_stimmung.md`
