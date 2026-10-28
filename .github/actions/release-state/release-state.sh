#!/usr/bin/env bash
# Writes released=true and the release details to GITHUB_OUTPUT when SHA is a
# published release, released=false otherwise.
set -euo pipefail
: "${REPO:?}" "${SHA:?}" "${MANIFEST:?}"
# shellcheck source-path=SCRIPTDIR source=../lib/github.sh
source "$(dirname "$0")/../lib/github.sh"

version=$(manifest_version "$MANIFEST" "$SHA")
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
    fi
  elif ((status != 3)); then
    exit 1
  fi
fi

if [[ $released == true ]]; then
  release=$(api_get "repos/$REPO/releases/tags/$tag")
  [[ $(jq -r .draft <<<"$release") == false ]] || released=false
fi

if [[ $released == true ]]; then
  IFS=. read -r major minor patch <<<"$version"
  {
    echo "tag=$tag"
    echo "version=$version"
    echo "major=$major"
    echo "minor=$minor"
    echo "patch=$patch"
    echo "prerelease=$(jq -r .prerelease <<<"$release")"
    echo "sha=$commit"
    echo "release-url=$(jq -r .html_url <<<"$release")"
  } >>"$GITHUB_OUTPUT"
fi
echo "released=$released" >>"$GITHUB_OUTPUT"
summary "manifest $version, released: $released"
