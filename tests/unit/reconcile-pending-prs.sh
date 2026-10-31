# shellcheck shell=bash
# Tests of reconcile-pending-prs.

script=reconcile-pending-prs/run.sh

# pending_prs BODY: the closed pull requests labelled pending.
pending_prs() {
  fixture "repos/$REPO/issues?state=closed&labels=autorelease:%20pending&per_page=100" "$1"
}

# pr NUMBER BASE VERSION: a pull request merged into BASE as commit mNUMBER,
# where the manifest has VERSION.
pr() {
  local number=$1 base=$2 version=$3
  fixture "repos/$REPO/pulls/$number" \
    "{\"base\":{\"ref\":\"$base\"},\"merge_commit_sha\":\"m$number\"}"
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
