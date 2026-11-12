# shellcheck shell=bash
# Release pull requests of REPO. Source this file; it expects SHELL_LIB and
# REPO.

# shellcheck source=/dev/null
source "$SHELL_LIB/github/api.sh"

# The label of a merged release pull request whose release is not tagged yet,
# and the same label in an API path or query.
readonly PENDING_LABEL='autorelease: pending'
readonly PENDING_LABEL_URL=${PENDING_LABEL// /%20}

# release_head BASE: print the branch of release-please's pull requests into
# BASE.
release_head() {
  local base=$1
  printf '%s\n' "release-please--branches--$base"
}

# pending_release_prs BASE: print the merged pull requests into BASE that are
# still labelled PENDING_LABEL, one JSON object per line.
pending_release_prs() {
  local base=$1 numbers number pr
  # The label is filtered by the API, so only pending pull requests are listed.
  numbers=$(api_get \
    "repos/$REPO/issues?state=closed&labels=$PENDING_LABEL_URL&per_page=100" \
    --paginate --jq '.[] | select(.pull_request.merged_at != null) | .number')
  for number in $numbers; do
    pr=$(api_get "repos/$REPO/pulls/$number")
    jq -c --arg base "$base" 'select(.base.ref == $base)' <<<"$pr"
  done
}

# release-please reads only this many merged pull requests of the target
# branch, the most recently created first. Sorting by update would move a pull
# request whenever it is labelled or commented on.
readonly RELEASE_PLEASE_WINDOW=200
readonly PULLS_PER_PAGE=100

# commit_pulls COMMIT: print the pull requests of a commit, a JSON array.
commit_pulls() {
  local commit=$1
  api_get "repos/$REPO/commits/$commit/pulls"
}

# merged_window BASE: print the numbers of the merged pull requests into BASE
# that release-please reads, one per line.
merged_window() {
  local base=$1 page=1 left=$RELEASE_PLEASE_WINDOW body merged taken size
  while ((left > 0)); do
    body=$(api_get "repos/$REPO/pulls?state=closed&base=$base&sort=created&direction=desc&per_page=$PULLS_PER_PAGE&page=$page")
    merged=$(jq -c --argjson left "$left" \
      '[.[] | select(.merged_at != null) | .number][:$left]' <<<"$body")
    jq -r '.[]' <<<"$merged"
    taken=$(jq length <<<"$merged")
    size=$(jq length <<<"$body")
    ((size == PULLS_PER_PAGE)) || break
    left=$((left - taken)) page=$((page + 1))
  done
}
