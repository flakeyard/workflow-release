# shellcheck shell=bash source-path=SCRIPTDIR
# Published releases of REPO. Source this file; it expects SHELL_LIB and
# REPO.

# shellcheck source=optional.sh
source "${BASH_SOURCE[0]%/*}/optional.sh"
# shellcheck source=../version.sh
source "${BASH_SOURCE[0]%/*}/../version.sh"

# published_release TAG: print the published release of a tag; empty when
# there is none. The API answers a draft release by tag with HTTP 404.
published_release() {
  local tag=$1
  api_find "repos/$REPO/releases/tags/$tag"
}

# published_releases PRERELEASES: print "TAG ID" of the published vX.Y.Z
# releases, oldest version first; pre-releases only if PRERELEASES is true.
published_releases() {
  local prereleases=$1 tag id
  api_get "repos/$REPO/releases?per_page=100" --paginate --jq "
    def published: .draft | not;
    def wanted: $prereleases or (.prerelease | not);
    .[] | select(published and wanted) | \"\(.tag_name) \(.id)\"" \
    | while read -r tag id; do
      if is_release_tag "$tag"; then printf '%s %s\n' "$tag" "$id"; fi
    done | sort -V
}

# newest_release MAJOR: print the newest published vMAJOR.Y.Z. Major 0 counts
# pre-releases, since all 0.y.z are; other majors skip them. Empty when none.
newest_release() {
  local major=$1 prereleases=false
  if ((major == 0)); then prereleases=true; fi
  published_releases "$prereleases" | { grep -E "^v$major\." || true; } \
    | tail -n 1 | cut -d ' ' -f 1
}
