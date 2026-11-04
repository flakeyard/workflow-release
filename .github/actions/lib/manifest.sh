# shellcheck shell=bash source-path=SCRIPTDIR
# The root version in the release-please manifest. Source this file; it
# expects REPO and MANIFEST.

# shellcheck source=github/contents.sh
source "${BASH_SOURCE[0]%/*}/github/contents.sh"
# shellcheck source=report.sh
source "${BASH_SOURCE[0]%/*}/report.sh"

# The root version of a release: X.Y.Z without leading zeros, which
# arithmetic would read as octal. The digits are listed, since a range such as
# 0-9 also matches other digits in some locales.
readonly VERSION_NUMBER='(0|[123456789][0123456789]*)'
readonly RELEASE_VERSION="^$VERSION_NUMBER\\.$VERSION_NUMBER\\.$VERSION_NUMBER\$"

# root_version REF: print the version of the root package in MANIFEST at a
# commit; empty when there is none.
root_version() {
  local ref=$1
  file_at "$MANIFEST" "$ref" | jq -r '."." // empty'
}

# find_release_version REF: print the version of the root package in MANIFEST
# at a commit; empty when there is no manifest, or no root version X.Y.Z.
find_release_version() {
  local ref=$1 content version
  content=$(find_file_at "$MANIFEST" "$ref")
  # A manifest that is no JSON object has no root version either.
  version=$(jq -r 'objects | ."." | strings' <<<"$content" 2>/dev/null) || version=""
  is_release_version "$version" || return 0
  printf '%s\n' "$version"
}

# is_release_version VERSION: VERSION is X.Y.Z.
is_release_version() {
  local version=$1
  [[ $version =~ $RELEASE_VERSION ]]
}

# check_release_version VERSION: fail unless VERSION is X.Y.Z.
check_release_version() {
  local version=$1
  is_release_version "$version" \
    || fail "the root version must be X.Y.Z, not '$version'" "$MANIFEST"
}
