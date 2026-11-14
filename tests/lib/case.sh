# shellcheck shell=bash
# The run that every test starts with and its parameters, and the copy of the
# library that the steps run, on top of case.sh of action-shell-lib. Source this
# file after it, consumer/library.sh and consumer/step.sh; it expects root, the
# repository's directory, and SHELL_LIB, the directory of the library.
# shellcheck disable=SC2034 # ACTIONS and stub_variables: read by the suites and step.sh

: "${root:?}" "${SHELL_LIB:?}"
# The repository, commit, ref and files of the run of every test; the tests
# use them in the paths of fixtures too.
readonly REPO=o/r SHA=aaa REF=refs/heads/main
readonly MANIFEST=.release-please-manifest.json CONFIG=release-please-config.json
# A parameter of a test, given as lower-case name=value to configure.
readonly PARAM_FORM='^([a-z][a-z0-9_]*)=(.*)$'
declare -A params
# The tools of the runner that the scripts and the stubs run from
# SYSTEM_PATH.
readonly RUNNER_TOOLS=(base64 bash cat cut date grep jq mktemp mv rm sort tail)
# The directory of the internal actions, ACTIONS/<name>/action.yml.
readonly ACTIONS=${root}/.github/actions

# Files shared by all tests, removed at the end.
shared=$(mktemp -d)
trap 'rm -rf -- "$shared"' EXIT
sysbin=${shared}/bin
mkdir "${sysbin}"
for tool in "${RUNNER_TOOLS[@]}"; do
  ln -s "$(command -v "${tool}")" "${sysbin}/${tool}"
done

# The copy of the library that the steps run, whose SYSTEM_PATH is the stubs
# of tests/bin, those of the library and the tools of the runner.
shell_lib=${shared}/shell-lib
copy_library "${shell_lib}" "${root}/tests/bin:${TESTING_BIN}:${sysbin}"
readonly shell_lib
# The variable of the stubs of tests/bin, which every step gets besides the
# variables of its run line and of the stubs of the library.
stub_variables=(TESTING_BIN)

# start_test: setup for one test of a script: the run above, the copy of the
# library in SHELL_LIB, and the stubs of tests/bin before those of the library, which
# they call in TESTING_BIN.
start_test() {
  setup
  params=()
  apply PATH="${root}/tests/bin:${TESTING_BIN}:${HOST_PATH}" TESTING_BIN="${TESTING_BIN}" \
    SHELL_LIB="${shell_lib}" REPO="${REPO}" SHA="${SHA}" REF="${REF}" \
    MANIFEST="${MANIFEST}" CONFIG="${CONFIG}"
}

# configure NAME=VALUE...: apply the variables of the script; lower-case
# names are parameters of the test instead, read by param.
configure() {
  local pair
  for pair; do
    if [[ ${pair} =~ ${PARAM_FORM} ]]; then
      params[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
    else
      apply "${pair}"
    fi
  done
}

# param NAME [DEFAULT]: print a parameter of the test given to configure.
param() {
  local name=$1 default=${2:-}
  printf '%s\n' "${params[${name}]-${default}}"
}
