# workflow-release

A reusable GitHub Actions workflow that releases a repository with
[release-please](https://github.com/googleapis/release-please): it keeps a
release pull request up to date, creates the tag `vX.Y.Z` and its GitHub release
when that pull request is merged, and optionally keeps a moving tag `vX` at the
latest release of each major version.

It works with a GitHub App of your own or with `GITHUB_TOKEN` alone. With an
environment that requires approval, only the job that releases waits for it, and
only when a release is due.

## Usage

Call it on pushes to the default branch and to `release/vN` branches, with
`N >= 1`; these are the only events it supports. Releases `0.y.z` are made only
on the default branch, and a push to `release/v0` is skipped.

```yaml
# .github/workflows/release.yaml
name: release

on:
  push:
    branches: [main, "release/v[1-9]*"]

permissions: {}

jobs:
  release:
    uses: flakeyard/workflow-release/.github/workflows/release.yaml@<commit> # v0.1.0
    permissions:
      contents: write
      issues: write
      pull-requests: write
      actions: write
    with:
      app-client-id: ${{ vars.RELEASE_APP_CLIENT_ID }}
      environment: release
      move-major-tag: true
    secrets:
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}

  # Publishing runs in the workflow run of the release commit.
  publish:
    needs: release
    if: ${{ !cancelled() && needs.release.outputs.released == 'true' }}
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@<commit> # v7.0.1
        with:
          ref: ${{ needs.release.outputs.sha }}
          persist-credentials: false
      # build and publish needs.release.outputs.tag
```

Reference the workflow by full commit SHA, as above. Do not put the calling job
in a concurrency group with `cancel-in-progress: true`: a cancelled run can lose
a release's publication. Concurrency group names starting with
`flakeyard-release-` are reserved for this workflow.

### Configuration

The repository needs a release-please configuration with one root package and
tags `vX.Y.Z` and the default labels; the workflow checks this and fails
otherwise. For example, `release-please-config.json`:

```json
{
  "release-type": "simple",
  "include-component-in-tag": false,
  "bump-minor-pre-major": true,
  "prerelease": true,
  "initial-version": "0.1.0",
  "packages": { ".": {} }
}
```

and `.release-please-manifest.json`:

```json
{ ".": "0.0.0" }
```

Versions `0.y.z` are published as pre-releases, and breaking changes raise their
minor version. To release `1.0.0`, add `"release-as": "1.0.0"` to the package,
merge the release pull request, then remove `release-as` again. Not supported,
and rejected before anything is written: draft releases, other packages,
components, separate pull requests, tags without `v` or with a custom separator,
custom labels and pull request title patterns, other versioning strategies and
`skip-github-release`. On `release/vN`, the manifest's major version must be
`N`.

Release assets are not supported: with immutable releases, assets can only be
added before a release is published, and this workflow publishes releases
directly. Publish artifacts to registries in the `publish` job instead.

### With a GitHub App

Before the first run:

1. Install the App on the repository with read and write access to contents,
   issues, pull requests and workflows. GitHub refuses a tag made by an App when
   its commits carry workflow files and the App may not write them, which is
   every tag of a repository with workflows.
2. Create the environment, here `release`, restrict its deployment branches to
   the default branch and `release/v[1-9]*`, and store the App's private key in
   it as `APP_PRIVATE_KEY`.
3. Store the App's client ID, here in the variable `RELEASE_APP_CLIENT_ID`.
4. If a ruleset restricts tags `v*`, allow the App to bypass it.

The workflow fails when only one of the client ID and the key is given: every
job that uses the key fails before using it, and the first job fails too when
`environment` is empty. A secret of the environment is visible only to the jobs
of that environment, so a missing one shows up only in a run that uses it; check
it whenever you change the environment.

### With a required reviewer

A job that uses an environment with required reviewers waits for approval. The
job that releases then runs only when a release or a repair of `vX` is due (see
[Behaviour](#behaviour)), so ordinary merges do not wait. With the default
`app-pull-requests: true`, the release pull request is also updated with the App
in the environment, and every push asks for that approval as well. To avoid
that, in this order:

1. Allow GitHub Actions to create pull requests in the repository (**Settings →
   Actions → General → Workflow permissions**); in an organization, it must be
   allowed there first.
2. Set `app-pull-requests: false`, and `check-workflow` if the repository has a
   check workflow (see [Without a GitHub App](#without-a-github-app) for what it
   must do).
3. Add the reviewer to the environment, and check that `APP_PRIVATE_KEY` is set
   in it.

With step 2 before step 1, the next creation of a release pull request fails; an
update of an existing one still works, which hides the failure until the next
release.

GitHub has one setting for creating and approving pull requests. With it on, any
job with `pull-requests: write` can approve a pull request as
`github-actions[bot]`, and a workflow can ask for that permission in its own
file, whatever the default permissions are. Anyone who can push a workflow,
including an app with write access, can then add an approval. While rulesets
require no approvals, that gives nothing beyond write access; once they do, turn
the setting off and open release pull requests with an App again, from an
environment without reviewers.

Release pull requests opened with `GITHUB_TOKEN` get their checks only through
`check-workflow` and are authored by `github-actions[bot]`.

### Without a GitHub App

Leave `app-client-id` empty and omit the secret. Then:

- Allow GitHub Actions to create pull requests in the repository settings
  (**Settings → Actions → General → Workflow permissions**); otherwise
  release-please cannot open the release pull request.
- Pull requests opened with `GITHUB_TOKEN` start no workflows. Set
  `check-workflow` to the file name of your check workflow, for example
  `test.yaml`; it is started with `workflow_dispatch` on the open release pull
  request in every run.
- A check run started that way does not count for required checks. The check
  workflow needs `statuses: write` and must report its result as a commit status
  on the checked commit: `pending` when it starts, then `success` or `failure`.
  Make that status the required check, with GitHub Actions as its source.
- GitHub may still create a `pull_request` run for the release pull request that
  waits for approval; it is not needed and ends when the pull request is merged.
- Tags created with `GITHUB_TOKEN` start no workflows either. Publish in the
  `publish` job of the same run, as shown above.
- The workflow creates and moves tags with `GITHUB_TOKEN`, so a ruleset cannot
  restrict tags `v*` to it; anyone with write access can move them.

## Inputs

- `app-client-id` (default `""`): client ID of a GitHub App to act as. Empty
  uses `GITHUB_TOKEN`.
- `environment` (default `""`): environment that holds `APP_PRIVATE_KEY`, used
  by the job that releases and, with `app-pull-requests`, by the job that
  updates the release pull request. With an environment, the job that releases
  runs only when a release is due. Empty means none.
- `app-pull-requests` (default `true`): update the release pull request with the
  App, in `environment`. `false` updates it with `GITHUB_TOKEN`, without the
  environment, and starts `check-workflow` on it. Without an App, it changes
  nothing.
- `move-major-tag` (default `false`): keep `vX` at the newest published
  `vX.Y.Z`, and `v0` at the newest `0.y.z`.
- `check-workflow` (default `""`): check workflow to start on the release pull
  request when it is updated with `GITHUB_TOKEN`: without an App, or with
  `app-pull-requests: false`.
- `config-file` (default `release-please-config.json`): release-please
  configuration.
- `manifest-file` (default `.release-please-manifest.json`): release-please
  manifest.

## Secrets

- `APP_PRIVATE_KEY`: private key of the App. Required with `app-client-id`. Pass
  it under this name: an environment secret reaches the workflow only when the
  caller passes a secret with the same name.

## Outputs

- `released`: `true` when the run's commit is a published release. A run that
  creates the release of an older commit, such as a run that waited in the
  queue, reports `false` and reruns the run of that commit, which reports it.
- `tag`: release tag, such as `v1.2.3`.
- `version`: released version, such as `1.2.3`.
- `major`, `minor`, `patch`: parts of the version.
- `prerelease`: `true` for releases `0.y.z`.
- `sha`: commit of the release, the run's commit. Build published artifacts from
  this commit.
- `release-url`: URL of the GitHub release.

## Permissions

The calling job must grant `contents: write`, `issues: write`,
`pull-requests: write` and `actions: write`, whichever path is used: GitHub
checks the permissions of every job of a called workflow, including jobs that
are skipped.

- `Plan` uses `GITHUB_TOKEN` to read workflow runs and their approvals
  (`actions`) and to relabel release pull requests left pending (`issues`).
- With an App, its token creates releases and moves `vX`, and with
  `app-pull-requests` updates the release pull request. It is limited to the
  current repository and to contents, issues, pull requests and workflows.
- Without an App, `GITHUB_TOKEN` uses `contents`, `issues` and `pull-requests`
  for releases. Without an App or with `app-pull-requests: false`, it uses them
  for the release pull request, and `actions` to start `check-workflow`.
- On every path, `GITHUB_TOKEN` uses `contents` to keep the newest release
  latest, and `actions` to rerun the run of a release commit that another run
  released.

## Behaviour

- **Branches.** Runs only on the default branch and on `release/vN` with
  `N >= 1`; on `release/v0`, `Plan` only reports a notice and every other job is
  skipped. On `release/vN`, release-please works on that branch. On every
  branch, the newest release of the repository stays marked as latest.
- **Jobs.** `Plan` checks the run and decides, without the key and without the
  environment, whether a release is due. `Release` creates releases and moves
  `vX`; it is the only job that uses the key, except `Release pull request` with
  `app-pull-requests`, and it runs no code of the repository. release-please
  releases every pending pull request that it finds at the head of the branch,
  with the configuration and the manifest there, so `Release` first fails unless
  each of them was merged at or before the run's commit and, when one is
  pending, the configuration and the manifest at the head are those at that
  commit. The run of a later merge commit releases such a pull request, and a
  rerun of the run of the head takes the release over. `Release state` derives
  the outputs from the repository. `Keep the latest release` keeps the newest
  release marked as latest, on every branch, so that a release on `release/vN`
  cannot take it from a newer one on another branch.
  `Publish at the release commit` reruns the run of a release commit that this
  run released. `Release pull request` updates the release pull request after
  `Release`, so that it sees a new tag, and `Start checks` starts
  `check-workflow` when that pull request is updated with `GITHUB_TOKEN`. A
  failure of a later job does not affect the outputs. The pull request update is
  retried once after 30 seconds. With the App, `Release pull request` uses the
  environment for the key but creates no deployment.
- **Due releases.** Without an environment, `Release` runs on every push whose
  `Plan` succeeds. With one, it runs only when `Plan` finds a reason:
  - release: the push merged a release pull request of release-please, from
    `release-please--branches--<branch>`, still labelled `autorelease: pending`;
  - takeover: such a pull request was merged earlier, its release does not
    exist, and the newest push run of its merge commit completed without a
    rejection; this run releases it, and the rerun of that run publishes it;
  - repair: `move-major-tag` is on, and `vX` must be created or moved forward.

  A pending pull request whose run is still queued, running or waiting releases
  itself. One whose release was rejected is not due again (see
  [Approval](#approval)), and a rejected repair asks again only after the next
  release. Pending pull requests from another branch, older than the 200 merged
  pull requests that release-please reads, or without a root version X.Y.Z in
  the manifest at their merge commit, are never due; `Plan` warns about them,
  and they are never relabelled `autorelease: tagged`. The decision is no
  security boundary: a wrong one costs an approval request or delays a release
  until the next push, and `Release` derives what it does from the repository.
  `Plan` writes its findings and its decision to its job summary and as notices
  of the run, which the API can read; they are a hint, not evidence. Its
  findings list every other pending pull request, also when a release is due,
  since an approval releases them too.

- **Unpublishable releases.** A job can wait for approval, and a run can be
  rerun, for 30 days. When the merge commit of a pending release pull request
  has no push run, such as with `[skip ci]` in its message, or its run is older
  than 29 days, the run of its commit could never publish the release. `Plan`
  then fails instead of taking over and asks to abandon that version (see
  [Approval](#approval)), and `Release` does not run, with an environment or
  without one.
- **Reruns.** The outputs are derived from the manifest and the release tag, not
  only from release-please's own outputs, and the latest release and the moving
  tag are synced from the repository's releases. If release-please fails after
  creating a release, the job still sets the outputs, syncs the tags and then
  fails; a rerun completes the remaining work. A merged release pull request
  left labelled `autorelease: pending` by such a failure is relabelled
  `autorelease: tagged` once its release exists, since release-please cannot
  recreate an immutable release by itself. A rerun of a completed run changes
  nothing but reports its release again, so publishing jobs must be idempotent.
  Only the run of the release commit reports a release, since attestations name
  the commit of their run as the source. When a run releases an older commit, or
  may have done so before release-please failed, `Publish at the release commit`
  waits up to 10 minutes for the newest push run of that commit on the branch to
  complete and reruns all its jobs; that run then reports the release, without
  asking for approval, since nothing is due. It fails with what to do when there
  is no such run, when the run is still running after the wait, or when GitHub
  refuses the rerun, such as for runs older than 30 days: rerun it, or, when
  that is not possible, `vX.Y.Z` is released but the run of its commit cannot
  publish it; cut the next patch release. Creating a branch, such as
  `release/vN` at a release, is never reported as a release.
- **Moving tag.** `vX` is created or moved to the newest published,
  non-prerelease `vX.Y.Z` of the major version on the branch, only forward. `v0`
  follows the releases `0.y.z`, which are all pre-releases and carry no
  compatibility guarantee.
- **Concurrency.** Release jobs of one repository run one at a time and queue
  instead of being cancelled; so do the jobs that keep the latest release, and
  the release pull request jobs of one branch. `Plan` is in no group, so a
  release that waits for approval does not keep other pushes from planning. A
  run that waited in the queue behind a failed run can create the release of
  that run's commit; the rerun of that run publishes it.

## Approval

With a required reviewer on the environment, the approval is the only defence
against anyone who can merge, such as a compromised app with write access. Check
the repository, not the output of the run: a modified caller workflow can write
any summary. Before approving a run at commit `SHA`:

1. The run is a `push` run of the release workflow on the default branch or
   `release/vN`, at `SHA`: check the run page, not its summary.
2. `SHA` merges a release pull request that you merged. For a takeover, the
   pending pull request is one that you merged, and its own run failed rather
   than being rejected.
3. No merged pull request other than the one of step 2 is labelled
   `autorelease: pending`: the approval releases every one of them. This lists
   their numbers:

   ```sh
   gh api 'repos/OWNER/REPO/issues?state=closed&labels=autorelease:%20pending' \
     --paginate --jq '.[] | select(.pull_request.merged_at) | .number'
   ```

4. The release pull request changes only the manifest, `CHANGELOG.md` and the
   version files of the configuration.
5. `git log --format='%h %G? %an %s' vPREV..SHA` lists only signed squash
   commits of pull requests that you reviewed.
6. `git diff vPREV..SHA -- .github/` is empty or has only changes that you
   reviewed.
7. The caller at `SHA` references `flakeyard/workflow-release` at the commit of
   one of its release tags
   (`gh api repos/flakeyard/workflow-release/commits/vX.Y.Z --jq .sha`), not at
   a commit of another branch or of a fork.

Approve in **Review deployments** of the run, or with the API:

```sh
gh api -X POST repos/OWNER/REPO/actions/runs/RUN_ID/pending_deployments \
  -F 'environment_ids[]=ENVIRONMENT_ID' -f state=approved -f comment='checked'
```

Approve or reject within days: GitHub fails a job that waits for 30 days. After
a rejection, `Release` fails, `released` is `false` and the run is red. The
release pull request stays labelled `autorelease: pending`, so release-please
opens no new release pull request, and later pushes do not ask again. Then
either:

- **Approve later.** **Re-run failed jobs** of that run: `Release` asks for
  approval again and releases the commit of that run. This works for 30 days
  after the run was created.
- **Abandon.** First remove the label `autorelease: pending` from the merged
  release pull request and add `autorelease: abandoned`, which is only for
  readers. Then merge a commit that reverts its merge commit, such as
  `chore: abandon vX.Y.Z` made with `git revert --no-commit MERGE_SHA`. The
  revert puts the manifest back at the last released version and removes the
  version's section from `CHANGELOG.md`: release-please finds the latest release
  only by the version in the manifest, and while it names a version without a
  tag, it lists the whole history again and bumps the version by all of it. The
  push of the revert opens a release pull request for the version after the last
  release, with all changes since that release; it is the abandoned version
  again unless later commits raise it further. Do not rerun the rejected run
  afterwards: it asks for approval again but releases nothing, since its pull
  request is no longer pending.

When `Plan` reports a pending release as unpublishable, abandon it in the same
way. When a release exists but the run of its commit can no longer publish it,
its artifacts are never published; cut the next patch release, for example by
merging a `fix:` commit.

## Requirements

GitHub-hosted `ubuntu-24.04` runners: the workflow uses their `bash`, `gh`,
`jq`, GNU coreutils (`base64`, `mktemp`, `sort -V`) and GNU `grep`.

## Development

The workflow in
[`.github/workflows/release.yaml`](.github/workflows/release.yaml) only composes
steps. Each step's logic is a small composite action in
[`.github/actions`](.github/actions), released together with the workflow and
referenced with `$/`:

- `preflight`: the event, the release branch, the App inputs and a supported
  release-please configuration, checked with `GITHUB_TOKEN` before anything is
  written;
- `release-plan`: whether the job that releases is due on a push;
- `token`: the App token or `GITHUB_TOKEN`, after checking that the client ID
  and the key come together;
- `reconcile-pending-prs`: release pull requests left pending by a failed run;
- `release-scope`: before release-please, that every pending release pull
  request was merged at or before the run's commit, and that the configuration
  and the manifest at the head of the branch are those at that commit;
- `release-state`: the outputs, derived from the repository, as one JSON object;
- `rerun-release-commit`: the rerun of the run of a release commit;
- `keep-latest`: the newest release stays latest;
- `sync-major-tag`: the moving tag `vX`;
- `release-pr`: the release pull request, with one retry;
- `dispatch-checks`: checks of the release pull request when `GITHUB_TOKEN`
  updates it.

Each action runs its `run.sh`, or one script per check when it has several
(`preflight/inputs.sh` and `preflight/config.sh`). Each job first calls
[action-shell-lib][action-shell-lib] once, pinned by commit, and passes its
directory to the actions as the input `shell-lib`, which they give to their
scripts as `SHELL_LIB`; the actions do not call the library themselves. The
scripts source `report.sh`, which reports errors, warnings, notices and the job
summary, and `github/api.sh` and `github/contents.sh`, which call the GitHub
API, from the library, and the helpers of this repository in `lib`:
`lib/github/` calls the GitHub API on top of the library (`optional.sh`,
`files.sh`, `tags.sh`, `releases.sh`, `pulls.sh`, `runs.sh`, `commits.sh`),
`lib/version.sh` tells versions and tags of releases, `lib/manifest.sh` reads
the release-please manifest, `lib/app-key.sh` checks the App inputs,
`lib/major-tag.sh` works out how `vX` has to change and `lib/clock.sh` measures
ages. `tests/run.sh` tests them with the harness, the fixtures and the stubs of
`gh`, `date` and `sleep` in `internal/testing` of the library, which `tests/bin`
extends with `gh workflow` and fixtures that appear after a sleep; it takes the
library at the commit that `release.yaml` pins: CI passes it in `SHELL_LIB`, and
otherwise `tests/run.sh` fetches it with `git` into
`~/.cache/flakeyard/action-shell-lib/<commit>`. The suites in `tests/unit`
mirror the actions and share the helpers in `tests/lib`. `tests/unit/workflows`
has one file per workflow. `release.sh` checks the job graph: only `Release`
and, with the App, `Release pull request` reach the environment and the key,
`Release` runs only when it is due or there is no environment and runs
release-please right after `release-scope`, no job with an environment runs code
of the repository, every job passes the library to the actions that need it, and
every use of the library names one commit; the others check that the
repository's own workflows call workflow-check and workflow-scorecard as
[FY-0034][fy-0034] asks. They read the workflows with mikefarah `yq` v4, which
GitHub-hosted runners have, and fail without it; locally, run
`nix shell nixpkgs#yq-go -c tests/run.sh`.

The repository checks itself with [`test.yaml`](.github/workflows/test.yaml):
its job `unit` runs `tests/run.sh`, and the job `check` calls
[workflow-check](https://github.com/flakeyard/workflow-check), which checks the
title of the pull request, `renovate.json` and the tags of its presets.
[`scorecard.yaml`](.github/workflows/scorecard.yaml) runs OpenSSF Scorecard
through [workflow-scorecard](https://github.com/flakeyard/workflow-scorecard).
The repository releases itself through
[`release-self.yaml`](.github/workflows/release-self.yaml), whose release pull
requests are checked by a dispatched run of `test.yaml`. Before a pull request,
run `tests/run.sh`, shellcheck, shfmt, actionlint and zizmor; actionlint does
not yet know the `$/` syntax and `queue: max` and reports them as errors. The
design follows
[FY-0007](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0007-branching-and-releases.md),
[FY-0028](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0028-supply-chain.md),
[FY-0030](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0030-actions-workflows-and-release-bot.md),
[FY-0034][fy-0034] and [FY-0035][fy-0035].

## Bootstrap

Following
[FY-0022](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0022-bootstrap.md),
some checks of this repository are not released yet. Until they are:

- actionlint, zizmor, shellcheck, shfmt, prettier, markdownlint, typos and REUSE
  run locally before every pull request; the atoms will provide them.

## License

[MIT](LICENSE).

[action-shell-lib]: https://github.com/flakeyard/action-shell-lib
[fy-0034]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0034-check-every-repository-with-workflow-check.md
[fy-0035]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0035-extract-logic-that-has-two-users.md
