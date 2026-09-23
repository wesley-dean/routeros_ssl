#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
}

teardown() {
  teardown_common
}

@test "an explicit configuration file drives a successful workflow" {
  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"test-user@router.example.test"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"/certificate import"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"example.test.pem"* ]]
}

@test "command-line flags override configuration values" {
  cli_cert="${TEST_TMPDIR}/cli-cert.pem"
  cli_key="${TEST_TMPDIR}/cli-key.pem"
  printf '%s\n' cert >"$cli_cert"
  printf '%s\n' key >"$cli_key"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"     -u cli-user     -H cli-router.example.test     -p 2200     -k "$SSH_KEY_FILE"     -d cli.example.test     -C "$cli_cert"     -K "$cli_key"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"cli-user@cli-router.example.test"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *$'\t2200\t'* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"cli.example.test.pem"* ]]
}

@test "environment values survive when explicit config omits them" {
  {
    printf 'CERTIFICATE=%q\n' "$CERT_FILE"
    printf 'KEY=%q\n' "$KEY_FILE"
  } >"$CONFIG_FILE_PATH"

  run env     CONFIG_FILE="$CONFIG_FILE_PATH"     ROUTEROS_USER=env-user     ROUTEROS_HOST=env-router.example.test     ROUTEROS_SSH_PORT=2022     ROUTEROS_PRIVATE_KEY="$SSH_KEY_FILE"     DOMAIN=env.example.test     ROUTEROS_SSH_OPTIONS=     "$SCRIPT"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"env-user@env-router.example.test"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"env.example.test.pem"* ]]
}

@test "automatic config discovery loads .env" {
  cp "$CONFIG_FILE_PATH" "${TEST_TMPDIR}/.env"

  run bash -c 'cd "$1"; unset CONFIG_FILE; "$2"'     _ "$TEST_TMPDIR" "$SCRIPT"

  [ "$status" -eq 0 ]
}

@test "settings file overrides .env during automatic discovery" {
  write_config "${TEST_TMPDIR}/.env" env.example.test
  write_config     "${TEST_TMPDIR}/letsencrypt-routeros.settings"     settings.example.test

  run bash -c 'cd "$1"; unset CONFIG_FILE; "$2"'     _ "$TEST_TMPDIR" "$SCRIPT"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"settings.example.test.pem"* ]]
  [[ "$COMMAND_LOG_CONTENT" != *"env.example.test.pem"* ]]
}

@test "explicit CONFIG_FILE is not overridden by discovered files" {
  explicit="${TEST_TMPDIR}/explicit.conf"
  write_config "$explicit" explicit.example.test
  write_config "${TEST_TMPDIR}/.env" env.example.test
  write_config     "${TEST_TMPDIR}/letsencrypt-routeros.settings"     settings.example.test

  run bash -c 'cd "$1"; CONFIG_FILE="$2" "$3"'     _ "$TEST_TMPDIR" "$explicit" "$SCRIPT"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"explicit.example.test.pem"* ]]
  [[ "$COMMAND_LOG_CONTENT" != *"settings.example.test.pem"* ]]
}

@test "positional username overrides the deferred admin default" {
  {
    printf 'ROUTEROS_HOST=%q\n' "$TEST_ROUTEROS_HOST"
    printf 'ROUTEROS_SSH_PORT=%q\n' "$TEST_ROUTEROS_SSH_PORT"
    printf 'ROUTEROS_PRIVATE_KEY=%q\n' "$SSH_KEY_FILE"
    printf 'DOMAIN=%q\n' "$TEST_DOMAIN"
    printf 'CERTIFICATE=%q\n' "$CERT_FILE"
    printf 'KEY=%q\n' "$KEY_FILE"
  } >"$CONFIG_FILE_PATH"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT" positional-user

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"positional-user@router.example.test"* ]]
}

@test "admin is the final username default" {
  {
    printf 'ROUTEROS_HOST=%q\n' "$TEST_ROUTEROS_HOST"
    printf 'ROUTEROS_SSH_PORT=%q\n' "$TEST_ROUTEROS_SSH_PORT"
    printf 'ROUTEROS_PRIVATE_KEY=%q\n' "$SSH_KEY_FILE"
    printf 'DOMAIN=%q\n' "$TEST_DOMAIN"
    printf 'CERTIFICATE=%q\n' "$CERT_FILE"
    printf 'KEY=%q\n' "$KEY_FILE"
  } >"$CONFIG_FILE_PATH"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"admin@router.example.test"* ]]
}

@test "options and positional arguments compose after getopts shifting" {
  {
    printf 'CERTIFICATE=%q\n' "$CERT_FILE"
    printf 'KEY=%q\n' "$KEY_FILE"
  } >"$CONFIG_FILE_PATH"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT"     -u option-user     positional-user     positional-host.example.test     2201     "$SSH_KEY_FILE"     mixed.example.test

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"option-user@positional-host.example.test"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *$'\t2201\t'* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"mixed.example.test.pem"* ]]
}

@test "complete CLI configuration works without a config file" {
  run bash -c '
    cd "$1"
    unset CONFIG_FILE
    "$2"       -u cli-user       -H cli-router.example.test       -p 2202       -k "$3"       -d cli-only.example.test       -C "$4"       -K "$5"
  ' _ "$TEST_TMPDIR" "$SCRIPT" "$SSH_KEY_FILE" "$CERT_FILE" "$KEY_FILE"

  [ "$status" -eq 0 ]
}

@test "unsafe domain is rejected before any transport command" {
  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT" -d 'bad;system-reboot'

  [ "$status" -eq 1 ]
  [ ! -s "$COMMAND_LOG" ]
  [[ "$output" == *"Unsafe certificate domain identifier"* ]]
}
