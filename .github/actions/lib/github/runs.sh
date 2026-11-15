# shellcheck shell=bash
# Workflow runs of REPO. Source this file; it expects SHELL_LIB and
# REPO.

# shellcheck source=/dev/null
source "${SHELL_LIB}/github/api.sh"

# run_path ID: print the API path of a workflow run.
run_path() {
  local id=$1
  printf '%s\n' "repos/${REPO}/actions/runs/${id}"
}

# workflow_run ID: print a workflow run.
workflow_run() {
  local id=$1 path
  path=$(run_path "${id}") || return
  api_get "${path}"
}

# workflow_id RUN: print the id of the workflow of a run.
workflow_id() {
  local run=$1 json
  json=$(workflow_run "${run}") || return
  jq -r .workflow_id <<<"${json}"
}

# commit_run WORKFLOW BRANCH COMMIT: print the newest push run of WORKFLOW at
# COMMIT on BRANCH; empty when there is none.
commit_run() {
  local workflow=$1 branch=$2 commit=$3 runs
  runs=$(api_get "repos/${REPO}/actions/workflows/${workflow}/runs?branch=${branch}&event=push&head_sha=${commit}&per_page=1") \
    || return
  jq -c '.workflow_runs[0] // empty' <<<"${runs}"
}

# branch_runs WORKFLOW BRANCH COUNT: print the newest COUNT push runs of
# WORKFLOW on BRANCH, newest first, one JSON object per line.
branch_runs() {
  local workflow=$1 branch=$2 count=$3 runs
  runs=$(api_get "repos/${REPO}/actions/workflows/${workflow}/runs?branch=${branch}&event=push&per_page=${count}") \
    || return
  jq -c '.workflow_runs[]' <<<"${runs}"
}

# run_review ID ENVIRONMENT: print the state of the last review of ENVIRONMENT
# in run ID, approved or rejected; empty when nobody reviewed it. The reviews
# of all attempts of the run are listed, in the order the API gives them.
run_review() {
  local id=$1 environment=$2 path approvals
  path=$(run_path "${id}") || return
  approvals=$(api_get "${path}/approvals") || return
  jq -r --arg environment "${environment}" '
    def of_environment: any(.environments[]; .name == $environment);
    [.[] | select(of_environment)] | last | .state // empty' <<<"${approvals}"
}
