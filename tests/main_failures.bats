#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
}

teardown() {
  teardown_common
}

@test "main exits 1 when local requirements fail" {
  missing="${TEST_TMPDIR}/missing.pem"
  {
    printf 'ROUTEROS_USER=%q\n' "$TEST_ROUTEROS_USER"
    printf 'ROUTEROS_HOST=%q\n' "$TEST_ROUTEROS_HOST"
    printf 'ROUTEROS_SSH_PORT=%q\n' "$TEST_ROUTEROS_SSH_PORT"
    printf 'ROUTEROS_PRIVATE_KEY=%q\n' "$SSH_KEY_FILE"
    printf 'DOMAIN=%q\n' "$TEST_DOMAIN"
    printf 'CERTIFICATE=%q\n' "$missing"
    printf 'KEY=%q\n' "$KEY_FILE"
    printf 'ROUTEROS_SSH_OPTIONS=%q\n' ""
  } >"$CONFIG_FILE_PATH"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"NOT FOUND"* ]]
}

@test "main exits 2 when RouterOS connection verification fails" {
  export FAKE_SSH_FAIL_MATCH="/system resource print"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 2 ]
}

@test "main exits 4 when certificate upload fails" {
  export FAKE_SCP_FAIL_CALL=1

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 4 ]
}

@test "second scp failure is currently masked and main exits zero [known defect #112]" {
  export FAKE_SCP_FAIL_CALL=2

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not upload new file"* ]]
  [[ "$output" == *"Finished processing key"* ]]
}

@test "main should exit 5 when private-key upload fails after #112" {
  skip "blocked by #112: upload_key currently masks upload_file failure"

  export FAKE_SCP_FAIL_CALL=2
  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"
  [ "$status" -eq 5 ]
}

@test "main exits 6 when service configuration fails" {
  export FAKE_SSH_FAIL_MATCH="/ip service set www-ssl"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 6 ]
}

@test "setup failure status 3 should become observable after #112" {
  skip "blocked by #112: setup suppresses delete_file failures"

  export FAKE_SSH_FAIL_MATCH="/file remove"
  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"
  [ "$status" -eq 3 ]
}

@test "cleanup failure status 7 should become observable after #112" {
  skip "blocked by #112: cleanup suppresses delete_file failures"

  export FAKE_SSH_FAIL_MATCH="/file remove"
  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"
  [ "$status" -eq 7 ]
}

@test "certificate upload failure bypasses final cleanup [known defect #112]" {
  export FAKE_SCP_FAIL_CALL=1

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 4 ]
  removal_count=0
  while IFS= read -r command; do
    if [[ "$command" == *"/file remove"* ]]; then
      ((removal_count += 1))
    fi
  done <"$COMMAND_LOG"
  [ "$removal_count" -eq 2 ]
}

@test "partial upload failure should run post-failure cleanup after #112" {
  skip "blocked by #112: early exits currently bypass final cleanup"

  export FAKE_SCP_FAIL_CALL=1
  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"
  [ "$status" -eq 4 ]

  removal_count=0
  while IFS= read -r command; do
    if [[ "$command" == *"/file remove"* ]]; then
      ((removal_count += 1))
    fi
  done <"$COMMAND_LOG"
  [ "$removal_count" -gt 2 ]
}
