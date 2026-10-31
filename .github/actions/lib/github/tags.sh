# shellcheck shell=bash source-path=SCRIPTDIR
# Tags of REPO. Source this file; it expects REPO.

# shellcheck source=api.sh
source "${BASH_SOURCE[0]%/*}/api.sh"

# find_tag_commit TAG: print the commit a tag points at, following an annotated
# tag; empty when the tag does not exist.
find_tag_commit() {
  local tag=$1 ref
  ref=$(api_find "repos/$REPO/git/ref/tags/$tag") || return 1
  [[ -n $ref ]] || return 0
  if [[ $(jq -r .object.type <<<"$ref") == tag ]]; then
    # The ref exists, so a missing tag object is an error.
    ref=$(api_get "repos/$REPO/git/tags/$(jq -r .object.sha <<<"$ref")") || return 1
  fi
  jq -r .object.sha <<<"$ref"
}
