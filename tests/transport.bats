#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
}

teardown() {
  teardown_common
}

@test "verify_connection issues the RouterOS resource command" {
  run bash -c     'source "$1"; routeros_ssh="ssh -i $2 user@router -p 22"; verify_connection'     _ "$SCRIPT" "$SSH_KEY_FILE"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"/system resource print"* ]]
  [[ "$output" == *"Connected."* ]]
}

@test "verify_connection returns 1 and separates diagnostics on failure" {
  export FAKE_SSH_FAIL_MATCH="/system resource print"
  stdout_file="${TEST_TMPDIR}/stdout"
  stderr_file="${TEST_TMPDIR}/stderr"

  run bash -c '
    source "$1"
    routeros_ssh="ssh -i $2 user@router -p 22"
    if verify_connection >"$3" 2>"$4"; then
      rc=0
    else
      rc=$?
    fi
    printf "%s\n" "$rc"
  ' _ "$SCRIPT" "$SSH_KEY_FILE" "$stdout_file" "$stderr_file"

  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
  stdout_content="$(<"$stdout_file")"
  stderr_content="$(<"$stderr_file")"
  [[ "$stdout_content" == *"Checking connection to RouterOS"* ]]
  [[ "$stderr_content" == *"Error in:"* ]]
}

@test "upload_file removes, uploads, sleeps, and imports in order" {
  run bash -c '
    source "$1"
    ROUTEROS_USER=test-user
    ROUTEROS_HOST=router.example.test
    routeros_ssh="ssh"
    routeros_scp="scp"
    upload_file "$2" example.pem example.pem_0
  ' _ "$SCRIPT" "$CERT_FILE"

  [ "$status" -eq 0 ]
  mapfile -t commands <"$COMMAND_LOG"
  [ "${#commands[@]}" -eq 4 ]
  [[ "${commands[0]}" == *"/certificate remove [find name=example.pem_0]"* ]]
  [[ "${commands[1]}" == scp* ]]
  [[ "${commands[1]}" == *$'test-user@router.example.test:example.pem'* ]]
  [ "${commands[2]}" = $'sleep\t2' ]
  [[ "${commands[3]}" == *"/certificate import file-name=example.pem"* ]]
}

@test "upload_file returns 1 when scp fails and does not import" {
  export FAKE_SCP_STATUS=9

  run bash -c '
    source "$1"
    ROUTEROS_USER=test-user
    ROUTEROS_HOST=router.example.test
    routeros_ssh="ssh"
    routeros_scp="scp"
    upload_file "$2" example.pem example.pem_0
  ' _ "$SCRIPT" "$CERT_FILE"

  [ "$status" -eq 1 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *$'scp\t'* ]]
  [[ "$COMMAND_LOG_CONTENT" != *"/certificate import"* ]]
}

@test "upload_file returns 2 when RouterOS import fails" {
  export FAKE_SSH_FAIL_MATCH="/certificate import"
  export FAKE_SSH_FAIL_STATUS=9

  run bash -c '
    source "$1"
    ROUTEROS_USER=test-user
    ROUTEROS_HOST=router.example.test
    routeros_ssh="ssh"
    routeros_scp="scp"
    upload_file "$2" example.pem example.pem_0
  ' _ "$SCRIPT" "$CERT_FILE"

  [ "$status" -eq 2 ]
  [[ "$output" == *"Could not import file file"* ]]
}

@test "delete_file currently masks RouterOS deletion failure [known defect #112]" {
  export FAKE_SSH_FAIL_MATCH="/file remove"
  export FAKE_SSH_FAIL_STATUS=8

  run bash -c '
    source "$1"
    routeros_ssh="ssh"
    delete_file stale.pem
  ' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not delete file"* ]]
}

@test "delete_file should propagate deletion failure after #112" {
  skip "blocked by #112: delete_file currently masks remote failure"

  export FAKE_SSH_FAIL_MATCH="/file remove"
  run bash -c 'source "$1"; routeros_ssh="ssh"; delete_file stale.pem' _ "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "configure_services emits commands for www-ssl api-ssl and sstp" {
  run bash -c '
    source "$1"
    routeros_ssh="ssh"
    configure_services example.pem_0
  ' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"/ip service set www-ssl certificate=example.pem_0"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"/ip service set api-ssl certificate=example.pem_0"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"/interface sstp-server server set certificate=example.pem_0"* ]]
}

@test "configure_services returns 1 when www-ssl configuration fails" {
  export FAKE_SSH_FAIL_MATCH="www-ssl"

  run bash -c     'source "$1"; routeros_ssh="ssh"; configure_services example.pem_0'     _ "$SCRIPT"

  [ "$status" -eq 1 ]
}

@test "configure_services returns 2 when api-ssl configuration fails" {
  export FAKE_SSH_FAIL_MATCH="api-ssl"

  run bash -c     'source "$1"; routeros_ssh="ssh"; configure_services example.pem_0'     _ "$SCRIPT"

  [ "$status" -eq 2 ]
}

@test "configure_services returns 3 when sstp configuration fails" {
  export FAKE_SSH_FAIL_MATCH="sstp-server"

  run bash -c     'source "$1"; routeros_ssh="ssh"; configure_services example.pem_0'     _ "$SCRIPT"

  [ "$status" -eq 3 ]
}

@test "cleanup suppresses both remote deletion failures [known defect #112]" {
  export FAKE_SSH_FAIL_MATCH="/file remove"

  run bash -c     'source "$1"; routeros_ssh="ssh"; cleanup example.pem example.key'     _ "$SCRIPT"

  [ "$status" -eq 0 ]
  mapfile -t commands <"$COMMAND_LOG"
  [ "${#commands[@]}" -eq 2 ]
  [[ "${commands[0]}" == *"/file remove example.pem"* ]]
  [[ "${commands[1]}" == *"/file remove example.key"* ]]
}

@test "upload_key currently masks upload_file failure in conditional context [known defect #112]" {
  run bash -c '
    source "$1"
    upload_file() { return 9; }
    upload_key cert key key_0 || exit 5
    printf "%s\n" after-upload-key
  ' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Finished processing key"* ]]
  [[ "$output" == *"after-upload-key"* ]]
}

@test "upload_key should preserve upload_file failure after #112" {
  skip "blocked by #112: wrapper success currently masks upload_file failure"

  run bash -c '
    source "$1"
    upload_file() { return 9; }
    upload_key cert key key_0
  ' _ "$SCRIPT"

  [ "$status" -eq 9 ]
}

@test "SSH private key path with spaces should remain one argument after #112" {
  skip "blocked by #112: scalar SSH command construction performs word splitting"

  spaced="${TEST_TMPDIR}/ssh key"
  cp "$SSH_KEY_FILE" "$spaced"
  run env CONFIG_FILE="$CONFIG_FILE_PATH" ROUTEROS_PRIVATE_KEY="$spaced" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "unknown configured service currently exits the caller with 100 [known defect #112]" {
  run bash -c '
    source "$1"
    services=(unknown-service)
    routeros_ssh="ssh"
    configure_services example.pem_0
    printf "%s\n" unreachable
  ' _ "$SCRIPT"

  [ "$status" -eq 100 ]
  [[ "$output" == *"Unknown service 'unknown-service'"* ]]
  [[ "$output" != *"unreachable"* ]]
}

@test "unknown configured service should return instead of exiting after #112" {
  skip "blocked by #112: configure_services currently exits the caller"

  run bash -c '
    source "$1"
    services=(unknown-service)
    routeros_ssh="ssh"
    configure_services example.pem_0
  ' _ "$SCRIPT"

  [ "$status" -ne 100 ]
}
