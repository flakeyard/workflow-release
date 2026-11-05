#!/usr/bin/env bash
# Reruns the push run of COMMIT on BRANCH, the commit of the release TAG that
# this run created at an older commit, so that a run at the release commit
# publishes TAG: attestations name the commit of the run as the source. Unless
# CREATED is true, release-please failed in this run, and TAG counts as created
# by it only when it was published after this run first started.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
: "${REPO:?}" "${RUN_ID:?}" "${BRANCH:?}" "${TAG:?}" "${COMMIT:?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/github/api.sh
source "$lib/github/api.sh"
# shellcheck source=../lib/github/releases.sh
source "$lib/github/releases.sh"
# shellcheck source=../lib/github/runs.sh
source "$lib/github/runs.sh"
# shellcheck source=../lib/report.sh
source "$lib/report.sh"

# A run of the release commit that is still running is waited for this long.
readonly WAIT_ATTEMPTS=40 WAIT_SECONDS=15
# What to do when the run of the release commit cannot publish TAG.
readonly CANNOT_PUBLISH="$TAG is released but the run of its commit cannot publish it; cut the next patch release"

# this_run_started: print when the first attempt of this run started.
this_run_started() {
  api_get "$(run_path "$RUN_ID")/attempts/1" | jq -r .run_started_at
}

# published_at TAG: print when the release of TAG was published; empty when
# there is no published release.
published_at() {
  local tag=$1
  published_release "$tag" | jq -r '.published_at // empty'
}

# require_created_by_this_run: exit unless release-please created TAG in this
# run or TAG was published after this run first started. Timestamps of the API
# are UTC in one format and compare as strings.
require_created_by_this_run() {
  [[ ${CREATED:-} != true ]] || return 0
  local published started
  published=$(published_at "$TAG")
  started=$(this_run_started)
  if [[ -z $published || $published < "$started" ]]; then
    summary "$TAG was not published by this run; nothing to rerun"
    exit 0
  fi
}

# wait_until_completed ID URL: wait for a run to complete, since only a
# completed run can be rerun; fail when it is still running at the end.
wait_until_completed() {
  local id=$1 url=$2 attempt status
  for ((attempt = 1; attempt <= WAIT_ATTEMPTS; attempt++)); do
    ((attempt == 1)) || sleep "$WAIT_SECONDS"
    status=$(api_get "$(run_path "$id")" | jq -r .status)
    [[ $status != completed ]] || return 0
  done
  fail "$url, the run of $COMMIT, is still running; when it completes, rerun it to publish $TAG"
}

# rerun ID URL: rerun all jobs of a completed run; its publishing jobs were
# skipped, not failed.
rerun() {
  local id=$1 url=$2
  api_request POST "$(run_path "$id")/rerun" >/dev/null \
    || fail "could not rerun $url, the run of $COMMIT (runs can be rerun for 30 days); rerun it, or if it cannot be rerun: $CANNOT_PUBLISH"
}

require_created_by_this_run
# This run's workflow is the caller's.
workflow=$(workflow_id "$RUN_ID")
run=$(commit_run "$workflow" "$BRANCH" "$COMMIT")
[[ -n $run ]] \
  || fail "no push run of this workflow at $COMMIT on $BRANCH: $CANNOT_PUBLISH"
id=$(jq -r .id <<<"$run")
url=$(jq -r .html_url <<<"$run")
wait_until_completed "$id" "$url"
rerun "$id" "$url"
notice "reran $url, the run of $COMMIT, to publish $TAG"
summary "reran $url to publish $TAG"
