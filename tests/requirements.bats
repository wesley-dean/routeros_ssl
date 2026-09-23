#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
}

teardown() {
  teardown_common
}

@test "verify_requirements succeeds for readable certificate and key files" {
  run bash -c     'source "$1"; CERTIFICATE="$2"; KEY="$3"; verify_requirements'     _ "$SCRIPT" "$CERT_FILE" "$KEY_FILE"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Looking for '$CERT_FILE'"* ]]
  [[ "$output" == *"Looking for key '$KEY_FILE'"* ]]
}

@test "verify_requirements returns 1 when certificate is missing" {
  missing="${TEST_TMPDIR}/missing-cert.pem"

  run bash -c     'source "$1"; CERTIFICATE="$2"; KEY="$3"; verify_requirements'     _ "$SCRIPT" "$missing" "$KEY_FILE"

  [ "$status" -eq 1 ]
  [[ "$output" == *"CERTIFICATE '$missing' NOT FOUND"* ]]
  [[ "$output" == *"level=error"* ]]
}

@test "verify_requirements returns 3 when private key is missing" {
  missing="${TEST_TMPDIR}/missing-key.pem"

  run bash -c     'source "$1"; CERTIFICATE="$2"; KEY="$3"; verify_requirements'     _ "$SCRIPT" "$CERT_FILE" "$missing"

  [ "$status" -eq 3 ]
  [[ "$output" == *"KEY '$missing' NOT FOUND"* ]]
}

@test "verify_requirements returns 4 when private key is unreadable" {
  chmod 000 "$KEY_FILE"

  run bash -c     'source "$1"; CERTIFICATE="$2"; KEY="$3"; verify_requirements'     _ "$SCRIPT" "$CERT_FILE" "$KEY_FILE"

  [ "$status" -eq 4 ]
  [[ "$output" == *"KEY '$KEY_FILE' NOT READABLE"* ]]
}
