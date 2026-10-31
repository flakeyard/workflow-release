# shellcheck shell=bash
# Tests of keep-latest.

script=keep-latest/run.sh

# latest_setup: v2.0.0 is the newest release that is not a pre-release.
latest_setup() {
  setup
  releases '[
    {"tag_name":"v2.0.0","id":20,"draft":false,"prerelease":false},
    {"tag_name":"v1.4.1","id":141,"draft":false,"prerelease":false},
    {"tag_name":"v3.0.0","id":30,"draft":false,"prerelease":true}
  ]'
}

latest_setup
fixture "repos/$REPO/releases/latest" '{"id":141}'
run "keep-latest: restores the newest" ok "$script"
expect call "PATCH repos/$REPO/releases/20 make_latest=true"
finish

latest_setup
fixture "repos/$REPO/releases/latest" '{"id":20}'
run "keep-latest: nothing to do" ok "$script"
expect no-calls
finish

latest_setup
run "keep-latest: no latest release yet" ok "$script"
expect call "PATCH repos/$REPO/releases/20 make_latest=true"
finish

setup
releases '[{"tag_name":"v0.1.0","id":1,"draft":false,"prerelease":true}]'
run "keep-latest: only pre-releases" ok "$script"
expect no-calls
finish

latest_setup
fixture "repos/$REPO/releases/latest" "HTTP 500"
run "keep-latest: API error fails" fail "$script"
finish
