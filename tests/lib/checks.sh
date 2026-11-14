# shellcheck shell=bash
# Checks of the last run of a script, on top of checks.sh of action-shell-lib.
# Source this file after case.sh.
# shellcheck disable=SC2154 # work and current come from the library.

# expect_param_message: check the message given as message=TEXT, if any.
expect_param_message() {
  local message
  message=$(param message)
  [[ -z ${message} ]] || expect message "${message}"
}

# expect_state FIELD VALUE: the field FIELD of the output state of the last
# run is VALUE.
expect_state() {
  local field=$1 expected=$2 value
  [[ -n ${current} ]] || return 0
  value=$(sed -n 's/^state=//p' "${work}/output" | jq -r --arg field "${field}" '.[$field]')
  [[ ${value} == "${expected}" ]] || report "state.${field} is '${value}', expected '${expected}'"
}

# order FIRST SECOND: the stubs recorded the call FIRST before SECOND.
order() {
  local first=$1 second=$2 a b
  [[ -n ${current} ]] || return 0
  a=$(grep -nF -- "${first}" "${work}/calls" | head -n 1 | cut -d: -f1)
  b=$(grep -nF -- "${second}" "${work}/calls" | head -n 1 | cut -d: -f1)
  [[ -n ${a} && -n ${b} && ${a} -lt ${b} ]] || report "'${first}' not before '${second}': $(paste -sd';' "${work}/calls")"
}

# expect_first_notice TEXT: the first notice of the last run is TEXT.
expect_first_notice() {
  local expected=$1 first
  [[ -n ${current} ]] || return 0
  first=$(grep -m 1 '^::notice::' "${work}/stdout")
  [[ ${first} == "::notice::${expected}" ]] || report "the first notice is '${first}', expected '${expected}'"
}
