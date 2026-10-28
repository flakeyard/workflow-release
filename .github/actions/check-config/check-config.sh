#!/usr/bin/env bash
# Fails unless CONFIG and MANIFEST at SHA describe one root package tagged
# vX.Y.Z with default labels.
set -euo pipefail
: "${REPO:?}" "${SHA:?}" "${CONFIG:?}" "${MANIFEST:?}"
# shellcheck source-path=SCRIPTDIR source=../lib/github.sh
source "$(dirname "$0")/../lib/github.sh"

config=$(file_at "$CONFIG" "$SHA")
manifest=$(file_at "$MANIFEST" "$SHA")
problems=$(jq -r -f "$(dirname "$0")/config.jq" <<<"$config")
if [[ -n $problems ]]; then
  while IFS= read -r line; do echo "::error file=$CONFIG::$line"; done <<<"$problems"
  exit 1
fi
if ! jq -e 'has(".")' <<<"$manifest" >/dev/null; then
  echo "::error file=$MANIFEST::the manifest has no \".\" entry"
  exit 1
fi
