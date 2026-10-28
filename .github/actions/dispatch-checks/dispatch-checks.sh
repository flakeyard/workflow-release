#!/usr/bin/env bash
# Starts WORKFLOW on the open release pull request into BASE, if there is one.
set -euo pipefail
: "${REPO:?}" "${OWNER:?}" "${BASE:?}" "${WORKFLOW:?}"
# shellcheck source-path=SCRIPTDIR source=../lib/github.sh
source "$(dirname "$0")/../lib/github.sh"

head=release-please--branches--$BASE
number=$(gh api "repos/$REPO/pulls?state=open&base=$BASE&head=$OWNER:$head" \
  --jq '.[0].number // empty')
if [[ -z $number ]]; then
  summary "no open release pull request"
  exit 0
fi
gh workflow run "$WORKFLOW" --repo "$REPO" --ref "$head"
summary "started $WORKFLOW on #$number ($head)"
