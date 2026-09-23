#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
}

teardown() {
  teardown_common
}

@test "sourcing succeeds without running main" {
  run bash -c 'source "$1"; printf "%s\n" sourced' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$output" = "sourced" ]
}

@test "sourcing does not enable errexit in the caller" {
  run bash -c '
    set +e
    source "$1"
    [[ $- != *e* ]]
  ' _ "$SCRIPT"

  [ "$status" -eq 0 ]
}

@test "source-time defaults defer the administrative user and certificate paths" {
  run bash -c '
    source "$1"
    printf "%s|%s|%s|%s\n"       "$ROUTEROS_USER" "$ROUTEROS_SSH_PORT" "$CERTIFICATE" "$KEY"
  ' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$output" = "|||" ]
}

@test "usage_help documents -H for host and -h for help" {
  run bash -c 'source "$1"; usage_help' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"-H [RouterOS Host]"* ]]
  [[ "$output" == *$'  -h\n'* ]]
  [[ "$output" != *"-h [RouterOS Host]"* ]]
}

@test "help succeeds without loading an invalid explicit config" {
  run env CONFIG_FILE="${TEST_TMPDIR}/missing.conf" "$SCRIPT" -h

  [ "$status" -eq 0 ]
  [[ "$output" == *"or use configuration files:"* ]]
}

@test "invalid options return non-zero" {
  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT" -Z

  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown option -Z"* ]]
}

@test "formerly accepted -i option is rejected" {
  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT" -i

  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown option -i"* ]]
}

@test "SSH port is declared after sourcing" {
  run bash -c 'source "$1"; [[ -v ROUTEROS_SSH_PORT ]]' _ "$SCRIPT"

  [ "$status" -eq 0 ]
}

@test "certificate defaults are derived only after DOMAIN is resolved" {
  run bash -c '
    source "$1"
    ROUTEROS_HOST=router.example.test
    ROUTEROS_SSH_PORT=22
    ROUTEROS_PRIVATE_KEY=/tmp/id
    DOMAIN=late.example.test
    resolve_configuration
    printf "%s|%s\n" "$CERTIFICATE" "$KEY"
  ' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$output" = "/etc/letsencrypt/live/late.example.test/cert.pem|/etc/letsencrypt/live/late.example.test/privkey.pem" ]
}

@test "selected public artifact is executable" {
  [ -x "$SCRIPT" ]
}

@test "public artifact can be executed directly" {
  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT" -h

  [ "$status" -eq 0 ]
}
