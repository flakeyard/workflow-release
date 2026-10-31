# shellcheck shell=bash
# Tests of dispatch-checks.

script=dispatch-checks/dispatch-checks.sh

# dispatch_setup BASE BODY: the open release pull requests into BASE are BODY.
dispatch_setup() {
  local base=$1 body=$2
  setup
  export BASE=$base OWNER=o WORKFLOW=check.yaml
  fixture "repos/$REPO/pulls?state=open&base=$base&head=$OWNER:release-please--branches--$base" "$body"
}

dispatch_setup main '[{"number":9}]'
run "dispatch-checks: starts the check on the release PR" ok "$script"
expect call "workflow run check.yaml --repo $REPO --ref release-please--branches--main"
finish

dispatch_setup release/v1 '[{"number":3}]'
run "dispatch-checks: release branch" ok "$script"
expect call "--ref release-please--branches--release/v1"
finish

dispatch_setup main '[]'
run "dispatch-checks: no release PR" ok "$script"
expect no-calls
finish

dispatch_setup main "HTTP 500"
run "dispatch-checks: API error fails" fail "$script"
finish
