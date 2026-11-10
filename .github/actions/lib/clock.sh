# shellcheck shell=bash
# Ages of timestamps.

# seconds_since TIME: print the seconds from TIME, a timestamp of the API, to
# now.
seconds_since() {
  local time=$1 start now
  start=$(date -u -d "$time" +%s)
  now=$(date -u +%s)
  echo $((now - start))
}
