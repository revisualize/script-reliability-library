# script-reliability-library

[![ci](https://github.com/revisualize/script-reliability-library/actions/workflows/ci.yml/badge.svg)](https://github.com/revisualize/script-reliability-library/actions/workflows/ci.yml)
[![test](https://github.com/revisualize/script-reliability-library/actions/workflows/test.yml/badge.svg)](https://github.com/revisualize/script-reliability-library/actions/workflows/test.yml)
[![shellcheck](https://github.com/revisualize/script-reliability-library/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/revisualize/script-reliability-library/actions/workflows/shellcheck.yml)
[![bash-compat](https://github.com/revisualize/script-reliability-library/actions/workflows/bash-compat.yml/badge.svg)](https://github.com/revisualize/script-reliability-library/actions/workflows/bash-compat.yml)
[![markdown-lint](https://github.com/revisualize/script-reliability-library/actions/workflows/markdown-lint.yml/badge.svg)](https://github.com/revisualize/script-reliability-library/actions/workflows/markdown-lint.yml)
[![links](https://github.com/revisualize/script-reliability-library/actions/workflows/links.yml/badge.svg)](https://github.com/revisualize/script-reliability-library/actions/workflows/links.yml)
[![content-policy](https://github.com/revisualize/script-reliability-library/actions/workflows/content-policy.yml/badge.svg)](https://github.com/revisualize/script-reliability-library/actions/workflows/content-policy.yml)
[![license: all rights reserved](https://img.shields.io/badge/license-all%20rights%20reserved-lightgrey)](LICENSE)

Shared reliability plumbing for operational shell scripts. Source it once, call `reliability_initialize`, and get consistent logging, dependency checks, single-instance locking, temp-directory cleanup, and retry-with-backoff without re-implementing them in every script you write.

This is a library, not a program. You source `reliability_library.sh` from your own script; you do not execute it directly. Every public name is prefixed `reliability_` so it will not collide with yours.

## What it gives you

- `reliability_initialize <tool_name> <log_file>` registers a single EXIT trap and sets the tool name and log destination. Call it before anything else.
- `reliability_log_message` writes an ISO-8601 timestamped, tool-tagged line to the log file, and mirrors it to syslog through `logger` when that is available.
- `reliability_require_commands` checks that the external commands you depend on exist, and exits with a clear error listing every one that is missing rather than failing halfway through a run.
- `reliability_acquire_lock` takes a `flock` on a lock file so a second copy of your script exits quietly instead of running concurrently. It lets the shell assign a free descriptor rather than hardcoding one, so it will not collide with a descriptor your script is already using.
- `reliability_create_temporary_directory` makes a temp directory and registers it for automatic removal on exit, so a crash does not leave litter behind.
- `reliability_run_with_retry <max_attempts> <base_delay> <command...>` retries a failing command with exponential backoff and a little jitter, and returns the command's own exit status when it finally gives up.

## Usage

```bash
#!/usr/bin/env bash
set -euo pipefail
source /path/to/reliability_library.sh

reliability_initialize "my_tool" "/var/log/my_tool.log"
reliability_require_commands curl jq flock
reliability_acquire_lock "/var/lock/my_tool.lock"

reliability_create_temporary_directory work_dir
reliability_run_with_retry 5 2 curl -fsS https://example.internal/health -o "${work_dir}/health.json"
reliability_log_message "health captured"
```

The EXIT trap set by `reliability_initialize` cleans up every registered temp directory when your script ends, however it ends.

## Requirements

Bash 4.3 or newer. `reliability_create_temporary_directory` returns its path through a `local -n` name reference, which Bash 4.3 introduced; under 4.2 that function fails when called. GNU coreutils (`date --iso-8601`, `mktemp`), and `flock` from util-linux for `reliability_acquire_lock`. `logger` is used when present.

## Tests

```bash
bash test/run_all_tests.sh;
```

The harness runs the bats suite in `test/` and fails if it executed zero tests. The suite exercises every function and its failure paths: the logging format, the missing-command exit code, temp-directory creation and cleanup, the retry success and exhaustion paths, and that a second lock holder is actually blocked. It runs entirely against temporary fixtures and touches nothing real.

## Continuous integration

Each badge above is its own GitHub Actions workflow in `.github/workflows/`. Every workflow runs on each push and pull request, can be re-run by hand from the Actions tab, and links to its run history.

| Workflow | A green badge means |
|---|---|
| [`ci`](https://github.com/revisualize/script-reliability-library/actions/workflows/ci.yml) | `bash test/run_all_tests.sh` passed on Python 3.9 and 3.12 and reported a non-zero count of executed tests, and shellcheck found nothing at style severity. |
| [`test`](https://github.com/revisualize/script-reliability-library/actions/workflows/test.yml) | `bash test/run_all_tests.sh` passed on Python 3.9 and 3.12. The run fails if any suite fails or if zero tests executed, and the job summary lists each suite with its test count. |
| [`shellcheck`](https://github.com/revisualize/script-reliability-library/actions/workflows/shellcheck.yml) | Every shell script outside `test/fixtures/` parses with `bash -n` and has no shellcheck findings at style severity. |
| [`bash-compat`](https://github.com/revisualize/script-reliability-library/actions/workflows/bash-compat.yml) | The test suite passed under every Bash release from the floor stated in Requirements through 5.3, each built from its release source. |
| [`markdown-lint`](https://github.com/revisualize/script-reliability-library/actions/workflows/markdown-lint.yml) | Every Markdown file passes markdownlint. |
| [`links`](https://github.com/revisualize/script-reliability-library/actions/workflows/links.yml) | Every link in every Markdown file resolved on the latest run. It also runs weekly, because a link can break with no commit here. |
| [`content-policy`](https://github.com/revisualize/script-reliability-library/actions/workflows/content-policy.yml) | Every tracked file meets the publishing rules: UTF-8, LF line endings, no em dashes, scripts documented as `bash name.sh`, and vendor-neutral wording. |

A badge reports the latest run of those checks. What the tool needs on your own host is listed under Requirements.

## License and use

View-only, all rights reserved. This is a reference sample of my work, not open-source. See `LICENSE`.

The full body of work, and how to hire me, are at **[revisualized.com](https://revisualized.com)**.
