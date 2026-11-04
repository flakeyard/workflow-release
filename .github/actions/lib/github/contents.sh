# shellcheck shell=bash source-path=SCRIPTDIR
# Files of REPO at a commit. Source this file; it expects REPO.

# shellcheck source=api.sh
source "${BASH_SOURCE[0]%/*}/api.sh"

# file_at PATH REF: print a file of the repository at a commit.
file_at() {
  local path=$1 ref=$2
  gh api "repos/$REPO/contents/$path?ref=$ref" --jq .content | base64 -d
}

# find_file_at PATH REF: print a file of the repository at a commit; prints
# nothing when it does not exist there.
find_file_at() {
  local path=$1 ref=$2 response
  response=$(api_find "repos/$REPO/contents/$path?ref=$ref")
  [[ -n $response ]] || return 0
  jq -r .content <<<"$response" | base64 -d
}
