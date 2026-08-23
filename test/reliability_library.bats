#!/usr/bin/env bats
#
# Test suite for reliability_library.sh. Run with:  bats test/
# Every function is exercised, including its failure paths.

setup() {
  source "${BATS_TEST_DIRNAME}/../reliability_library.sh"
  TEST_LOG="$(mktemp)"
  reliability_initialize "test_tool" "${TEST_LOG}"
}

teardown() {
  reliability_run_cleanup
  rm -f "${TEST_LOG}"
}

@test "log_message writes a timestamped, tool-tagged line" {
  reliability_log_message "hello world"
  run grep -q "test_tool hello world" "${TEST_LOG}"
  [ "${status}" -eq 0 ]
}

@test "require_commands passes when all commands are present" {
  run reliability_require_commands bash sh
  [ "${status}" -eq 0 ]
}

@test "require_commands exits 2 when a command is missing" {
  run reliability_require_commands definitely_not_a_real_cmd_xyz
  [ "${status}" -eq 2 ]
}

@test "create_temporary_directory assigns the path and the directory exists" {
  reliability_create_temporary_directory made_dir
  [ -n "${made_dir}" ]
  [ -d "${made_dir}" ]
}

@test "create_temporary_directory registers the directory for cleanup" {
  reliability_create_temporary_directory made_dir
  [ "${reliability_cleanup_paths[-1]}" = "${made_dir}" ]
}

@test "run_cleanup removes registered temporary directories" {
  reliability_create_temporary_directory made_dir
  reliability_run_cleanup
  [ ! -d "${made_dir}" ]
}

@test "run_with_retry returns 0 on immediate success" {
  run reliability_run_with_retry 3 0 true
  [ "${status}" -eq 0 ]
}

@test "run_with_retry succeeds once the command eventually succeeds" {
  counter="$(mktemp)"; echo 0 > "${counter}"
  flaky="$(mktemp)"; chmod +x "${flaky}"
  cat > "${flaky}" <<EOF
#!/usr/bin/env bash
n=\$(cat "${counter}"); n=\$((n + 1)); echo "\${n}" > "${counter}"
[ "\${n}" -ge 2 ]
EOF
  run reliability_run_with_retry 3 0 "${flaky}"
  [ "${status}" -eq 0 ]
  rm -f "${counter}" "${flaky}"
}

@test "run_with_retry returns the failure status after exhausting attempts" {
  run reliability_run_with_retry 2 0 false
  [ "${status}" -eq 1 ]
}

@test "acquire_lock blocks a second concurrent holder" {
  lockf="$(mktemp)"
  ( reliability_acquire_lock "${lockf}"; sleep 1 ) &
  sleep 0.2
  run bash -c "source '${BATS_TEST_DIRNAME}/../reliability_library.sh'; reliability_initialize t /dev/null; reliability_acquire_lock '${lockf}' && echo GOTLOCK"
  [[ "${output}" != *GOTLOCK* ]]
  wait
  rm -f "${lockf}"
}
