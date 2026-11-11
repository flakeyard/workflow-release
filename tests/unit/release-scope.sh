# shellcheck shell=bash
# Tests of release-scope.

script=.github/actions/release-scope/run.sh

# scope_setup PR...: the pull requests PR..., as pr_json prints them, are
# pending in main, whose head is SHA.
scope_setup() {
  local pr numbers=()
  start_test
  apply BASE=main
  head_at "$SHA"
  for pr; do
    pull "$pr"
    numbers+=("$(jq .number <<<"$pr")")
  done
  pending_prs "$(jq -nc '[$ARGS.positional[] | {number: tonumber,
    pull_request: {merged_at: "x"}}]' --args "${numbers[@]}")"
}

# head_at COMMIT: the head of main is COMMIT.
head_at() {
  local commit=$1
  fixture "repos/$REPO/git/ref/heads/main" "{\"object\":{\"sha\":\"$commit\"}}"
}

# config_at REF CONTENT VERSION: the configuration CONTENT and the manifest
# with VERSION at REF.
config_at() {
  local ref=$1 content=$2 version=$3
  file_fixture "$REPO" "$CONFIG" "$ref" "$content"
  manifest "$version" "$ref"
}

# moved_head_setup: #5 is pending since m5, and the head of main moved on to
# h1; the configuration and the manifest at SHA are given.
moved_head_setup() {
  scope_setup "$(pr_json 5 m5)"
  relation m5 ahead
  head_at h1
  config_at "$SHA" '{"packages":{".":{}}}' 1.3.0
}

# relation COMMIT STATUS: SHA has STATUS compared with COMMIT.
relation() {
  local commit=$1 status=$2
  fixture "repos/$REPO/compare/$commit...$SHA" "{\"status\":\"$status\"}"
}

scope_setup
apply LOG_GETS=1
run "release-scope: nothing pending" ok "$script"
expect errors 0
expect no-call "git/ref/heads"
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

moved_head_setup
config_at h1 '{"packages":{".":{}}}' 1.3.0
run "release-scope: the head moved on, with the same configuration" ok "$script"
expect errors 0
finish

moved_head_setup
config_at h1 '{"packages":{".":{"release-as":"9.0.0"}}}' 1.3.0
run "release-scope: the configuration changed at the head" fail "$script"
expect errors 1
expect message "::error file=$CONFIG::$CONFIG at h1, the head of main, is not the one at $SHA"
finish

moved_head_setup
config_at h1 '{"packages":{".":{}}}' 1.4.0
run "release-scope: the manifest changed at the head" fail "$script"
expect errors 1
expect message "::error file=$MANIFEST::$MANIFEST at h1"
finish

moved_head_setup
manifest 1.3.0 h1
run "release-scope: no configuration at the head" fail "$script"
expect message "$CONFIG does not exist at h1"
finish

moved_head_setup
fixture "repos/$REPO/git/ref/heads/main" "HTTP 500"
run "release-scope: an API error reading the head fails" fail "$script"
expect message "HTTP 500"
finish
