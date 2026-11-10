# shellcheck shell=bash
# Tests of token: the check of the App inputs.

script=.github/actions/token/run.sh

# token_case NAME EXPECTED [NAME=VALUE...]: check neither a client ID nor a
# key, with the given overrides; message=TEXT is expected.
token_case() {
  local name=$1 expected=$2
  shift 2
  start_test
  apply CLIENT_ID="" HAS_KEY=false
  configure "$@"
  run "token: $name" "$expected" "$script"
  expect_param_message
  finish
}
token_case "client ID and key" ok CLIENT_ID=Iv1 HAS_KEY=true
token_case "no App" ok
token_case "client ID without key" fail CLIENT_ID=Iv1 \
  message="app-client-id is set but APP_PRIVATE_KEY is empty"
token_case "key without client ID" fail HAS_KEY=true \
  message="APP_PRIVATE_KEY is set but app-client-id is empty"

# The permissions that the token of the App asks for.
if require_yq .github/actions/token/action.yml; then
  token_action=$(load_yaml .github/actions/token/action.yml)
  workflow_check "$token_action" "token: the App token may write contents, issues, pull requests and workflows" \
    '[.runs.steps[] | select(.id == "app") | .with | to_entries[] | select(.key | startswith("permission-"))] | from_entries
      == {"permission-contents": "write", "permission-issues": "write", "permission-pull-requests": "write", "permission-workflows": "write"}'
fi
