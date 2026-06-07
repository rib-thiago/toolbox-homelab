# Codex Parallel Work

This runbook defines how to handle parallel work while a long Codex or Toolbox workfront is still open.

It exists to prevent accidental contamination of inventories, semantic inventories, reports, patches, branches, and Git history.

## 1. Purpose

Long workfronts may remain open across multiple Codex sessions, ChatGPT reviews, operator decisions, and usage-limit resets.

Examples:

* semantic inventory block expansion;
* large documentation consolidation;
* media workflow redesign;
* service-map reconciliation;
* architecture/open-question review;
* graph design;
* ADR preparation.

During those long workfronts, the operator may still want to perform smaller unrelated tasks.

This runbook defines when that is safe and how to isolate it.

## 2. Core rule

Do not start parallel repository-changing work while the main workfront has uncommitted changes, unless the work is explicitly isolated through a documented stash or branch strategy.

Before starting parallel work, always run:

```bash
cd /srv/toolbox/app || exit 1
git status --short
git branch --show-current
```

## 3. Work categories

### Safe parallel work

Usually safe without touching Git:

* ChatGPT discussion;
* planning;
* prompt writing;
* reading reports;
* reviewing TSVs;
* reviewing handoffs;
* drafting documents outside the repo;
* deciding priorities;
* analyzing open questions conceptually.

These do not contaminate the repository.

### Repository-reading parallel work

Usually safe if read-only:

* reading committed docs;
* reading committed scripts;
* listing files;
* checking Git log;
* inspecting generated reports under `/srv/toolbox/shared`.

These should not create repository changes.

### Repository-changing parallel work

Requires isolation:

* editing scripts;
* editing docs;
* editing `knowledge/`;
* adding runbooks;
* adding service maps;
* changing policies;
* changing inventories under versioned paths;
* adding tests;
* changing Git-tracked examples;
* committing.

### Runtime-changing parallel work

Requires separate explicit plan and approval:

* changing services;
* moving media;
* writing metadata;
* changing backup behavior;
* changing firewall;
* changing Docker configuration;
* changing permissions;
* changing Samba, Tailscale, Nginx Proxy Manager, FileBrowser, or media library state.

Runtime-changing work should normally not run in parallel with an unfinished architecture/inventory workfront.

## 4. Preferred strategy: finish or commit the active workfront

If the active workfront is close to closure, prefer:

1. finish calibration;
2. validate;
3. commit;
4. push;
5. final clean rerun;
6. start parallel work from clean `master`.

This is the safest option.

## 5. When to use a stash

Use a stash when:

* the current workfront has uncommitted changes;
* the parallel task is small;
* the parallel task should start from clean `master`;
* the current patch is not ready to commit;
* the operator wants to preserve work-in-progress without mixing changes.

Before stashing, create or update a live-log describing the current workfront.

Minimum live-log content:

* current branch;
* `git status --short`;
* files modified;
* generated artifacts;
* latest handoff path;
* what remains to do;
* whether the patch was tested;
* how to resume.

Then run:

```bash
cd /srv/toolbox/app || exit 1

git status --short
git diff --stat
git stash push -u -m "wip: <short workfront description>"
git status --short
```

Use `-u` only when untracked files are part of the work-in-progress and should be preserved.

Do not use `git stash push -u` blindly if large generated artifacts or accidental files may be untracked in the repo.

Inspect first:

```bash
git status --short
```

## 6. Listing stashes

To list stashes:

```bash
git stash list
```

To inspect a stash summary:

```bash
git stash show --stat stash@{0}
```

To inspect a stash patch:

```bash
git stash show -p stash@{0}
```

For large patches, inspect in pages:

```bash
git stash show -p stash@{0} | sed -n '1,220p'
```

## 7. Restoring a stashed workfront

Before restoring:

```bash
cd /srv/toolbox/app || exit 1
git status --short
git branch --show-current
```

Only restore onto the intended branch and a clean working tree.

To restore while keeping the stash:

```bash
git stash apply stash@{0}
```

To restore and remove the stash:

```bash
git stash pop stash@{0}
```

Prefer `apply` over `pop` when the workfront is important and conflicts would be costly.

After restoring:

```bash
git status --short
git diff --check
```

Update the workfront live-log.

## 8. When to use a branch

Use a branch when:

* the parallel task may require multiple commits;
* the task is conceptually separate;
* the task may be reviewed independently;
* the main workfront should remain recoverable;
* the parallel task could last across sessions;
* the changes may need to be abandoned without touching `master`.

Create a branch from clean `master`:

```bash
cd /srv/toolbox/app || exit 1

git status --short
git switch master
git pull --ff-only
git switch -c <type>/<short-topic>
```

Examples:

```text
docs/codex-operating-model
docs/codex-parallel-work
fix/block4-semantic-classifier
docs/service-map-lote2
```

Do not create a branch from a dirty working tree unless deliberately carrying the current patch into the branch.

## 9. Carrying current work into a branch

If the current uncommitted work should become its own branch:

```bash
cd /srv/toolbox/app || exit 1

git status --short
git switch -c <type>/<short-topic>
git status --short
```

Then continue work and commit on that branch.

This is appropriate when the current patch is real work that should not stay on `master`.

## 10. Parallel branch workflow

A parallel branch should have its own live-log when the work is multi-step.

Recommended flow:

1. create branch;
2. create or update live-log under `/srv/toolbox/shared/reports/system/`;
3. perform bounded work;
4. validate;
5. commit with Git helper if appropriate;
6. push branch if needed;
7. return to `master` only after clean status.

Branch commits should still use the Toolbox Git helpers unless there is an approved reason not to.

## 11. Returning to the main workfront

Before returning:

```bash
cd /srv/toolbox/app || exit 1
git status --short
git branch --show-current
```

If on a parallel branch, finish or stash that branch’s work.

Then:

```bash
git switch master
git status --short
```

If the main workfront was stashed, restore it deliberately:

```bash
git stash list
git stash apply stash@{N}
git status --short
```

Read the relevant live-log before continuing.

## 12. Inventory contamination rules

Parallel work can contaminate inventory and semantic inventory.

Any repository change may affect:

* raw script inventory;
* toolbox inventory;
* semantic script inventory;
* service map consistency;
* open questions;
* docs/knowledge alignment.

If parallel work adds, removes, renames, or changes scripts, helpers, libraries, pipelines, policies, services, or runbooks, the operator must decide whether to rerun relevant inventories before continuing architecture work.

### Script changes

If a script is added, removed, renamed, or substantially changed:

* raw script inventory may be stale;
* `toolbox_inventory_v0` may be stale;
* semantic inventory may be stale;
* block handoffs may be stale.

### Knowledge changes

If `knowledge/` changes:

* service maps may need consistency checks;
* policies may affect Codex prompts;
* open questions may change;
* runbooks may supersede older prompts.

### Docs changes

If `docs/operations/` changes:

* script conventions may change;
* output destination rules may change;
* semantic inventory rules may change;
* runbooks may need updates.

## 13. Stash versus branch decision table

Use a stash when:

* work is temporary;
* work is not ready to commit;
* the parallel task is short;
* you want to return to the same branch later;
* the working tree needs to be clean quickly.

Use a branch when:

* work is substantial;
* work may need commits;
* work may need review;
* work may last across sessions;
* work should be isolated from the main workfront;
* you want a clear Git history.

Use neither when:

* the current work can be finished and committed first;
* the parallel task is discussion-only;
* the parallel task is read-only.

## 14. Dirty working tree rules

A dirty working tree must be explained before Codex starts a new task.

Codex should report:

* current branch;
* modified files;
* untracked files;
* whether changes belong to the current workfront;
* whether stash, branch, commit, or abort is recommended.

Codex must not patch unrelated files into a dirty working tree without explicit operator approval.

## 15. Generated artifacts and branches

Generated artifacts under `/srv/toolbox/shared` are not part of the Git working tree by default.

They still matter.

When switching branches or stashing work, preserve paths to relevant generated artifacts in the live-log.

Examples:

```text
/srv/toolbox/shared/reports/system/...
/srv/toolbox/shared/library-db/raw/...
/srv/toolbox/shared/inventory/toolbox/...
```

Generated evidence may refer to a Git commit or dirty Git state. After switching branches, older evidence may no longer describe the active source tree.

## 16. Codex usage limits and parallel work

Do not start a branch-heavy or patch-heavy parallel task when Codex usage is near the short-window limit.

If `/status` shows low remaining budget:

* preserve state;
* write or update handoff;
* stop;
* resume later.

Parallel work should not consume the remaining budget needed to safely close the active workfront.

## 17. Recommended pre-parallel checklist

Before starting parallel work:

```text
1. What is the active workfront?
2. Is Git clean?
3. If dirty, what files are modified?
4. Is there a live-log for the dirty work?
5. Is the new task read-only, repository-changing, or runtime-changing?
6. Should this be a stash, branch, or no-op?
7. Will this affect inventories or semantic inventories?
8. What is the Codex usage status?
9. What is the rollback path?
10. What is the next checkpoint?
```

## 18. Example: starting documentation work while Block 4 patch is open

Current state:

```text
M scripts/admin/system/generate-toolbox-script-semantics-inventory.sh
```

The modification belongs to the Block 4 semantic inventory patch.

If writing unrelated runbooks before closing Block 4, use one of two safe approaches.

### Option A — Stash Block 4 patch

```bash
cd /srv/toolbox/app || exit 1

git status --short
git diff --stat
git stash push -m "wip: block4 semantic inventory scope"
git status --short
git switch -c docs/codex-operating-model
```

Then create the documentation changes on the branch.

Later:

```bash
git switch master
git stash apply stash@{N}
```

### Option B — Create a branch carrying the current patch

Only use this if the documentation and Block 4 patch are intentionally part of the same branch.

```bash
cd /srv/toolbox/app || exit 1

git status --short
git switch -c work/block4-and-codex-operating-model
```

This is less clean if the documentation should be reviewed independently.

## 19. Final rule

Parallel work is allowed only when the operator can answer:

```text
What workfront am I in?
What branch am I on?
What is dirty?
Where is the handoff?
What will become stale if I continue?
How do I return?
```

If those questions cannot be answered, stop and create a handoff before proceeding.
