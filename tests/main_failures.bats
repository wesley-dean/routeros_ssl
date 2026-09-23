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
  write_config "$CONFIG_FILE_PATH"
  printf 'CERTIFICATE=%q\n' "$missing" >>"$CONFIG_FILE_PATH"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"NOT FOUND"* ]]
}

@test "main exits 2 when RouterOS connection verification fails" {
  export FAKE_SSH_FAIL_MATCH="/system resource print"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 2 ]
}

@test "main exits 3 when initial cleanup fails" {
  export FAKE_SSH_FAIL_MATCH="/file remove"
  export FAKE_SSH_FAIL_MATCH_CALL=1

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 3 ]
  [ "$(count_logged_commands '/file remove')" -eq 2 ]
}

@test "main exits 4 when certificate upload fails and still cleans up" {
  export FAKE_SCP_FAIL_CALL=1

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 4 ]
  [ "$(count_logged_commands '/file remove')" -eq 4 ]
}

@test "main exits 5 when private-key upload fails and still cleans up" {
  export FAKE_SCP_FAIL_CALL=2

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 5 ]
  [ "$(count_logged_commands '/file remove')" -eq 4 ]
}

@test "main exits 6 when service configuration fails and still cleans up" {
  export FAKE_SSH_FAIL_MATCH="/ip service set www-ssl"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 6 ]
  [ "$(count_logged_commands '/file remove')" -eq 4 ]
}

@test "main exits 7 when final cleanup fails" {
  export FAKE_SSH_FAIL_MATCH="/file remove"
  export FAKE_SSH_FAIL_MATCH_CALL=3

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 7 ]
}

@test "primary failure status wins when final cleanup also fails" {
  export FAKE_SCP_FAIL_CALL=1
  export FAKE_SSH_FAIL_MATCH="/file remove"
  export FAKE_SSH_FAIL_MATCH_CALL=3

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 4 ]
  [[ "$output" == *"Cleanup also failed after primary workflow status 4"* ]]
}

@test "invalid SSH port fails before transport" {
  write_config "$CONFIG_FILE_PATH"
  printf 'ROUTEROS_SSH_PORT=%q\n' not-a-port >>"$CONFIG_FILE_PATH"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 1 ]
  [ ! -s "$COMMAND_LOG" ]
}
