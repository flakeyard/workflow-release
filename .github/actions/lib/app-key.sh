# shellcheck shell=bash
# The inputs of a GitHub App: its client ID and its private key come together.
# Source this file; it expects SHELL_LIB.

# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"

# check_app_key CLIENT_ID HAS_KEY: fail unless both or neither of the client
# ID and the key are given; HAS_KEY is true when the key is.
check_app_key() {
  local client_id=$1 has_key=$2
  if [[ -n $client_id && $has_key != true ]]; then
    fail "app-client-id is set but APP_PRIVATE_KEY is empty; pass it under that name and set environment if it is an environment secret"
  fi
  if [[ -z $client_id && $has_key == true ]]; then
    fail "APP_PRIVATE_KEY is set but app-client-id is empty"
  fi
}
