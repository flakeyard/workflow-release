# shellcheck shell=bash
# Calls of the GitHub API whose resource may be missing, on top of api_request
# of action-shell-lib. Source this file; it expects SHELL_LIB.

# shellcheck source=/dev/null
source "$SHELL_LIB/github/api.sh"

# api_optional METHOD PATH: like api_request, but a missing resource is not an
# error and prints nothing.
api_optional() {
  local method=$1 path=$2 status=0
  api_request "$method" "$path" || status=$?
  ((status == 0 || status == NOT_FOUND)) || return 1
}

# api_find PATH: print a resource; prints nothing when it does not exist.
api_find() {
  local path=$1
  api_optional GET "$path"
}

# api_delete_if_exists PATH: delete a resource unless it is already gone.
api_delete_if_exists() {
  local path=$1
  api_optional DELETE "$path" >/dev/null
}
