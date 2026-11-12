# shellcheck shell=bash
# Tests of preflight: the run.

step=inputs

# inputs_case NAME EXPECTED [NAME=VALUE...]: check a push to main with neither
# a client ID nor a visible key, with the given overrides; message=TEXT is
# expected.
inputs_case() {
  local name=$1 expected=$2
  shift 2
  start_test
  apply EVENT=push CLIENT_ID="" HAS_KEY=false KEY_VISIBLE=true DEFAULT_BRANCH=main
  configure "$@"
  run_step "preflight run: $name" "$expected" "$ACTIONS/preflight" "$step"
  expect_param_message
  finish
}
inputs_case "App on main" ok CLIENT_ID=Iv1 HAS_KEY=true
inputs_case "no App on release/v12" ok REF=refs/heads/release/v12
inputs_case "default branch other than main" ok REF=refs/heads/trunk DEFAULT_BRANCH=trunk
inputs_case "client ID without key" fail CLIENT_ID=Iv1 message="APP_PRIVATE_KEY is empty"
inputs_case "key without client ID" fail HAS_KEY=true message="app-client-id is empty"
inputs_case "client ID and a key in an environment" ok CLIENT_ID=Iv1 KEY_VISIBLE=false
inputs_case "feature branch" fail REF=refs/heads/feature message="only on main and release/vN"
inputs_case "release/v1x" fail REF=refs/heads/release/v1x
inputs_case "release/v00" fail REF=refs/heads/release/v00 \
  message="only on main and release/vN with N >= 1"
inputs_case "workflow_dispatch" fail EVENT=workflow_dispatch DEFAULT_BRANCH="" \
  message="only on push events"

# skip_case NAME EXPECTED SKIP [NAME=VALUE...]: like inputs_case, and the
# output skip is SKIP.
skip_case() {
  local name=$1 expected=$2 skip=$3
  shift 3
  start_test
  apply EVENT=push CLIENT_ID="" HAS_KEY=false KEY_VISIBLE=true DEFAULT_BRANCH=main
  configure "$@"
  run_step "preflight run: $name" "$expected" "$ACTIONS/preflight" "$step"
  expect output skip "$skip"
  expect_param_message
  finish
}
skip_case "release/v0 is skipped" ok true REF=refs/heads/release/v0 \
  message="::notice::releases 0.y.z are made only on main; nothing to do on release/v0"
skip_case "release/v0 is skipped before the App inputs" ok true \
  REF=refs/heads/release/v0 CLIENT_ID=Iv1
skip_case "release/v0 as the default branch is not skipped" ok "" \
  REF=refs/heads/release/v0 DEFAULT_BRANCH=release/v0
skip_case "main is not skipped" ok ""
skip_case "release/v1 is not skipped" ok "" REF=refs/heads/release/v1

start_test
apply EVENT=push CLIENT_ID="" HAS_KEY=false KEY_VISIBLE=true DEFAULT_BRANCH=main REF=refs/heads/release/v0
run_hostile "preflight run: earlier steps of the job run no code in it" ok "$ACTIONS/preflight" "$step"
expect output skip true
finish
