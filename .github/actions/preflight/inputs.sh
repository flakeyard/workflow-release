#!/usr/bin/env bash
# Fails unless the run is a push to a release branch and, when KEY_VISIBLE is
# true, the App inputs are complete.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
: "${CLIENT_ID?}" "${HAS_KEY:?}" "${KEY_VISIBLE:?}" "${EVENT:?}" "${REF:?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/app-key.sh
source "$lib/app-key.sh"

if [[ $EVENT != push ]]; then
  echo "::error::the release workflow runs only on push events, not $EVENT"
  exit 1
fi
: "${DEFAULT_BRANCH:?}"
# An environment secret is visible only in jobs of that environment; the
# token action checks the key there.
if [[ $KEY_VISIBLE == true ]]; then check_app_key "$CLIENT_ID" "$HAS_KEY"; fi
if [[ $REF != "refs/heads/$DEFAULT_BRANCH" &&
  ! $REF =~ ^refs/heads/release/v[1-9][0-9]*$ ]]; then
  echo "::error::releases run only on $DEFAULT_BRANCH and release/vN, not $REF"
  exit 1
fi
