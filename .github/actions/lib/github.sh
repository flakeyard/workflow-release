# shellcheck shell=bash
# Helpers for GitHub API calls through gh. Source this file; it expects REPO.

# api_get PATH: print the response body. Returns 0 when found, 3 when the
# resource does not exist (HTTP 404) and 1 on any other error.
api_get() {
  local err status=0
  err=$(mktemp)
  gh api "$1" 2>"$err" || status=$?
  if ((status == 0)); then
    rm -f "$err"
    return 0
  fi
  if grep -q 'HTTP 404' "$err"; then
    rm -f "$err"
    return 3
  fi
  cat "$err" >&2
  rm -f "$err"
  return 1
}

# tag_commit TAG: print the commit a tag points at, following annotated tags.
# Returns like api_get.
tag_commit() {
  local ref sha
  ref=$(api_get "repos/$REPO/git/ref/tags/$1") || return
  sha=$(jq -r .object.sha <<<"$ref")
  if [[ $(jq -r .object.type <<<"$ref") == tag ]]; then
    api_get "repos/$REPO/git/tags/$sha" | jq -r .object.sha
  else
    echo "$sha"
  fi
}

# file_at PATH REF: print a file of the repository at a commit.
file_at() {
  gh api "repos/$REPO/contents/$1?ref=$2" --jq .content | base64 -d
}

# manifest_version MANIFEST REF: print the version of the root package.
manifest_version() {
  file_at "$1" "$2" | jq -r '."."'
}

# newest_release MAJOR: print the newest published vMAJOR.Y.Z. Major 0 counts
# pre-releases, since all 0.y.z are; other majors skip them. Empty when none.
newest_release() {
  local keep='.prerelease | not'
  if (($1 == 0)); then keep=true; fi
  gh api --paginate "repos/$REPO/releases" \
    --jq ".[] | select(.draft | not) | select($keep) | .tag_name" \
    | { grep -E "^v$1\.[0-9]+\.[0-9]+$" || true; } | sort -V | tail -n 1
}

# summary TEXT: append a line to the job summary.
summary() {
  echo "$*" >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
}
