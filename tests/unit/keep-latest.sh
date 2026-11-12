# shellcheck shell=bash
# Tests of keep-latest.

step=keep-latest

# latest_setup: v2.0.0 is the newest release that is not a pre-release.
latest_setup() {
  start_test
  releases '[
    {"tag_name":"v2.0.0","id":20,"draft":false,"prerelease":false},
    {"tag_name":"v1.4.1","id":141,"draft":false,"prerelease":false},
    {"tag_name":"v3.0.0","id":30,"draft":false,"prerelease":true}
  ]'
}

latest_setup
fixture "repos/$REPO/releases/latest" '{"id":141}'
run_step "keep-latest: restores the newest" ok "$ACTIONS/$step" "$step"
expect call "PATCH repos/$REPO/releases/20 make_latest=true"
finish

latest_setup
fixture "repos/$REPO/releases/latest" '{"id":20}'
run_step "keep-latest: nothing to do" ok "$ACTIONS/$step" "$step"
expect no-calls
finish

latest_setup
run_step "keep-latest: no latest release yet" ok "$ACTIONS/$step" "$step"
expect call "PATCH repos/$REPO/releases/20 make_latest=true"
finish

start_test
releases '[{"tag_name":"v0.1.0","id":1,"draft":false,"prerelease":true}]'
run_step "keep-latest: only pre-releases" ok "$ACTIONS/$step" "$step"
expect no-calls
finish

latest_setup
fixture "repos/$REPO/releases/latest" "HTTP 500"
run_step "keep-latest: API error fails" fail "$ACTIONS/$step" "$step"
finish

# release-please never writes a leading zero, which arithmetic would read as
# octal.
start_test
releases '[
  {"tag_name":"v1.4.1","id":141,"draft":false,"prerelease":false},
  {"tag_name":"v02.0.0","id":20,"draft":false,"prerelease":false}
]'
fixture "repos/$REPO/releases/latest" '{"id":141}'
run_step "keep-latest: a tag with a leading zero is no release" ok "$ACTIONS/$step" "$step"
expect no-calls
finish

# Variables of the environment with the names of the constants of
# lib/version.sh, which an earlier step can set, do not change the rule.
latest_setup
apply RELEASE_VERSION=x VERSION_NUMBER=x RELEASE_TAG=x
fixture "repos/$REPO/releases/latest" '{"id":141}'
run_step "keep-latest: the environment does not replace the release rule" ok "$ACTIONS/$step" "$step"
expect call "PATCH repos/$REPO/releases/20 make_latest=true"
finish

latest_setup
fixture "repos/$REPO/releases/latest" '{"id":141}'
run_hostile "keep-latest: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect call "PATCH repos/$REPO/releases/20 make_latest=true"
expect summary "marked v2.0.0 as latest"
finish
