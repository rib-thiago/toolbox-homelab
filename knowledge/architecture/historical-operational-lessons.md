# Historical Operational Lessons

This document records operational lessons learned through real homelab and Toolbox work.

It is not a full history, not a service inventory, not a policy document, and not a dependency graph.

It exists so that humans, ChatGPT, Codex/local agents, scripts, and future automation do not repeat known mistakes, ignore hard-won workarounds, or treat prior incidents as ordinary abstract policy.

## Scope

This document should record:

* problems that actually occurred;
* solutions or workarounds that were adopted;
* operational lessons learned from those incidents;
* consequences for future human or agent work;
* references to related service maps, policies, scripts, reports, or docs when useful.

This document should not duplicate:

* `knowledge/policies/`;
* `knowledge/services/`;
* `knowledge/graph/`;
* `/srv/toolbox/shared/inventory/`;
* generated reports, TSVs, logs, or snapshots;
* full chat history.

## How agents should use this document

Agents must consult this document before proposing changes in affected domains.

Lessons in this document do not automatically authorize changes. They provide operational memory and risk context.

If a lesson conflicts with current observed state, the agent must stop and ask for human review or run bounded read-only diagnostics.

If a lesson reveals a recurring decision or tradeoff, it may point to an ADR candidate.

## Relationship with inventory, graph, and ADRs

Inventory describes observed state.

Graph describes how observed and documented entities connect.

Historical lessons explain what was learned through prior work.

ADRs explain stable decisions, tradeoffs, and consequences.

Agents must not infer architectural intent from observed state alone.

## Lessons

### Filesystem, permissions, and media paths

#### H001 — Samba, UID/GID, and media permissions

Problem: Windows/Samba operations produced access-denied, move, rename, and ownership inconsistencies around `/srv/media`.

Resolution: Samba was stabilized using consistent UID/GID 1000 ownership, force user/group behavior, coherent directory/file masks, and normalization of media ownership.

Lesson: Media permission problems must not be solved with generic recursive `chmod` or `chown` commands. The correct approach is to diagnose ownership, UID/GID, Samba config, masks, bind mounts, Docker consumers, and the affected service paths.

Operational consequence: Any future work involving `/srv/media`, Samba, FileBrowser, Navidrome, music staging, or ownership must treat permission changes as high risk.

Related areas:

* `knowledge/services/samba.md`
* `knowledge/services/filebrowser.md`
* `knowledge/services/music-staging.md`
* `knowledge/policies/filesystem-safety-policy.md`

#### H002 — Samba and FileBrowser are different access layers

Problem: Samba and FileBrowser both expose files, but they do not have the same semantics or risks.

Resolution: Samba became the SMB/Windows access layer for media shares. FileBrowser became the browser-based access layer for selected filesystem areas and Toolbox artifacts.

Lesson: Access through Samba and access through FileBrowser must not be treated as equivalent.

Operational consequence: Agents must inspect mounts, paths, users, permissions, and access boundaries before proposing changes to either layer.

### Docker, networking, and exposure

#### H003 — Docker-first does not mean restart-first

Problem: Docker services can tempt operators or agents to diagnose by restarting, recreating, or changing Compose files.

Resolution: Service work shifted toward read-only inspection first: Compose files, bind mounts, networks, published ports, bounded logs, NPM routes, UFW, DOCKER-USER, and Tailscale/LAN access.

Lesson: A running container is part of a larger operational graph. Restarting or recreating it is not a harmless diagnostic step.

Operational consequence: Restart/recreate/change operations require an explicit plan and approval.

#### H004 — Private-first and VPN-first are stable operational lessons

Problem: Convenience can push homelab services toward public exposure.

Resolution: The homelab architecture consolidated around private-first access, LAN/VPN usage, Tailscale, MagicDNS, Nginx Proxy Manager, and no public exposure by default.

Lesson: Remote access should prefer private VPN-based access unless a deliberate architecture decision changes that.

Operational consequence: Agents must not propose public exposure, port forwarding, public tunnels, or public reverse proxy changes as routine convenience steps.

#### H005 — Firewall, Docker networking, NPM, and IPv6 must be analyzed together

Problem: Hardening Docker or service exposure can be incomplete if UFW, DOCKER-USER, IPv6, Nginx Proxy Manager, host listeners, and Docker networks are analyzed separately.

Resolution: Network hardening became an incremental diagnostic process rather than a single firewall command.

Lesson: Network security is cross-layer.

Operational consequence: Graph and inventory work should capture relationships among containers, host ports, proxy hosts, firewall rules, Docker networks, and VPN/LAN access.

### Toolbox operations and evidence

#### H006 — Reports, TSVs, logs, and snapshots became operational memory

Problem: Long terminal outputs and chat snippets were hard to reuse, audit, compare, or validate later.

Resolution: Toolbox workflows increasingly generate durable reports, TSVs, snapshots, logs, manifests, and inventories under `/srv/toolbox/shared`.

Lesson: Durable evidence is operational infrastructure, not bureaucracy.

Operational consequence: Agents should prefer scripts and artifacts over asking the user to paste large raw outputs.

#### H007 — Reusable command sequences should become scripts

Problem: Long ad hoc shell sequences are fragile, hard to audit, and easy to execute partially.

Resolution: Repeated diagnostic or validation patterns were converted into scripts under `scripts/admin/`, `scripts/media/`, `scripts/lib/`, or related Toolbox areas.

Lesson: The chat can design a process, but mature operations should be captured in versioned scripts.

Operational consequence: Agents should inspect existing scripts first and propose new scripts when a pattern is reusable.

#### H008 — Existing scripts are operational knowledge

Problem: Documentation initially underrepresented the fact that many validated scripts, helpers, libraries, pipelines, and workflows already existed.

Resolution: A script inventory diagnostic was created and the knowledge layer was updated so agents must inspect existing Toolbox assets before proposing new ones.

Lesson: The repository contains executable operational knowledge, not only source code.

Operational consequence: Agents should not replace existing validated workflows with manual commands unless they explain why the existing assets are insufficient.

#### H009 — `run-job` and pipelines are central but not universal

Problem: There was potential confusion between encapsulated pipelines and operational workflows that affect live state.

Resolution: `run-job` remains valid for encapsulated processing with job directories, logs, status, and outputs. Host-side workflows remain appropriate when there is live state, human decision, snapshots, repair/resume, or staged apply/validate phases.

Lesson: `run-job` is a central mechanism, not a universal execution model.

Operational consequence: Agents must choose deliberately between wrapper, workflow, run-job, and pipeline.

#### H010 — Git helper workflow reduced operational mistakes

Problem: Git operations risked incomplete commits, missing validation, incorrect staging, or omitted push.

Resolution: Git helper scripts were created for stage/check/commit and post-commit/push routines.

Lesson: Git is part of the operational audit trail.

Operational consequence: Agents must use the established Git helper syntax when asked to commit Toolbox changes.

#### H011 — Shell ergonomics is operational infrastructure

Problem: Repeated report/TSV/log navigation and chmod/syntax-check routines created friction and error risk.

Resolution: Shell helpers and aliases were introduced or preserved, including `latest-file`, `tsvless`, `rptless`, `nflog`, `tblive`, `mkxcheck`, and modular shell config.

Lesson: Shell ergonomics protects operational quality and continuity.

Operational consequence: Agents must not casually replace or break established shell muscle memory.

### Python, Beets, and MusicBrainz

#### H012 — Minimal Python tooling avoided unnecessary scope expansion

Problem: Beets/MusicBrainz work required Python tooling, but opening a full pyenv/Poetry modernization front would have distracted from music staging.

Resolution: Beets was installed through `pipx`, `fpcalc` through `libchromaprint-tools`, and `pyacoustid` through `pipx inject`; pyenv/Poetry were deferred.

Lesson: Install the minimum safe tooling needed for the active workflow; defer broader hygiene work when it does not block the task.

Operational consequence: Agents should distinguish blockers from future technical debt.

#### H013 — Beets must start in sandbox/dry-run mode

Problem: Beets can move, copy, or write metadata if misconfigured.

Resolution: A Beets sandbox was created with explicit `BEETSDIR` and safe settings such as no write, no move, no copy, and timid behavior.

Lesson: Powerful media tools must be proven in sandbox and dry-run mode before touching live staging or library files.

Operational consequence: Agents must verify Beets config before any Beets action.

#### H014 — Thembi showed that matching failures can be configuration failures

Problem: The initial Beets dry-run for Thembi did not produce usable candidates.

Resolution: Diagnosis revealed that `chroma` was enabled without `musicbrainz`; enabling `chroma musicbrainz` allowed MBID dry-run matching.

Lesson: Matching failures should not be attributed immediately to MusicBrainz data quality or album ambiguity.

Operational consequence: Agents should check Beets plugins, dependencies, config, logs, and MBID candidates before drawing conclusions.

#### H015 — MusicBrainz candidate diagnosis was necessary

Problem: Beets automatic/manual matching did not initially surface the expected release, but MusicBrainz candidates existed.

Resolution: A MusicBrainz release candidate diagnosis script scored candidates by track count, title match, date, and duration.

Lesson: Automated matching is evidence, not truth. Independent candidate diagnosis can reveal better explanations.

Operational consequence: Agents should treat MBID selection as a controlled evidence-based step.

#### H016 — Thembi and Spectrum are pilots, not complete proof

Problem: There was risk of overfitting workflows to one or two albums.

Resolution: Workflows were generalized gradually, and broader readiness/plugin questions were left open.

Lesson: Music-staging pipelines need diverse test cases before being considered general.

Operational consequence: Agents should not generalize from a single successful pilot.

### Stockhausen and advanced media curation

#### H017 — Stockhausen required a gold model

Problem: The Stockhausen-Verlag corpus had inconsistent metadata, complex structure, and high risk of damaging a curated collection.

Resolution: `012 Stimmung` was used as the gold model for metadata normalization, naming, grouping, and validation.

Lesson: Complex collections require an explicit model before bulk normalization.

Operational consequence: Agents must not retag complex collections without a model, plan, snapshots, and validation.

#### H018 — `metaflac` replaced `exiftool` for FLAC tag writing

Problem: `exiftool` was not reliable enough for the FLAC Vorbis-comment writing workflow.

Resolution: Tag writing shifted to `metaflac`.

Lesson: Tool choice must be validated against the actual file format and workflow, not assumed from general capability.

Operational consequence: FLAC metadata workflows should prefer the validated `metaflac` approach unless a new controlled test changes that.

#### H019 — Resume-safe apply logic mattered

Problem: Long Stockhausen operations could fail partially due to existing destinations, filename-length issues, interrupted jobs, or data irregularities.

Resolution: Scripts evolved toward idempotent/resume-safe behavior, destination checks, prefix fallback, snapshots, and repair/validate phases.

Lesson: Large media operations must expect partial progress and support safe continuation.

Operational consequence: Agents should design high-risk apply scripts with resume and validation logic.

#### H020 — Artwork hot/cold archive separated usability from preservation

Problem: Full artwork scans consumed too much hot-library storage.

Resolution: The hot layer kept only `cover.jpg`; full artwork moved to a compressed cold archive using WebP/7z with validation.

Lesson: Preservation can be rational and layered instead of maximalist in the hot path.

Operational consequence: Agents must not treat cold archives as trash or temporary files.

#### H021 — Freitag 050 validated controlled delta import

Problem: Album 050 was absent from the canonical library but present in staging with mixed single FLACs and CUE-based discs.

Resolution: The album was diagnosed, split, planned, imported, tagged, and validated as a controlled delta import.

Lesson: Importing a missing album into a curated corpus is a mini-project, not a copy operation.

Operational consequence: Agents should use structured import workflows for complex albums.

#### H022 — Stockhausen lessons should guide future TUI/dashboard/search design

Problem: Earlier UI/dashboard ideas risked being abstract rather than grounded in real operational pain.

Resolution: Future interface ideas were deferred until lessons from the Stockhausen saga could be extracted.

Lesson: Operational UI should be derived from actual workflows, reports, TSVs, validation needs, and failure modes.

Operational consequence: Agents should not design dashboard/TUI abstractions without grounding them in real Toolbox workflows.

### Music staging, Navidrome, and playback

#### H023 — Music staging directories have semantic meaning

Problem: Staging folders could be mistaken for ordinary temporary directories.

Resolution: States such as `incoming`, `downloading`, `reviewing`, `tagging`, `ready`, and `imported` were formalized.

Lesson: Staging is a curatorial state machine, not a disposable folder tree.

Operational consequence: Agents must not move, clean, or infer state transitions casually.

#### H024 — `ready` requires explicit criteria

Problem: Albums can appear ready while still needing integrity checks, artwork, replaygain, genre review, duplicate/missing checks, or metadata review.

Resolution: Tagging audits and plugin-readiness diagnostics were created, while final ready criteria remained open.

Lesson: Readiness must be explicit and validated.

Operational consequence: Agents should not mark music as ready based on visual inspection or partial metadata success.

#### H025 — Navidrome reflects metadata quality but should not be the correction layer

Problem: Navidrome exposed metadata fragmentation, album-count mismatches, and playback symptoms.

Resolution: Issues were traced back through tags, paths, staging/import workflows, and service configuration.

Lesson: Player symptoms should be diagnosed upstream.

Operational consequence: Agents should not “fix Navidrome” by editing library files outside media-curation workflows.

#### H026 — Feishin, Amperfy, and browser playback differ

Problem: Some high-resolution FLACs failed in browser/Feishin but worked in Amperfy.

Resolution: Navidrome ffmpeg/transcoding was validated and Feishin backend/player/transcoding settings were adjusted.

Lesson: Playback failure can be client/backend-specific.

Operational consequence: Agents should not convert, duplicate, or replace masters before diagnosing server transcoding and client behavior.

### Backup, storage, and recovery

#### H027 — Backup does not authorize deletion

Problem: It is tempting to treat “has backup” as permission to delete staging, media, or generated artifacts.

Resolution: Backup scope, restore confidence, and data category must be understood before deletion.

Lesson: Backup is only useful when scope and restore are known.

Operational consequence: Agents must not cite backup existence as deletion approval.

#### H028 — Storage pressure requires rational preservation

Problem: Large collections, artwork, downloads, staging, and old artifacts created storage pressure.

Resolution: Compression, cold archives, diagnostics, and selective cleanup were used instead of broad deletion.

Lesson: Operational sustainability requires balancing preservation and active storage.

Operational consequence: Agents should propose storage reduction through diagnostics and plans, not manual deletion.

#### H029 — ATA/storage incidents require follow-up diagnostics

Problem: A storage/ATA warning appeared during work.

Resolution: A storage pressure and ATA health diagnostic script was created.

Lesson: Storage warnings should be captured into repeatable diagnostics.

Operational consequence: Agents should not ignore low-level storage errors even if the system appears stable after reboot.

### Codex, graph, and knowledge architecture

#### H030 — The graph is generated knowledge, not hand-written service documentation

Problem: The `knowledge/graph/` layer was briefly described too vaguely, as if it were future relationship documentation.

Resolution: The model was corrected: graph artifacts should be generated through diagnostics/modeling and should describe entities and relations.

Lesson: Inventory = what exists. Graph = how it connects. ADR = why it exists.

Operational consequence: Agents must not invent graph relationships from memory.

#### H031 — Service maps are human operational maps, not the dependency graph

Problem: Service maps risked becoming manual graph substitutes or containers for all open questions.

Resolution: Service maps were aligned with graph and architecture boundaries.

Lesson: Services orient humans and agents; graph models relationships; architecture records lessons, questions, and decisions.

Operational consequence: Agents should keep service maps concise and avoid treating them as authoritative dependency graphs.

#### H032 — Codex must ask when intent is missing

Problem: Local agents can observe current state but cannot infer why decisions were made.

Resolution: The knowledge model separates context, policies, services, graph, inventories, architecture, and future ADRs.

Lesson: Observed state does not contain architectural intent.

Operational consequence: Codex should produce questions and ADR candidates instead of inventing rationale.

## What belongs elsewhere

Policies belong in `knowledge/policies/`.

Service maps belong in `knowledge/services/`.

Observed state belongs in `/srv/toolbox/shared/inventory/`.

Graph entities and relations belong in `knowledge/graph/`.

Stable decisions and ADRs belong in `knowledge/architecture/`.

Generated evidence belongs in `/srv/toolbox/shared/`.

## Related documents

* `knowledge/context/agent-entrypoint.md`
* `knowledge/context/homelab-context.md`
* `knowledge/context/toolbox-context.md`
* `knowledge/services/README.md`
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
