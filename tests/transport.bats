#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
}

teardown() {
  teardown_common
}

@test "verify_connection issues the RouterOS resource command" {
  run bash -c '
    source "$1"
    ROUTEROS_HOST=router
    ROUTEROS_SSH_PORT=22
    routeros_ssh=(ssh -i "$2" -p 22 user@router)
    verify_connection
  ' _ "$SCRIPT" "$SSH_KEY_FILE"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"/system resource print"* ]]
}

@test "verify_connection logs an error and returns 1 on failure" {
  export FAKE_SSH_FAIL_MATCH="/system resource print"

  run bash -c '
    source "$1"
    ROUTEROS_HOST=router
    ROUTEROS_SSH_PORT=22
    routeros_ssh=(ssh)
    verify_connection
  ' _ "$SCRIPT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"level=error"* ]]
  [[ "$output" == *"Could not connect to RouterOS"* ]]
}

@test "upload_file removes uploads and imports without a sleep command" {
  run bash -c '
    source "$1"
    ROUTEROS_USER=test-user
    ROUTEROS_HOST=router.example.test
    routeros_ssh=(ssh)
    routeros_scp=(scp)
    upload_file "$2" example.pem example.pem_0
  ' _ "$SCRIPT" "$CERT_FILE"

  [ "$status" -eq 0 ]
  mapfile -t commands <"$COMMAND_LOG"
  [ "${#commands[@]}" -eq 3 ]
  [[ "${commands[0]}" == *"/certificate remove"* ]]
  [[ "${commands[1]}" == scp* ]]
  [[ "${commands[2]}" == *"/certificate import"* ]]
  [[ "$COMMAND_LOG_CONTENT" != *"sleep"* ]]
}

@test "upload_file returns 1 when scp fails and does not import" {
  export FAKE_SCP_STATUS=9

  run bash -c '
    source "$1"
    ROUTEROS_USER=test-user
    ROUTEROS_HOST=router.example.test
    routeros_ssh=(ssh)
    routeros_scp=(scp)
    upload_file "$2" example.pem example.pem_0
  ' _ "$SCRIPT" "$CERT_FILE"

  [ "$status" -eq 1 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *$'scp\t'* ]]
  [[ "$COMMAND_LOG_CONTENT" != *"/certificate import"* ]]
}

@test "upload_file returns 2 when RouterOS import fails" {
  export FAKE_SSH_FAIL_MATCH="/certificate import"

  run bash -c '
    source "$1"
    ROUTEROS_USER=test-user
    ROUTEROS_HOST=router.example.test
    routeros_ssh=(ssh)
    routeros_scp=(scp)
    upload_file "$2" example.pem example.pem_0
  ' _ "$SCRIPT" "$CERT_FILE"

  [ "$status" -eq 2 ]
}

@test "delete_file propagates RouterOS deletion failure" {
  export FAKE_SSH_FAIL_MATCH="/file remove"

  run bash -c '
    source "$1"
    routeros_ssh=(ssh)
    delete_file stale.pem
  ' _ "$SCRIPT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not delete RouterOS file"* ]]
}

@test "configure_services emits commands for all supported services" {
  run bash -c '
    source "$1"
    routeros_ssh=(ssh)
    configure_services example.pem_0
  ' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"/ip service set www-ssl"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"/ip service set api-ssl"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"/interface sstp-server server set"* ]]
}

@test "configure_services returns 1 when www-ssl configuration fails" {
  export FAKE_SSH_FAIL_MATCH="www-ssl"

  run bash -c     'source "$1"; routeros_ssh=(ssh); configure_services example.pem_0'     _ "$SCRIPT"

  [ "$status" -eq 1 ]
}

@test "configure_services returns 2 when api-ssl configuration fails" {
  export FAKE_SSH_FAIL_MATCH="api-ssl"

  run bash -c     'source "$1"; routeros_ssh=(ssh); configure_services example.pem_0'     _ "$SCRIPT"

  [ "$status" -eq 2 ]
}

@test "configure_services returns 3 when sstp configuration fails" {
  export FAKE_SSH_FAIL_MATCH="sstp-server"

  run bash -c     'source "$1"; routeros_ssh=(ssh); configure_services example.pem_0'     _ "$SCRIPT"

  [ "$status" -eq 3 ]
}

@test "cleanup attempts both files and returns failure" {
  export FAKE_SSH_FAIL_MATCH="/file remove"

  run bash -c '
    source "$1"
    routeros_ssh=(ssh)
    cleanup example.pem example.key
  ' _ "$SCRIPT"

  [ "$status" -eq 1 ]
  [ "$(count_logged_commands '/file remove')" -eq 2 ]
}

@test "upload_key preserves upload_file failure" {
  run bash -c '
    source "$1"
    upload_file() { return 9; }
    upload_key cert key key_0
  ' _ "$SCRIPT"

  [ "$status" -eq 9 ]
}

@test "SSH private key path with spaces remains one argv element" {
  spaced="${TEST_TMPDIR}/ssh key"
  cp "$SSH_KEY_FILE" "$spaced"
  write_config "$CONFIG_FILE_PATH"

  run env     CONFIG_FILE="$CONFIG_FILE_PATH"     ROUTEROS_PRIVATE_KEY="$spaced"     "$SCRIPT"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *$'-i\t'"$spaced"$'\t'* ]]
}

@test "SSH option string is tokenized into explicit argv elements" {
  export TEST_ROUTEROS_SSH_OPTIONS="-o StrictHostKeyChecking=no -o BatchMode=yes"
  write_config "$CONFIG_FILE_PATH"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *$'-o\tStrictHostKeyChecking=no\t-o\tBatchMode=yes\t'* ]]
}

@test "unknown configured service returns without terminating caller" {
  run bash -c '
    source "$1"
    services=(unknown-service)
    routeros_ssh=(ssh)
    if configure_services example.pem_0; then
      rc=0
    else
      rc=$?
    fi
    printf "rc=%s after\n" "$rc"
  ' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=64 after"* ]]
}
