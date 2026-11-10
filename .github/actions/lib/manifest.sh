# shellcheck shell=bash source-path=SCRIPTDIR
# The root version in the release-please manifest. Source this file; it
# expects SHELL_LIB, REPO and MANIFEST.

# shellcheck source=/dev/null
source "$SHELL_LIB/github/contents.sh"
# shellcheck source=github/files.sh
source "${BASH_SOURCE[0]%/*}/github/files.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"
# shellcheck source=version.sh
source "${BASH_SOURCE[0]%/*}/version.sh"

# root_version REF: print the version of the root package in MANIFEST at a
# commit; empty when there is none. Fails when there is no MANIFEST.
root_version() {
  local ref=$1
  required_file "$MANIFEST" "$ref" | jq -r '."." // empty'
}

# find_release_version REF: print the version of the root package in MANIFEST
# at a commit; empty when there is no manifest, or no root version X.Y.Z.
find_release_version() {
  local ref=$1 content="" status=0 version
  content=$(file_at "$MANIFEST" "$ref") || status=$?
  ((status == 0 || status == NOT_FOUND)) || return 1
  # A manifest that is no JSON object has no root version either.
  version=$(jq -r 'objects | ."." | strings' <<<"$content" 2>/dev/null) || version=""
  is_release_version "$version" || return 0
  printf '%s\n' "$version"
}

# check_release_version VERSION: fail unless VERSION is X.Y.Z.
check_release_version() {
  local version=$1
  is_release_version "$version" \
    || fail "the root version must be X.Y.Z, not '$version'" "$MANIFEST"
}
