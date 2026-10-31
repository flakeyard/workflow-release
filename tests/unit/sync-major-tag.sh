# shellcheck shell=bash
# Tests of sync-major-tag.

script=sync-major-tag/run.sh

# sync_setup VERSION: the manifest at VERSION and two pages of releases.
sync_setup() {
  local version=$1
  setup
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
run "sync-major-tag: creates a missing tag at the newest release" ok "$script"
expect call "POST repos/$REPO/git/refs ref=refs/tags/v1 sha=c110"
finish

sync_setup 1.10.0
tag v1.10.0 c110
tag v1 c110
run "sync-major-tag: already in place" ok "$script"
expect no-calls
finish

sync_setup 1.10.0
tag v1.10.0 c110
tag v1 c19
fixture "repos/$REPO/compare/c19...c110" '{"status":"ahead"}'
run "sync-major-tag: moves forward" ok "$script"
expect call "PATCH repos/$REPO/git/refs/tags/v1 sha=c110 force=true"
finish

sync_setup 1.10.0
tag v1.10.0 c110
annotated_tag v1 t1 c19
fixture "repos/$REPO/compare/c19...c110" '{"status":"ahead"}'
run "sync-major-tag: moves an annotated tag" ok "$script"
expect call "PATCH repos/$REPO/git/refs/tags/v1 sha=c110 force=true"
finish

for relation in behind diverged; do
  sync_setup 1.10.0
  tag v1.10.0 c110
  tag v1 cnew
  fixture "repos/$REPO/compare/cnew...c110" "{\"status\":\"$relation\"}"
  run "sync-major-tag: never moves when $relation" ok "$script"
  expect no-calls
  expect message "not moved"
  finish
done

sync_setup 2.0.0
tag v2.0.0 c200
run "sync-major-tag: newest release on a later page" ok "$script"
expect call "POST repos/$REPO/git/refs ref=refs/tags/v2 sha=c200"
finish

sync_setup 0.2.0
tag v0.2.0 c020
run "sync-major-tag: v0 follows pre-releases" ok "$script"
expect call "POST repos/$REPO/git/refs ref=refs/tags/v0 sha=c020"
finish

sync_setup 3.0.0
run "sync-major-tag: no release of the major yet" ok "$script"
expect no-calls
finish

sync_setup 1.10.0
run "sync-major-tag: newest release without a tag" fail "$script"
expect message "has no tag"
finish

sync_setup 1.10.0
tag v1.10.0 c110
fixture "repos/$REPO/git/ref/tags/v1" "HTTP 500"
run "sync-major-tag: API error fails" fail "$script"
finish

sync_setup 1.10.0
tag v1.10.0 c110
export FAIL_ON="POST repos/$REPO/git/refs 422"
run "sync-major-tag: creating the tag fails when it appeared meanwhile" fail "$script"
expect message "HTTP 422"
finish
