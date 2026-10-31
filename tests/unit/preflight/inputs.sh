# shellcheck shell=bash
# Tests of preflight: the run.

script=preflight/inputs.sh

# inputs_case NAME EXPECTED [NAME=VALUE...]: check a push to main with neither
# a client ID nor a key, with the given overrides; message=TEXT is expected.
inputs_case() {
  local name=$1 expected=$2
  shift 2
  setup
  export EVENT=push CLIENT_ID="" HAS_KEY=false DEFAULT_BRANCH=main
  apply "$@"
  run "preflight run: $name" "$expected" "$script"
  expect_param_message
  finish
}
inputs_case "App on main" ok CLIENT_ID=Iv1 HAS_KEY=true
inputs_case "no App on release/v12" ok REF=refs/heads/release/v12
inputs_case "default branch other than main" ok REF=refs/heads/trunk DEFAULT_BRANCH=trunk
inputs_case "client ID without key" fail CLIENT_ID=Iv1 message="APP_PRIVATE_KEY is empty"
inputs_case "key without client ID" fail HAS_KEY=true message="app-client-id is empty"
inputs_case "feature branch" fail REF=refs/heads/feature message="only on main and release/vN"
inputs_case "release/v1x" fail REF=refs/heads/release/v1x
inputs_case "release/v0" fail REF=refs/heads/release/v0
inputs_case "workflow_dispatch" fail EVENT=workflow_dispatch DEFAULT_BRANCH="" \
  message="only on push events"
