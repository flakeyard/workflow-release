# shellcheck shell=bash source-path=SCRIPTDIR
# Tags of REPO. Source this file; it expects SHELL_LIB and
# REPO.

# shellcheck source=optional.sh
source "${BASH_SOURCE[0]%/*}/optional.sh"

# find_tag_commit TAG: print the commit a tag points at, following an annotated
# tag; empty when the tag does not exist.
find_tag_commit() {
  local tag=$1 ref type sha
  ref=$(api_find "repos/${REPO}/git/ref/tags/${tag}") || return 1
  [[ -n ${ref} ]] || return 0
  type=$(jq -r .object.type <<<"${ref}") || return 1
  if [[ ${type} == tag ]]; then
    sha=$(jq -r .object.sha <<<"${ref}") || return 1
    # The ref exists, so a missing tag object is an error.
    ref=$(api_get "repos/${REPO}/git/tags/${sha}") || return 1
  fi
  jq -r .object.sha <<<"${ref}"
}
