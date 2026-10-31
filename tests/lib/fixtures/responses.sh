# shellcheck shell=bash
# Responses of the gh stub, read from the files of FIXTURES.

# fixture_file PATH: the file that answers GET PATH, as the gh stub names it.
fixture_file() {
  local path=$1
  printf '%s\n' "$FIXTURES/${path//[\/?&=]/_}"
}

# fixture PATH BODY: answer GET PATH with BODY.
fixture() {
  local path=$1 body=$2
  printf '%s\n' "$body" >"$(fixture_file "$path")"
}

# next_page PATH PAGE BODY: answer page PAGE of a paginated GET PATH.
next_page() {
  local path=$1 page=$2 body=$3
  printf '%s\n' "$body" >"$(fixture_file "$path").$page"
}

# late PATH: the fixture of PATH appears only after the script sleeps.
late() {
  local file
  file=$(fixture_file "$1")
  mv -- "$file" "$file.late"
}

# later PATH BODY: answer GET PATH with BODY after the script sleeps, like a
# run that completes.
later() {
  local path=$1 body=$2
  printf '%s\n' "$body" >"$(fixture_file "$path").late"
}

# file_fixture PATH REF CONTENT: answer the contents API for a file, with the
# base64 wrapped at 60 characters like the API does.
file_fixture() {
  local path=$1 ref=$2 content=$3 encoded
  encoded=$(printf '%s' "$content" | base64 -w 60 | paste -sd '#' | sed 's/#/\\n/g')
  fixture "repos/$REPO/contents/$path?ref=$ref" "{\"content\":\"$encoded\"}"
}
