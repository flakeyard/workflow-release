# shellcheck shell=bash
# Tests of release-scope.

script=.github/actions/release-scope/run.sh

# scope_setup PR...: the pull requests PR..., as pr_json prints them, are
# pending in main.
scope_setup() {
  local pr numbers=()
  start_test
  apply BASE=main
  for pr; do
    pull "$pr"
    numbers+=("$(jq .number <<<"$pr")")
  done
  pending_prs "$(jq -nc '[$ARGS.positional[] | {number: tonumber,
    pull_request: {merged_at: "x"}}]' --args "${numbers[@]}")"
}

# relation COMMIT STATUS: SHA has STATUS compared with COMMIT.
relation() {
  local commit=$1 status=$2
  fixture "repos/$REPO/compare/$commit...$SHA" "{\"status\":\"$status\"}"
}

scope_setup
run "release-scope: nothing pending" ok "$script"
expect errors 0
finish

scope_setup "$(pr_json 4 "$SHA")"
apply LOG_GETS=1
run "release-scope: this run's commit merged the pending pull request" ok "$script"
expect no-call "compare"
finish

# A takeover releases a pull request merged before SHA.
scope_setup "$(pr_json 5 m5)"
relation m5 ahead
run "release-scope: pending since an earlier commit" ok "$script"
finish

for status in behind diverged; do
  scope_setup "$(pr_json 4 "$SHA")" "$(pr_json 6 m6)"
  relation m6 "$status"
  run "release-scope: pending pull request merged after the commit ($status)" fail "$script"
  expect errors 1
  expect message "#6 is labelled autorelease: pending and was merged as m6, which $SHA does not contain"
  finish
done

scope_setup "$(pr_json 6 m6)" "$(pr_json 7 m7 feature)"
relation m6 behind
relation m7 behind
run "release-scope: every pull request merged after the commit is named" fail "$script"
expect errors 2
expect message "#7 is labelled"
finish

scope_setup "$(pr_json 5 m5)"
fixture "repos/$REPO/compare/m5...$SHA" "HTTP 500"
run "release-scope: an API error fails" fail "$script"
expect message "HTTP 500"
finish
