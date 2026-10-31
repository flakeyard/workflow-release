# shellcheck shell=bash
# Helpers for GitHub API calls through gh. Source this file; it expects REPO
# and, for the manifest helpers, MANIFEST.

# Status of api_request when the resource does not exist (HTTP 404).
readonly NOT_FOUND=3
# The root version of a release.
readonly RELEASE_VERSION='^[0-9]+\.[0-9]+\.[0-9]+$'

# Helpers called inside $(...) stop at their first failing command too.
shopt -s inherit_errexit

# fail MESSAGE [FILE]: report an error, about FILE if given, and exit.
fail() {
  local message=$1 file=${2:-}
  if [[ -n $file ]]; then
    echo "::error file=$file::$message"
  else
    echo "::error::$message"
  fi
  exit 1
}

# api_request METHOD PATH: print the response body. Returns 0 on success,
# NOT_FOUND when the resource does not exist and 1 on any other error, after
# printing the error.
api_request() {
  local method=$1 path=$2 tmp status=0
  tmp=$(mktemp -d)
  gh api -X "$method" "$path" >"$tmp/body" 2>"$tmp/error" || status=$?
  if ((status == 0)); then
    cat -- "$tmp/body"
  elif grep -q 'HTTP 404' "$tmp/error"; then
    status=$NOT_FOUND
  else
    cat -- "$tmp/error" >&2
    status=1
  fi
  rm -rf -- "$tmp"
  return "$status"
}

# api_optional METHOD PATH: like api_request, but a missing resource is not an
# error and prints nothing.
api_optional() {
  local method=$1 path=$2 status=0
  api_request "$method" "$path" || status=$?
  ((status == 0 || status == NOT_FOUND)) || return 1
}

# api_get PATH: print a resource; fails when it does not exist.
api_get() {
  local path=$1 status=0
  api_request GET "$path" || status=$?
  if ((status == NOT_FOUND)); then echo "$path: Not Found (HTTP 404)" >&2; fi
  ((status == 0)) || return 1
}

# api_find PATH: print a resource; prints nothing when it does not exist.
api_find() { api_optional GET "$1"; }

# api_delete_if_exists PATH: delete a resource unless it is already gone.
api_delete_if_exists() { api_optional DELETE "$1" >/dev/null; }

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

# published_release TAG: print the published release of a tag; empty when
# there is none. The API answers a draft release by tag with HTTP 404.
published_release() {
  local tag=$1
  api_find "repos/$REPO/releases/tags/$tag"
}

# file_at PATH REF: print a file of the repository at a commit.
file_at() {
  local path=$1 ref=$2
  gh api "repos/$REPO/contents/$path?ref=$ref" --jq .content | base64 -d
}

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

# published_releases PRERELEASES: print "TAG ID" of the published vX.Y.Z
# releases, oldest version first; pre-releases only if PRERELEASES is true.
published_releases() {
  local prereleases=$1
  gh api --paginate "repos/$REPO/releases?per_page=100" --jq "
    def published: .draft | not;
    def wanted: $prereleases or (.prerelease | not);
    .[] | select(published and wanted) | \"\(.tag_name) \(.id)\"" \
    | { grep -E '^v[0-9]+\.[0-9]+\.[0-9]+ ' || true; } | sort -V
}

# newest_release MAJOR: print the newest published vMAJOR.Y.Z. Major 0 counts
# pre-releases, since all 0.y.z are; other majors skip them. Empty when none.
newest_release() {
  local major=$1 prereleases=false
  if ((major == 0)); then prereleases=true; fi
  published_releases "$prereleases" | { grep -E "^v$major\." || true; } \
    | tail -n 1 | cut -d ' ' -f 1
}

# summary TEXT: append a line to the job summary.
summary() {
  echo "$*" >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
}
