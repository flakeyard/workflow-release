#!/usr/bin/env bash
# Writes released=true and the release details to GITHUB_OUTPUT when SHA is a
# published release, released=false otherwise.
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

# releases_this_run TAG COMMIT: TAG at COMMIT is the release of this run,
# either at its commit or created by it. A run that waited in the queue
# releases an older commit.
releases_this_run() {
  local tag=$1 commit=$2
  [[ $commit == "$SHA" ]] || created_in_this_run "$tag"
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

if [[ -n $commit ]] && releases_this_run "$tag" "$commit"; then
  if [[ $commit != "$SHA" ]]; then
    echo "::notice::$tag was released at $commit, not at $SHA"
  fi
  release=$(published_release "$tag")
  [[ -n $release ]] || fail "tag $tag exists but has no published release"
  state=$(state_json "$version" "$commit" "$release")
  released=true
else
  if [[ -n $commit && ${RELEASE_FAILED:-} == true ]]; then
    echo "::warning::$tag exists at $commit; if it was released by this run" \
      "before release-please failed, rerun the run of $commit to publish it"
  fi
  state=$(state_json "" "" "")
  released=false
fi
echo "state=$state" >>"$GITHUB_OUTPUT"
summary "manifest $version, released: $released"
