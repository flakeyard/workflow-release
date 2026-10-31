# shellcheck shell=bash
# The life of one test: its fixtures directory, environment, parameters and
# count. Source this file; it expects root, the repository's directory.

: "${root:?}"
failed=0 passed=0 current=""
# Test parameters given as lower-case name=value to apply.
declare -A params

# setup: fresh fixtures, calls, outputs and environment for one test.
setup() {
  work=$(mktemp -d)
  export FIXTURES=$work/fixtures CALLS=$work/calls GITHUB_OUTPUT=$work/output
  export GITHUB_STEP_SUMMARY=$work/summary PATH=$root/tests/bin:$PATH
  mkdir -p "$FIXTURES"
  : >"$CALLS"
  : >"$GITHUB_OUTPUT"
  export REPO=o/r SHA=aaa REF=refs/heads/main
  export MANIFEST=.release-please-manifest.json CONFIG=release-please-config.json
  unset NEW_BRANCH CREATED CREATED_TAG RELEASE_FAILED CLIENT_ID HAS_KEY EVENT \
    DEFAULT_BRANCH BASE OWNER WORKFLOW FAIL_ON RUN_ID BRANCH TAG COMMIT
  params=()
}

# apply NAME=VALUE...: override defaults of a test. Upper-case names are
# exported to the script; lower-case ones are test parameters, read by param.
apply() {
  local pair
  for pair; do
    if [[ $pair =~ ^[A-Z][A-Z0-9_]*= ]]; then
      declare -gx -- "$pair"
    elif [[ $pair =~ ^([a-z][a-z0-9_]*)=(.*)$ ]]; then
      params[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
    else
      echo "apply: not NAME=VALUE: $pair" >&2
      exit 2
    fi
  done
}

# param NAME [DEFAULT]: print a test parameter given to apply.
param() {
  local name=$1 default=${2:-}
  printf '%s\n' "${params[$name]-$default}"
}

# report MESSAGE: fail the current test.
report() {
  [[ -n $current ]] || return 0
  echo "FAIL $current: $1"
  failed=$((failed + 1))
  current=""
}

# finish: count the current test and remove its files.
finish() {
  if [[ -n $current ]]; then passed=$((passed + 1)); fi
  current=""
  rm -rf "$work"
}
