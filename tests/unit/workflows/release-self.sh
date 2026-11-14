# shellcheck shell=bash
# shellcheck disable=SC2016 # jq expressions, not expansions.
# Static tests of the release of this repository: its release pull requests,
# opened with GITHUB_TOKEN, are checked by a dispatched run of test.yaml.

# self_test NAME FILTER: FILTER is true of release-self.yaml.
self_test() { workflow_check "${self_workflow}" "release-self.yaml: $1" "$2"; }

if require_yq .github/workflows/release-self.yaml; then
  self_workflow=$(load_workflow release-self.yaml)
  self_test "release pull requests are opened with GITHUB_TOKEN" \
    '.jobs.release.with["app-pull-requests"] == false'
  self_test "release pull requests are checked by test.yaml" \
    '.jobs.release.with["check-workflow"] == "test.yaml"'
fi
