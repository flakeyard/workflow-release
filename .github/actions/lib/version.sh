# shellcheck shell=bash
# Versions X.Y.Z of releases and their tags vX.Y.Z.

# Sourcing this file twice defines its read-only constants once. A variable of
# the environment with the same name is not read-only, and the constant
# replaces it.
[[ $(declare -p RELEASE_VERSION 2>/dev/null) != "declare -r"* ]] || return 0

# The root version of a release: X.Y.Z without leading zeros, which
# arithmetic would read as octal and release-please never writes. The digits
# are listed, since a range such as 0-9 also matches other digits in some
# locales.
readonly VERSION_NUMBER='(0|[123456789][0123456789]*)'
readonly RELEASE_VERSION="^${VERSION_NUMBER}\\.${VERSION_NUMBER}\\.${VERSION_NUMBER}\$"
# The tag of a release, vX.Y.Z.
readonly RELEASE_TAG="^v${RELEASE_VERSION#^}"

# is_release_version VERSION: VERSION is X.Y.Z.
is_release_version() {
  local version=$1
  [[ ${version} =~ ${RELEASE_VERSION} ]]
}

# is_release_tag TAG: TAG is vX.Y.Z.
is_release_tag() {
  local tag=$1
  [[ ${tag} =~ ${RELEASE_TAG} ]]
}
