# shellcheck shell=bash
# shellcheck disable=SC2016 # jq expressions, not expansions.
# Static tests of the CI of this repository: it runs the unit tests and calls
# workflow-check as the caller contract asks of every repository (FY-0034).

# The condition of the caller job: no result for a superseded pull request
# run, and a final status for every dispatched run.
readonly CALLER_CONDITION="\${{ !cancelled() || github.event_name == 'workflow_dispatch' }}"
readonly CALLER_PERMISSIONS='{"actions":"read","contents":"read","pull-requests":"read","statuses":"write"}'
readonly WORKFLOW_CHECK='^flakeyard/workflow-check/\\.github/workflows/check\\.yaml@[0-9a-f]{40}$'

# ci_test NAME FILTER: FILTER is true of test.yaml.
ci_test() { workflow_check "${ci_workflow}" "test.yaml: $1" "$2"; }

if require_yq .github/workflows/test.yaml; then
  ci_workflow=$(load_workflow test.yaml)
  ci_test "no permissions at the top level" '.permissions == {}'
  ci_test "the unit tests run without credentials" \
    '.jobs.unit | (.steps[0].with == {"persist-credentials": false})
    and ([.steps[].run // empty] == ["tests/run.sh"])'
  ci_test "the unit tests get the library from its step" \
    '.jobs.unit.steps | (.[1].id == "lib")
    and (.[2].env == {"SHELL_LIB": "${{ steps.lib.outputs.path }}"})'
  ci_test "the job check calls workflow-check pinned by commit, unnamed" \
    ".jobs.check | (.uses | test(\"${WORKFLOW_CHECK}\")) and (has(\"name\") | not)"
  ci_test "check needs every other job and passes their results" \
    '(.jobs | keys - ["check"]) as $others
    | .jobs.check | (.needs // [] | sort) == $others and .with.needs == "${{ toJSON(needs) }}"'
  ci_test "no job needs check" \
    '[.jobs[] | .needs // [] | .[] | select(. == "check")] == []'
  ci_test "check runs unless cancelled, and always on dispatch" \
    ".jobs.check | condition == \"${CALLER_CONDITION}\""
  ci_test "check gets the permissions of workflow-check" \
    ".jobs.check.permissions == ${CALLER_PERMISSIONS}"
  ci_test "check forbids configuration files of atom tools (FY-0037)" \
    '.jobs.check.with["forbid-tool-configs"] == true'
  ci_test "check builds the root flake with the checks of its atoms and expects the flakeyard presets" \
    '.jobs.check.with | .flake == "." and .["expect-checks"] == "[\"workflows\"]" and .["renovate-presets"] == "[\"flakeyard/renovate-config\"]"'
  ci_test "an edit of a pull request cancels no run" \
    '.concurrency["cancel-in-progress"] | contains("github.event.action != '"'edited'"'")'
  ci_test "dispatched and edited pull requests are checked" \
    '.on | has("workflow_dispatch") and (.pull_request.types | index("edited") != null)'
fi
