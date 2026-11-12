---
id: ADR-0001
title: Run the steps of internal actions through run-step.sh
status: accepted
date: 2026-11-12
supersedes: []
superseded_by: []
related: []
affects: [".github/actions/**", ".github/workflows/release.yaml", "tests/**"]
review_by:
---

## Context

Each job of `release.yaml` calls [action-shell-lib][asl-0001] once, as its first
step, and gives its directory to the internal actions of `.github/actions` as
the input `shell-lib`. Each action runs its `run.sh`, or `preflight/inputs.sh`
and `preflight/config.sh`, from `shell: bash`, with every variable of the job,
and the script sources the modules of the library and of `.github/actions/lib`.
`release-pr` pauses before its retry with `sleep 30` from `shell: bash`.

An earlier step of a job can set any variable for the steps after it, through
`GITHUB_ENV` and `GITHUB_PATH`. `BASH_ENV` then runs a file before the script,
exported functions (`BASH_FUNC_name%%`) replace commands such as `jq` or
`source`, `SHELLOPTS` and `PS4` run code, `BASH_SOURCE` names another directory
to source from, and `PATH` puts other tools first. Today every step of the jobs
of `release.yaml` is pinned code of flakeyard, of release-please or of
create-github-app-token, but any of them, or a later change of a job, could
steer every script of the workflow, with the token of its job; in the job
`Release`, with the token of the App.

[FY-0035][fy-0035] and [action-shell-lib ADR-0001][asl-0001] answer this threat
for consumers of the library: `run-step.sh STEP_DIR STEP [VARIABLE...]` runs the
script `STEP_DIR/STEP.sh` with `/usr/bin/env -i` and `/usr/bin/bash -p`, with
only the variables named on the run line of the step and `SHELL_LIB`, and finds
its own modules from `$0`. `step_environment` of `env.sh` then sets `PATH` to
`SYSTEM_PATH`, the tools of the runner, and keeps the `PATH` of the job in
`JOB_PATH`. action-setup-nix, action-flake-lock and workflow-check run every
step of their actions this way.

## Decision

Every step of an internal action that runs a script runs it through
`run-step.sh` of the library that the job passes, with an explicit list of
variables:

```yaml
- shell: /usr/bin/bash --noprofile --norc -p -e -o pipefail {0}
  env:
    SHELL_LIB: ${{ inputs.shell-lib }}
    GH_TOKEN: ${{ inputs.token }}
    REPO: ${{ github.repository }}
  run: >-
    /usr/bin/bash -p "$SHELL_LIB/run-step.sh" "$GITHUB_ACTION_PATH/scripts/step"
    keep-latest GH_TOKEN REPO GITHUB_STEP_SUMMARY
```

- **Layout.** The script of a step is
  `.github/actions/<action>/scripts/step/<step>.sh`, the layout that the library
  documents for its consumers. An action with one script names it after the
  action. `preflight` keeps its two steps, `inputs` and `config`, since the
  second needs the token and runs only when the first does not skip the run;
  `release-pr` gets the input `shell-lib` and pauses before its retry with the
  step `pause`. Helpers that only this repository uses stay in
  `.github/actions/lib`.
- **Variables.** The run line names every variable that the script reads: its
  inputs from `env`, and the variables of the runner that it needs, such as
  `GITHUB_OUTPUT`, `GITHUB_STEP_SUMMARY` and `GH_TOKEN`. A script that does not
  call the API gets no token.
- **Environment.** A script sources `env.sh` of the library and runs
  `step_environment` before any command that is not a builtin. It finds its own
  files from `$0`, never from `BASH_SOURCE`. `gh`, `jq`, `date`, `sleep` and
  coreutils come from `SYSTEM_PATH`; no script runs a tool of the job, and one
  that needs one finds it with `job_tool` of `env.sh`.
- **Key.** The internal actions keep running from the repository of the
  workflow, through `$/`; the job `Release`, which holds the key, still checks
  out and runs no code of the calling repository ([FY-0030][fy-0030]).
- **Tests.** The unit tests run each script as its step does, with `run_step` of
  `internal/testing/consumer/step.sh` of the pinned library: through
  `run-step.sh` of a copy of that library made by `copy_library`, with only the
  variables of its run line and of the stubs, so that a variable missing from
  the run line fails them. For each step, `run_hostile` gives it a hostile
  environment: `BASH_ENV`, exported functions, `SHELLOPTS` and `PS4` that run
  code, and a `BASH_SOURCE` that names a directory of hostile modules; none of
  it may run. `check_action_steps` of the library checks that every step of an
  internal action that runs a script has the shell and run line above, with
  every variable of its `env` named on its run line.

## Constraints

- Every step of an internal action that does not use another action MUST run
  `/usr/bin/bash -p "$SHELL_LIB/run-step.sh"` with the arguments
  `"$GITHUB_ACTION_PATH/scripts/step" <step> [VARIABLE...]`, from
  `shell: /usr/bin/bash --noprofile --norc -p -e -o pipefail {0}`, with
  `SHELL_LIB` set to `${{ inputs.shell-lib }}` in its `env`.
- The run line MUST name every variable of the step's `env` other than
  `SHELL_LIB`, and every variable of the runner that the script reads. A step
  MUST NOT get `GH_TOKEN` unless its script calls the API.
- A script MUST source `env.sh` of the library and run `step_environment` before
  it runs anything but builtins, and MUST find its own files from `$0`, not from
  `BASH_SOURCE`.
- Every command of a script MUST come from `SYSTEM_PATH`, or by absolute path
  from `job_tool` of `env.sh`.
- The unit tests MUST run every script through `run-step.sh` with only the
  variables of its run line and of the stubs, and MUST check for every step that
  `BASH_ENV`, exported functions, `SHELLOPTS`, `PS4` and `BASH_SOURCE` set by
  earlier steps run nothing.
- The unit tests MUST check every internal action with `check_action_steps` of
  the pinned library.

## Consequences

- (+) No step of a job before an internal action can run code in it or change
  the tools it runs, except through the variables of the dynamic loader.
- (+) The variables that each script sees, the token included, are visible in
  its `action.yml`, where a review sees them.
- (+) Internal actions follow the same contract as action-setup-nix,
  action-flake-lock and workflow-check, so one review of the library covers all
  of them.
- (−) Variables of the dynamic loader, such as `LD_PRELOAD`, still reach the
  first `bash` of every step; GitHub does not block them.
- (−) A script that needs a new variable of the runner fails until its run line
  names it; the tests catch it only where they cover the code that reads it.
- (−) The scripts move two directories deeper, so their paths change.
- (±) The unit tests need mikefarah `yq` to read the run lines, as the static
  tests of the workflows already do.

## Alternatives considered

- **Keep `run.sh` as the script of the step.** `run-step.sh` takes any
  `STEP_DIR`, so `"$GITHUB_ACTION_PATH" run` would work with fewer moves, but it
  leaves the layout that the library and its test helpers document.
- **Merge the two steps of `preflight`.** One script would give the check of the
  App inputs the token that only the check of the configuration needs.
- **Pause `release-pr` with `/usr/bin/sleep` from `bash -p`.** Safe as well, but
  a second form of step that the tests and reviews would have to tell apart.
- **Unset the dangerous variables in each script.** A script cannot undo
  `BASH_ENV` or a function that ran before its first line, and a list of
  variables to drop is never complete.

[asl-0001]:
  https://github.com/flakeyard/action-shell-lib/blob/main/docs/adr/records/0001-shell-library.md
[fy-0030]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0030-actions-workflows-and-release-bot.md
[fy-0035]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0035-extract-logic-that-has-two-users.md
