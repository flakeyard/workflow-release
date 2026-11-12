#!/usr/bin/env bash
# Fails unless CONFIG and MANIFEST at SHA describe one root package tagged
# vX.Y.Z with default labels, and on release/vN its major version is N.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}"
: "${REPO:?}" "${SHA:?}" "${REF:?}" "${CONFIG:?}" "${MANIFEST:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "$SHELL_LIB/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0001).
lib=${0%/*}/../../../lib
# shellcheck source=../../../lib/github/files.sh
source "$lib/github/files.sh"
# shellcheck source=../../../lib/manifest.sh
source "$lib/manifest.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"

readonly RELEASE_BRANCH='^refs/heads/release/v([0-9]+)$'

config=$(required_file "$CONFIG" "$SHA")
problems=$(jq -r -f "${0%/*}/config.jq" <<<"$config")
if [[ -n $problems ]]; then
  while IFS= read -r line; do error "$line" "$CONFIG"; done <<<"$problems"
  flush
  exit 1
fi
version=$(root_version "$SHA")
check_release_version "$version"
if [[ $REF =~ $RELEASE_BRANCH && ${version%%.*} != "${BASH_REMATCH[1]}" ]]; then
  fail "version $version does not belong on ${REF#refs/heads/}" "$MANIFEST"
fi
