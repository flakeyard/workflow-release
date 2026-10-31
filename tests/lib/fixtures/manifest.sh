# shellcheck shell=bash
# The release-please manifest, as the contents API answers it.

# manifest VERSION [REF]: the root version in the manifest at REF, or at SHA.
manifest() {
  local version=$1 ref=${2:-$SHA}
  file_fixture "$MANIFEST" "$ref" "{\".\": \"$version\"}"
}
