# workflow-release

A reusable GitHub Actions workflow that releases a repository with
[release-please](https://github.com/googleapis/release-please): it keeps a
release pull request up to date, creates the tag `vX.Y.Z` and its GitHub release
when that pull request is merged, and optionally keeps a moving tag `vX` at the
latest release of each major version.

It works with a GitHub App of your own or with `GITHUB_TOKEN` alone.

## Usage

Call it on pushes to the default branch and to `release/vN` branches:

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

Reference the workflow by full commit SHA, as above. The repository needs a
release-please configuration, for example `release-please-config.json`:

```json
{
  "release-type": "simple",
  "include-component-in-tag": false,
  "bump-minor-pre-major": true,
  "prerelease": true,
  "packages": { ".": {} }
}
```

and `.release-please-manifest.json`:

```json
{ ".": "0.0.0" }
```

With `prerelease` and `bump-minor-pre-major`, versions `0.y.z` are published as
pre-releases and breaking changes raise the minor version. Remove `prerelease`
when releasing `1.0.0`.

### Without a GitHub App

Leave `app-client-id` empty and omit the secret. Then:

- Allow GitHub Actions to create pull requests in the repository settings
  (**Settings → Actions → General → Workflow permissions**); otherwise
  release-please cannot open the release pull request.
- Pull requests opened with `GITHUB_TOKEN` start no workflows. Set
  `check-workflow` to the file name of your check workflow, for example
  `check.yaml`; it is started with `workflow_dispatch` on the release pull
  request after every update.
- A check run started that way does not count for required checks. The check
  workflow must report its result as a commit status on the checked commit:
  `pending` when it starts, then `success` or `failure`. Make that status the
  required check, with GitHub Actions as its source.
- Tags created with `GITHUB_TOKEN` start no workflows either. Publish in the
  `publish` job of the same run, as shown above.

## Inputs

- `app-client-id` (default `""`): client ID of a GitHub App to act as. Empty
  uses `GITHUB_TOKEN`.
- `environment` (default `""`): environment that holds `APP_PRIVATE_KEY`. Empty
  means none.
- `move-major-tag` (default `false`): keep `vX` at the newest published
  `vX.Y.Z`.
- `check-workflow` (default `""`): check workflow to start on the release pull
  request when no App is used.
- `config-file` (default `release-please-config.json`): release-please
  configuration.
- `manifest-file` (default `.release-please-manifest.json`): release-please
  manifest.

## Secrets

- `APP_PRIVATE_KEY`: private key of the App. Required when `app-client-id` is
  set; the run fails without it. Pass it under this name: an environment secret
  reaches the workflow only when the caller passes a secret with the same name.

## Outputs

- `released`: `true` when the pushed commit is a published release.
- `tag`: release tag, such as `v1.2.3`.
- `version`: released version, such as `1.2.3`.
- `major`, `minor`, `patch`: parts of the version.
- `sha`: commit of the release. Build published artifacts from this commit.
- `release-url`: URL of the GitHub release.

## Permissions

The calling job must grant `contents: write`, `issues: write`,
`pull-requests: write` and `actions: write`. `GITHUB_TOKEN` uses them when no
App is given; `actions: write` is used only to start `check-workflow`. With an
App, its token is limited to the current repository and to contents, issues and
pull requests.

## Behaviour

- **Branches.** Runs only on the default branch and on `release/vN`. On
  `release/vN`, release-please works on that branch, and the newest release of
  the repository stays marked as latest.
- **Two jobs.** `release` creates releases; `pull-request` updates the release
  pull request. A failure of the second does not affect the first, and the pull
  request update is retried once.
- **Reruns.** The outputs are derived from the manifest and the release that
  points at the pushed commit, not from release-please's own outputs. Rerunning
  a failed run reports the release again and completes the tag sync; rerunning a
  completed run changes nothing. Publishing jobs of callers must therefore be
  idempotent.
- **Moving tag.** `vX` is created or moved to the newest published,
  non-prerelease `vX.Y.Z` of the major version on the branch, only forward. No
  `v0` is created. In repositories whose rulesets restrict tags, the App must be
  allowed to bypass them.
- **Concurrency.** Release jobs of one repository run one at a time.

## Requirements

GitHub-hosted Ubuntu runners: the workflow uses their `bash`, `gh` and `jq`.

## Development

The workflow releases itself through
[`release-self.yaml`](.github/workflows/release-self.yaml). Before a pull
request, run actionlint and zizmor on `.github/workflows`; actionlint does not
yet know the `$/` syntax and reports it as an error. The design follows
[FY-0007](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0007-branching-and-releases.md),
[FY-0010](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0010-release-bot.md)
and
[FY-0020](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0020-actions-and-workflows.md).

## License

[MIT](LICENSE).
