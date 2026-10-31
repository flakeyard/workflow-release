# shellcheck shell=bash
# Test helpers for the scripts in .github/actions, with a stub of gh. Source
# this file; it expects root, the repository's directory.

: "${root:?}"
actions=$root/.github/actions
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
    DEFAULT_BRANCH BASE OWNER WORKFLOW FAIL_ON
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

# --- Fixtures ----------------------------------------------------------------

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

# file_fixture PATH REF CONTENT: answer the contents API for a file, with the
# base64 wrapped at 60 characters like the API does.
file_fixture() {
  local path=$1 ref=$2 content=$3 encoded
  encoded=$(printf '%s' "$content" | base64 -w 60 | paste -sd '#' | sed 's/#/\\n/g')
  fixture "repos/$REPO/contents/$path?ref=$ref" "{\"content\":\"$encoded\"}"
}

# manifest VERSION [REF]: the root version in the manifest at REF, or at SHA.
manifest() {
  local version=$1 ref=${2:-$SHA}
  file_fixture "$MANIFEST" "$ref" "{\".\": \"$version\"}"
}

# tag TAG COMMIT: a lightweight tag.
tag() {
  local tag=$1 commit=$2
  fixture "repos/$REPO/git/ref/tags/$tag" "{\"object\":{\"type\":\"commit\",\"sha\":\"$commit\"}}"
}

# annotated_tag TAG OBJECT [COMMIT]: an annotated tag; its tag object OBJECT
# exists only when COMMIT is given.
annotated_tag() {
  local tag=$1 object=$2 commit=${3:-}
  fixture "repos/$REPO/git/ref/tags/$tag" "{\"object\":{\"type\":\"tag\",\"sha\":\"$object\"}}"
  [[ -z $commit ]] || fixture "repos/$REPO/git/tags/$object" "{\"object\":{\"sha\":\"$commit\"}}"
}

# releases BODY: the first page of the list of releases.
releases() { fixture "repos/$REPO/releases?per_page=100" "$1"; }

# release TAG [PRERELEASE]: a published release. The API answers a draft by
# tag with HTTP 404, so a draft has no fixture.
release() {
  local tag=$1 prerelease=${2:-false}
  fixture "repos/$REPO/releases/tags/$tag" \
    "{\"draft\":false,\"prerelease\":$prerelease,\"html_url\":\"https://x/$tag\"}"
}

# released_at VERSION COMMIT: the manifest at SHA has VERSION, and its release
# is tagged at COMMIT.
released_at() {
  local version=$1 commit=$2
  manifest "$version"
  tag "v$version" "$commit"
  release "v$version"
}

# --- Runs and checks ---------------------------------------------------------

# run NAME EXPECTED SCRIPT: run an action script; EXPECTED is ok or fail.
run() {
  local name=$1 expected=$2 script=$3 status=0
  "$actions/$script" >"$work/stdout" 2>"$work/stderr" || status=$?
  current=$name
  if [[ $expected == fail && $status -eq 0 ]] || [[ $expected == ok && $status -ne 0 ]]; then
    report "expected $expected, exit status $status: $(cat "$work/stdout" "$work/stderr")"
  fi
}

# report MESSAGE: fail the current test.
report() {
  [[ -n $current ]] || return 0
  echo "FAIL $current: $1"
  failed=$((failed + 1))
  current=""
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

# finish: count the current test and remove its files.
finish() {
  if [[ -n $current ]]; then passed=$((passed + 1)); fi
  current=""
  rm -rf "$work"
}
