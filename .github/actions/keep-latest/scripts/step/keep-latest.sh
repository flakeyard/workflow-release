#!/usr/bin/env bash
# Marks the newest published, non-prerelease vX.Y.Z of REPO as latest.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}"
: "${REPO:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "${SHELL_LIB}/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0001).
lib=${0%/*}/../../../lib
# shellcheck source=../../../lib/github/optional.sh
source "${lib}/github/optional.sh"
# shellcheck source=../../../lib/github/releases.sh
source "${lib}/github/releases.sh"
# shellcheck source=/dev/null
source "${SHELL_LIB}/report.sh"

newest=$(published_releases false | tail -n 1)
[[ -n ${newest} ]] || exit 0
read -r tag id <<<"${newest}"

current=$(api_find "repos/${REPO}/releases/latest")
if [[ -z ${current} || $(jq -r .id <<<"${current}") != "${id}" ]]; then
  gh api --silent -X PATCH "repos/${REPO}/releases/${id}" -f make_latest=true
  summary "marked ${tag} as latest"
fi
