#!/usr/bin/env bash
# Moves vX of the manifest's major version forward to its newest release.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}"
: "${REPO:?}" "${SHA:?}" "${MANIFEST:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "${SHELL_LIB}/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0001).
lib=${0%/*}/../../../lib
# shellcheck source=../../../lib/major-tag.sh
source "${lib}/major-tag.sh"
# shellcheck source=../../../lib/manifest.sh
source "${lib}/manifest.sh"
# shellcheck source=/dev/null
source "${SHELL_LIB}/report.sh"

version=$(root_version "${SHA}")
check_release_version "${version}"
major=${version%%.*}

change=$(major_tag_change "${major}")
read -r change latest target <<<"${change}"
case ${change} in
  none) summary "no release of v${major} yet" ;;
  untagged) fail "release ${latest} has no tag" ;;
  create)
    gh api --silent -X POST "repos/${REPO}/git/refs" -f ref="refs/tags/v${major}" -f sha="${target}"
    summary "created v${major} at ${latest}"
    ;;
  current) summary "v${major} already at ${latest}" ;;
  move)
    gh api --silent -X PATCH "repos/${REPO}/git/refs/tags/v${major}" -f sha="${target}" -F force=true
    summary "moved v${major} to ${latest}"
    ;;
  *) warning "v${major} not moved: ${latest} is ${change} of v${major}" ;;
esac
