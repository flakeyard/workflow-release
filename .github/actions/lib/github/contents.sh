# shellcheck shell=bash
# Files of REPO at a commit. Source this file; it expects REPO.

# file_at PATH REF: print a file of the repository at a commit.
file_at() {
  local path=$1 ref=$2
  gh api "repos/$REPO/contents/$path?ref=$ref" --jq .content | base64 -d
}
