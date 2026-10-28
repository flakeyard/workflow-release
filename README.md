# workflow-release

A reusable GitHub Actions workflow that releases a repository with
[release-please](https://github.com/googleapis/release-please): it keeps a
release pull request up to date, creates the tag `vX.Y.Z` and its GitHub release
when that pull request is merged, and optionally keeps a moving tag `vX` at the
latest release of each major version.

It works with a GitHub App of your own or with `GITHUB_TOKEN` alone.

## Usage

Call it on pushes to the default branch and to `release/vN` branches; these are
the only events it supports.

```yaml
# .github/workflows/release.yaml
name: release

on:
  push:
    branches: [main, "release/v*"]

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

  # Publishing runs in the same workflow run as the release.
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
merge the release pull request, then remove `release-as` again. Draft releases,
other packages, components in tags and tags without `v` are not supported.

Release assets are not supported: with immutable releases, assets can only be
added before a release is published, and this workflow publishes releases
directly. Publish artifacts to registries in the `publish` job instead.

### With a GitHub App

Before the first run:

1. Install the App on the repository with read and write access to contents,
   issues and pull requests.
2. Create the environment, here `release`, restrict its deployment branches to
   the default branch and `release/v*`, and store the App's private key in it as
   `APP_PRIVATE_KEY`.
3. Store the App's client ID, here in the variable `RELEASE_APP_CLIENT_ID`.
4. If a ruleset restricts tags `v*`, allow the App to bypass it.

The workflow fails when only one of the client ID and the key is given.

### Without a GitHub App

Leave `app-client-id` empty and omit the secret. Then:

- Allow GitHub Actions to create pull requests in the repository settings
  (**Settings → Actions → General → Workflow permissions**); otherwise
  release-please cannot open the release pull request.
- Pull requests opened with `GITHUB_TOKEN` start no workflows. Set
  `check-workflow` to the file name of your check workflow, for example
  `check.yaml`; it is started with `workflow_dispatch` on the open release pull
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
- `environment` (default `""`): environment that holds `APP_PRIVATE_KEY`. Empty
  means none.
- `move-major-tag` (default `false`): keep `vX` at the newest published
  `vX.Y.Z`, and `v0` at the newest `0.y.z`.
- `check-workflow` (default `""`): check workflow to start on the release pull
  request when no App is used.
- `config-file` (default `release-please-config.json`): release-please
  configuration.
- `manifest-file` (default `.release-please-manifest.json`): release-please
  manifest.

## Secrets

- `APP_PRIVATE_KEY`: private key of the App. Required with `app-client-id`. Pass
  it under this name: an environment secret reaches the workflow only when the
  caller passes a secret with the same name.

## Outputs

- `released`: `true` when the run's commit is a published release.
- `tag`: release tag, such as `v1.2.3`.
- `version`: released version, such as `1.2.3`.
- `major`, `minor`, `patch`: parts of the version.
- `prerelease`: `true` for releases `0.y.z`.
- `sha`: commit of the release. Build published artifacts from this commit.
- `release-url`: URL of the GitHub release.

## Permissions

The calling job must grant `contents: write`, `issues: write`,
`pull-requests: write` and `actions: write`, whichever path is used: GitHub
checks the permissions of every job of a called workflow, including jobs that
are skipped.

- With an App, its token does the work and is limited to the current repository
  and to contents, issues and pull requests; `GITHUB_TOKEN` is not used for
  writes.
- Without an App, `GITHUB_TOKEN` uses `contents`, `issues` and `pull-requests`
  for releases and the release pull request, and `actions` to start
  `check-workflow`.

## Behaviour

- **Branches.** Runs only on the default branch and on `release/vN`. On
  `release/vN`, release-please works on that branch, and the newest release of
  the repository stays marked as latest.
- **Jobs.** `Release` creates releases, `Release pull request` updates the
  release pull request, and `Start checks` starts `check-workflow` without an
  App. A failure of a later job does not affect the outputs of `Release`. The
  pull request update is retried once after 30 seconds. `Release pull request`
  uses the environment for the key but creates no deployment.
- **Reruns.** The outputs are derived from the manifest and the release tag, not
  only from release-please's own outputs, and the latest release and the moving
  tag are synced from the repository's releases. If release-please fails after
  creating a release, the job still sets the outputs, syncs the tags and then
  fails; a rerun completes the remaining work. A merged release pull request
  left labelled `autorelease: pending` by such a failure is relabelled
  `autorelease: tagged` once its release exists, since release-please cannot
  recreate an immutable release by itself. A rerun of a completed run changes
  nothing but reports its release again, so publishing jobs must be idempotent.
  Creating a branch, such as `release/vN` at a release, is never reported as a
  release.
- **Moving tag.** `vX` is created or moved to the newest published,
  non-prerelease `vX.Y.Z` of the major version on the branch, only forward. `v0`
  follows the releases `0.y.z`, which are all pre-releases and carry no
  compatibility guarantee.
- **Concurrency.** Release jobs of one repository run one at a time and queue
  instead of being cancelled.

## Requirements

GitHub-hosted `ubuntu-24.04` runners: the workflow uses their `bash`, `gh` and
`jq`.

## Development

The workflow releases itself through
[`release-self.yaml`](.github/workflows/release-self.yaml). Before a pull
request, run actionlint and zizmor on `.github/workflows`; actionlint does not
yet know the `$/` syntax and reports it as an error. The design follows
[FY-0007](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0007-branching-and-releases.md),
[FY-0021](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0021-release-bot.md)
and
[FY-0020](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0020-actions-and-workflows.md).

## Bootstrap

Following
[FY-0022](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0022-bootstrap.md),
this repository has no CI checks yet. Until they are released:

- actionlint, zizmor, shellcheck, prettier, markdownlint, typos and REUSE run
  locally before every pull request; `workflow-check` and the atoms will provide
  them;
- pull request titles are checked by the reviewer; `workflow-check` will check
  them;
- OpenSSF Scorecard comes with `workflow-check`.

## License

[MIT](LICENSE).
