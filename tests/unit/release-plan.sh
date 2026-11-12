# shellcheck shell=bash
# Tests of release-plan.

step=release-plan
# This run was created a minute before now; the merge run of a pending pull
# request a day and a half before, unless a test says otherwise.
now=2026-11-02T12:00:00Z this_run_created=2026-11-02T11:59:00Z
merged=$MERGED_AT
# More than 29 days before now, and exactly 28 days before now.
too_old=2026-10-03T11:00:00Z still_young=2026-10-05T12:00:00Z
head=$(release_branch main)

branch_runs_path="repos/o/r/actions/workflows/5/runs?branch=main&event=push&per_page=20"
# The first page of the window, newest created first like release-please
# reads it; ${window_path%1}N is page N.
window_path="repos/o/r/pulls?state=closed&base=main&sort=created&direction=desc&per_page=100&page=1"

# pending PR...: these pull requests are pending, in release-please's window,
# and release 1.3.0 at their merge commits.
pending() {
  local pr numbers=() number commit
  for pr; do
    number=$(jq .number <<<"$pr")
    commit=$(jq -r .merge_commit_sha <<<"$pr")
    numbers+=("$number")
    pull "$pr"
    manifest 1.3.0 "$commit"
  done
  pending_prs "$(jq -nc '[$ARGS.positional[] | {number: tonumber,
    pull_request: {merged_at: "x"}}]' --args "${numbers[@]}")"
  fixture "$window_path" "$(jq -nc '[$ARGS.positional[] | {number: tonumber,
    merged_at: "x"}]' --args "${numbers[@]}")"
}

# merge_run COMMIT STATUS [CREATED]: run 77 is the push run of COMMIT, and
# nobody reviewed it.
merge_run() {
  local commit=$1 status=$2 created=${3:-$merged}
  fixture "$(commit_runs_path main "$commit")" "{\"workflow_runs\":[{\"id\":77,
    \"status\":\"$status\",\"created_at\":\"$created\",\"html_url\":\"https://x/runs/77\"}]}"
  reviews 77
}

# reviews ID [ENVIRONMENT:STATE...]: the reviews of run ID, in API order.
reviews() {
  local id=$1
  shift
  fixture "repos/$REPO/actions/runs/$id/approvals" "$(jq -nc '[$ARGS.positional[]
    | split(":") | {state: .[1], environments: [{name: .[0]}]}]' --args "$@")"
}

# plan_setup [NAME=VALUE...]: run 100 of workflow 5 on main, gated by the
# environment release, with nothing pending; the values override that.
plan_setup() {
  start_test
  apply BASE=main RUN_ID=100 ENVIRONMENT=release MOVE_MAJOR_TAG=false
  fixed_time "$now"
  apply "$@"
  fixture "repos/$REPO/actions/runs/100" \
    "{\"id\":100,\"workflow_id\":5,\"created_at\":\"$this_run_created\"}"
  fixture "repos/$REPO/commits/$SHA/pulls" '[]'
  pending_prs '[]'
  manifest 1.2.3
}

# expect_due DUE [REASON]: the decision of the last run, and its REASON when
# it is due.
expect_due() {
  expect output due "$1"
  [[ $1 != true ]] || expect message "::notice::Due: $2."
}

# takeover_setup [NAME=VALUE...]: #5 merged as m5 is pending, and its run 77
# completed without a review.
takeover_setup() {
  plan_setup "$@"
  pending "$(pr_json 5 m5)"
  merge_run m5 completed
}

# repair_setup [NAME=VALUE...]: v1 is behind the newest release v1.2.3, and the
# earlier run 90 was approved.
repair_setup() {
  plan_setup MOVE_MAJOR_TAG=true "$@"
  releases '[{"tag_name":"v1.2.3","draft":false,"prerelease":false}]'
  tag v1.2.3 c123
  tag v1 c122
  fixture "repos/$REPO/compare/c122...c123" '{"status":"ahead"}'
  earlier_runs '{"id":90,"status":"completed"}'
  reviews 90 release:approved
}

# earlier_runs RUN...: the newest push runs on main after this run 100, each
# created a minute earlier than the one before.
earlier_runs() {
  fixture "$branch_runs_path" "$(jq -nc --arg now "$this_run_created" '
    [{id: 100, status: "in_progress", created_at: $now}] + ([$ARGS.positional[]
    | fromjson] | to_entries | map(.value + {html_url: "https://x/runs/\(.value.id)",
    created_at: "2026-11-02T11:\(58 - .key):00Z"}))
    | {workflow_runs: .}' --args "$@")"
}

plan_setup
run_step "release-plan: nothing pending" ok "$ACTIONS/$step" "$step"
expect_due false
expect message "::notice::No release due."
finish

plan_setup
fixture "repos/$REPO/commits/$SHA/pulls" "[$(pr_json 4 "$SHA")]"
manifest 1.3.0
run_step "release-plan: this push merged a pending release pull request" ok "$ACTIONS/$step" "$step"
expect_due true release
finish

# An approval releases every pending pull request, so the plan lists the
# others also when this push is due.
plan_setup
fixture "repos/$REPO/commits/$SHA/pulls" "[$(pr_json 4 "$SHA")]"
manifest 1.3.0
pending "$(pr_json 4 "$SHA")" "$(pr_json 5 m5)"
manifest 1.2.4 m5
merge_run m5 in_progress
run_step "release-plan: lists the other pending pull requests when due" ok "$ACTIONS/$step" "$step"
expect_due true release
expect summary "- also pending: #5 \`chore(main): release\`, merged as m5"
expect no-message "also pending: #4"
finish

# An approval would also release #5, whose run can never publish it.
plan_setup
fixture "repos/$REPO/commits/$SHA/pulls" "[$(pr_json 4 "$SHA")]"
manifest 1.3.0
pending "$(pr_json 4 "$SHA")" "$(pr_json 5 m5)"
manifest 1.2.4 m5
fixture "$(commit_runs_path main m5)" '{"workflow_runs":[]}'
run_step "release-plan: due, but another pending release is unpublishable" fail "$ACTIONS/$step" "$step"
expect message "the release of #5 at m5 can never be published"
finish

plan_setup
fixture "repos/$REPO/commits/$SHA/pulls" "[$(pr_json 4 "$SHA" "$head" release/v1)]"
run_step "release-plan: merged into another branch" ok "$ACTIONS/$step" "$step"
expect_due false
finish

plan_setup
fixture "repos/$REPO/commits/$SHA/pulls" "[$(pr_json 4 "$SHA" feature)]"
run_step "release-plan: merged from another head branch" ok "$ACTIONS/$step" "$step"
expect_due false
finish

plan_setup
fixture "repos/$REPO/commits/$SHA/pulls" "[$(pr_json 4 "$SHA")]"
release v1.2.3
run_step "release-plan: merged, and its release exists" ok "$ACTIONS/$step" "$step"
expect_due false
finish

takeover_setup
release v1.3.0
run_step "release-plan: pending with its release" ok "$ACTIONS/$step" "$step"
expect_due false
finish

plan_setup
pending "$(pr_json 5 m5 feature)"
run_step "release-plan: pending from a foreign head branch" ok "$ACTIONS/$step" "$step"
expect_due false
expect message "::warning::#5 is labelled autorelease: pending but is not from $head"
finish

# unversioned_case NAME CONTENT [TAG]: the manifest at the merge commit of
# the pending #5 has no root version X.Y.Z; a release of TAG, the tag such a
# version would give, exists but is never read.
unversioned_case() {
  local name=$1 content=$2 tag=${3:-}
  takeover_setup
  file_fixture "$REPO" "$MANIFEST" m5 "$content"
  [[ -z $tag ]] || fixture "repos/$REPO/releases/tags/$tag" "HTTP 500"
  run_step "release-plan: pending with a root version $name" ok "$ACTIONS/$step" "$step"
  expect_due false
  expect message "::warning::#5 is pending, but $MANIFEST at its merge commit m5 has no root version X.Y.Z"
  finish
}
unversioned_case "missing" '{"x": "1.3.0"}'
unversioned_case "that is an object" '{".": {"a": 1}}'
unversioned_case "that is a path" '{".": "../../x?y=1"}' "v../../x?y=1"
unversioned_case "with a leading zero" '{".": "08.0.0"}' v08.0.0
unversioned_case "in a manifest that is no JSON" 'not json'

# The merge commit predates the manifest: the contents API answers 404.
takeover_setup
rm -- "$(fixture_file "repos/$REPO/contents/$MANIFEST?ref=m5")"
run_step "release-plan: pending without a manifest at its merge commit" ok "$ACTIONS/$step" "$step"
expect_due false
expect message "has no root version X.Y.Z, so it is never due"
finish

plan_setup
fixture "repos/$REPO/commits/$SHA/pulls" "[$(pr_json 4 "$SHA")]"
manifest 01.3.0
run_step "release-plan: merged with a root version that is not X.Y.Z" ok "$ACTIONS/$step" "$step"
expect_due false
expect message "::warning::#4 is pending, but $MANIFEST at its merge commit $SHA has no root version X.Y.Z"
finish

plan_setup
pending "$(pr_json 5 m5)"
fixture "$window_path" '[{"number":6,"merged_at":"x"}]'
run_step "release-plan: pending beyond release-please's window" ok "$ACTIONS/$step" "$step"
expect_due false
expect message "::warning::#5 is pending but not among the 200 merged pull requests"
finish

plan_setup
pending "$(pr_json 5 m5)"
fixture "$window_path" "$(jq -nc '[range(100) | {number: (1000 + .), merged_at: "x"}]')"
fixture "${window_path%1}2" '[{"number":7,"merged_at":null},{"number":5,"merged_at":"x"}]'
merge_run m5 completed
run_step "release-plan: pending on the second page of the window" ok "$ACTIONS/$step" "$step"
expect_due true takeover
finish

plan_setup
pending "$(pr_json 5 m5)"
fixture "$window_path" "$(jq -nc '[range(100) | {number: (1000 + .), merged_at: "x"}]')"
fixture "${window_path%1}2" "$(jq -nc '[range(100) | {number: (2000 + .), merged_at: "x"}]')"
fixture "${window_path%1}3" '[{"number":5,"merged_at":"x"}]'
run_step "release-plan: the window ends after 200 merged pull requests" ok "$ACTIONS/$step" "$step"
expect_due false
expect message "not among the 200"
finish

for status in queued in_progress waiting pending requested; do
  takeover_setup
  merge_run m5 "$status"
  run_step "release-plan: the merge run is $status" ok "$ACTIONS/$step" "$step"
  expect_due false
  finish
done

# Twelve pending pull requests whose runs are still running: two findings
# each, more than a step keeps as notices.
plan_setup
prs=()
for number in {11..22}; do prs+=("$(pr_json "$number" "m$number")"); done
pending "${prs[@]}"
for number in {11..22}; do merge_run "m$number" in_progress; done
run_step "release-plan: the limit of notices does not hide the decision" ok "$ACTIONS/$step" "$step"
expect_due false
expect_first_notice "No release due."
expect message "::notice::16 more notices are not shown here."
finish

takeover_setup
run_step "release-plan: the merge run completed without a review" ok "$ACTIONS/$step" "$step"
expect_due true takeover
expect message "::notice::takeover of v1.3.0: https://x/runs/77 completed without releasing it;"
expect message "::notice::Due: takeover."
finish

takeover_setup
reviews 77 release:approved
run_step "release-plan: the merge run failed after the approval" ok "$ACTIONS/$step" "$step"
expect_due true takeover
finish

for environment in release ""; do
  takeover_setup ENVIRONMENT="$environment"
  fixture "$(commit_runs_path main m5)" '{"workflow_runs":[]}'
  run_step "release-plan: the merge commit has no run (environment '$environment')" fail "$ACTIONS/$step" "$step"
  expect message "the release of #5 at m5 can never be published from the run of its commit: its merge commit has no push run of this workflow; abandon v1.3.0 (README, Abandon)"
  expect output due ""
  finish
done

takeover_setup
reviews 77 release:rejected
run_step "release-plan: the release was rejected" ok "$ACTIONS/$step" "$step"
expect_due false
expect message "::notice::not due: the release of v1.3.0 was rejected in https://x/runs/77"
finish

takeover_setup
reviews 77 release:approved release:rejected
run_step "release-plan: the last review rejected the release" ok "$ACTIONS/$step" "$step"
expect_due false
finish

takeover_setup
reviews 77 release:rejected release:approved
run_step "release-plan: the last review approved the release" ok "$ACTIONS/$step" "$step"
expect_due true takeover
finish

takeover_setup
reviews 77 other:rejected
run_step "release-plan: a rejection of another environment" ok "$ACTIONS/$step" "$step"
expect_due true takeover
finish

for environment in release ""; do
  takeover_setup ENVIRONMENT="$environment"
  merge_run m5 completed "$too_old"
  run_step "release-plan: the merge run is too old (environment '$environment')" fail "$ACTIONS/$step" "$step"
  expect message "the release of #5 at m5 can never be published from the run of its commit: the run of its merge commit is too old to be approved or rerun; abandon v1.3.0 (README, Abandon)"
  finish
done

takeover_setup
merge_run m5 waiting "$too_old"
run_step "release-plan: a waiting merge run that is too old" fail "$ACTIONS/$step" "$step"
expect message "abandon v1.3.0"
finish

takeover_setup
merge_run m5 completed "$still_young"
run_step "release-plan: the merge run is 28 days old" ok "$ACTIONS/$step" "$step"
expect_due true takeover
finish

plan_setup NEW_BRANCH=true
fixture "repos/$REPO/actions/runs/100" "HTTP 500"
run_step "release-plan: branch creation" ok "$ACTIONS/$step" "$step"
expect_due false
finish

takeover_setup ENVIRONMENT=""
run_step "release-plan: without an environment, due is reported" ok "$ACTIONS/$step" "$step"
expect_due true takeover
finish

plan_setup
# shellcheck disable=SC2016 # the backticks are part of the title
title='release [x](https://e) **b** `c`'
fixture "repos/$REPO/commits/$SHA/pulls" "[$(pr_json 4 "$SHA" "$head" main "$merged" "$title")]"
manifest 1.3.0
run_step "release-plan: a title is printed as code" ok "$ACTIONS/$step" "$step"
expect_due true release
expect summary "#4 \`release [x](https://e) **b** 'c'\`"
finish

repair_setup
run_step "release-plan: v1 is behind the newest release" ok "$ACTIONS/$step" "$step"
expect_due true repair
finish

repair_setup
rm -- "$(fixture_file "repos/$REPO/git/ref/tags/v1")"
run_step "release-plan: v1 is missing" ok "$ACTIONS/$step" "$step"
expect_due true repair
finish

for relation in behind diverged; do
  repair_setup
  fixture "repos/$REPO/compare/c122...c123" "{\"status\":\"$relation\"}"
  run_step "release-plan: v1 is $relation, no repair" ok "$ACTIONS/$step" "$step"
  expect_due false
  finish
done

repair_setup
tag v1 c123
run_step "release-plan: v1 is in place" ok "$ACTIONS/$step" "$step"
expect_due false
finish

repair_setup MOVE_MAJOR_TAG=false
run_step "release-plan: v1 is not moved" ok "$ACTIONS/$step" "$step"
expect_due false
finish

repair_setup
reviews 90 release:rejected
run_step "release-plan: repair after a rejected run" ok "$ACTIONS/$step" "$step"
expect_due false
finish

repair_setup
earlier_runs '{"id":91,"status":"completed"}' '{"id":92,"status":"in_progress"}' \
  '{"id":90,"status":"completed"}'
reviews 91
reviews 90 release:rejected
run_step "release-plan: repair after runs that asked nothing since a rejection" ok "$ACTIONS/$step" "$step"
expect_due false
finish

repair_setup
earlier_runs '{"id":90,"status":"waiting"}'
run_step "release-plan: repair while an earlier run waits for approval" ok "$ACTIONS/$step" "$step"
expect_due false
finish

repair_setup
earlier_runs '{"id":91,"status":"completed"}'
reviews 91
run_step "release-plan: repair when no earlier run asked" ok "$ACTIONS/$step" "$step"
expect_due true repair
finish

repair_setup ENVIRONMENT=""
fixture "$branch_runs_path" "HTTP 500"
run_step "release-plan: repair without an environment reads no approvals" ok "$ACTIONS/$step" "$step"
expect_due true repair
finish

takeover_setup MOVE_MAJOR_TAG=true
fixture "repos/$REPO/contents/$MANIFEST?ref=$SHA" "HTTP 500"
run_step "release-plan: a takeover is not checked for a repair" ok "$ACTIONS/$step" "$step"
expect_due true takeover
finish

# A failure after a finding still writes the finding as a notice.
plan_setup MOVE_MAJOR_TAG=true
pending "$(pr_json 5 m5)"
merge_run m5 in_progress
manifest 1.2
run_step "release-plan: a failure writes the findings before it" fail "$ACTIONS/$step" "$step"
expect message "the root version must be X.Y.Z, not '1.2'"
expect message "::notice::not due: https://x/runs/77, the run of #5"
finish

plan_setup MOVE_MAJOR_TAG=true
rm -- "$(fixture_file "repos/$REPO/contents/$MANIFEST?ref=$SHA")"
run_step "release-plan: a missing manifest is named" fail "$ACTIONS/$step" "$step"
expect message "$MANIFEST does not exist at $SHA"
finish

# api_error_case SETUP PATH: an HTTP 500 of GET PATH fails the plan.
api_error_case() {
  local setup=$1 path=$2
  "$setup"
  fixture "$path" "HTTP 500"
  run_step "release-plan: HTTP 500 of $path fails" fail "$ACTIONS/$step" "$step"
  expect message "HTTP 500"
  finish
}
for path in "repos/o/r/actions/runs/100" "repos/o/r/commits/aaa/pulls" \
  "$(pending_path)" "repos/o/r/pulls/5" "$window_path" \
  "repos/o/r/contents/.release-please-manifest.json?ref=m5" \
  "repos/o/r/releases/tags/v1.3.0" "$(commit_runs_path main m5)" \
  "repos/o/r/actions/runs/77/approvals"; do
  api_error_case takeover_setup "$path"
done
for path in "repos/o/r/contents/.release-please-manifest.json?ref=aaa" \
  "repos/o/r/releases?per_page=100" "repos/o/r/git/ref/tags/v1.2.3" \
  "repos/o/r/git/ref/tags/v1" "repos/o/r/compare/c122...c123" \
  "$branch_runs_path" "repos/o/r/actions/runs/90/approvals"; do
  api_error_case repair_setup "$path"
done

takeover_setup
run_hostile "release-plan: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect_due true takeover
expect summary "Release plan of $SHA on main."
finish
