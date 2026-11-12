# shellcheck shell=bash
# Tests of sync-major-tag.

step=sync-major-tag

# sync_setup VERSION: the manifest at VERSION and two pages of releases.
sync_setup() {
  local version=$1
  start_test
  manifest "$version"
  releases '[
    {"tag_name":"v1.9.0","draft":false,"prerelease":false},
    {"tag_name":"v1.10.0","draft":false,"prerelease":false},
    {"tag_name":"v1.11.0","draft":true,"prerelease":false},
    {"tag_name":"v0.1.0","draft":false,"prerelease":true}
  ]'
  next_page "repos/$REPO/releases?per_page=100" 2 '[
    {"tag_name":"v2.0.0","draft":false,"prerelease":false},
    {"tag_name":"v0.2.0","draft":false,"prerelease":true}
  ]'
}

sync_setup 1.10.0
tag v1.10.0 c110
run_step "sync-major-tag: creates a missing tag at the newest release" ok "$ACTIONS/$step" "$step"
expect call "POST repos/$REPO/git/refs ref=refs/tags/v1 sha=c110"
finish

sync_setup 1.10.0
tag v1.10.0 c110
tag v1 c110
run_step "sync-major-tag: already in place" ok "$ACTIONS/$step" "$step"
expect no-calls
finish

sync_setup 1.10.0
tag v1.10.0 c110
tag v1 c19
fixture "repos/$REPO/compare/c19...c110" '{"status":"ahead"}'
run_step "sync-major-tag: moves forward" ok "$ACTIONS/$step" "$step"
expect call "PATCH repos/$REPO/git/refs/tags/v1 sha=c110 force=true"
finish

sync_setup 1.10.0
tag v1.10.0 c110
tag v1 c19
fixture "repos/$REPO/compare/c19...c110" '{"status":"ahead"}'
transient_failures "repos/$REPO/compare/c19...c110" 1
run_step "sync-major-tag: a transient error of the comparison is retried" ok "$ACTIONS/$step" "$step"
expect sleeps 5
expect call "PATCH repos/$REPO/git/refs/tags/v1 sha=c110 force=true"
finish

sync_setup 1.10.0
tag v1.10.0 c110
annotated_tag v1 t1 c19
fixture "repos/$REPO/compare/c19...c110" '{"status":"ahead"}'
run_step "sync-major-tag: moves an annotated tag" ok "$ACTIONS/$step" "$step"
expect call "PATCH repos/$REPO/git/refs/tags/v1 sha=c110 force=true"
finish

for relation in behind diverged; do
  sync_setup 1.10.0
  tag v1.10.0 c110
  tag v1 cnew
  fixture "repos/$REPO/compare/cnew...c110" "{\"status\":\"$relation\"}"
  run_step "sync-major-tag: never moves when $relation" ok "$ACTIONS/$step" "$step"
  expect no-calls
  expect message "not moved"
  finish
done

sync_setup 2.0.0
tag v2.0.0 c200
run_step "sync-major-tag: newest release on a later page" ok "$ACTIONS/$step" "$step"
expect call "POST repos/$REPO/git/refs ref=refs/tags/v2 sha=c200"
finish

sync_setup 2.0.0
tag v2.0.0 c200
transient_failures "repos/$REPO/releases?per_page=100" 1
run_step "sync-major-tag: a transient error of the list of releases is retried" ok "$ACTIONS/$step" "$step"
expect sleeps 5
expect call "POST repos/$REPO/git/refs ref=refs/tags/v2 sha=c200"
finish

sync_setup 0.2.0
tag v0.2.0 c020
run_step "sync-major-tag: v0 follows pre-releases" ok "$ACTIONS/$step" "$step"
expect call "POST repos/$REPO/git/refs ref=refs/tags/v0 sha=c020"
finish

sync_setup 3.0.0
run_step "sync-major-tag: no release of the major yet" ok "$ACTIONS/$step" "$step"
expect no-calls
finish

sync_setup 1.10.0
run_step "sync-major-tag: newest release without a tag" fail "$ACTIONS/$step" "$step"
expect message "has no tag"
finish

sync_setup 1.10.0
tag v1.10.0 c110
fixture "repos/$REPO/git/ref/tags/v1" "HTTP 500"
run_step "sync-major-tag: API error fails" fail "$ACTIONS/$step" "$step"
finish

sync_setup 1.10.0
tag v1.10.0 c110
apply FAIL_ON="POST repos/$REPO/git/refs 422"
run_step "sync-major-tag: creating the tag fails when it appeared meanwhile" fail "$ACTIONS/$step" "$step"
expect message "HTTP 422"
finish

sync_setup 1.10
run_step "sync-major-tag: version not X.Y.Z fails" fail "$ACTIONS/$step" "$step"
expect message "the root version must be X.Y.Z, not '1.10'"
expect no-calls
finish

start_test
run_step "sync-major-tag: a missing manifest is named" fail "$ACTIONS/$step" "$step"
expect message "$MANIFEST does not exist at $SHA"
finish

sync_setup 1.10.0
tag v1.10.0 c110
run_hostile "sync-major-tag: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect call "POST repos/$REPO/git/refs ref=refs/tags/v1 sha=c110"
expect summary "created v1 at v1.10.0"
finish
