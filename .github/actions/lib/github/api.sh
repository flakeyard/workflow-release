# shellcheck shell=bash
# Calls of the GitHub API through gh, which tell a missing resource from an
# error.

# Several helpers source this file; its read-only constant is defined once.
[[ ! -v NOT_FOUND ]] || return 0

# Status of api_request when the resource does not exist (HTTP 404).
readonly NOT_FOUND=3

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
