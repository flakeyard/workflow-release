# shellcheck shell=bash
# Static tests of the job graph of the release workflow: only the job that
# releases, and the release pull request when it uses the App, may reach the
# environment and the key.
# shellcheck disable=SC2034 # current is the test that report and finish count.

: "${root:?}"

# Jobs that may use the environment and the key, sorted.
readonly KEY_JOBS='["pull-request","release"]'
# The plan sees only whether the key was passed, never its value.
readonly KEY_PRESENCE="secrets.APP_PRIVATE_KEY != ''"
# References to actions that are not code of the calling repository: actions
# of this workflow's repository, and others pinned by commit.
readonly OWN_OR_PINNED='^(\$/\.github/actions/[a-z-]+|[a-z0-9-]+/[a-z0-9-]+@[0-9a-f]{40})$'

# graph_check NAME FILTER: FILTER, a jq expression over the workflow, is
# true.
graph_check() {
  local name=$1 filter=$2
  setup
  current="release.yaml: $name"
  jq -e --arg presence "$KEY_PRESENCE" --argjson key_jobs "$KEY_JOBS" \
    --arg own_or_pinned "$OWN_OR_PINNED" "
    def condition: (.if // \"\") | gsub(\"\\\\s+\"; \" \");
    def key_references: tostring | gsub(\$presence; \"\") | contains(\"secrets.APP_PRIVATE_KEY\");
    def gated: has(\"environment\");
    $filter" <<<"$workflow" >/dev/null || report "not true: $filter"
  finish
}

if require_yq release.yaml; then
  workflow=$(load_workflow release.yaml)

  graph_check "only the release jobs use an environment" \
    "[.jobs | to_entries[] | select(.value | gated) | .key] | sort == \$key_jobs"
  graph_check "only the release jobs use the key" \
    "[.jobs | to_entries[] | select(.value | key_references) | .key] | sort == \$key_jobs"
  graph_check "the release pull request uses the environment and the key only with the App" \
    "[.jobs[\"pull-request\"] | .. | strings | select(contains(\"secrets.\") or contains(\"inputs.environment\") or contains(\"inputs.app-client-id\"))]
    | length > 0 and all(contains(\"inputs.app-pull-requests &&\"))"
  graph_check "release runs only when no environment is set or the plan finds it due" \
    ".jobs.release | .needs == \"plan\" and .environment == \"\${{ inputs.environment }}\"
    and (condition | contains(\"needs.plan.outputs.checked == 'true' && (inputs.environment == '' || needs.plan.outputs.due == 'true')\"))"
  graph_check "jobs with an environment run no code of the repository" \
    "[.jobs[] | select(gated) | .steps[] | select(has(\"run\") or ((.uses // \"\") | test(\$own_or_pinned) | not))] == []"
  graph_check "jobs with an environment check out nothing" \
    "[.jobs[] | select(gated) | .steps[] | .uses // \"\" | select(test(\"actions/checkout\"))] == []"
  graph_check "every job after the plan runs unless cancelled" \
    "[.jobs | to_entries[] | select(.key != \"plan\") | select(.value | condition | startswith(\"\${{ !cancelled() \") | not) | .key] == []"
  graph_check "the plan uses no environment and only GITHUB_TOKEN" \
    ".jobs.plan | (gated | not) and ([.steps[] | .with.token // empty] | all(. == \"\${{ github.token }}\"))"
  graph_check "latest and state use GITHUB_TOKEN" \
    "[.jobs.latest, .jobs.state | .steps[] | .with.token] | all(. == \"\${{ github.token }}\")"
  graph_check "on release/v0 the plan stops after the preflight and nothing runs" \
    ".jobs.plan | (.outputs.checked | contains(\"steps.preflight.outputs.skip != 'true'\"))
    and ([.steps[1:][] | .if // \"\"] | all(contains(\"steps.preflight.outputs.skip != 'true'\")))"
  graph_check "outputs come from the state job" \
    "[.on.workflow_call.outputs[] | .value | select(contains(\"jobs.state.outputs.state\") | not)] == []"
fi
