#!/usr/bin/env bash
# Marks the newest published, non-prerelease vX.Y.Z of REPO as latest.
set -euo pipefail
: "${REPO:?}"
# shellcheck source-path=SCRIPTDIR source=../lib/github.sh
source "$(dirname "$0")/../lib/github.sh"

newest=$(gh api --paginate "repos/$REPO/releases" \
  --jq '.[] | select((.draft or .prerelease) | not) | "\(.tag_name) \(.id)"' \
  | { grep -E '^v[0-9]+\.[0-9]+\.[0-9]+ ' || true; } | sort -V | tail -n 1)
[[ -n $newest ]] || exit 0

status=0
current=$(api_get "repos/$REPO/releases/latest") || status=$?
((status == 0 || status == 3)) || exit 1
if [[ $status == 3 || $(jq -r .id <<<"$current") != "${newest#* }" ]]; then
  gh api --silent -X PATCH "repos/$REPO/releases/${newest#* }" -f make_latest=true
  summary "marked ${newest% *} as latest"
fi
