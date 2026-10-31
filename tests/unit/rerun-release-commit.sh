# shellcheck shell=bash
# Tests of rerun-release-commit.

script=rerun-release-commit/rerun-release-commit.sh
# When this run first started, and a release published before and after it.
started=2026-10-31T12:00:00Z before=2026-10-31T11:00:00Z after=2026-10-31T12:01:00Z

# runs_path: the push runs of workflow 5 at COMMIT on BRANCH.
runs_path() {
  printf '%s\n' "repos/$REPO/actions/workflows/5/runs?branch=$BRANCH&event=push&head_sha=$COMMIT&per_page=1"
}

# commit_run_fixture STATUS: the run 77 of COMMIT has STATUS.
commit_run_fixture() {
  local status=$1
  fixture "repos/$REPO/actions/runs/77" "{\"id\":77,\"status\":\"$status\"}"
}

# rerun_setup [NAME=VALUE...]: this run 100 of workflow 5 created v1.2.3 at
# bbb, whose completed run is 77; the values override that.
rerun_setup() {
  setup
  export RUN_ID=100 BRANCH=main TAG=v1.2.3 COMMIT=bbb CREATED=true
  apply "$@"
  fixture "repos/$REPO/actions/runs/100" '{"id":100,"workflow_id":5}'
  fixture "repos/$REPO/actions/runs/100/attempts/1" "{\"run_started_at\":\"$started\"}"
  fixture "$(runs_path)" '{"workflow_runs":[{"id":77,"html_url":"https://x/runs/77"}]}'
  commit_run_fixture completed
}

# release_published_at TIME: the release of TAG was published at TIME.
release_published_at() {
  local time=$1
  fixture "repos/$REPO/releases/tags/$TAG" "{\"draft\":false,\"published_at\":\"$time\"}"
}

rerun_setup
run "rerun-release-commit: reruns the run of the release commit" ok "$script"
expect call "POST repos/$REPO/actions/runs/77/rerun"
expect message "::notice::reran https://x/runs/77, the run of bbb, to publish v1.2.3"
finish

rerun_setup BRANCH=release/v1
run "rerun-release-commit: release branch" ok "$script"
expect call "POST repos/$REPO/actions/runs/77/rerun"
finish

rerun_setup
commit_run_fixture in_progress
later "repos/$REPO/actions/runs/77" '{"id":77,"status":"completed"}'
run "rerun-release-commit: waits for the run to complete" ok "$script"
expect call "POST repos/$REPO/actions/runs/77/rerun"
finish

rerun_setup
commit_run_fixture in_progress
run "rerun-release-commit: run still in progress fails" fail "$script"
expect message "is still running; when it completes, rerun it to publish v1.2.3"
expect no-calls
finish

rerun_setup
fixture "$(runs_path)" '{"workflow_runs":[]}'
run "rerun-release-commit: no run of the release commit fails" fail "$script"
expect message "no push run of this workflow at bbb on main; publish v1.2.3 from bbb by hand"
expect no-calls
finish

rerun_setup FAIL_ON="POST repos/o/r/actions/runs/77/rerun 403"
run "rerun-release-commit: rerun refused fails" fail "$script"
expect message "could not rerun https://x/runs/77"
expect message "HTTP 403"
finish

rerun_setup CREATED=false
release_published_at "$after"
run "rerun-release-commit: published after a failure in this run" ok "$script"
expect call "POST repos/$REPO/actions/runs/77/rerun"
finish

rerun_setup CREATED=false
release_published_at "$before"
run "rerun-release-commit: published before this run" ok "$script"
expect no-calls
finish

rerun_setup CREATED=false
run "rerun-release-commit: no published release" ok "$script"
expect no-calls
finish

rerun_setup
fixture "repos/$REPO/actions/runs/100" "HTTP 500"
run "rerun-release-commit: API error fails" fail "$script"
expect no-calls
finish
