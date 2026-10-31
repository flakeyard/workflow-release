#!/usr/bin/env bash
# Unit tests of the scripts in .github/actions, with a stub of gh.
# Usage: tests/run.sh
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
actions=$root/.github/actions
failed=0 passed=0 current=""

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
}

# fixture PATH BODY: answer GET PATH with BODY.
fixture() { printf '%s\n' "$2" >"$FIXTURES/${1//[\/?&=]/_}"; }

# file_fixture PATH REF CONTENT: answer the contents API for a file, with the
# base64 wrapped at 60 characters like the API does.
file_fixture() {
  local encoded
  encoded=$(printf '%s' "$3" | base64 -w 60 | paste -sd '#' | sed 's/#/\\n/g')
  fixture "repos/o/r/contents/$1?ref=$2" "{\"content\":\"$encoded\"}"
}

manifest() { file_fixture "$MANIFEST" "${2:-aaa}" "{\".\": \"$1\"}"; }
tag() { fixture "repos/o/r/git/ref/tags/$1" "{\"object\":{\"type\":\"commit\",\"sha\":\"$2\"}}"; }
releases() { fixture "repos/o/r/releases" "$1"; }
# release TAG [PRERELEASE]: a published release. The API answers a draft by
# tag with HTTP 404, so a draft has no fixture.
release() {
  fixture "repos/o/r/releases/tags/$1" \
    "{\"draft\":false,\"prerelease\":${2:-false},\"html_url\":\"https://x/$1\"}"
}

# run NAME EXPECTED SCRIPT: run an action script; EXPECTED is ok or fail.
run() {
  local name=$1 expected=$2 status=0
  "$actions/$3" >"$work/stdout" 2>"$work/stderr" || status=$?
  current=$name
  if [[ $expected == fail && $status -eq 0 ]] || [[ $expected == ok && $status -ne 0 ]]; then
    report "expected $expected, exit status $status: $(cat "$work/stdout" "$work/stderr")"
  fi
}

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

# order FIRST SECOND: FIRST was called before SECOND.
order() {
  [[ -n $current ]] || return 0
  local a b
  a=$(grep -nF -- "$1" "$CALLS" | head -n 1 | cut -d: -f1)
  b=$(grep -nF -- "$2" "$CALLS" | head -n 1 | cut -d: -f1)
  [[ -n $a && -n $b && $a -lt $b ]] || report "'$1' not before '$2': $(paste -sd';' "$CALLS")"
}

finish() {
  if [[ -n $current ]]; then passed=$((passed + 1)); fi
  current=""
  rm -rf "$work"
}

# --- preflight: the run ------------------------------------------------------

inputs_case() {
  setup
  export EVENT=$2 CLIENT_ID=$3 HAS_KEY=$4 REF=$5 DEFAULT_BRANCH=$6
  run "preflight run: $1" "$7" preflight/check-inputs.sh
  [[ -z ${8:-} ]] || expect message "$8"
  finish
}
inputs_case "App on main" push Iv1 true refs/heads/main main ok
inputs_case "no App on release/v12" push "" false refs/heads/release/v12 main ok
inputs_case "default branch other than main" push "" false refs/heads/trunk trunk ok
inputs_case "client ID without key" push Iv1 false refs/heads/main main fail "APP_PRIVATE_KEY is empty"
inputs_case "key without client ID" push "" true refs/heads/main main fail "app-client-id is empty"
inputs_case "feature branch" push "" false refs/heads/feature main fail "only on main and release/vN"
inputs_case "release/v1x" push "" false refs/heads/release/v1x main fail
inputs_case "release/v0" push "" false refs/heads/release/v0 main fail
inputs_case "workflow_dispatch" workflow_dispatch "" false refs/heads/main "" fail "only on push events"

# --- preflight: the configuration --------------------------------------------

config_case() {
  setup
  file_fixture "$CONFIG" aaa "$2"
  manifest "${4:-0.0.0}"
  export REF=${5:-refs/heads/main}
  run "preflight config: $1" "$3" preflight/check-config.sh
  finish
}
ok='"include-component-in-tag":false,"packages":{".":{}}'
config_case "supported" "{$ok}" ok
config_case "package-level setting" '{"packages":{".":{"include-component-in-tag":false}}}' ok
config_case "component in tag by default" '{"packages":{".":{}}}' fail
config_case "package enables component in tag" '{"include-component-in-tag":false,"packages":{".":{"include-component-in-tag":true}}}' fail
config_case "no v in tag" "{\"include-v-in-tag\":false,$ok}" fail
config_case "package without v in tag" '{"include-component-in-tag":false,"packages":{".":{"include-v-in-tag":false}}}' fail
config_case "two packages" '{"include-component-in-tag":false,"packages":{".":{},"lib":{}}}' fail
config_case "draft" "{\"draft\":true,$ok}" fail
config_case "tag separator" "{\"tag-separator\":\"/\",$ok}" fail
config_case "custom label" "{\"label\":\"x\",$ok}" fail
config_case "custom release label" "{\"release-label\":\"x\",$ok}" fail
config_case "title pattern" "{\"pull-request-title-pattern\":\"x\",$ok}" fail
config_case "separate pull requests" "{\"separate-pull-requests\":true,$ok}" fail
config_case "component" '{"include-component-in-tag":false,"packages":{".":{"component":"c"}}}' fail
config_case "prerelease versioning" "{\"versioning\":\"prerelease\",$ok}" fail
config_case "skip releases" "{\"skip-github-release\":true,$ok}" fail
config_case "manifest version not X.Y.Z" "{$ok}" fail 1.2
config_case "release/v2 with version 2" "{$ok}" ok 2.1.0 refs/heads/release/v2
config_case "release/v1 with version 2" "{$ok}" fail 2.1.0 refs/heads/release/v1

setup
file_fixture "$CONFIG" aaa "{$ok}"
file_fixture "$MANIFEST" aaa '{"lib": "1.0.0"}'
run "preflight config: manifest without root" fail preflight/check-config.sh
finish

# --- release-state -----------------------------------------------------------

setup
manifest 1.2.3
tag v1.2.3 aaa
release v1.2.3
run "release-state: release at the commit" ok release-state/release-state.sh
expect state released true
expect state tag v1.2.3
expect state major 1
expect state patch 3
expect state sha aaa
expect state prerelease false
expect state release-url https://x/v1.2.3
finish

setup
manifest 1.2.3
tag v1.2.3 bbb
release v1.2.3
run "release-state: release at another commit" ok release-state/release-state.sh
expect state released false
expect state tag ""
finish

setup
manifest 1.2.3
tag v1.2.3 bbb
release v1.2.3
export RELEASE_FAILED=true
run "release-state: another commit after a failure warns" ok release-state/release-state.sh
expect state released false
expect message "rerun the run of bbb"
finish

setup
manifest 1.2.3
tag v1.2.3 bbb
release v1.2.3
export CREATED=true CREATED_TAG=v1.2.3
run "release-state: released by this run at an older commit" ok release-state/release-state.sh
expect state released true
expect state sha bbb
finish

setup
manifest 1.2.3
tag v1.2.3 bbb
release v1.2.3
export CREATED=true CREATED_TAG=v1.2.2
run "release-state: this run released another tag" ok release-state/release-state.sh
expect state released false
finish

setup
manifest 1.2.3
tag v1.2.3 aaa
release v1.2.3
export NEW_BRANCH=true
run "release-state: branch created at a release" ok release-state/release-state.sh
expect state released false
finish

setup
manifest 1.2.3
tag v1.2.3 aaa
release v1.2.3
export NEW_BRANCH=true CREATED=true CREATED_TAG=v1.2.3
run "release-state: branch push that released" ok release-state/release-state.sh
expect state released true
finish

setup
manifest 0.0.0
run "release-state: no release yet" ok release-state/release-state.sh
expect state released false
finish

setup
manifest 0.3.0
fixture "repos/o/r/git/ref/tags/v0.3.0" '{"object":{"type":"tag","sha":"t1"}}'
fixture "repos/o/r/git/tags/t1" '{"object":{"sha":"aaa"}}'
release v0.3.0 true
run "release-state: annotated tag, pre-release" ok release-state/release-state.sh
expect state released true
expect state prerelease true
finish

setup
manifest 0.3.0
fixture "repos/o/r/git/ref/tags/v0.3.0" '{"object":{"type":"tag","sha":"t1"}}'
release v0.3.0 true
run "release-state: annotated tag object missing fails" fail release-state/release-state.sh
expect message "HTTP 404"
finish

setup
manifest 0.3.0
fixture "repos/o/r/git/ref/tags/v0.3.0" '{"object":{"type":"tag","sha":"t1"}}'
fixture "repos/o/r/git/tags/t1" "HTTP 500"
release v0.3.0 true
run "release-state: annotated tag API error fails" fail release-state/release-state.sh
expect message "HTTP 500"
finish

setup
manifest 1.2.3
tag v1.2.3 aaa
mv "$FIXTURES/repos_o_r_git_ref_tags_v1.2.3" "$FIXTURES/repos_o_r_git_ref_tags_v1.2.3.late"
release v1.2.3
export CREATED=true CREATED_TAG=v1.2.3
run "release-state: waits for the tag this run created" ok release-state/release-state.sh
expect state released true
expect state sha aaa
finish

setup
manifest 1.2.3
release v1.2.3
export CREATED=true CREATED_TAG=v1.2.3
run "release-state: tag this run created never appears" fail release-state/release-state.sh
expect message "release-please created v1.2.3, but the tag does not exist"
finish

setup
manifest 1.2.3
tag v1.2.3 aaa
# A draft release: the API answers by tag with HTTP 404.
run "release-state: tag whose release is a draft" fail release-state/release-state.sh
expect message "has no published release"
finish

setup
manifest 1.2.3
tag v1.2.3 aaa
run "release-state: tag without release" fail release-state/release-state.sh
expect message "has no published release"
finish

setup
manifest 1.2
run "release-state: version not X.Y.Z" fail release-state/release-state.sh
finish

setup
manifest 1.2.3
fixture "repos/o/r/git/ref/tags/v1.2.3" "HTTP 500"
run "release-state: API error fails" fail release-state/release-state.sh
finish

# --- sync-major-tag ----------------------------------------------------------

sync_releases='[
  {"tag_name":"v1.9.0","draft":false,"prerelease":false},
  {"tag_name":"v1.10.0","draft":false,"prerelease":false},
  {"tag_name":"v1.11.0","draft":true,"prerelease":false},
  {"tag_name":"v0.1.0","draft":false,"prerelease":true}
]'

sync_setup() {
  setup
  manifest "$1"
  releases "$sync_releases"
  # A second page of releases.
  printf '%s\n' '[{"tag_name":"v2.0.0","draft":false,"prerelease":false},
    {"tag_name":"v0.2.0","draft":false,"prerelease":true}]' >"$FIXTURES/repos_o_r_releases.2"
}

sync_setup 1.10.0
tag v1.10.0 c110
run "sync-major-tag: creates a missing tag at the newest release" ok sync-major-tag/sync-major-tag.sh
expect call "POST repos/o/r/git/refs ref=refs/tags/v1 sha=c110"
finish

sync_setup 1.10.0
tag v1.10.0 c110
tag v1 c110
run "sync-major-tag: already in place" ok sync-major-tag/sync-major-tag.sh
expect no-calls
finish

sync_setup 1.10.0
tag v1.10.0 c110
tag v1 c19
fixture "repos/o/r/compare/c19...c110" '{"status":"ahead"}'
run "sync-major-tag: moves forward" ok sync-major-tag/sync-major-tag.sh
expect call "PATCH repos/o/r/git/refs/tags/v1 sha=c110 force=true"
finish

sync_setup 1.10.0
tag v1.10.0 c110
fixture "repos/o/r/git/ref/tags/v1" '{"object":{"type":"tag","sha":"t1"}}'
fixture "repos/o/r/git/tags/t1" '{"object":{"sha":"c19"}}'
fixture "repos/o/r/compare/c19...c110" '{"status":"ahead"}'
run "sync-major-tag: moves an annotated tag" ok sync-major-tag/sync-major-tag.sh
expect call "PATCH repos/o/r/git/refs/tags/v1 sha=c110 force=true"
finish

for relation in behind diverged; do
  sync_setup 1.10.0
  tag v1.10.0 c110
  tag v1 cnew
  fixture "repos/o/r/compare/cnew...c110" "{\"status\":\"$relation\"}"
  run "sync-major-tag: never moves when $relation" ok sync-major-tag/sync-major-tag.sh
  expect no-calls
  expect message "not moved"
  finish
done

sync_setup 2.0.0
tag v2.0.0 c200
run "sync-major-tag: newest release on a later page" ok sync-major-tag/sync-major-tag.sh
expect call "POST repos/o/r/git/refs ref=refs/tags/v2 sha=c200"
finish

sync_setup 0.2.0
tag v0.2.0 c020
run "sync-major-tag: v0 follows pre-releases" ok sync-major-tag/sync-major-tag.sh
expect call "POST repos/o/r/git/refs ref=refs/tags/v0 sha=c020"
finish

sync_setup 3.0.0
run "sync-major-tag: no release of the major yet" ok sync-major-tag/sync-major-tag.sh
expect no-calls
finish

sync_setup 1.10.0
run "sync-major-tag: newest release without a tag" fail sync-major-tag/sync-major-tag.sh
expect message "has no tag"
finish

sync_setup 1.10.0
tag v1.10.0 c110
fixture "repos/o/r/git/ref/tags/v1" "HTTP 500"
run "sync-major-tag: API error fails" fail sync-major-tag/sync-major-tag.sh
finish

sync_setup 1.10.0
tag v1.10.0 c110
export FAIL_ON="POST repos/o/r/git/refs 422"
run "sync-major-tag: creating the tag fails when it appeared meanwhile" fail sync-major-tag/sync-major-tag.sh
expect message "HTTP 422"
finish

# --- keep-latest -------------------------------------------------------------

latest_releases='[
  {"tag_name":"v2.0.0","id":20,"draft":false,"prerelease":false},
  {"tag_name":"v1.4.1","id":141,"draft":false,"prerelease":false},
  {"tag_name":"v3.0.0","id":30,"draft":false,"prerelease":true}
]'

setup
releases "$latest_releases"
fixture "repos/o/r/releases/latest" '{"id":141}'
run "keep-latest: restores the newest" ok keep-latest/keep-latest.sh
expect call "PATCH repos/o/r/releases/20 make_latest=true"
finish

setup
releases "$latest_releases"
fixture "repos/o/r/releases/latest" '{"id":20}'
run "keep-latest: nothing to do" ok keep-latest/keep-latest.sh
expect no-calls
finish

setup
releases "$latest_releases"
run "keep-latest: no latest release yet" ok keep-latest/keep-latest.sh
expect call "PATCH repos/o/r/releases/20 make_latest=true"
finish

setup
releases '[{"tag_name":"v0.1.0","id":1,"draft":false,"prerelease":true}]'
run "keep-latest: only pre-releases" ok keep-latest/keep-latest.sh
expect no-calls
finish

setup
releases "$latest_releases"
fixture "repos/o/r/releases/latest" "HTTP 500"
run "keep-latest: API error fails" fail keep-latest/keep-latest.sh
finish

# --- reconcile-pending-prs ---------------------------------------------------

pending='repos/o/r/issues?state=closed&labels=autorelease:%20pending&per_page=100'
pr() {
  fixture "repos/o/r/pulls/$1" "{\"base\":{\"ref\":\"$2\"},\"merge_commit_sha\":\"m$1\"}"
  manifest "$3" "m$1"
}

reconcile_setup() {
  setup
  export BASE=main
  fixture "$pending" '[
    {"number":5,"pull_request":{"merged_at":"x"}},
    {"number":6,"pull_request":{"merged_at":"x"}},
    {"number":8,"pull_request":{"merged_at":null}},
    {"number":9,"pull_request":{"merged_at":"x"}}
  ]'
  pr 5 main 1.2.0
  pr 6 main 1.3.0
  pr 9 release/v1 1.1.1
}

reconcile_setup
release v1.2.0
release v1.1.1
run "reconcile: relabels merged PRs into the branch whose release exists" ok reconcile-pending-prs/reconcile-pending-prs.sh
expect call "POST repos/o/r/issues/5/labels labels[]=autorelease: tagged"
expect call "DELETE repos/o/r/issues/5/labels/autorelease:%20pending"
order "POST repos/o/r/issues/5" "DELETE repos/o/r/issues/5"
expect no-call "issues/6/"
expect no-call "issues/8/"
expect no-call "issues/9/"
finish

reconcile_setup
release v1.2.0
# v1.3.0 is a draft: the API answers by tag with HTTP 404.
releases '[{"tag_name":"v1.3.0","draft":true,"prerelease":false}]'
run "reconcile: draft release" ok reconcile-pending-prs/reconcile-pending-prs.sh
expect call "POST repos/o/r/issues/5/labels"
expect no-call "issues/6/"
finish

reconcile_setup
release v1.2.0
export FAIL_ON="DELETE repos/o/r/issues/5/labels/autorelease:%20pending 404"
run "reconcile: pending label already removed" ok reconcile-pending-prs/reconcile-pending-prs.sh
expect call "DELETE repos/o/r/issues/5/labels/autorelease:%20pending"
finish

reconcile_setup
release v1.2.0
export FAIL_ON="DELETE repos/o/r/issues/5/labels/autorelease:%20pending"
run "reconcile: removing the label fails" fail reconcile-pending-prs/reconcile-pending-prs.sh
expect message "HTTP 502"
finish

reconcile_setup
release v1.2.0
export FAIL_ON="POST repos/o/r/issues/5/labels"
run "reconcile: adding the label fails" fail reconcile-pending-prs/reconcile-pending-prs.sh
expect no-call "DELETE"
finish

reconcile_setup
fixture "repos/o/r/releases/tags/v1.2.0" "HTTP 500"
run "reconcile: API error fails" fail reconcile-pending-prs/reconcile-pending-prs.sh
finish

setup
export BASE=main
fixture "$pending" '[]'
run "reconcile: nothing pending" ok reconcile-pending-prs/reconcile-pending-prs.sh
expect no-calls
finish

setup
export BASE=release/v1
fixture "$pending" '[{"number":9,"pull_request":{"merged_at":"x"}}]'
pr 9 release/v1 1.1.1
release v1.1.1
run "reconcile: release branch" ok reconcile-pending-prs/reconcile-pending-prs.sh
expect call "POST repos/o/r/issues/9/labels"
finish

# --- dispatch-checks ---------------------------------------------------------

dispatch_setup() {
  setup
  export BASE=$1 OWNER=o WORKFLOW=check.yaml
}

dispatch_setup main
fixture "repos/o/r/pulls?state=open&base=main&head=o:release-please--branches--main" '[{"number":9}]'
run "dispatch-checks: starts the check on the release PR" ok dispatch-checks/dispatch-checks.sh
expect call "workflow run check.yaml --repo o/r --ref release-please--branches--main"
finish

dispatch_setup release/v1
fixture "repos/o/r/pulls?state=open&base=release/v1&head=o:release-please--branches--release/v1" '[{"number":3}]'
run "dispatch-checks: release branch" ok dispatch-checks/dispatch-checks.sh
expect call "--ref release-please--branches--release/v1"
finish

dispatch_setup main
fixture "repos/o/r/pulls?state=open&base=main&head=o:release-please--branches--main" '[]'
run "dispatch-checks: no release PR" ok dispatch-checks/dispatch-checks.sh
expect no-calls
finish

dispatch_setup main
fixture "repos/o/r/pulls?state=open&base=main&head=o:release-please--branches--main" "HTTP 500"
run "dispatch-checks: API error fails" fail dispatch-checks/dispatch-checks.sh
finish

echo "passed: $passed, failed: $failed"
((failed == 0))
