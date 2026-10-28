#!/usr/bin/env bash
# Fails unless the App inputs are complete and REF is a release branch.
set -euo pipefail
: "${CLIENT_ID?}" "${HAS_KEY:?}" "${REF:?}" "${DEFAULT_BRANCH:?}"

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
