# shellcheck shell=bash
# shellcheck disable=SC2016 # jq expressions, not expansions.
# Static tests of the Scorecard workflow of this repository: it calls
# workflow-scorecard as FY-0034 asks of every repository.

readonly SCORECARD_PERMISSIONS='{"actions":"read","contents":"read","id-token":"write","security-events":"write"}'
readonly WORKFLOW_SCORECARD='^flakeyard/workflow-scorecard/\\.github/workflows/scorecard\\.yaml@[0-9a-f]{40}$'

# scorecard_test NAME FILTER: FILTER is true of scorecard.yaml.
scorecard_test() { workflow_check "$scorecard_workflow" "scorecard.yaml: $1" "$2"; }

if require_yq .github/workflows/scorecard.yaml; then
  scorecard_workflow=$(load_yaml .github/workflows/scorecard.yaml)
  scorecard_test "no permissions at the top level" '.permissions == {}'
  scorecard_test "runs on main, weekly and on dispatch, and on nothing else" \
    '.on | (keys == ["push","schedule","workflow_dispatch"])
    and .push == {"branches":["main"]} and (.schedule | length == 1)'
  scorecard_test "its only job calls workflow-scorecard pinned by commit" \
    ".jobs | keys == [\"scorecard\"] and (.scorecard.uses | test(\"$WORKFLOW_SCORECARD\"))"
  scorecard_test "the job gets exactly the permissions of Scorecard" \
    ".jobs.scorecard.permissions == $SCORECARD_PERMISSIONS"
  scorecard_test "the job passes no inputs and no secrets" \
    '.jobs.scorecard | (has("with") or has("secrets")) | not'
fi
