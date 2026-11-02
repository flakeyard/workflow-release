# shellcheck shell=bash source-path=SCRIPTDIR
# Merged release pull requests of REPO. Source this file; it expects REPO.

# shellcheck source=api.sh
source "${BASH_SOURCE[0]%/*}/api.sh"

# pending_release_prs BASE: print the merged pull requests into BASE that are
# still labelled "autorelease: pending", one JSON object per line.
pending_release_prs() {
  local base=$1 numbers number pr
  # The label is filtered by the API, so only pending pull requests are listed.
  numbers=$(gh api --paginate \
    "repos/$REPO/issues?state=closed&labels=autorelease:%20pending&per_page=100" \
    --jq '.[] | select(.pull_request.merged_at != null) | .number')
  for number in $numbers; do
    pr=$(api_get "repos/$REPO/pulls/$number")
    jq -c --arg base "$base" 'select(.base.ref == $base)' <<<"$pr"
  done
}
