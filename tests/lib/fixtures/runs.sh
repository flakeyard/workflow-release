# shellcheck shell=bash
# Workflow runs, as the actions API answers them. The paths are written out,
# not taken from lib/github, so that the tests check the paths that the
# scripts call.

# commit_runs_path BRANCH COMMIT: the push runs of workflow 5 at COMMIT on
# BRANCH.
commit_runs_path() {
  local branch=$1 commit=$2
  printf '%s\n' "repos/${REPO}/actions/workflows/5/runs?branch=${branch}&event=push&head_sha=${commit}&per_page=1"
}
