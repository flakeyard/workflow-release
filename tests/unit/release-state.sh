# shellcheck shell=bash
# Tests of release-state.

script=.github/actions/release-state/run.sh

start_test
released_at 1.2.3 "$SHA"
run "release-state: release at the commit" ok "$script"
expect_state released true
expect_state tag v1.2.3
expect_state major 1
expect_state patch 3
expect_state sha "$SHA"
expect_state prerelease false
expect_state release-url https://x/v1.2.3
finish

start_test
released_at 1.2.3 bbb
run "release-state: release at another commit" ok "$script"
expect_state released false
expect_state tag ""
expect output elsewhere-tag ""
finish

start_test
released_at 1.2.3 bbb
apply RELEASE_FAILED=true
run "release-state: another commit after a failure may be this run's" ok "$script"
expect_state released false
expect output elsewhere-tag v1.2.3
expect output elsewhere-sha bbb
expect output elsewhere-created false
expect message "the run of bbb publishes it"
finish

start_test
released_at 1.2.3 bbb
apply CREATED=true CREATED_TAG=v1.2.3
run "release-state: released by this run at an older commit" ok "$script"
expect_state released false
expect_state sha ""
expect output elsewhere-tag v1.2.3
expect output elsewhere-sha bbb
expect output elsewhere-created true
expect message "v1.2.3 was released at bbb, not at aaa"
finish

start_test
released_at 1.2.3 "$SHA"
apply CREATED=true CREATED_TAG=v1.2.3
run "release-state: released by this run at its commit" ok "$script"
expect_state released true
expect output elsewhere-tag ""
finish

# A takeover in this run released v1.3.0 at its merge commit m5, which SHA
# reverted: the manifest at SHA is back at 1.2.3.
start_test
released_at 1.2.3 bbb
tag v1.3.0 m5
release v1.3.0
apply CREATED=true CREATED_TAG=v1.3.0
run "release-state: this run released another tag" ok "$script"
expect_state released false
expect output elsewhere-tag v1.3.0
expect output elsewhere-sha m5
expect output elsewhere-created true
expect message "v1.3.0 was released at m5, not at aaa"
finish

start_test
released_at 1.2.3 "$SHA"
tag v1.3.0 m5
release v1.3.0
apply CREATED=true CREATED_TAG=v1.3.0
run "release-state: this run released another tag, the commit is released" ok "$script"
expect_state released true
expect_state tag v1.2.3
expect output elsewhere-tag v1.3.0
expect output elsewhere-sha m5
finish

start_test
released_at 1.2.3 bbb
tag v1.3.0 m5
late "repos/$REPO/git/ref/tags/v1.3.0"
apply CREATED=true CREATED_TAG=v1.3.0
run "release-state: waits for another tag this run created" ok "$script"
expect output elsewhere-tag v1.3.0
expect output elsewhere-sha m5
finish

start_test
released_at 1.2.3 bbb
apply CREATED=true CREATED_TAG=v1.3.0
run "release-state: another tag this run created never appears" fail "$script"
expect message "release-please created v1.3.0, but the tag does not exist"
finish

start_test
released_at 1.2.3 bbb
tag v1.3.0 "$SHA"
apply CREATED=true CREATED_TAG=v1.3.0
run "release-state: another tag this run created at its commit fails" fail "$script"
expect message "release-please created v1.3.0 at aaa, whose manifest has 1.2.3"
expect output elsewhere-tag ""
finish

start_test
released_at 1.2.3 bbb
apply CREATED=true CREATED_TAG=../v1.3.0
run "release-state: another tag this run created is not vX.Y.Z" fail "$script"
expect message "release-please created '../v1.3.0', not a tag vX.Y.Z"
expect output elsewhere-tag ""
finish

start_test
released_at 1.2.3 "$SHA"
apply NEW_BRANCH=true
run "release-state: branch created at a release" ok "$script"
expect_state released false
finish

start_test
released_at 1.2.3 "$SHA"
apply NEW_BRANCH=true CREATED=true CREATED_TAG=v1.2.3
run "release-state: branch push that released" ok "$script"
expect_state released true
finish

start_test
manifest 0.0.0
run "release-state: no release yet" ok "$script"
expect_state released false
finish

start_test
manifest 0.3.0
annotated_tag v0.3.0 t1 "$SHA"
release v0.3.0 true
run "release-state: annotated tag, pre-release" ok "$script"
expect_state released true
expect_state prerelease true
finish

start_test
manifest 0.3.0
annotated_tag v0.3.0 t1
release v0.3.0 true
run "release-state: annotated tag object missing fails" fail "$script"
expect message "HTTP 404"
finish

start_test
manifest 0.3.0
annotated_tag v0.3.0 t1
fixture "repos/$REPO/git/tags/t1" "HTTP 500"
release v0.3.0 true
run "release-state: annotated tag API error fails" fail "$script"
expect message "HTTP 500"
finish

start_test
released_at 1.2.3 "$SHA"
late "repos/$REPO/git/ref/tags/v1.2.3"
apply CREATED=true CREATED_TAG=v1.2.3
run "release-state: waits for the tag this run created" ok "$script"
expect_state released true
expect_state sha "$SHA"
finish

start_test
manifest 1.2.3
release v1.2.3
apply CREATED=true CREATED_TAG=v1.2.3
run "release-state: tag this run created never appears" fail "$script"
expect message "release-please created v1.2.3, but the tag does not exist"
finish

start_test
manifest 1.2.3
tag v1.2.3 "$SHA"
# No release, or a draft: the API answers a draft by tag with HTTP 404.
run "release-state: tag without a published release" fail "$script"
expect message "has no published release"
finish

start_test
manifest 1.2
run "release-state: version not X.Y.Z" fail "$script"
finish

start_test
manifest 1.2.3
fixture "repos/$REPO/git/ref/tags/v1.2.3" "HTTP 500"
run "release-state: API error fails" fail "$script"
finish

start_test
run "release-state: a missing manifest is named" fail "$script"
expect message "$MANIFEST does not exist at $SHA"
finish
