# shellcheck shell=bash
# Releases, as the releases API answers them.

# releases BODY: the first page of the list of releases.
releases() { fixture "repos/$REPO/releases?per_page=100" "$1"; }

# release TAG [PRERELEASE]: a published release. The API answers a draft by
# tag with HTTP 404, so a draft has no fixture.
release() {
  local tag=$1 prerelease=${2:-false}
  fixture "repos/$REPO/releases/tags/$tag" \
    "{\"draft\":false,\"prerelease\":$prerelease,\"html_url\":\"https://x/$tag\"}"
}

# released_at VERSION COMMIT: the manifest at SHA has VERSION, and its release
# is tagged at COMMIT.
released_at() {
  local version=$1 commit=$2
  manifest "$version"
  tag "v$version" "$commit"
  release "v$version"
}
