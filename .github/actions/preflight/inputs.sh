#!/usr/bin/env bash
# Fails unless the run is a push to a release branch and the App inputs are
# complete.
set -euo pipefail
shopt -s inherit_errexit
: "${CLIENT_ID?}" "${HAS_KEY:?}" "${EVENT:?}" "${REF:?}"

if [[ $EVENT != push ]]; then
  echo "::error::the release workflow runs only on push events, not $EVENT"
  exit 1
fi
: "${DEFAULT_BRANCH:?}"
if [[ -n $CLIENT_ID && $HAS_KEY != true ]]; then
  echo "::error::app-client-id is set but APP_PRIVATE_KEY is empty;" \
    "pass it under that name and set environment if it is an environment secret"
  exit 1
fi
if [[ -z $CLIENT_ID && $HAS_KEY == true ]]; then
  echo "::error::APP_PRIVATE_KEY is set but app-client-id is empty"
  exit 1
fi
if [[ $REF != "refs/heads/$DEFAULT_BRANCH" &&
  ! $REF =~ ^refs/heads/release/v[1-9][0-9]*$ ]]; then
  echo "::error::releases run only on $DEFAULT_BRANCH and release/vN, not $REF"
  exit 1
fi
