# shellcheck shell=bash
# Commits of REPO. Source this file; it expects SHELL_LIB and REPO.

# shellcheck source=/dev/null
source "$SHELL_LIB/github/api.sh"

# compare_status BASE HEAD: print how commit HEAD relates to commit BASE:
# ahead when HEAD descends from BASE, identical, behind or diverged.
compare_status() {
  local base=$1 head=$2
  api_get "repos/$REPO/compare/$base...$head" | jq -r .status
}
