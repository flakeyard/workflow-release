# shellcheck shell=bash
# The run that every test starts with and its parameters, on top of case.sh
# of action-shell-lib. Source this file after it; it expects root, the
# repository's directory, and SHELL_LIB, the directory of the library.

: "${root:?}" "${SHELL_LIB:?}"
# The repository, commit, ref and files of the run of every test; the tests
# use them in the paths of fixtures too.
readonly REPO=o/r SHA=aaa REF=refs/heads/main
readonly MANIFEST=.release-please-manifest.json CONFIG=release-please-config.json
# A parameter of a test, given as lower-case name=value to configure.
readonly PARAM_FORM='^([a-z][a-z0-9_]*)=(.*)$'
declare -A params

# start_test: setup for one test of a script: the run above, the library in
# SHELL_LIB, and the stubs of tests/bin before those of the library, which
# they call in TESTING_BIN.
start_test() {
  setup
  params=()
  apply PATH="$root/tests/bin:$TESTING_BIN:$HOST_PATH" TESTING_BIN="$TESTING_BIN" \
    SHELL_LIB="$SHELL_LIB" REPO="$REPO" SHA="$SHA" REF="$REF" \
    MANIFEST="$MANIFEST" CONFIG="$CONFIG"
}

# configure NAME=VALUE...: apply the variables of the script; lower-case
# names are parameters of the test instead, read by param.
configure() {
  local pair
  for pair; do
    if [[ $pair =~ $PARAM_FORM ]]; then
      params[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
    else
      apply "$pair"
    fi
  done
}

# param NAME [DEFAULT]: print a parameter of the test given to configure.
param() {
  local name=$1 default=${2:-}
  printf '%s\n' "${params[$name]-$default}"
}
