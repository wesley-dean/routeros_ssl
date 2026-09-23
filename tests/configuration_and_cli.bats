#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
}

teardown() {
  teardown_common
}

@test "an explicit configuration file drives a successful workflow" {
  run env CONFIG_FILE="$CONFIG_FILE_PATH" bash "$SCRIPT"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"test-user@router.example.test"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"/certificate import file-name=example.test.pem"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"/ip service set www-ssl certificate=example.test.pem_0"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"/interface sstp-server server set certificate=example.test.pem_0"* ]]
}

@test "command-line flags override configuration values" {
  cli_cert="${TEST_TMPDIR}/cli-cert.pem"
  cli_key="${TEST_TMPDIR}/cli-key.pem"
  printf '%s\n' cert >"$cli_cert"
  printf '%s\n' key >"$cli_key"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" bash "$SCRIPT"     -u cli-user     -H cli-router.example.test     -p 2200     -k "$SSH_KEY_FILE"     -d cli.example.test     -C "$cli_cert"     -K "$cli_key"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"cli-user@cli-router.example.test"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *$'\t2200'* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"cli.example.test.pem"* ]]
}

@test "environment values survive when an explicit config omits them" {
  {
    printf 'CERTIFICATE=%q\n' "$CERT_FILE"
    printf 'KEY=%q\n' "$KEY_FILE"
  } >"$CONFIG_FILE_PATH"

  run env     CONFIG_FILE="$CONFIG_FILE_PATH"     ROUTEROS_USER=env-user     ROUTEROS_HOST=env-router.example.test     ROUTEROS_SSH_PORT=2022     ROUTEROS_PRIVATE_KEY="$SSH_KEY_FILE"     DOMAIN=env.example.test     ROUTEROS_SSH_OPTIONS=     bash "$SCRIPT"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"env-user@env-router.example.test"* ]]
  [[ "$COMMAND_LOG_CONTENT" == *"env.example.test.pem"* ]]
}

@test "automatic config discovery currently fails when CONFIG_FILE is empty [known defect #112]" {
  cp "$CONFIG_FILE_PATH" "${TEST_TMPDIR}/.env"

  run bash -c     'cd "$1"; unset CONFIG_FILE; bash "$2"'     _ "$TEST_TMPDIR" "$SCRIPT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not load CONFIG_FILE ''"* ]]
}

@test "automatic config discovery should load .env after #112" {
  skip "blocked by #112: automatic config discovery is currently inverted"

  cp "$CONFIG_FILE_PATH" "${TEST_TMPDIR}/.env"
  run bash -c 'cd "$1"; unset CONFIG_FILE; bash "$2"' _ "$TEST_TMPDIR" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "settings file wins over .env when discovery is triggered" {
  seed="${TEST_TMPDIR}/seed.conf"
  env_file="${TEST_TMPDIR}/.env"
  settings_file="${TEST_TMPDIR}/letsencrypt-routeros.settings"

  write_config "$seed" seed.example.test
  write_config "$env_file" env.example.test
  write_config "$settings_file" settings.example.test

  run bash -c     'cd "$1"; CONFIG_FILE="$2" bash "$3"'     _ "$TEST_TMPDIR" "$seed" "$SCRIPT"

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"settings.example.test.pem"* ]]
  [[ "$COMMAND_LOG_CONTENT" != *"seed.example.test.pem"* ]]
  [[ "$COMMAND_LOG_CONTENT" != *"env.example.test.pem"* ]]
}

@test "default admin user currently masks positional username [known defect #112]" {
  {
    printf 'ROUTEROS_HOST=%q\n' "$TEST_ROUTEROS_HOST"
    printf 'ROUTEROS_SSH_PORT=%q\n' "$TEST_ROUTEROS_SSH_PORT"
    printf 'ROUTEROS_PRIVATE_KEY=%q\n' "$SSH_KEY_FILE"
    printf 'DOMAIN=%q\n' "$TEST_DOMAIN"
    printf 'CERTIFICATE=%q\n' "$CERT_FILE"
    printf 'KEY=%q\n' "$KEY_FILE"
    printf 'ROUTEROS_SSH_OPTIONS=%q\n' ""
  } >"$CONFIG_FILE_PATH"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" bash "$SCRIPT" positional-user

  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"admin@router.example.test"* ]]
  [[ "$COMMAND_LOG_CONTENT" != *"positional-user@router.example.test"* ]]
}

@test "positional username should override the default after #112" {
  skip "blocked by #112: ROUTEROS_USER defaults before positional resolution"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" bash "$SCRIPT" positional-user
  [ "$status" -eq 0 ]
  read_command_log
  [[ "$COMMAND_LOG_CONTENT" == *"positional-user@"* ]]
}

@test "mixed options and positional arguments should compose after #112" {
  skip "blocked by #112: getopts arguments are not shifted before positional use"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" bash "$SCRIPT"     -u option-user positional-user positional-host 2201 "$SSH_KEY_FILE" mixed.test
  [ "$status" -eq 0 ]
}
