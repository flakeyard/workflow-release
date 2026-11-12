# shellcheck shell=bash
# Tests of rerun-release-commit.

step=rerun-release-commit
# When this run first started, and a release published before and after it.
started=2026-10-31T12:00:00Z before=2026-10-31T11:00:00Z after=2026-10-31T12:01:00Z

# The release that this run created, and its commit.
tag=v1.2.3 commit=bbb

# commit_run_fixture STATUS: the run 77 of the release commit has STATUS.
commit_run_fixture() {
  local status=$1
  fixture "repos/$REPO/actions/runs/77" "{\"id\":77,\"status\":\"$status\"}"
}

# commit_runs_fixture BRANCH: run 77 is the push run of the release commit on
# BRANCH.
commit_runs_fixture() {
  local branch=$1
  fixture "$(commit_runs_path "$branch" "$commit")" '{"workflow_runs":[{"id":77,"html_url":"https://x/runs/77"}]}'
}

# rerun_setup [NAME=VALUE...]: this run 100 of workflow 5 on main created the
# release, whose completed run is 77; the values override that.
rerun_setup() {
  start_test
  apply RUN_ID=100 BRANCH=main TAG="$tag" COMMIT="$commit" CREATED=true
  apply "$@"
  fixture "repos/$REPO/actions/runs/100" '{"id":100,"workflow_id":5}'
  fixture "repos/$REPO/actions/runs/100/attempts/1" "{\"run_started_at\":\"$started\"}"
  commit_runs_fixture main
  commit_run_fixture completed
}

# release_published_at TIME: the release was published at TIME.
release_published_at() {
  local time=$1
  fixture "repos/$REPO/releases/tags/$tag" "{\"draft\":false,\"published_at\":\"$time\"}"
}

rerun_setup
run_step "rerun-release-commit: reruns the run of the release commit" ok "$ACTIONS/$step" "$step"
expect call "POST repos/$REPO/actions/runs/77/rerun"
expect message "::notice::reran https://x/runs/77, the run of bbb, to publish v1.2.3"
finish

rerun_setup BRANCH=release/v1
commit_runs_fixture release/v1
run_step "rerun-release-commit: release branch" ok "$ACTIONS/$step" "$step"
expect call "POST repos/$REPO/actions/runs/77/rerun"
finish

rerun_setup
commit_run_fixture in_progress
later "repos/$REPO/actions/runs/77" '{"id":77,"status":"completed"}'
run_step "rerun-release-commit: waits for the run to complete" ok "$ACTIONS/$step" "$step"
expect call "POST repos/$REPO/actions/runs/77/rerun"
finish

rerun_setup
commit_run_fixture in_progress
run_step "rerun-release-commit: run still in progress fails" fail "$ACTIONS/$step" "$step"
expect message "is still running; when it completes, rerun it to publish v1.2.3"
expect no-calls
finish

rerun_setup
fixture "$(commit_runs_path main "$commit")" '{"workflow_runs":[]}'
run_step "rerun-release-commit: no run of the release commit fails" fail "$ACTIONS/$step" "$step"
expect message "no push run of this workflow at bbb on main: v1.2.3 is released but the run of its commit cannot publish it; cut the next patch release"
expect no-message abandon
expect no-calls
finish

rerun_setup FAIL_ON="POST repos/o/r/actions/runs/77/rerun 403"
run_step "rerun-release-commit: rerun refused fails" fail "$ACTIONS/$step" "$step"
expect message "could not rerun https://x/runs/77"
expect message "rerun it, or if it cannot be rerun: v1.2.3 is released but the run of its commit cannot publish it; cut the next patch release"
expect no-message abandon
expect message "HTTP 403"
finish

rerun_setup CREATED=false
release_published_at "$after"
run_step "rerun-release-commit: published after a failure in this run" ok "$ACTIONS/$step" "$step"
expect call "POST repos/$REPO/actions/runs/77/rerun"
finish

rerun_setup CREATED=false
release_published_at "$before"
run_step "rerun-release-commit: published before this run" ok "$ACTIONS/$step" "$step"
expect no-calls
finish

rerun_setup CREATED=false
run_step "rerun-release-commit: no published release" ok "$ACTIONS/$step" "$step"
expect no-calls
finish

rerun_setup
fixture "repos/$REPO/actions/runs/100" "HTTP 500"
run_step "rerun-release-commit: API error fails" fail "$ACTIONS/$step" "$step"
expect no-calls
finish

rerun_setup
run_hostile "rerun-release-commit: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect call "POST repos/$REPO/actions/runs/77/rerun"
expect summary "reran https://x/runs/77 to publish v1.2.3"
finish
