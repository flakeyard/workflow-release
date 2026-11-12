# shellcheck shell=bash
# Tests of dispatch-checks.

step=dispatch-checks

# dispatch_setup BASE BODY: the open release pull requests into BASE are BODY.
dispatch_setup() {
  local base=$1 body=$2
  start_test
  apply BASE="$base" OWNER=o WORKFLOW=check.yaml
  fixture "repos/$REPO/pulls?state=open&base=$base&head=o:release-please--branches--$base" "$body"
}

dispatch_setup main '[{"number":9}]'
run_step "dispatch-checks: starts the check on the release PR" ok "$ACTIONS/$step" "$step"
expect call "workflow run check.yaml --repo $REPO --ref release-please--branches--main"
finish

dispatch_setup release/v1 '[{"number":3}]'
run_step "dispatch-checks: release branch" ok "$ACTIONS/$step" "$step"
expect call "--ref release-please--branches--release/v1"
finish

dispatch_setup main '[]'
run_step "dispatch-checks: no release PR" ok "$ACTIONS/$step" "$step"
expect no-calls
finish

dispatch_setup main '[{"number":9}]'
transient_failures "repos/$REPO/pulls?state=open&base=main&head=o:release-please--branches--main" 1
run_step "dispatch-checks: a transient error is retried" ok "$ACTIONS/$step" "$step"
expect sleeps 5
expect call "workflow run check.yaml"
finish

dispatch_setup main "HTTP 500"
run_step "dispatch-checks: API error fails" fail "$ACTIONS/$step" "$step"
finish

dispatch_setup main '[{"number":9}]'
run_hostile "dispatch-checks: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect call "workflow run check.yaml --repo $REPO --ref release-please--branches--main"
expect summary "started check.yaml on #9 (release-please--branches--main)"
finish
