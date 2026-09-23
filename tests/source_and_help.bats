#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
}

teardown() {
  teardown_common
}

@test "sourcing the script defines functions without running main" {
  run bash -c 'source "$1"; printf "%s\n" sourced' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$output" = "sourced" ]
}

@test "source-time defaults expose the current administrative user" {
  run bash -c     'source "$1"; printf "%s|%s\n" "$ROUTEROS_USER" "$ROUTEROS_SSH_OPTIONS"'     _ "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$output" = "admin|" ]
}

@test "usage_help lists both supported configuration file names" {
  run bash -c 'source "$1"; usage_help' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"* .env"* ]]
  [[ "$output" == *"* letsencrypt-routeros.settings"* ]]
}

@test "help currently documents -h as the RouterOS host [known defect #112]" {
  run bash -c 'source "$1"; usage_help' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"-h [RouterOS Host]"* ]]
}

@test "executable -h prints usage after an explicit config is loaded" {
  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT" -h

  [ "$status" -eq 0 ]
  [[ "$output" == *"or use a configuration file:"* ]]
}

@test "invalid options currently print usage and exit zero [known defect #112]" {
  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT" -Z

  [ "$status" -eq 0 ]
  [[ "$output" == *"illegal option"* ]]
  [[ "$output" == *"or use a configuration file:"* ]]
}

@test "invalid options should return non-zero after #112" {
  skip "blocked by #112: invalid-option status is currently zero"

  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT" -Z
  [ "$status" -ne 0 ]
}

@test "SSH port is currently undeclared after sourcing [known defect #112]" {
  run bash -c 'source "$1"; [[ -v ROUTEROS_SSH_PORT ]]' _ "$SCRIPT"

  [ "$status" -eq 1 ]
}

@test "certificate defaults currently bind before DOMAIN is assigned [known defect #112]" {
  run bash -c '
    source "$1"
    DOMAIN=late.example.test
    printf "%s|%s\n" "$CERTIFICATE" "$KEY"
  ' _ "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$output" = "/etc/letsencrypt//live/cert.pem|/etc/letsencrypt//live/privkey.pem" ]
}

@test "certificate defaults should be derived after DOMAIN is known after #112" {
  skip "blocked by #112: CERTIFICATE and KEY defaults are evaluated too early"

  run bash -c '
    source "$1"
    DOMAIN=late.example.test
    resolve_defaults
    printf "%s|%s\n" "$CERTIFICATE" "$KEY"
  ' _ "$SCRIPT"

  [ "$output" = "/etc/letsencrypt/live/late.example.test/cert.pem|/etc/letsencrypt/live/late.example.test/privkey.pem" ]
}

@test "accepted but unhandled -i option is currently ignored [known defect #112]" {
  run env CONFIG_FILE="$CONFIG_FILE_PATH" "$SCRIPT" -i

  [ "$status" -eq 0 ]
}
