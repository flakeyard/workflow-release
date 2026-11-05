# shellcheck shell=bash
# Tests of reconcile-pending-prs.

script=reconcile-pending-prs/run.sh

# pr NUMBER BASE VERSION [HEAD]: a pull request from HEAD, release-please's
# branch by default, merged into BASE as commit mNUMBER, where the manifest has
# VERSION.
pr() {
  local number=$1 base=$2 version=$3
  pull "$(pr_json "$number" "m$number" "${4:-}" "$base")"
  manifest "$version" "m$number"
}

# reconcile_setup: pending pull requests into main and release/v1; #8 was
# closed without merging.
reconcile_setup() {
  setup
  export BASE=main
  pending_prs '[
    {"number":5,"pull_request":{"merged_at":"x"}},
    {"number":6,"pull_request":{"merged_at":"x"}},
    {"number":8,"pull_request":{"merged_at":null}},
    {"number":9,"pull_request":{"merged_at":"x"}}
  ]'
  pr 5 main 1.2.0
  pr 6 main 1.3.0
  pr 9 release/v1 1.1.1
}

reconcile_setup
release v1.2.0
release v1.1.1
run "reconcile: relabels merged PRs into the branch whose release exists" ok "$script"
expect call "POST repos/$REPO/issues/5/labels labels[]=autorelease: tagged"
expect call "DELETE repos/$REPO/issues/5/labels/autorelease:%20pending"
order "POST repos/$REPO/issues/5" "DELETE repos/$REPO/issues/5"
expect no-call "issues/6/"
expect no-call "issues/8/"
expect no-call "issues/9/"
finish

reconcile_setup
release v1.2.0
# v1.3.0 is a draft: the API answers by tag with HTTP 404.
releases '[{"tag_name":"v1.3.0","draft":true,"prerelease":false}]'
run "reconcile: draft release" ok "$script"
expect call "POST repos/$REPO/issues/5/labels"
expect no-call "issues/6/"
finish

reconcile_setup
release v1.2.0
export FAIL_ON="DELETE repos/$REPO/issues/5/labels/autorelease:%20pending 404"
run "reconcile: pending label already removed" ok "$script"
expect call "DELETE repos/$REPO/issues/5/labels/autorelease:%20pending"
finish

reconcile_setup
release v1.2.0
export FAIL_ON="DELETE repos/$REPO/issues/5/labels/autorelease:%20pending"
run "reconcile: removing the label fails" fail "$script"
expect message "HTTP 502"
finish

reconcile_setup
release v1.2.0
export FAIL_ON="POST repos/$REPO/issues/5/labels"
run "reconcile: adding the label fails" fail "$script"
expect no-call "DELETE"
finish

reconcile_setup
fixture "repos/$REPO/releases/tags/v1.2.0" "HTTP 500"
run "reconcile: API error fails" fail "$script"
finish

setup
export BASE=main
pending_prs '[]'
run "reconcile: nothing pending" ok "$script"
expect no-calls
finish

setup
export BASE=release/v1
pending_prs '[{"number":9,"pull_request":{"merged_at":"x"}}]'
pr 9 release/v1 1.1.1
release v1.1.1
run "reconcile: release branch" ok "$script"
expect call "POST repos/$REPO/issues/9/labels"
finish

setup
export BASE=main
pending_prs '[{"number":3,"pull_request":{"merged_at":"x"}}]'
pr 3 main 1.2.0 feature
release v1.2.0
run "reconcile: pending label on a pull request from another head branch" ok "$script"
expect no-calls
finish

# The merge commit predates the manifest: the contents API answers 404.
setup
export BASE=main
pending_prs '[{"number":3,"pull_request":{"merged_at":"x"}}]'
pull "$(pr_json 3 m3)"
run "reconcile: no manifest at the merge commit" ok "$script"
expect no-calls
finish

# no_version_case NAME CONTENT [TAG]: a manifest whose root version is not
# X.Y.Z leaves the pull request pending and reaches no API path. A release of
# TAG, the tag such a version would give, exists but is never read.
no_version_case() {
  local name=$1 content=$2 tag=${3:-}
  setup
  export BASE=main
  pending_prs '[{"number":3,"pull_request":{"merged_at":"x"}}]'
  pull "$(pr_json 3 m3)"
  file_fixture "$MANIFEST" m3 "$content"
  [[ -z $tag ]] || release "$tag"
  run "reconcile: root version $name" ok "$script"
  expect no-calls
  finish
}
no_version_case "missing" '{"x": "1.2.0"}'
no_version_case "an object" '{".": {"a": 1}}'
no_version_case "a path" '{".": "../../x?y=1"}' "v../../x?y=1"
no_version_case "with a leading zero" '{".": "01.2.0"}' v01.2.0
no_version_case "in a manifest that is no JSON" 'not json'

setup
export BASE=main
pending_prs '[{"number":3,"pull_request":{"merged_at":"x"}}]'
pull "$(pr_json 3 m3)"
fixture "repos/$REPO/contents/$MANIFEST?ref=m3" "HTTP 500"
run "reconcile: API error reading the manifest fails" fail "$script"
expect message "HTTP 500"
finish
