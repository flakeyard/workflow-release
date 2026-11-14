# shellcheck shell=bash
# Responses of the gh stub that change while a script runs, on top of
# internal/testing/fixtures.sh of action-shell-lib.

# late PATH: the fixture of PATH appears only after the script sleeps.
late() {
  local file
  file=$(fixture_file "$1")
  mv -- "${file}" "${file}.late"
}

# later PATH BODY: answer GET PATH with BODY after the script sleeps, like a
# run that completes.
later() {
  local path=$1 body=$2
  printf '%s\n' "${body}" >"$(fixture_file "${path}").late"
}
