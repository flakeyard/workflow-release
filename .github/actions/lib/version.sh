# shellcheck shell=bash
# Versions X.Y.Z of releases and their tags vX.Y.Z.

# Several helpers source this file; its read-only constants are defined once.
[[ ! -v RELEASE_VERSION ]] || return 0

# The root version of a release: X.Y.Z without leading zeros, which
# arithmetic would read as octal and release-please never writes. The digits
# are listed, since a range such as 0-9 also matches other digits in some
# locales.
readonly VERSION_NUMBER='(0|[123456789][0123456789]*)'
readonly RELEASE_VERSION="^$VERSION_NUMBER\\.$VERSION_NUMBER\\.$VERSION_NUMBER\$"
# The tag of a release, vX.Y.Z.
readonly RELEASE_TAG="^v${RELEASE_VERSION#^}"

# is_release_version VERSION: VERSION is X.Y.Z.
is_release_version() {
  local version=$1
  [[ $version =~ $RELEASE_VERSION ]]
}

# is_release_tag TAG: TAG is vX.Y.Z.
is_release_tag() {
  local tag=$1
  [[ $tag =~ $RELEASE_TAG ]]
}
