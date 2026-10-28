#!/usr/bin/env bash
# Writes released=true and the release details to GITHUB_OUTPUT when SHA is a
# published release, released=false otherwise.
set -euo pipefail
: "${REPO:?}" "${SHA:?}" "${MANIFEST:?}"
# shellcheck source-path=SCRIPTDIR source=../lib/github.sh
source "$(dirname "$0")/../lib/github.sh"

version=$(manifest_version "$MANIFEST" "$SHA")
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error file=$MANIFEST::the root version must be X.Y.Z, not '$version'"
  exit 1
fi
tag=v$version
released=false
commit=""

if [[ ${NEW_BRANCH:-} == true && ${CREATED:-} != true ]]; then
  # Creating a branch, such as release/vN at a release, releases nothing new.
  echo "::notice::branch created at $SHA; not a new release"
else
  status=0
  commit=$(tag_commit "$tag") || status=$?
  if ((status == 0)); then
    if [[ $commit == "$SHA" ]]; then
      released=true
    elif [[ ${CREATED:-} == true && ${CREATED_TAG:-} == "$tag" ]]; then
      # A run that waited in the queue released an older commit.
      released=true
      echo "::notice::$tag was released at $commit, not at $SHA"
    elif [[ ${RELEASE_FAILED:-} == true ]]; then
      echo "::warning::$tag exists at $commit; if it was released by this run" \
        "before release-please failed, rerun the run of $commit to publish it"
    fi
  elif ((status != 3)); then
    exit 1
  fi
fi

if [[ $released == true ]]; then
  status=0
  release=$(api_get "repos/$REPO/releases/tags/$tag") || status=$?
  if ((status == 3)); then
    echo "::error::tag $tag exists but has no release"
    exit 1
  fi
  ((status == 0)) || exit 1
  [[ $(jq -r .draft <<<"$release") == false ]] || released=false
fi

# One JSON output with string fields, all empty unless released.
fields=(released "$released" tag "" version "" major "" minor "" patch ""
  prerelease "" sha "" release-url "")
if [[ $released == true ]]; then
  IFS=. read -r major minor patch <<<"$version"
  fields=(released true tag "$tag" version "$version" major "$major"
    minor "$minor" patch "$patch" prerelease "$(jq -r .prerelease <<<"$release")"
    sha "$commit" release-url "$(jq -r .html_url <<<"$release")")
fi
echo "state=$(jq -nc '$ARGS.positional as $a | [range(0; $a | length; 2) | {($a[.]): $a[. + 1]}] | add' \
  --args "${fields[@]}")" >>"$GITHUB_OUTPUT"
summary "manifest $version, released: $released"
