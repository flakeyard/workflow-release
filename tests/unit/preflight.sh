# shellcheck shell=bash
# Tests of preflight: the run and the release-please configuration.

# inputs_case NAME EXPECTED [NAME=VALUE...]: check a push to main with neither
# a client ID nor a key, with the given overrides; message=TEXT is expected.
inputs_case() {
  local name=$1 expected=$2
  shift 2
  setup
  export EVENT=push CLIENT_ID="" HAS_KEY=false DEFAULT_BRANCH=main
  apply "$@"
  run "preflight run: $name" "$expected" preflight/check-inputs.sh
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

# A supported configuration, without its braces.
ok='"include-component-in-tag":false,"packages":{".":{}}'

# config_case NAME EXPECTED [NAME=VALUE...]: check the configuration
# config=JSON, {$ok} by default, with the root version version=X.Y.Z, 0.0.0 by
# default, and the given overrides.
config_case() {
  local name=$1 expected=$2
  shift 2
  setup
  apply "$@"
  file_fixture "$CONFIG" "$SHA" "$(param config "{$ok}")"
  manifest "$(param version 0.0.0)"
  run "preflight config: $name" "$expected" preflight/check-config.sh
  finish
}
config_case "supported" ok
config_case "package-level setting" ok config='{"packages":{".":{"include-component-in-tag":false}}}'
config_case "component in tag by default" fail config='{"packages":{".":{}}}'
config_case "package enables component in tag" fail \
  config='{"include-component-in-tag":false,"packages":{".":{"include-component-in-tag":true}}}'
config_case "no v in tag" fail config="{\"include-v-in-tag\":false,$ok}"
config_case "package without v in tag" fail \
  config='{"include-component-in-tag":false,"packages":{".":{"include-v-in-tag":false}}}'
config_case "two packages" fail config='{"include-component-in-tag":false,"packages":{".":{},"lib":{}}}'
config_case "draft" fail config="{\"draft\":true,$ok}"
config_case "tag separator" fail config="{\"tag-separator\":\"/\",$ok}"
config_case "custom label" fail config="{\"label\":\"x\",$ok}"
config_case "custom release label" fail config="{\"release-label\":\"x\",$ok}"
config_case "title pattern" fail config="{\"pull-request-title-pattern\":\"x\",$ok}"
config_case "separate pull requests" fail config="{\"separate-pull-requests\":true,$ok}"
config_case "component" fail \
  config='{"include-component-in-tag":false,"packages":{".":{"component":"c"}}}'
config_case "prerelease versioning" fail config="{\"versioning\":\"prerelease\",$ok}"
config_case "skip releases" fail config="{\"skip-github-release\":true,$ok}"
config_case "manifest version not X.Y.Z" fail version=1.2
config_case "release/v2 with version 2" ok version=2.1.0 REF=refs/heads/release/v2
config_case "release/v1 with version 2" fail version=2.1.0 REF=refs/heads/release/v1

setup
file_fixture "$CONFIG" "$SHA" "{$ok}"
file_fixture "$MANIFEST" "$SHA" '{"lib": "1.0.0"}'
run "preflight config: manifest without root" fail preflight/check-config.sh
finish
