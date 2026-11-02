# shellcheck shell=bash
# Ages of timestamps, measured to NOW when it is set, as tests do, and to the
# current time otherwise.

# seconds_since TIME: print the seconds from TIME, a timestamp of the API, to
# now.
seconds_since() {
  local time=$1 start now
  start=$(date -u -d "$time" +%s)
  now=$(date -u -d "${NOW:-now}" +%s)
  echo $((now - start))
}
