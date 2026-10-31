#!/usr/bin/env bash
# Writes released=true and the release details to GITHUB_OUTPUT when SHA is a
# published release, released=false otherwise. A release at an older commit
# that this run created, or may have created before release-please failed, is
# written as elsewhere-tag and elsewhere-sha, for the run of that commit to
# publish it.
set -euo pipefail
: "${REPO:?}" "${SHA:?}" "${MANIFEST:?}"
# shellcheck source-path=SCRIPTDIR source=../lib/github.sh
source "$(dirname "$0")/../lib/github.sh"

# A tag that release-please has just created can take a moment to be visible.
readonly TAG_ATTEMPTS=5 TAG_RETRY_SECONDS=3

# is_branch_creation: the push created a branch, such as release/vN at a
# release, and released nothing new.
is_branch_creation() {
  [[ ${NEW_BRANCH:-} == true && ${CREATED:-} != true ]]
}

# created_in_this_run TAG: release-please created TAG in this run.
created_in_this_run() {
  local tag=$1
  [[ ${CREATED:-} == true && ${CREATED_TAG:-} == "$tag" ]]
}

# release_tag_commit TAG: print the commit of TAG, empty when there is no such
# tag. A tag created in this run is tried again until it is visible.
release_tag_commit() {
  local tag=$1 attempts=1 attempt commit=""
  if created_in_this_run "$tag"; then attempts=$TAG_ATTEMPTS; fi
  for ((attempt = 1; attempt <= attempts; attempt++)); do
    ((attempt == 1)) || sleep "$TAG_RETRY_SECONDS"
    commit=$(find_tag_commit "$tag") || return 1
    [[ -z $commit ]] || break
  done
  printf '%s\n' "$commit"
}

# at_this_commit COMMIT: COMMIT is the run's commit. Only the run of a commit
# publishes its release, so that attestations name the release commit.
at_this_commit() {
  local commit=$1
  [[ $commit == "$SHA" ]]
}

# write_elsewhere TAG COMMIT CREATED: write the release TAG at another commit;
# CREATED is true when release-please reported creating it in this run.
write_elsewhere() {
  local tag=$1 commit=$2 created=$3
  {
    echo "elsewhere-tag=$tag"
    echo "elsewhere-sha=$commit"
    echo "elsewhere-created=$created"
  } >>"$GITHUB_OUTPUT"
}

# report_elsewhere TAG COMMIT: when this run created TAG at COMMIT, an older
# commit, or may have done so before release-please failed, write it for the
# run of COMMIT to publish. A run that waited in the queue releases an older
# commit.
report_elsewhere() {
  local tag=$1 commit=$2
  if created_in_this_run "$tag"; then
    echo "::notice::$tag was released at $commit, not at $SHA; the run of $commit publishes it"
    write_elsewhere "$tag" "$commit" true
  elif [[ ${RELEASE_FAILED:-} == true ]]; then
    echo "::notice::$tag exists at $commit; if this run released it before" \
      "release-please failed, the run of $commit publishes it"
    write_elsewhere "$tag" "$commit" false
  fi
}

# state_json VERSION COMMIT RELEASE: print the output, one JSON object with
# string fields; all of them empty but released=false when VERSION is empty.
state_json() {
  local version=$1 commit=$2 release=$3 released=false major minor patch
  if [[ -n $version ]]; then released=true; fi
  IFS=. read -r major minor patch <<<"$version"
  jq -nc --arg released "$released" \
    --arg tag "${version:+v$version}" --arg version "$version" \
    --arg major "$major" --arg minor "$minor" --arg patch "$patch" \
    --arg prerelease "$(jq -r '.prerelease | values' <<<"$release")" \
    --arg sha "$commit" --arg release-url "$(jq -r '.html_url | values' <<<"$release")" \
    '$ARGS.named'
}

version=$(root_version "$SHA")
check_release_version "$version"
tag=v$version
commit=""

if is_branch_creation; then
  echo "::notice::branch created at $SHA; not a new release"
else
  commit=$(release_tag_commit "$tag")
  if [[ -z $commit ]] && created_in_this_run "$tag"; then
    fail "release-please created $tag, but the tag does not exist"
  fi
fi

if [[ -n $commit ]] && at_this_commit "$commit"; then
  release=$(published_release "$tag")
  [[ -n $release ]] || fail "tag $tag exists but has no published release"
  state=$(state_json "$version" "$commit" "$release")
  released=true
else
  if [[ -n $commit ]]; then report_elsewhere "$tag" "$commit"; fi
  state=$(state_json "" "" "")
  released=false
fi
echo "state=$state" >>"$GITHUB_OUTPUT"
summary "manifest $version, released: $released"
