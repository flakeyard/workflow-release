# shellcheck shell=bash source-path=SCRIPTDIR
# The root version in the release-please manifest. Source this file; it
# expects REPO and MANIFEST.

# shellcheck source=github/contents.sh
source "${BASH_SOURCE[0]%/*}/github/contents.sh"
# shellcheck source=report.sh
source "${BASH_SOURCE[0]%/*}/report.sh"

# The root version of a release.
readonly RELEASE_VERSION='^[0-9]+\.[0-9]+\.[0-9]+$'

# root_version REF: print the version of the root package in MANIFEST at a
# commit; empty when there is none.
root_version() {
  local ref=$1
  file_at "$MANIFEST" "$ref" | jq -r '."." // empty'
}

# check_release_version VERSION: fail unless VERSION is X.Y.Z.
check_release_version() {
  local version=$1
  [[ $version =~ $RELEASE_VERSION ]] \
    || fail "the root version must be X.Y.Z, not '$version'" "$MANIFEST"
}
