#!/usr/bin/env bash
# Fails unless CONFIG and MANIFEST at SHA describe one root package tagged
# vX.Y.Z with default labels, and on release/vN its major version is N.
set -euo pipefail
: "${REPO:?}" "${SHA:?}" "${REF:?}" "${CONFIG:?}" "${MANIFEST:?}"
# shellcheck source-path=SCRIPTDIR source=../lib/github.sh
source "$(dirname "$0")/../lib/github.sh"

config=$(file_at "$CONFIG" "$SHA")
manifest=$(file_at "$MANIFEST" "$SHA")
problems=$(jq -r -f "$(dirname "$0")/config.jq" <<<"$config")
if [[ -n $problems ]]; then
  while IFS= read -r line; do echo "::error file=$CONFIG::$line"; done <<<"$problems"
  exit 1
fi
version=$(jq -r '."." // empty' <<<"$manifest")
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error file=$MANIFEST::the root version must be X.Y.Z, not '$version'"
  exit 1
fi
if [[ $REF =~ ^refs/heads/release/v([0-9]+)$ && ${version%%.*} != "${BASH_REMATCH[1]}" ]]; then
  echo "::error file=$MANIFEST::version $version does not belong on ${REF#refs/heads/}"
  exit 1
fi
