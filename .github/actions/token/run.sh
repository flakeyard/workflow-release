#!/usr/bin/env bash
# Fails unless both or neither of the client ID and the private key of the
# App are given, before the key is used.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
: "${SHELL_LIB:?}"
: "${CLIENT_ID?}" "${HAS_KEY:?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/app-key.sh
source "$lib/app-key.sh"

check_app_key "$CLIENT_ID" "$HAS_KEY"
