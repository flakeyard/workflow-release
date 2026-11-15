#!/usr/bin/env bash
# Writes released=true and the release details to GITHUB_OUTPUT when SHA is a
# published release, released=false otherwise. A release at an older commit
# that this run created, or may have created before release-please failed, is
# written as elsewhere-tag and elsewhere-sha, for the run of that commit to
# publish it; also when its tag is not the one of the manifest at SHA.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}"
: "${REPO:?}" "${SHA:?}" "${MANIFEST:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "${SHELL_LIB}/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0001).
lib=${0%/*}/../../../lib
# shellcheck source=../../../lib/github/releases.sh
source "${lib}/github/releases.sh"
# shellcheck source=../../../lib/github/tags.sh
source "${lib}/github/tags.sh"
# shellcheck source=../../../lib/manifest.sh
source "${lib}/manifest.sh"
# shellcheck source=/dev/null
source "${SHELL_LIB}/report.sh"

# A tag that release-please has just created can take a moment to be visible.
readonly TAG_ATTEMPTS=5 TAG_RETRY_SECONDS=3

# The tag that release-please created in this run; empty when it created
# none. Tags of releases are never empty, so TAG == created_tag means that
# release-please created TAG in this run.
created_tag=""
if [[ ${CREATED:-} == true ]]; then created_tag=${CREATED_TAG:-}; fi
readonly created_tag

# release_tag_commit TAG: print the commit of TAG, empty when there is no such
# tag. A tag created in this run is tried again until it is visible.
release_tag_commit() {
  local tag=$1 attempts=1 attempt commit=""
  if [[ ${tag} == "${created_tag}" ]]; then attempts=${TAG_ATTEMPTS}; fi
  for ((attempt = 1; attempt <= attempts; attempt++)); do
    ((attempt == 1)) || sleep "${TAG_RETRY_SECONDS}"
    commit=$(find_tag_commit "${tag}")
    [[ -z ${commit} ]] || break
  done
  printf '%s\n' "${commit}"
}

# write_elsewhere TAG COMMIT CREATED: write the release TAG at another commit;
# CREATED is true when release-please reported creating it in this run.
write_elsewhere() {
  local tag=$1 commit=$2 created=$3
  {
    echo "elsewhere-tag=${tag}"
    echo "elsewhere-sha=${commit}"
    echo "elsewhere-created=${created}"
  } >>"${GITHUB_OUTPUT}"
}

# report_elsewhere TAG COMMIT: when this run created TAG at COMMIT, an older
# commit, or may have done so before release-please failed, write it for the
# run of COMMIT to publish. A run that waited in the queue releases an older
# commit.
report_elsewhere() {
  local tag=$1 commit=$2
  if [[ ${tag} == "${created_tag}" ]]; then
    notice "${tag} was released at ${commit}, not at ${SHA}; the run of ${commit} publishes it"
    write_elsewhere "${tag}" "${commit}" true
  elif [[ ${RELEASE_FAILED:-} == true ]]; then
    notice "${tag} exists at ${commit}; if this run released it before release-please failed, the run of ${commit} publishes it"
    write_elsewhere "${tag}" "${commit}" false
  fi
}

# report_created_elsewhere: write the tag that release-please created in this
# run, not the tag of the manifest at SHA, for the run of its commit to publish.
report_created_elsewhere() {
  local commit
  is_release_tag "${CREATED_TAG}" || fail "release-please created '${CREATED_TAG}', not a tag vX.Y.Z"
  commit=$(release_tag_commit "${CREATED_TAG}")
  [[ -n ${commit} ]] || fail "release-please created ${CREATED_TAG}, but the tag does not exist"
  [[ ${commit} != "${SHA}" ]] \
    || fail "release-please created ${CREATED_TAG} at ${SHA}, whose manifest has ${version}"
  report_elsewhere "${CREATED_TAG}" "${commit}"
}

# state_json VERSION COMMIT RELEASE: print the output, one JSON object with
# string fields; all of them empty but released=false when VERSION is empty.
state_json() {
  local version=$1 commit=$2 release=$3 released=false major minor patch prerelease url
  if [[ -n ${version} ]]; then released=true; fi
  IFS=. read -r major minor patch <<<"${version}"
  prerelease=$(jq -r '.prerelease | values' <<<"${release}")
  url=$(jq -r '.html_url | values' <<<"${release}")
  jq -nc --arg released "${released}" \
    --arg tag "${version:+v${version}}" --arg version "${version}" \
    --arg major "${major}" --arg minor "${minor}" --arg patch "${patch}" \
    --arg prerelease "${prerelease}" --arg sha "${commit}" --arg release-url "${url}" \
    '$ARGS.named'
}

version=$(root_version "${SHA}")
check_release_version "${version}"
tag=v${version}
commit=""

# The push created a branch, such as release/vN at a release, and released
# nothing new.
if [[ ${NEW_BRANCH:-} == true && ${CREATED:-} != true ]]; then
  notice "branch created at ${SHA}; not a new release"
else
  commit=$(release_tag_commit "${tag}")
  if [[ -z ${commit} && ${tag} == "${created_tag}" ]]; then
    fail "release-please created ${tag}, but the tag does not exist"
  fi
fi

# Only the run of a commit publishes its release, so that attestations name
# the release commit.
if [[ -n ${commit} && ${commit} == "${SHA}" ]]; then
  release=$(published_release "${tag}")
  [[ -n ${release} ]] || fail "tag ${tag} exists but has no published release"
  state=$(state_json "${version}" "${commit}" "${release}")
  released=true
else
  state=$(state_json "" "" "")
  released=false
fi
# release-please created a tag in this run that is not the tag of the
# manifest at SHA: a takeover releases the version of an older merge commit,
# which a later commit, such as a revert, may have changed.
if [[ -n ${created_tag} && ${created_tag} != "${tag}" ]]; then
  report_created_elsewhere
elif [[ -n ${commit} && ${commit} != "${SHA}" ]]; then
  report_elsewhere "${tag}" "${commit}"
fi
echo "state=${state}" >>"${GITHUB_OUTPUT}"
summary "manifest ${version}, released: ${released}"
