# shellcheck shell=bash
# Tests of preflight: the release-please configuration.

script=preflight/config.sh

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
  run "preflight config: $name" "$expected" "$script"
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
run "preflight config: manifest without root" fail "$script"
finish
