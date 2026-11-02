# shellcheck shell=bash source-path=SCRIPTDIR
# Workflow runs of REPO. Source this file; it expects REPO.

# shellcheck source=api.sh
source "${BASH_SOURCE[0]%/*}/api.sh"

# run_path ID: print the API path of a workflow run.
run_path() {
  local id=$1
  printf '%s\n' "repos/$REPO/actions/runs/$id"
}

# workflow_id RUN: print the id of the workflow of a run.
workflow_id() {
  local run=$1
  api_get "$(run_path "$run")" | jq -r .workflow_id
}

# commit_run WORKFLOW BRANCH COMMIT: print the newest push run of WORKFLOW at
# COMMIT on BRANCH; empty when there is none.
commit_run() {
  local workflow=$1 branch=$2 commit=$3
  api_get "repos/$REPO/actions/workflows/$workflow/runs?branch=$branch&event=push&head_sha=$commit&per_page=1" \
    | jq -c '.workflow_runs[0] // empty'
}
