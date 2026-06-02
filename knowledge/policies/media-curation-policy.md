# Media Curation Policy

This policy defines safety and workflow rules for media curation in the Toolbox and homelab.

It applies to human-assisted work, ChatGPT-assisted work, Codex/local-agent work, scripts, diagnostics, validation routines, music-staging workflows, metadata workflows, artwork workflows, import workflows, cold-archive workflows, and any operation that may affect media collections.

This policy must be read together with:

* `knowledge/context/agent-entrypoint.md`
* `knowledge/context/homelab-context.md`
* `knowledge/context/toolbox-context.md`
* `knowledge/policies/agent-safety-policy.md`
* `knowledge/policies/change-management-policy.md`
* `knowledge/policies/reporting-policy.md`
* `knowledge/policies/filesystem-safety-policy.md`

## Primary principle

Media curation must preserve user data, archival masters, library integrity, and operational traceability.

Agents must not treat media collections as disposable working directories.

The default mode for media work is read-only diagnosis.

Metadata writes, imports, deletes, moves, renames, transcodes, artwork changes, and cold-archive cleanup require explicit plan, approval, and validation.

## Existing Toolbox workflows

The Toolbox already contains media scripts, Stockhausen scripts, music-staging scripts, Beets-related workflows, reports, TSVs, snapshots, and validation routines created through prior work.

Before proposing ad hoc commands or new scripts, agents must inspect whether an existing Toolbox script, helper, runbook, report, TSV, inventory, plan/apply/validate workflow, or `run-job` pipeline already covers the task.

Existing scripts may be used when appropriate, but they must still be reviewed before execution, especially when they affect media files, metadata, artwork, staging states, cold archives, or the main music library.

Agents should prefer existing validated media workflows over manual filesystem or metadata commands.

If no suitable existing workflow exists, the agent may propose a new script or workflow, but must explain why existing assets are insufficient.

## Related Toolbox and media policies

This policy does not replace existing Toolbox policies, conventions, or media documentation.

Agents and operators must consult applicable documents before planning or applying media changes.

Authoritative related documents include:

* `knowledge/policies/filesystem-safety-policy.md`
* `docs/operations/toolbox_storage_policy.md`
* `docs/operations/toolbox_reports_policy.md`
* `docs/operations/toolbox_logging_policy.md`
* `docs/operations/toolbox_output_destinations_policy.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_scripts_lib_policy.md`
* `docs/media/stockhausen_metadata_policy.md`
* `docs/media/stockhausen_gold_model_stimmung.md`

If a conflict exists between this policy and a media-specific policy, the operator or agent must stop and ask for human review instead of choosing one silently.

If a document appears stale, incomplete, or inconsistent with observed host state, the inconsistency must be reported and reviewed.

## Sensitive media paths

The following paths are sensitive:

* `/srv/media/music/`
* `/srv/media/music-staging/`
* `/srv/media/photos/`
* `/srv/media/photos-raw/`
* `/srv/media/videos/`
* `/srv/media/calibre-library/`
* `/srv/media/pdfs`
* `/srv/media/pdfs-raw/`
* `/srv/toolbox/shared/artwork-cold-archive/`
* `/srv/toolbox/shared/cold-archive/`
* any imported music library path;
* any staging path;
* any cold archive path;
* any Samba-exported media path;
* any media path used by Navidrome, Jellyfin, Immich, Calibre-Web, Kavita, or FileBrowser.

Sensitivity does not prohibit read-only inspection.

Sensitivity means modification requires a plan, approval, and validation.

## Main library versus staging

The main media library and staging areas have different meanings.

The main library is for curated, imported, usable collections.

Staging areas are for review, tagging, validation, conversion, import preparation, and temporary operational work.

Agents must not bypass staging workflows.

Agents must not move material directly into the main library without an approved import workflow.

Agents must not clean staging merely because files appear duplicated, old, incomplete, or already present elsewhere.

Staging state must be interpreted from current host state and current workflow documentation, not guessed from directory names alone.

## Music staging state model

The music-staging workflow may include states such as:

* incoming;
* downloading;
* reviewing;
* tagging;
* ready;
* imported;
* rejected or deferred states when explicitly configured.

Known semantics:

* `reviewing` means material is being evaluated.
* `tagging` means material is under curation.
* `ready` means material has passed the required checks for import.
* `imported` means material has been moved or integrated into the main library through an approved workflow.

Agents must not change staging state without an approved plan.

A state transition should preserve evidence through reports, TSVs, logs, or snapshots when practical.

## Archival master policy

The music library favors preservation of archival masters.

Known principles:

* preserve FLAC masters where possible;
* avoid uncontrolled duplicate compatibility libraries;
* prefer on-demand transcoding for playback compatibility when appropriate;
* avoid destructive conversion of archival masters;
* keep derived/export formats separate from master libraries;
* document exceptions.

Agents must not replace archival masters with transcoded derivatives.

Agents must not delete archival masters because a derivative, streamable, or compressed copy exists.

## Metadata policy

Metadata writes are sensitive data operations.

Metadata changes include:

* FLAC Vorbis comments;
* ID3 tags;
* embedded artwork;
* MusicBrainz identifiers;
* album artist;
* artist;
* composer;
* performer;
* title;
* album;
* date;
* grouping;
* genre;
* disc and track numbers;
* replaygain;
* lyrics;
* sidecar metadata.

Metadata writes require:

* diagnosis;
* plan;
* target list;
* before-state evidence;
* approved apply step;
* validation;
* rollback or recovery explanation when practical.

Agents must not silently rewrite metadata.

Agents must not run metadata tools in write mode without explicit approval.

## MusicBrainz and Beets policy

MusicBrainz and Beets workflows must remain controlled.

Known principles:

* identification and matching should be diagnosed before writing;
* `chroma` and `musicbrainz` may be used for matching when configured and validated;
* MBID-based workflows should use dry-run and validation before writes;
* plugin behavior should be explicit;
* sandbox or dry-run modes are preferred before apply;
* metadata apply must be separated from import/move operations when risk justifies it.

Agents must not assume Beets configuration is correct without verifying it from the host.

Agents must not import or write tags through Beets without an approved plan.

Plugin use must follow the current approved curation strategy.

## Artwork policy

Artwork is part of media curation and may be large, duplicated, embedded, external, or archival.

Artwork operations include:

* fetching artwork;
* embedding artwork;
* extracting artwork;
* converting artwork;
* compressing artwork;
* moving artwork;
* deleting artwork;
* building artwork archives;
* preserving booklets, scans, covers, and auxiliary images.

Artwork changes require care because they may affect library size, player behavior, metadata, and archival completeness.

Agents must not purge artwork merely because a cover image exists.

Artwork cleanup must be planned, validated, and traceable.

## Cold archive policy

Cold archives preserve heavy, auxiliary, intermediate, or non-hot-library material outside the active library.

Cold archive workflows require:

* plan;
* source inventory;
* output destination;
* manifest when applicable;
* report;
* validation;
* cleanup decision;
* human approval before purge.

Agents must not purge hot-library material merely because a cold archive path exists.

Agents must not treat cold archives as trash or temporary output.

Cold archives should preserve enough information to support later audit, reconstruction, or review.

## Stockhausen policy

The Stockhausen workflow is a major validated media-curation case and must not be treated as an ordinary ad hoc tagging task.

Known principles include:

* preserve the validated metadata model;
* use `Karlheinz Stockhausen` consistently according to the approved policy;
* distinguish composer, artist, album artist, performer, grouping, and track title semantics;
* preserve MusicBrainz identifiers when available;
* use `metaflac` for reliable FLAC Vorbis tag writing when appropriate;
* validate before purge or cleanup;
* respect cold-archive decisions;
* do not infer missing albums or metadata from memory alone.

Agents must consult:

* `docs/media/stockhausen_metadata_policy.md`
* `docs/media/stockhausen_gold_model_stimmung.md`

before proposing Stockhausen metadata, artwork, import, cleanup, or normalization work.

## Photos, videos, ebooks, and PDFs

This policy is music-heavy because music curation has been the most developed media workflow.

However, other media collections are also sensitive.

Agents must treat photos, raw photos, videos, ebooks, and PDFs as user data.

Agents must not delete, rename, move, transform, compress, OCR, extract, or reorganize non-music media without an approved plan.

Service-specific behavior for Immich, Jellyfin, Calibre-Web, Kavita, FileBrowser, or Samba must be verified before changes.

## Player and service behavior

Media files may be consumed by services such as:

* Navidrome;
* Jellyfin;
* Immich;
* Calibre-Web;
* Kavita;
* FileBrowser;
* Samba clients;
* Feishin;
* Amperfy.

Agents must not assume that a filesystem change is isolated from service behavior.

Before changing media organization, metadata, permissions, or filenames, agents should consider whether the change affects library scans, player grouping, client compatibility, thumbnails, cached metadata, or user workflows.

## Transcoding policy

Transcoding can be useful for playback compatibility, exports, or derived outputs.

Transcoding must not overwrite archival masters.

Known principles:

* prefer on-demand transcoding for playback compatibility when appropriate;
* derived exports should be separated from master libraries;
* compatibility copies should not be introduced without a deliberate plan;
* destructive in-place conversion is not allowed without explicit approval.

Agents must distinguish between:

* archival master;
* playback stream;
* export derivative;
* temporary processing file.

## Import policy

Importing material into the main library is a high-sensitivity operation.

Import requires:

* current staging state;
* source path;
* destination path;
* metadata state;
* artwork state;
* duplicate/collision check;
* target list;
* validation method;
* rollback or recovery explanation;
* human approval.

Agents must not move material into the main library because it appears complete.

Readiness must be validated according to the current workflow.

## Duplicate and missing checks

Duplicate and missing checks are diagnostic tools.

They must not automatically trigger deletion, merge, or import.

Agents may use duplicate/missing diagnostics to inform plans, but destructive or structural action requires separate approval.

False positives are possible and must be treated carefully.

## Integrity checks

Integrity checks may include:

* FLAC validation;
* ffprobe checks;
* checksums;
* metadata reads;
* file counts;
* duration checks;
* MusicBrainz matching;
* artwork existence checks;
* cue/log validation;
* sample playback;
* service scan validation.

Integrity checks should generate reports and TSVs when practical.

A successful integrity check does not automatically authorize import, deletion, or metadata writes.

## Reporting and evidence

Media curation should produce durable evidence.

Evidence may include:

* reports;
* TSVs;
* logs;
* snapshots;
* manifests;
* inventories;
* before/after metadata dumps;
* ChatGPT briefs.

Generated artifacts must follow:

* `knowledge/policies/reporting-policy.md`
* `docs/operations/toolbox_output_destinations_policy.md`

The source tree should contain the method.

The shared tree should contain the evidence.

## Long-running media work

Long-running media work requires an execution and logging strategy.

Examples:

* artwork archive build;
* compression;
* metadata scan;
* audio split;
* Beets batch operation;
* MusicBrainz lookup batch;
* checksum scan;
* OCR batch;
* import validation;
* cold archive validation.

Before launching long-running media work, the plan must specify:

* command;
* expected duration or uncertainty;
* log path;
* output path;
* progress monitoring method;
* validation method;
* interruption behavior;
* whether `nohup`, `nf`, `nflog`, `tblive`, external redirection, `run-job`, or a pipeline should be used.

## Error handling

If a media operation fails, the operator or agent must stop and report:

* command attempted;
* affected path;
* affected files;
* metadata or filesystem state changed;
* partial outputs;
* logs generated;
* reports generated;
* whether retry is safe;
* whether rollback is needed;
* safest next diagnostic step.

Do not continue blindly after partial metadata writes, partial imports, failed moves, failed splits, failed archive builds, or failed cleanup.

## Anti-drift rule

Agents must not introduce new media organization schemes, staging states, archive layouts, metadata policies, naming schemes, or output locations merely because they are common in generic media managers.

Every proposed addition must explain:

* function;
* destination;
* relationship with existing Toolbox and media workflows;
* risk of redundancy;
* validation method;
* rollback or cleanup path.

Media curation must adapt to the homelab and Toolbox, not replace them.
