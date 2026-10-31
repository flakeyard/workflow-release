# shellcheck shell=bash
# Tests of release-state.

script=release-state/release-state.sh

setup
released_at 1.2.3 "$SHA"
run "release-state: release at the commit" ok "$script"
expect state released true
expect state tag v1.2.3
expect state major 1
expect state patch 3
expect state sha "$SHA"
expect state prerelease false
expect state release-url https://x/v1.2.3
finish

setup
released_at 1.2.3 bbb
run "release-state: release at another commit" ok "$script"
expect state released false
expect state tag ""
finish

setup
released_at 1.2.3 bbb
export RELEASE_FAILED=true
run "release-state: another commit after a failure warns" ok "$script"
expect state released false
expect message "rerun the run of bbb"
finish

setup
released_at 1.2.3 bbb
export CREATED=true CREATED_TAG=v1.2.3
run "release-state: released by this run at an older commit" ok "$script"
expect state released true
expect state sha bbb
finish

setup
released_at 1.2.3 bbb
export CREATED=true CREATED_TAG=v1.2.2
run "release-state: this run released another tag" ok "$script"
expect state released false
finish

setup
released_at 1.2.3 "$SHA"
export NEW_BRANCH=true
run "release-state: branch created at a release" ok "$script"
expect state released false
finish

setup
released_at 1.2.3 "$SHA"
export NEW_BRANCH=true CREATED=true CREATED_TAG=v1.2.3
run "release-state: branch push that released" ok "$script"
expect state released true
finish

setup
manifest 0.0.0
run "release-state: no release yet" ok "$script"
expect state released false
finish

setup
manifest 0.3.0
annotated_tag v0.3.0 t1 "$SHA"
release v0.3.0 true
run "release-state: annotated tag, pre-release" ok "$script"
expect state released true
expect state prerelease true
finish

setup
manifest 0.3.0
annotated_tag v0.3.0 t1
release v0.3.0 true
run "release-state: annotated tag object missing fails" fail "$script"
expect message "HTTP 404"
finish

setup
manifest 0.3.0
annotated_tag v0.3.0 t1
fixture "repos/$REPO/git/tags/t1" "HTTP 500"
release v0.3.0 true
run "release-state: annotated tag API error fails" fail "$script"
expect message "HTTP 500"
finish

setup
released_at 1.2.3 "$SHA"
late "repos/$REPO/git/ref/tags/v1.2.3"
export CREATED=true CREATED_TAG=v1.2.3
run "release-state: waits for the tag this run created" ok "$script"
expect state released true
expect state sha "$SHA"
finish

setup
manifest 1.2.3
release v1.2.3
export CREATED=true CREATED_TAG=v1.2.3
run "release-state: tag this run created never appears" fail "$script"
expect message "release-please created v1.2.3, but the tag does not exist"
finish

setup
manifest 1.2.3
tag v1.2.3 "$SHA"
# No release, or a draft: the API answers a draft by tag with HTTP 404.
run "release-state: tag without a published release" fail "$script"
expect message "has no published release"
finish

setup
manifest 1.2
run "release-state: version not X.Y.Z" fail "$script"
finish

setup
manifest 1.2.3
fixture "repos/$REPO/git/ref/tags/v1.2.3" "HTTP 500"
run "release-state: API error fails" fail "$script"
finish
