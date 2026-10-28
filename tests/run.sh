#!/usr/bin/env bash
# Unit tests of the scripts in .github/actions, with a stub of gh.
# Usage: tests/run.sh
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
actions=$root/.github/actions
failed=0 passed=0

# setup: fresh fixtures, calls, outputs and environment for one test.
setup() {
  work=$(mktemp -d)
  export FIXTURES=$work/fixtures CALLS=$work/calls GITHUB_OUTPUT=$work/output
  export GITHUB_STEP_SUMMARY=$work/summary PATH=$root/tests/bin:$PATH
  mkdir -p "$FIXTURES"
  : >"$CALLS"
  : >"$GITHUB_OUTPUT"
  export REPO=o/r SHA=aaa MANIFEST=.release-please-manifest.json CONFIG=release-please-config.json
  unset NEW_BRANCH CREATED CREATED_TAG CLIENT_ID HAS_KEY REF DEFAULT_BRANCH BASE OWNER WORKFLOW
}

# fixture PATH BODY: answer GET PATH with BODY.
fixture() { printf '%s\n' "$2" >"$FIXTURES/${1//[\/?&=]/_}"; }

# file_fixture PATH REF CONTENT: answer the contents API for a file.
file_fixture() {
  fixture "repos/o/r/contents/$1?ref=$2" "{\"content\":\"$(printf '%s' "$3" | base64 -w0)\"}"
}

# tag TAG COMMIT: a lightweight tag.
tag() { fixture "repos/o/r/git/ref/tags/$1" "{\"object\":{\"type\":\"commit\",\"sha\":\"$2\"}}"; }

# releases JSON: the releases list.
releases() { fixture "repos/o/r/releases" "$1"; }

# run NAME EXPECTED_STATUS SCRIPT: run an action script and check its status.
run() {
  local name=$1 expected=$2 status=0
  shift 2
  "$actions/$1" >"$work/stdout" 2>"$work/stderr" || status=$?
  if [[ $expected == fail && $status -ne 0 ]] || [[ $expected == ok && $status -eq 0 ]]; then
    current=$name
    return 0
  fi
  report "$name" "expected $expected, exit status $status: $(cat "$work/stdout" "$work/stderr")"
  return 1
}

report() {
  echo "FAIL $1: $2"
  failed=$((failed + 1))
  current=""
}

# expect KIND VALUE: check the output, a call or the absence of calls.
expect() {
  [[ -n ${current:-} ]] || return 0
  case $1 in
    output) grep -qxF -- "$2" "$GITHUB_OUTPUT" || {
      report "$current" "no output '$2' in: $(paste -sd' ' "$GITHUB_OUTPUT")"
      return
    } ;;
    call) grep -qF -- "$2" "$CALLS" || {
      report "$current" "no call '$2' in: $(paste -sd';' "$CALLS")"
      return
    } ;;
    no-calls) [[ ! -s $CALLS ]] || {
      report "$current" "unexpected calls: $(paste -sd';' "$CALLS")"
      return
    } ;;
    stdout) grep -qF -- "$2" "$work/stdout" || {
      report "$current" "no '$2' in stdout: $(cat "$work/stdout")"
      return
    } ;;
  esac
}

done_test() {
  if [[ -n ${current:-} ]]; then passed=$((passed + 1)); fi
  rm -rf "$work"
}

# --- check-inputs -----------------------------------------------------------

inputs_case() {
  setup
  export CLIENT_ID=$2 HAS_KEY=$3 REF=$4 DEFAULT_BRANCH=main
  run "check-inputs: $1" "$5" check-inputs/check-inputs.sh
  done_test
}
inputs_case "App on main" Iv1 true refs/heads/main ok
inputs_case "no App on release/v12" "" false refs/heads/release/v12 ok
inputs_case "client ID without key" Iv1 false refs/heads/main fail
inputs_case "key without client ID" "" true refs/heads/main fail
inputs_case "feature branch" "" false refs/heads/feature fail
inputs_case "release/v1x" "" false refs/heads/release/v1x fail
inputs_case "release/v0" "" false refs/heads/release/v0 fail

# --- check-config -----------------------------------------------------------

config_case() {
  setup
  file_fixture "$CONFIG" aaa "$2"
  local manifest='{".": "0.0.0"}'
  file_fixture "$MANIFEST" aaa "${4:-$manifest}"
  run "check-config: $1" "$3" check-config/check-config.sh
  done_test
}
config_case "supported" '{"include-component-in-tag":false,"packages":{".":{}}}' ok
config_case "package-level setting" '{"packages":{".":{"include-component-in-tag":false}}}' ok
config_case "component in tag by default" '{"packages":{".":{}}}' fail
config_case "no v in tag" '{"include-component-in-tag":false,"include-v-in-tag":false,"packages":{".":{}}}' fail
config_case "two packages" '{"include-component-in-tag":false,"packages":{".":{},"lib":{}}}' fail
config_case "draft" '{"include-component-in-tag":false,"draft":true,"packages":{".":{}}}' fail
config_case "custom label" '{"include-component-in-tag":false,"label":"x","packages":{".":{}}}' fail
config_case "manifest without root" '{"include-component-in-tag":false,"packages":{".":{}}}' fail '{"lib": "1.0.0"}'

# --- release-state ----------------------------------------------------------

release_fixture() {
  fixture "repos/o/r/releases/tags/$1" \
    "{\"draft\":${2:-false},\"prerelease\":${3:-false},\"html_url\":\"https://x/$1\"}"
}

setup
file_fixture "$MANIFEST" aaa '{".": "1.2.3"}'
tag v1.2.3 aaa
release_fixture v1.2.3
run "release-state: release at the commit" ok release-state/release-state.sh
expect output released=true
expect output tag=v1.2.3
expect output major=1
expect output patch=3
expect output sha=aaa
expect output prerelease=false
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "1.2.3"}'
tag v1.2.3 bbb
release_fixture v1.2.3
run "release-state: release at another commit" ok release-state/release-state.sh
expect output released=false
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "1.2.3"}'
tag v1.2.3 bbb
release_fixture v1.2.3
export CREATED=true CREATED_TAG=v1.2.3
run "release-state: released by this run at an older commit" ok release-state/release-state.sh
expect output released=true
expect output sha=bbb
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "1.2.3"}'
tag v1.2.3 aaa
release_fixture v1.2.3
export NEW_BRANCH=true
run "release-state: branch created at a release" ok release-state/release-state.sh
expect output released=false
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "0.0.0"}'
run "release-state: no release yet" ok release-state/release-state.sh
expect output released=false
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "0.3.0"}'
fixture "repos/o/r/git/ref/tags/v0.3.0" '{"object":{"type":"tag","sha":"t1"}}'
fixture "repos/o/r/git/tags/t1" '{"object":{"sha":"aaa"}}'
release_fixture v0.3.0 false true
run "release-state: annotated tag, pre-release" ok release-state/release-state.sh
expect output released=true
expect output prerelease=true
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "1.2.3"}'
tag v1.2.3 aaa
release_fixture v1.2.3 true
run "release-state: draft" ok release-state/release-state.sh
expect output released=false
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "1.2.3"}'
fixture "repos/o/r/git/ref/tags/v1.2.3" "HTTP 500"
run "release-state: API error fails" fail release-state/release-state.sh
done_test

# --- sync-major-tag ---------------------------------------------------------

sync_releases='[
  {"tag_name":"v1.9.0","draft":false,"prerelease":false},
  {"tag_name":"v1.10.0","draft":false,"prerelease":false},
  {"tag_name":"v1.11.0","draft":true,"prerelease":false},
  {"tag_name":"v2.0.0","draft":false,"prerelease":false},
  {"tag_name":"v0.1.0","draft":false,"prerelease":true},
  {"tag_name":"v0.2.0","draft":false,"prerelease":true}
]'

setup
file_fixture "$MANIFEST" aaa '{".": "1.10.0"}'
releases "$sync_releases"
tag v1.10.0 c110
run "sync-major-tag: creates a missing tag at the newest release" ok sync-major-tag/sync-major-tag.sh
expect call "POST repos/o/r/git/refs ref=refs/tags/v1 sha=c110"
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "1.10.0"}'
releases "$sync_releases"
tag v1.10.0 c110
tag v1 c110
run "sync-major-tag: already in place" ok sync-major-tag/sync-major-tag.sh
expect no-calls
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "1.10.0"}'
releases "$sync_releases"
tag v1.10.0 c110
tag v1 c19
fixture "repos/o/r/compare/c19...c110" '{"status":"ahead"}'
run "sync-major-tag: moves forward" ok sync-major-tag/sync-major-tag.sh
expect call "PATCH repos/o/r/git/refs/tags/v1 sha=c110 force=true"
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "1.10.0"}'
releases "$sync_releases"
tag v1.10.0 c110
tag v1 cnew
fixture "repos/o/r/compare/cnew...c110" '{"status":"behind"}'
run "sync-major-tag: never moves back" ok sync-major-tag/sync-major-tag.sh
expect no-calls
expect stdout "not moved"
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "0.2.0"}'
releases "$sync_releases"
tag v0.2.0 c020
run "sync-major-tag: v0 follows pre-releases" ok sync-major-tag/sync-major-tag.sh
expect call "POST repos/o/r/git/refs ref=refs/tags/v0 sha=c020"
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "3.0.0"}'
releases "$sync_releases"
run "sync-major-tag: no release of the major yet" ok sync-major-tag/sync-major-tag.sh
expect no-calls
done_test

setup
file_fixture "$MANIFEST" aaa '{".": "1.10.0"}'
releases "$sync_releases"
tag v1.10.0 c110
fixture "repos/o/r/git/ref/tags/v1" "HTTP 500"
run "sync-major-tag: API error fails" fail sync-major-tag/sync-major-tag.sh
done_test

# --- keep-latest ------------------------------------------------------------

latest_releases='[
  {"tag_name":"v2.0.0","id":20,"draft":false,"prerelease":false},
  {"tag_name":"v1.4.1","id":141,"draft":false,"prerelease":false}
]'

setup
releases "$latest_releases"
fixture "repos/o/r/releases/latest" '{"id":141}'
run "keep-latest: restores the newest" ok keep-latest/keep-latest.sh
expect call "PATCH repos/o/r/releases/20 make_latest=true"
done_test

setup
releases "$latest_releases"
fixture "repos/o/r/releases/latest" '{"id":20}'
run "keep-latest: nothing to do" ok keep-latest/keep-latest.sh
expect no-calls
done_test

# --- reconcile --------------------------------------------------------------

reconcile_prs='[
  {"number":5,"title":"chore(main): release 1.2.0","merged_at":"x","labels":[{"name":"autorelease: pending"}]},
  {"number":6,"title":"chore(main): release 1.3.0","merged_at":"x","labels":[{"name":"autorelease: pending"}]},
  {"number":7,"title":"chore(main): release 1.1.0","merged_at":"x","labels":[{"name":"autorelease: tagged"}]},
  {"number":8,"title":"chore(main): release 1.4.0","merged_at":null,"labels":[{"name":"autorelease: pending"}]}
]'

setup
export BASE=main
fixture "repos/o/r/pulls?state=closed&base=main&sort=updated&direction=desc&per_page=50" "$reconcile_prs"
release_fixture v1.2.0
run "reconcile: relabels only pending merged PRs whose release exists" ok reconcile/reconcile.sh
expect call "DELETE repos/o/r/issues/5/labels/autorelease:%20pending"
expect call "POST repos/o/r/issues/5/labels labels[]=autorelease: tagged"
if [[ -n ${current:-} ]] && grep -qE 'issues/(6|7|8)/' "$CALLS"; then report "$current" "touched other PRs: $(paste -sd';' "$CALLS")"; fi
done_test

# --- dispatch-checks --------------------------------------------------------

setup
export BASE=main OWNER=o WORKFLOW=check.yaml
fixture "repos/o/r/pulls?state=open&base=main&head=o:release-please--branches--main" '[{"number":9}]'
run "dispatch-checks: starts the check on the release PR" ok dispatch-checks/dispatch-checks.sh
expect call "workflow run check.yaml --repo o/r --ref release-please--branches--main"
done_test

setup
export BASE=main OWNER=o WORKFLOW=check.yaml
fixture "repos/o/r/pulls?state=open&base=main&head=o:release-please--branches--main" '[]'
run "dispatch-checks: no release PR" ok dispatch-checks/dispatch-checks.sh
expect no-calls
done_test

echo "passed: $passed, failed: $failed"
((failed == 0))
