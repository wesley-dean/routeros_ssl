#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
}

teardown() {
  teardown_common
}

@test "verify_requirements succeeds for readable certificate and key files" {
  run bash -c     'source "$1" || true; CERTIFICATE="$2"; KEY="$3"; verify_requirements'     _ "$SCRIPT" "$CERT_FILE" "$KEY_FILE"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Looking for '$CERT_FILE'"* ]]
  [[ "$output" == *"Looking for key '$KEY_FILE'"* ]]
  [[ "$output" == *"Readable"* ]]
}

@test "verify_requirements returns 1 when the certificate is missing" {
  missing="${TEST_TMPDIR}/missing-cert.pem"

  run bash -c     'source "$1" || true; CERTIFICATE="$2"; KEY="$3"; verify_requirements'     _ "$SCRIPT" "$missing" "$KEY_FILE"

  [ "$status" -eq 1 ]
  [[ "$output" == *"CERTIFICATE '$missing' NOT FOUND"* ]]
}

@test "verify_requirements returns 3 when the private key is missing" {
  missing="${TEST_TMPDIR}/missing-key.pem"

  run bash -c     'source "$1" || true; CERTIFICATE="$2"; KEY="$3"; verify_requirements'     _ "$SCRIPT" "$CERT_FILE" "$missing"

  [ "$status" -eq 3 ]
  [[ "$output" == *"KEY '$missing' NOT FOUND"* ]]
}

@test "unreadable private key currently reports an error but returns zero [known defect #112]" {
  chmod 000 "$KEY_FILE"

  run bash -c     'source "$1" || true; CERTIFICATE="$2"; KEY="$3"; verify_requirements'     _ "$SCRIPT" "$CERT_FILE" "$KEY_FILE"

  [ "$status" -eq 0 ]
  [[ "$output" == *"KEY '$KEY_FILE' NOT READABLE"* ]]
}

@test "unreadable private key should return 4 after #112" {
  skip "blocked by #112: unreadable KEY currently falls through successfully"

  chmod 000 "$KEY_FILE"
  run bash -c     'source "$1" || true; CERTIFICATE="$2"; KEY="$3"; verify_requirements'     _ "$SCRIPT" "$CERT_FILE" "$KEY_FILE"
  [ "$status" -eq 4 ]
}
