# shellcheck shell=bash
# Messages of a step: errors in the log and lines of the job summary.

# fail MESSAGE [FILE]: report an error, about FILE if given, and exit.
fail() {
  local message=$1 file=${2:-}
  if [[ -n $file ]]; then
    echo "::error file=$file::$message"
  else
    echo "::error::$message"
  fi
  exit 1
}

# summary TEXT: append a line to the job summary.
summary() {
  echo "$*" >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
}

# warning MESSAGE: report a warning.
warning() {
  echo "::warning::$*"
}

# code_span TEXT: print TEXT as inline code of the job summary. Text that
# others choose, such as a pull request title, cannot leave the code span, so
# it renders as no link or markup.
code_span() {
  local text=$1 tick='`'
  text=${text//$'\n'/ }
  text=${text//$'\r'/ }
  text=${text//\`/\'}
  printf '%s%s%s\n' "$tick" "$text" "$tick"
}
