# script-reliability-library

![ci](https://github.com/revisualize/script-reliability-library/actions/workflows/ci.yml/badge.svg)

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

## Tests

```bash
bats test/
```

The suite exercises every function and its failure paths: the logging format, the missing-command exit code, temp-directory creation and cleanup, the retry success and exhaustion paths, and that a second lock holder is actually blocked. It runs entirely against temporary fixtures and touches nothing real.

## Continuous integration

Every push runs `shellcheck` and `bats` on GitHub Actions. The badge is green only when both pass.

## License and use

View-only, all rights reserved. This is a reference sample of my work, not open-source. See `LICENSE`.

The full body of work, and how to hire me, are at **revisualized.com**.
