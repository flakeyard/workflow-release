#!/usr/bin/env bash
# Fails unless both or neither of the client ID and the private key of the
# App are given, before the key is used.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}"
: "${CLIENT_ID?}" "${HAS_KEY:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "$SHELL_LIB/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0001).
lib=${0%/*}/../../../lib
# shellcheck source=../../../lib/app-key.sh
source "$lib/app-key.sh"

check_app_key "$CLIENT_ID" "$HAS_KEY"
