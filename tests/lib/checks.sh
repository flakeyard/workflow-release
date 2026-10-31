# shellcheck shell=bash
# Runs of an action script and checks of what it did. Source this file after
# case.sh; it expects root, the repository's directory.
# shellcheck disable=SC2154 # work is the directory of the test, from setup.

: "${root:?}"
actions=$root/.github/actions

# run NAME EXPECTED SCRIPT: run an action script; EXPECTED is ok or fail.
run() {
  local name=$1 expected=$2 script=$3 status=0
  "$actions/$script" >"$work/stdout" 2>"$work/stderr" || status=$?
  current=$name
  if [[ $expected == fail && $status -eq 0 ]] || [[ $expected == ok && $status -ne 0 ]]; then
    report "expected $expected, exit status $status: $(cat "$work/stdout" "$work/stderr")"
  fi
}

# expect KIND [VALUE...]: check outputs, calls or messages of the last run.
expect() {
  [[ -n $current ]] || return 0
  case $1 in
    state)
      local value
      value=$(sed -n 's/^state=//p' "$GITHUB_OUTPUT" | jq -r --arg k "$2" '.[$k]')
      [[ $value == "$3" ]] || report "state.$2 is '$value', expected '$3'"
      ;;
    output)
      local value
      value=$(sed -n "s/^$2=//p" "$GITHUB_OUTPUT")
      [[ $value == "$3" ]] || report "output $2 is '$value', expected '$3'"
      ;;
    call) grep -qF -- "$2" "$CALLS" || report "no call '$2' in: $(paste -sd';' "$CALLS")" ;;
    no-call) ! grep -qF -- "$2" "$CALLS" || report "unexpected call '$2'" ;;
    no-calls) [[ ! -s $CALLS ]] || report "unexpected calls: $(paste -sd';' "$CALLS")" ;;
    message) grep -qF -- "$2" "$work/stdout" "$work/stderr" || report "no message '$2' in: $(cat "$work/stdout" "$work/stderr")" ;;
  esac
}

# expect_param_message: check the message given as message=TEXT, if any.
expect_param_message() {
  local message
  message=$(param message)
  [[ -z $message ]] || expect message "$message"
}

# order FIRST SECOND: FIRST was called before SECOND.
order() {
  [[ -n $current ]] || return 0
  local a b
  a=$(grep -nF -- "$1" "$CALLS" | head -n 1 | cut -d: -f1)
  b=$(grep -nF -- "$2" "$CALLS" | head -n 1 | cut -d: -f1)
  [[ -n $a && -n $b && $a -lt $b ]] || report "'$1' not before '$2': $(paste -sd';' "$CALLS")"
}
