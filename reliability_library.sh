#!/usr/bin/env bash
# ------------------------------------------------------------------------------
#  reliability_library.sh - shared reliability plumbing for shell scripts
#
#  Author:    Joseph Tracy  <https://revisualized.com>
#  Copyright: (c) 2026 Joseph Tracy. All rights reserved.
#  Origin:    Original work by the author, written on the author's own time
#             from public documentation and public references. Contains no
#             proprietary or employer material.
#  License:   View-only. See LICENSE. No copying, reuse, redistribution, or
#             derivative works without the author's written permission.
#  Home:      https://revisualized.com
# ------------------------------------------------------------------------------
#
# reliability_library.sh
# Shared reliability plumbing for operational scripts. Source this file;
# do not execute it. All public names are prefixed reliability_.
#
# Sourcing contract: call reliability_initialize <tool_name> <log_file>
# before anything else. EXIT trap registration happens there, once.
#

reliability_tool_name="unnamed_tool"
reliability_log_file="/dev/null"
reliability_cleanup_paths=()
reliability_lock_descriptor=""

reliability_initialize() {
    reliability_tool_name="$1"
    reliability_log_file="$2"
    trap reliability_run_cleanup EXIT
}

reliability_log_message() {
    local message_text="$1"
    printf '%s %s %s\n' "$(date --iso-8601=seconds)" "$reliability_tool_name" "$message_text" \
        >> "$reliability_log_file"
    if command -v logger > /dev/null 2>&1; then
        logger --tag "$reliability_tool_name" -- "$message_text"
    fi
}

reliability_require_commands() {
    local missing_command_list=()
    local candidate_command
    for candidate_command in "$@"; do
        if ! command -v "$candidate_command" > /dev/null 2>&1; then
            missing_command_list+=("$candidate_command")
        fi
    done
    if [ "${#missing_command_list[@]}" -gt 0 ]; then
        reliability_log_message "ERROR: missing required commands: ${missing_command_list[*]}"
        printf 'Missing required commands: %s\n' "${missing_command_list[*]}" >&2
        exit 2
    fi
}

reliability_acquire_lock() {
    local lock_file_path="$1"
    # Let the shell assign a free descriptor instead of hardcoding one and
    # reaching for eval. A fixed number can collide with a descriptor the
    # sourcing script is already using. Requires bash 4.1 or newer.
    exec {reliability_lock_descriptor}>"${lock_file_path}"
    if ! flock -n "$reliability_lock_descriptor"; then
        reliability_log_message "Previous run still holds ${lock_file_path}, exiting."
        exit 0
    fi
}

reliability_create_temporary_directory() {
    local -n destination_variable_reference="$1"
    local created_directory
    created_directory=$(mktemp -d) || return 1
    reliability_cleanup_paths+=("$created_directory")
    # shellcheck disable=SC2034  # nameref output parameter: this assignment writes to the caller's variable
    destination_variable_reference="$created_directory"
}

reliability_run_cleanup() {
    local cleanup_path
    for cleanup_path in "${reliability_cleanup_paths[@]:-}"; do
        [ -n "$cleanup_path" ] && rm -rf "$cleanup_path"
    done
}

reliability_run_with_retry() {
    local max_attempts="$1"
    local base_delay_seconds="$2"
    shift 2
    local attempt_number=1
    local final_exit_status=0
    local backoff_delay_seconds
    while true; do
        # Capture the command's own exit status. Using `if "$@"; then...` here
        # is a trap: an if with a false condition and no else yields $? = 0, so
        # the retry would report success after exhausting all attempts.
        "$@" && return 0
        final_exit_status=$?
        if [ "$attempt_number" -ge "$max_attempts" ]; then
            reliability_log_message "Retry exhausted after ${max_attempts} attempts: $*"
            return "$final_exit_status"
        fi
        backoff_delay_seconds=$((base_delay_seconds * (2 ** (attempt_number - 1)) + RANDOM % 3))
        reliability_log_message "Attempt ${attempt_number} failed, retrying in ${backoff_delay_seconds}s: $*"
        sleep "$backoff_delay_seconds"
        attempt_number=$((attempt_number + 1))
    done
}
