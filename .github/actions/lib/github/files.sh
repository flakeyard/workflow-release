# shellcheck shell=bash
# Files of REPO that a step needs, on top of file_at of action-shell-lib.
# Source this file; it expects SHELL_LIB and REPO.

# shellcheck source=/dev/null
source "${SHELL_LIB}/github/contents.sh"

# required_file PATH REF: print the file PATH of REPO at REF. Returns 1 on any
# error, also when the file does not exist, after printing it on stderr:
# file_at says nothing about a missing file.
required_file() {
  local path=$1 ref=$2 status=0
  file_at "${path}" "${ref}" || status=$?
  if ((status == NOT_FOUND)); then
    printf '%s does not exist at %s\n' "${path}" "${ref}" >&2
  fi
  ((status == 0)) || return 1
}
