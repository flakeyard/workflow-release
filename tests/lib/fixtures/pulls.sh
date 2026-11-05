# shellcheck shell=bash
# Pull requests, as the pulls and issues API answer them. The paths are
# written out, not taken from lib/github, so that the tests check the paths
# that the scripts call.

# When the pull requests of pr_json were merged, unless a test says otherwise.
readonly MERGED_AT=2026-11-01T00:00:00Z

# release_branch BASE: release-please's head branch for BASE.
release_branch() {
  local base=$1
  printf '%s\n' "release-please--branches--$base"
}

# pending_path: the closed issues labelled pending, first page.
pending_path() {
  printf '%s\n' "repos/$REPO/issues?state=closed&labels=autorelease:%20pending&per_page=100"
}

# pending_prs BODY: the closed pull requests labelled pending.
pending_prs() {
  local body=$1
  fixture "$(pending_path)" "$body"
}

# pr_json NUMBER COMMIT [HEAD] [BASE] [MERGED_AT] [TITLE]: a pull request
# labelled pending, merged into BASE, main by default, as COMMIT; from HEAD,
# release-please's branch for BASE by default.
pr_json() {
  local number=$1 commit=$2 base=${4:-main}
  local head=${3:-$(release_branch "$base")} merged_at=${5:-$MERGED_AT}
  local title=${6:-chore(main): release}
  jq -nc --argjson number "$number" --arg commit "$commit" --arg head "$head" \
    --arg base "$base" --arg merged_at "$merged_at" --arg title "$title" '{
      number: $number, title: $title, head: {ref: $head}, base: {ref: $base},
      merge_commit_sha: $commit, merged_at: $merged_at,
      labels: [{name: "autorelease: pending"}]}'
}

# pull PR: answer the pull request PR, as pr_json prints it, by its number.
pull() {
  local pr=$1 number
  number=$(jq .number <<<"$pr")
  fixture "repos/$REPO/pulls/$number" "$pr"
}
