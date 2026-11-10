# shellcheck shell=bash
# Static tests of a workflow with yaml.sh of action-shell-lib. Source this
# file after it.

# Helpers of the expressions of workflow_check.
readonly WORKFLOW_DEFS='
  def condition: (.if // "") | gsub("\\s+"; " ");
'

# workflow_check WORKFLOW NAME FILTER [JQ_ARG...]: yaml_check of FILTER, with
# the helpers above, over WORKFLOW, a workflow as load_yaml prints it.
workflow_check() {
  local workflow=$1 name=$2 filter=$3
  shift 3
  yaml_check "$workflow" "$name" "$WORKFLOW_DEFS $filter" "$@"
}
