Music Staging

Purpose

Music staging is the operational subsystem for reviewing, curating, validating, tagging, preparing, and importing music before it becomes part of the main music library.

It protects the main library from incomplete downloads, unreviewed metadata, broken files, duplicate albums, inconsistent artwork, incorrect MusicBrainz matches, and premature imports.

Music staging is not a disposable download folder. It is a controlled curatorial workflow that connects Soulseek/slskd, FileBrowser, Samba, Beets, MusicBrainz, Navidrome, Toolbox scripts, reports, TSVs, validation routines, and human approval.

Service type

operational_subsystem

Music staging is an operational subsystem because it combines:

* staged filesystem areas;
* download intake;
* review and tagging states;
* metadata workflows;
* Beets/MusicBrainz diagnostics;
* integrity checks;
* artwork decisions;
* import preparation;
* reports and TSVs;
* human decisions;
* Toolbox scripts and validation routines.

It is not a technical service by itself, although it depends on technical services such as slskd, Samba, FileBrowser, Docker, Navidrome, and sometimes Beets-related tooling installed on the host.

Current role in the homelab

Music staging currently acts as the safe buffer between downloaded music and the curated main music library.

Its role includes:

* receiving completed downloads from slskd/Soulseek;
* separating incomplete downloads from completed incoming material;
* supporting manual review through terminal, FileBrowser, Samba, and desktop tools;
* supporting Beets/MusicBrainz dry-run and matching workflows;
* supporting controlled metadata writes for FLAC material;
* supporting tagging, integrity, artwork, replaygain, genre, missing/duplicate, and import-readiness decisions;
* preventing unreviewed material from entering /srv/media/music;
* preserving audit trails through reports, TSVs, snapshots, and validation outputs;
* helping Navidrome receive cleaner, more stable albums.

Music staging must be understood together with media curation policy, filesystem safety policy, FileBrowser, Samba, slskd, Navidrome, Beets/MusicBrainz, and Toolbox script conventions.

Important paths

Main music library:

* /srv/media/music

Music staging root:

* /srv/media/music-staging

Known or expected staging states may include:

* /srv/media/music-staging/incoming
* /srv/media/music-staging/downloading
* /srv/media/music-staging/reviewing
* /srv/media/music-staging/tagging
* /srv/media/music-staging/ready
* /srv/media/music-staging/imported
* /srv/media/music-staging/rejected
* /srv/media/music-staging/deferred
* /srv/media/music-staging/archive

Actual directories must be verified from the host before making decisions.

Beets sandbox and related paths may include:

* /srv/toolbox/shared/beets/media-staging
* Beets config, database, and sandbox library paths under that directory.

Toolbox source and knowledge paths:

* /srv/toolbox/app
* /srv/toolbox/app/knowledge
* /srv/toolbox/app/docs
* /srv/toolbox/app/scripts/media/library
* /srv/toolbox/app/scripts/media/soulseek
* /srv/toolbox/app/scripts/media/stockhausen
* /srv/toolbox/app/scripts/admin/storage
* /srv/toolbox/app/scripts/admin/system

Generated music-staging evidence should be stored under:

* /srv/toolbox/shared/reports/media
* /srv/toolbox/shared/reports/media/staging
* /srv/toolbox/shared/reports/media/stockhausen
* /srv/toolbox/shared/reports/system
* /srv/toolbox/shared/library-db/raw/media
* /srv/toolbox/shared/library-db/raw/media/staging
* /srv/toolbox/shared/library-db/raw/media/stockhausen
* /srv/toolbox/shared/library-db/raw/system
* /srv/toolbox/shared/library-db/snapshots/media
* /srv/toolbox/shared/library-db/snapshots/media/staging
* /srv/toolbox/shared/logs/media
* /srv/toolbox/shared/logs/media/staging

Current staging state, directory names, Beets config, reports, and import targets must be verified from the host before making changes.

Related services

Music staging is related to:

* Toolbox;
* FileBrowser;
* Samba;
* Docker;
* backup;
* Navidrome;
* slskd/Soulseek;
* networking;
* Nginx Proxy Manager;
* media curation workflows;
* Stockhausen workflows;
* Beets;
* MusicBrainz;
* future Codex/local-agent workflows.

Music staging is especially related to FileBrowser and Samba because both are used for human access, review, and transfer of files.

Music staging is related to Navidrome because only curated, imported music should become part of the main library scanned by Navidrome.

Music staging is related to backup because the primary backup strategy does not automatically mean large downloaded media or staging content is protected.

Related scripts and workflows

Music-staging scripts and workflows may be found under:

* scripts/media/library
* scripts/media/soulseek
* scripts/media/stockhausen
* scripts/admin/storage
* scripts/admin/system
* scripts/admin/backup

The Toolbox script inventory should be consulted before proposing new music-staging, Beets, MusicBrainz, metadata, artwork, integrity, import, or filesystem command sequences.

Agents must not assume that music-staging knowledge is isolated in one script directory. Music-staging behavior is distributed across media scripts, Stockhausen scripts, Soulseek/slskd setup, storage diagnostics, FileBrowser/Samba access, reports, TSVs, snapshots, and media policies.

Relevant workflow families include:

* music-staging diagnostics;
* music-staging transition workflows;
* Beets sandbox workflow;
* Beets dry-run workflow;
* Beets MBID dry-run workflow;
* Beets plugin readiness diagnostics;
* tagging-audit diagnostics;
* controlled FLAC metadata write workflow;
* MusicBrainz candidate diagnostics;
* album tag diagnostics;
* media inventory generation;
* music library SQLite initialization;
* Stockhausen-specific import and normalization workflows;
* artwork and cold-archive workflows;
* storage pressure diagnostics;
* knowledge/service documentation validation.

Music staging work should follow the standard workflow:

* diagnose;
* plan;
* apply;
* validate.

Staging state model

Music staging may use a state model such as:

* downloading;
* incoming;
* reviewing;
* tagging;
* ready;
* imported;
* rejected;
* deferred;
* archive.

Known semantics:

* downloading means incomplete or active downloads.
* incoming means completed downloads that have not yet been reviewed.
* reviewing means material is being evaluated.
* tagging means material is under metadata curation.
* ready means material has passed required checks and is candidate for import.
* imported means material has been integrated into the main library through an approved import workflow.
* rejected, deferred, or archive states must be interpreted from current workflow documentation and host state.

Agents must not change staging state by moving directories merely because a name appears to fit.

State transitions require an approved plan when they move, rename, delete, retag, import, or otherwise modify files.

Metadata policy

Music staging must preserve archival safety and avoid premature metadata writes.

Metadata work may include:

* reading existing tags;
* comparing file names and tags;
* checking MusicBrainz candidates;
* checking AcoustID/fingerprints where available;
* generating proposed tag plans;
* writing FLAC metadata only through approved workflows;
* validating metadata after writes;
* preserving or deferring MusicBrainz IDs according to the active workflow.

Agents must not write tags, remove tags, rewrite filenames, embed artwork, apply ReplayGain, or import into the main library without an approved plan.

For Stockhausen material, Stockhausen-specific policies and workflows take precedence when applicable.

Beets and MusicBrainz policy

Beets and MusicBrainz workflows must remain controlled.

Known principles include:

* use sandboxed Beets configuration for staging workflows;
* prefer dry-run and diagnostic modes before writes;
* confirm Beets configuration from the host before relying on it;
* verify active plugins when plugin behavior matters;
* treat MusicBrainz matching as evidence, not automatic truth;
* avoid overfitting a workflow to one successful album;
* validate results before changing staging state or importing.

Agents must not run Beets import, write tags, move files, or apply plugin effects without explicit approval.

Read-only or dry-run Beets inspection may still require confirmation of exact command, BEETSDIR, config path, target path, and expected non-mutating behavior.

Integrity, completeness, and duplicates

Music staging should distinguish between:

* technical integrity;
* metadata quality;
* album completeness;
* duplicate detection;
* artwork readiness;
* import readiness;
* player/library readiness.

A successful technical integrity check does not automatically authorize import.

A successful MusicBrainz match does not automatically authorize metadata writes.

A clean tag audit does not automatically authorize deletion of staging files.

Agents should use existing diagnostics and reports when available before proposing new checks.

Artwork policy

Artwork work in music staging may include:

* detecting existing covers;
* checking embedded artwork;
* checking external cover files;
* fetching artwork candidates;
* preparing artwork for import;
* embedding artwork when approved;
* preserving cold archive strategy when relevant.

Agents must not fetch, replace, embed, delete, or compress artwork without an approved plan.

Artwork for Stockhausen or other special collections may have collection-specific rules.

Import policy

Import from staging to the main music library is sensitive.

Import work may include:

* checking source state;
* checking target path;
* checking existing library duplicates;
* checking metadata;
* checking technical integrity;
* checking artwork;
* checking naming;
* generating a plan;
* using snapshots where appropriate;
* applying a controlled move/copy/import;
* validating the final library state;
* confirming Navidrome or player behavior after import when relevant.

Agents must not move material directly into /srv/media/music without an approved import workflow.

Agents must not delete staging material merely because an import appears successful unless deletion or archival behavior is explicitly planned and validated.

Transcoding policy

The homelab preference is to preserve archival masters and use on-demand transcoding for playback compatibility when appropriate.

Music staging should not create duplicate derivative libraries unless explicitly planned.

Conversion or export workflows should be treated as separate derivative/export workflows, not as the default path for canonical library import.

Agents must not transcode, replace masters, or delete originals without explicit approval.

Related reports, TSVs, inventories, and logs

Music-staging evidence should be stored under /srv/toolbox/shared.

Likely destinations include:

* /srv/toolbox/shared/reports/media
* /srv/toolbox/shared/reports/media/staging
* /srv/toolbox/shared/reports/media/stockhausen
* /srv/toolbox/shared/reports/system
* /srv/toolbox/shared/library-db/raw/media
* /srv/toolbox/shared/library-db/raw/media/staging
* /srv/toolbox/shared/library-db/raw/media/stockhausen
* /srv/toolbox/shared/library-db/raw/system
* /srv/toolbox/shared/library-db/snapshots/media
* /srv/toolbox/shared/library-db/snapshots/media/staging
* /srv/toolbox/shared/logs/media
* /srv/toolbox/shared/logs/media/staging

Useful evidence may include:

* staging inventory;
* album tag diagnostics;
* file duration reports;
* fingerprint reports;
* MusicBrainz candidate reports;
* Beets dry-run logs;
* plugin readiness reports;
* tagging audit reports;
* metadata write plans;
* metadata write validation reports;
* transition plans;
* import plans;
* import validation reports;
* integrity reports;
* artwork reports;
* duplicate and missing reports;
* Navidrome/player validation notes.

For destination rules, consult:

* docs/operations/toolbox_output_destinations_policy.md
* knowledge/policies/reporting-policy.md

Related policies and docs

Required context:

* knowledge/context/agent-entrypoint.md
* knowledge/context/homelab-context.md
* knowledge/context/toolbox-context.md

Required policies:

* knowledge/policies/agent-safety-policy.md
* knowledge/policies/change-management-policy.md
* knowledge/policies/reporting-policy.md
* knowledge/policies/filesystem-safety-policy.md
* knowledge/policies/media-curation-policy.md

Relevant service maps:

* knowledge/services/README.md
* knowledge/services/toolbox.md
* knowledge/services/docker.md
* knowledge/services/networking.md
* knowledge/services/samba.md
* knowledge/services/filebrowser.md
* knowledge/services/backup.md

Important operational documentation:

* docs/operations/toolbox_architecture_reconciliation.md
* docs/operations/toolbox_output_destinations_policy.md
* docs/operations/toolbox_reports_policy.md
* docs/operations/toolbox_logging_policy.md
* docs/operations/toolbox_script_conventions.md
* docs/operations/toolbox_storage_policy.md
* docs/operations/toolbox_runtime_profiles.md
* docs/media/stockhausen_metadata_policy.md
* docs/media/stockhausen_gold_model_stimmung.md

Future or related service documents may include:

* knowledge/services/navidrome.md
* knowledge/services/slskd.md

Sensitive operations

Sensitive music-staging operations include:

* moving files between staging states;
* deleting files from staging;
* deleting incomplete or rejected downloads;
* changing directory structure;
* writing metadata;
* removing metadata;
* renaming audio files;
* splitting or joining audio files;
* changing artwork;
* embedding artwork;
* applying ReplayGain;
* applying genres;
* running Beets imports;
* running MusicBrainz-driven writes;
* importing into /srv/media/music;
* deleting post-import staging material;
* changing slskd download paths;
* changing FileBrowser or Samba access to staging;
* changing backup assumptions for staging.

These operations require an explicit plan and approval.

Extra-sensitive operations include:

* recursive delete;
* bulk retagging;
* bulk renaming;
* moving material into the main music library;
* deleting after import;
* applying Beets writes;
* changing metadata on special curated collections;
* changing Stockhausen material outside Stockhausen-specific workflow;
* treating staging files as disposable because they came from downloads.

Read-only inspection allowed

Read-only music-staging inspection is allowed when bounded and relevant.

Allowed read-only inspection may include:

* listing staging directories;
* reading file names;
* reading tags;
* reading durations;
* reading codec and format metadata;
* reading existing reports and TSVs;
* reading Beets config when relevant;
* reading MusicBrainz candidate reports;
* inspecting FileBrowser/Samba-visible paths;
* reading bounded logs;
* checking Git status before editing tracked docs or scripts;
* reading relevant scripts and policies.

Read-only commands may include, when appropriate:

* find with bounded depth;
* ls;
* stat;
* ffprobe;
* metaflac --list;
* fpcalc when explicitly useful and acceptable;
* beet config with explicit BEETSDIR;
* beet version;
* bounded log reads.

Read-only inspection must not be confused with approval to move, delete, retag, rename, import, transcode, fetch artwork, embed artwork, or run mutating Beets operations.

Read-only collection plan

A local agent may collect the following in read-only mode:

* current staging directory tree summary;
* current albums or folders by staging state;
* metadata summaries for selected albums;
* codec and duration summaries;
* existing Beets sandbox configuration;
* Beets version and plugin status;
* MusicBrainz candidate reports if already generated;
* latest Toolbox script inventory report and TSV;
* music-staging-related rows from the script inventory;
* media-library-related rows from the script inventory;
* Stockhausen-related rows from the script inventory when relevant;
* storage-related rows from the script inventory;
* FileBrowser and Samba relationship notes;
* existing media, staging, Stockhausen, system, and storage reports;
* references to music staging, Beets, MusicBrainz, slskd, Soulseek, tagging, ready, imported, metadata, artwork, and Navidrome across knowledge/, docs/, and scripts/.

A local agent must not in read-only mode:

* move files;
* delete files;
* rename files;
* write metadata;
* remove metadata;
* embed artwork;
* fetch artwork;
* apply ReplayGain;
* change genre tags;
* run Beets import or write operations;
* change staging state;
* import into /srv/media/music;
* transcode or replace masters;
* modify FileBrowser or Samba access;
* modify slskd paths;
* commit or push changes.

Non-trivial music-staging inspection should generate a report and TSV.

Actions requiring approval

The following require explicit approval:

* moving material between staging states;
* deleting staging material;
* changing staging directory structure;
* editing music-staging scripts;
* editing Beets configuration;
* running Beets commands beyond approved read-only inspection;
* running MusicBrainz-assisted writes;
* writing FLAC metadata;
* renaming files;
* changing artwork;
* embedding artwork;
* applying ReplayGain;
* applying genre changes;
* running integrity repair;
* importing into /srv/media/music;
* deleting or archiving post-import material;
* changing slskd download paths;
* changing FileBrowser or Samba staging access;
* changing backup assumptions for staging;
* committing or pushing music-staging-related documentation or script changes.

Approval must be specific to the album, path, operation, source state, target state, and expected effect.

A general instruction to continue is not approval for unrelated media or staging changes.

Known historical lessons

Music staging has accumulated important operational lessons through slskd/Soulseek setup, Beets/MusicBrainz dry-runs, Thembi and Spectrum pilots, controlled metadata-write workflows, Stockhausen imports, FileBrowser/Samba access, and Navidrome library behavior.

Service-specific lessons should be summarized here only when they directly affect music-staging operation.

Detailed historical lessons should be consolidated under:

* knowledge/architecture/historical-operational-lessons.md

Until that document exists, agents must treat music-staging lessons mentioned in context, policies, service maps, reports, and validated scripts as operationally relevant.

Open questions

Music staging has open architectural and operational questions that should be resolved incrementally.

This service map should list only open questions that directly affect music staging as a curatorial subsystem.

Broader open questions should be consolidated under a future architecture document, such as:

* knowledge/architecture/open-questions.md

Current known areas for future clarification include final ready criteria, Beets plugin profile design, artwork workflow, ReplayGain workflow, genre policy, duplicate/missing workflow, import workflow, post-import cleanup policy, slskd service map, and future Codex/local-agent read-only inspection boundaries.

Source of truth

Stable source and knowledge:

* /srv/toolbox/app

Main music library:

* /srv/media/music

Music staging root:

* /srv/media/music-staging

Generated operational evidence:

* /srv/toolbox/shared

Current host state must be verified from the host when accuracy matters.

Examples of current music-staging state that must be verified include:

* current staging directories;
* current albums in each staging state;
* current Beets config;
* current Beets plugin state;
* current reports and TSVs;
* current metadata;
* current file integrity;
* current artwork;
* current duplicate/missing status;
* current import targets;
* current Navidrome behavior;
* current FileBrowser/Samba access;
* current backup assumptions.

Agents must not treat memory, old reports, or chat history as proof of current music-staging state.
