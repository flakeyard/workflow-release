# shellcheck shell=bash
# Tests of release-pr: the pause before the retry of release-please.

step=pause
# The pause restates RETRY_PAUSE_SECONDS of the script as an independent
# oracle.
readonly RETRY_PAUSE=30

start_test
run_step "release-pr: pauses before the retry" ok "$ACTIONS/release-pr" "$step"
expect sleeps "$RETRY_PAUSE"
finish

start_test
run_hostile "release-pr: earlier steps of the job run no code in it" ok "$ACTIONS/release-pr" "$step"
expect sleeps "$RETRY_PAUSE"
finish
