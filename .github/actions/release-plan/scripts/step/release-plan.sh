#!/usr/bin/env bash
# Decides whether the job that releases with the key is due on this push of
# SHA to BASE, writes due to GITHUB_OUTPUT and why to the job summary:
# - release: SHA merged a release pull request that is still pending;
# - takeover: an earlier one is pending, and the run of its merge commit
#   completed without releasing it;
# - repair: MOVE_MAJOR_TAG is true and vX must be created or moved forward.
# A release or repair whose approval was rejected is not due again. A pending
# release whose merge commit has no push run, or one too old to be rerun,
# fails the plan: the run of its commit could never publish it. The
# decision only saves approvals and is no security boundary: the job that
# releases derives what it does from the repository.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}"
: "${REPO:?}" "${BASE:?}" "${SHA:?}" "${RUN_ID:?}" "${MANIFEST:?}"
: "${ENVIRONMENT?}" "${MOVE_MAJOR_TAG:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "$SHELL_LIB/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0001).
lib=${0%/*}/../../../lib
# shellcheck source=../../../lib/github/pulls.sh
source "$lib/github/pulls.sh"
# shellcheck source=../../../lib/github/releases.sh
source "$lib/github/releases.sh"
# shellcheck source=../../../lib/github/runs.sh
source "$lib/github/runs.sh"
# shellcheck source=../../../lib/clock.sh
source "$lib/clock.sh"
# shellcheck source=../../../lib/major-tag.sh
source "$lib/major-tag.sh"
# shellcheck source=../../../lib/manifest.sh
source "$lib/manifest.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"

# A run can be approved and rerun for 30 days; the last day is left for that.
readonly MAX_RUN_AGE_DAYS=29 SECONDS_PER_DAY=86400
# Earlier push runs searched for the last approval request of a repair.
readonly EARLIER_RUNS=20
RELEASE_HEAD=$(release_head "$BASE")
readonly RELEASE_HEAD

due=false reason="" findings=()

# decide REASON: the job that releases is due; the first reason is reported.
decide() {
  local why=$1
  [[ $due == true ]] || reason=$why
  due=true
}

# note TEXT: report a finding of the plan in the job summary, and later as a
# notice; a job summary cannot be read through the API.
note() {
  summary "- $*"
  findings+=("$*")
}

# end_step: write the findings of note as notices, and the last annotation of
# each kind that reached the limit. It runs as the step exits, also when it
# fails. A step keeps only ANNOTATIONS_PER_KIND notices, so the findings come
# after the decision, which the limit must not hide.
end_step() {
  local finding
  for finding in "${findings[@]}"; do notice "$finding"; done
  flush
}
trap end_step EXIT

# is_branch_creation: the push created a branch, such as release/vN at a
# release; nothing is pending on a new branch.
is_branch_creation() {
  [[ ${NEW_BRANCH:-} == true ]]
}

# describe PR: print a pull request for the summary. Its title and head
# branch are chosen by others and printed as code.
describe() {
  local pr=$1 number title commit head
  number=$(jq -r .number <<<"$pr")
  title=$(jq -r .title <<<"$pr")
  commit=$(jq -r .merge_commit_sha <<<"$pr")
  head=$(jq -r .head.ref <<<"$pr")
  printf '#%s %s, merged as %s from %s\n' "$number" "$(code_span "$title")" \
    "$commit" "$(code_span "$head")"
}

# pr_tag PR: print the tag that merging PR releases, from the manifest at its
# merge commit; empty when that has no root version X.Y.Z.
pr_tag() {
  local pr=$1 commit version
  commit=$(jq -r .merge_commit_sha <<<"$pr")
  version=$(find_release_version "$commit")
  [[ -z $version ]] || printf 'v%s\n' "$version"
}

# unversioned PR: warn that the plan cannot tell what PR releases, since the
# manifest at its merge commit has no root version X.Y.Z. Such a version
# never reaches an API path or a message.
unversioned() {
  local pr=$1 number commit
  number=$(jq -r .number <<<"$pr")
  commit=$(jq -r .merge_commit_sha <<<"$pr")
  warning "#$number is pending, but $MANIFEST at its merge commit $commit has no root version X.Y.Z, so it is never due; relabel it autorelease: abandoned"
}

# find_unreleased_tag PR: set unreleased_tag to the tag that merging PR
# releases when that release does not exist yet, and to empty otherwise,
# after a warning when PR has no tag. The tag is not printed, so that the
# warning reaches the log.
find_unreleased_tag() {
  local pr=$1 tag release
  unreleased_tag=""
  tag=$(pr_tag "$pr")
  if [[ -z $tag ]]; then
    unversioned "$pr"
    return 0
  fi
  release=$(published_release "$tag")
  [[ -n $release ]] || unreleased_tag=$tag
}

# merged_here: print the pending release pull request that SHA merged into
# BASE; empty when there is none. The pull requests of the commit are read
# directly, so that a lagging index of labelled issues cannot hide it.
merged_here() {
  local prs
  prs=$(commit_pulls "$SHA")
  jq -c --arg base "$BASE" --arg head "$RELEASE_HEAD" --arg sha "$SHA" \
    --arg label "$PENDING_LABEL" '
    def pending: any(.labels[]; .name == $label);
    def release_pr: .base.ref == $base and .head.ref == $head;
    def merged_here: .merged_at != null and .merge_commit_sha == $sha;
    first(.[] | select(release_pr and pending and merged_here)) // empty' <<<"$prs"
}

# check_release: due when SHA merged a pending release pull request whose
# release does not exist yet.
check_release() {
  local pr tag
  pr=$(merged_here)
  [[ -n $pr ]] || return 0
  find_unreleased_tag "$pr"
  tag=$unreleased_tag
  [[ -n $tag ]] || return 0
  decide release
  note "release of $tag: this push merged $(describe "$pr")"
}

# in_window NUMBER WINDOW: release-please reads pull request NUMBER.
in_window() {
  local number=$1 window=$2
  grep -qx -- "$number" <<<"$window"
}

# check_pending: check the merged release pull requests into BASE that are
# still pending; WINDOW are those that release-please reads.
check_pending() {
  local prs window pr
  prs=$(pending_release_prs "$BASE")
  [[ -n $prs ]] || return 0
  window=$(merged_window "$BASE")
  while IFS= read -r pr; do
    check_pending_pr "$pr" "$window"
  done <<<"$prs"
}

# check_pending_pr PR WINDOW: check a pending pull request that SHA did not
# merge, and list it: release-please releases it too when the job that
# releases runs. One that release-please would not release only gets a
# warning, so that it does not ask for approval on every push.
check_pending_pr() {
  local pr=$1 window=$2 number commit head
  number=$(jq -r .number <<<"$pr")
  commit=$(jq -r .merge_commit_sha <<<"$pr")
  head=$(jq -r .head.ref <<<"$pr")
  [[ $commit != "$SHA" ]] || return 0
  note "also pending: $(describe "$pr")"
  if [[ $head != "$RELEASE_HEAD" ]]; then
    warning "#$number is labelled $PENDING_LABEL but is not from $RELEASE_HEAD, so it releases nothing; remove the label"
  elif ! in_window "$number" "$window"; then
    warning "#$number is pending but not among the $RELEASE_PLEASE_WINDOW merged pull requests that release-please reads, so it releases nothing; relabel it autorelease: abandoned"
  else
    check_unreleased "$pr"
  fi
}

# check_unreleased PR: check a pending release pull request whose release
# does not exist yet.
check_unreleased() {
  local pr=$1 tag commit run age
  find_unreleased_tag "$pr"
  tag=$unreleased_tag
  [[ -n $tag ]] || return 0
  commit=$(jq -r .merge_commit_sha <<<"$pr")
  run=$(commit_run "$workflow" "$BASE" "$commit")
  [[ -n $run ]] || unpublishable "$pr" "$tag" "its merge commit has no push run of this workflow"
  age=$(run_age "$run")
  ((age <= MAX_RUN_AGE_DAYS * SECONDS_PER_DAY)) \
    || unpublishable "$pr" "$tag" "the run of its merge commit is too old to be approved or rerun"
  check_merge_run "$pr" "$tag" "$run"
}

# run_age RUN: print the seconds since RUN was created.
run_age() {
  local run=$1 created
  created=$(jq -r .created_at <<<"$run")
  seconds_since "$created"
}

# unpublishable PR TAG WHY: fail, since the release of PR can never be
# published from the run of its commit. Taking over would release a commit
# whose run cannot publish it.
unpublishable() {
  local pr=$1 tag=$2 why=$3 number commit
  number=$(jq -r .number <<<"$pr")
  commit=$(jq -r .merge_commit_sha <<<"$pr")
  fail "the release of #$number at $commit can never be published from the run of its commit: $why; abandon $tag (README, Abandon)"
}

# check_merge_run PR TAG RUN: due unless RUN, the run of the merge commit of
# PR, has not completed yet (queued, in_progress, waiting, pending or
# requested), so that it releases by itself, or its release was rejected.
check_merge_run() {
  local pr=$1 tag=$2 run=$3 id url status review
  id=$(jq -r .id <<<"$run")
  url=$(jq -r .html_url <<<"$run")
  status=$(jq -r .status <<<"$run")
  if [[ $status != completed ]]; then
    note "not due: $url, the run of $(describe "$pr"), is $status and releases $tag"
    return 0
  fi
  review=$(run_review "$id" "$ENVIRONMENT")
  if [[ $review == rejected ]]; then
    note "not due: the release of $tag was rejected in $url; rerun its failed jobs to approve it, or abandon it (README, Abandon)"
    return 0
  fi
  take_over "$pr" "$tag" "$url completed without releasing it"
}

# take_over PR TAG WHY: due to release TAG for PR, whose run did not.
take_over() {
  local pr=$1 tag=$2 why=$3
  decide takeover
  note "takeover of $tag: $why; $(describe "$pr")"
}

# check_repair: due when vX of the manifest's major must be created or moved
# forward, unless the last approval request of an earlier run was rejected or
# is still waiting. A rejected repair asks again after the next release.
check_repair() {
  local version major change latest earlier
  version=$(root_version "$SHA")
  check_release_version "$version"
  major=${version%%.*}
  change=$(major_tag_change "$major")
  read -r change latest _ <<<"$change"
  [[ $change == create || $change == move ]] || return 0
  if [[ -n $ENVIRONMENT ]]; then
    earlier=$(earlier_request)
    if [[ $earlier == rejected* || $earlier == waiting* ]]; then
      note "not due: repair of v$major at $latest, since the approval of ${earlier#* } is ${earlier%% *}"
      return 0
    fi
  fi
  decide repair
  note "repair of v$major: $change it at $latest"
}

# earlier_request: print "STATE URL" of the newest of the last EARLIER_RUNS
# push runs on BASE before this one that asked for approval of ENVIRONMENT;
# STATE is waiting, approved or rejected. Empty when none of them asked.
earlier_request() {
  local runs run state url
  runs=$(branch_runs "$workflow" "$BASE" "$EARLIER_RUNS")
  runs=$(jq -c --arg started "$started" 'select(.created_at < $started)' <<<"$runs")
  while IFS= read -r run; do
    [[ -n $run ]] || continue
    state=$(request_state "$run")
    [[ -n $state ]] || continue
    url=$(jq -r .html_url <<<"$run")
    printf '%s %s\n' "$state" "$url"
    return 0
  done <<<"$runs"
}

# request_state RUN: print waiting, approved or rejected for a run that asked
# for approval of ENVIRONMENT; empty when it has not asked.
request_state() {
  local run=$1 id status
  id=$(jq -r .id <<<"$run")
  status=$(jq -r .status <<<"$run")
  if [[ $status == waiting ]]; then
    echo waiting
  elif [[ $status == completed ]]; then
    run_review "$id" "$ENVIRONMENT"
  fi
}

# write_decision: write the output due and the end of the summary.
write_decision() {
  echo "due=$due" >>"$GITHUB_OUTPUT"
  local decision="No release due."
  if [[ $due == true ]]; then decision="Due: $reason."; fi
  summary ""
  summary "$decision"
  notice "$decision"
}

summary "Release plan of $SHA on $BASE. This is a hint, not evidence:" \
  "before approving, check the repository (README, Approval)."
summary ""
if is_branch_creation; then
  note "not due: the push created $BASE"
  write_decision
  exit 0
fi
this_run=$(workflow_run "$RUN_ID")
# This run's workflow is the caller's.
workflow=$(jq -r .workflow_id <<<"$this_run")
started=$(jq -r .created_at <<<"$this_run")
check_release
# Also when due: an approval releases every pending pull request.
check_pending
if [[ $due == false && $MOVE_MAJOR_TAG == true ]]; then check_repair; fi
write_decision
