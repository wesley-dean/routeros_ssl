setup_common() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export PROJECT_ROOT

  SCRIPT="${ROUTEROS_SSL_UNDER_TEST:-${PROJECT_ROOT}/letsencrypt-routeros.bash}"
  export SCRIPT

  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  export HOME="${TEST_TMPDIR}/home"
  FAKE_BIN="${TEST_TMPDIR}/bin"
  export FAKE_BIN
  COMMAND_LOG="${TEST_TMPDIR}/commands.log"
  export COMMAND_LOG
  ROUTEROS_SSL_COMMAND_LOG="${COMMAND_LOG}"
  export ROUTEROS_SSL_COMMAND_LOG
  ROUTEROS_SSL_SCP_COUNT_FILE="${TEST_TMPDIR}/scp-count"
  ROUTEROS_SSL_SSH_MATCH_COUNT_FILE="${TEST_TMPDIR}/ssh-match-count"
  export ROUTEROS_SSL_SCP_COUNT_FILE ROUTEROS_SSL_SSH_MATCH_COUNT_FILE

  mkdir -p "$HOME" "$FAKE_BIN"
  : >"$COMMAND_LOG"

  CERT_FILE="${TEST_TMPDIR}/cert.pem"
  KEY_FILE="${TEST_TMPDIR}/privkey.pem"
  SSH_KEY_FILE="${TEST_TMPDIR}/id_test"
  CONFIG_FILE_PATH="${TEST_TMPDIR}/routeros.conf"
  export CERT_FILE KEY_FILE SSH_KEY_FILE CONFIG_FILE_PATH

  printf '%s\n' 'test certificate' >"$CERT_FILE"
  printf '%s\n' 'test private key' >"$KEY_FILE"
  printf '%s\n' 'test ssh key' >"$SSH_KEY_FILE"
  chmod 0600 "$CERT_FILE" "$KEY_FILE" "$SSH_KEY_FILE"

  install_fake_commands
  export PATH="${FAKE_BIN}:${PATH}"

  TEST_ROUTEROS_USER=test-user
  TEST_ROUTEROS_HOST=router.example.test
  TEST_ROUTEROS_SSH_PORT=2222
  TEST_DOMAIN=example.test
  TEST_ROUTEROS_SSH_OPTIONS=
  export TEST_ROUTEROS_USER TEST_ROUTEROS_HOST TEST_ROUTEROS_SSH_PORT
  export TEST_DOMAIN TEST_ROUTEROS_SSH_OPTIONS

  write_config "$CONFIG_FILE_PATH" "$TEST_DOMAIN"
}

teardown_common() {
  chmod -R u+rwX "$TEST_TMPDIR" 2>/dev/null || true
  rm -rf "$TEST_TMPDIR"
}

write_config() {
  local path="$1"
  local domain="${2:-$TEST_DOMAIN}"
  local user="${3:-$TEST_ROUTEROS_USER}"
  local host="${4:-$TEST_ROUTEROS_HOST}"
  local port="${5:-$TEST_ROUTEROS_SSH_PORT}"

  {
    printf 'ROUTEROS_USER=%q\n' "$user"
    printf 'ROUTEROS_HOST=%q\n' "$host"
    printf 'ROUTEROS_SSH_PORT=%q\n' "$port"
    printf 'ROUTEROS_PRIVATE_KEY=%q\n' "$SSH_KEY_FILE"
    printf 'DOMAIN=%q\n' "$domain"
    printf 'CERTIFICATE=%q\n' "$CERT_FILE"
    printf 'KEY=%q\n' "$KEY_FILE"
    printf 'ROUTEROS_SSH_OPTIONS=%q\n' "$TEST_ROUTEROS_SSH_OPTIONS"
  } >"$path"
}

install_fake_commands() {
  cat >"${FAKE_BIN}/ssh" <<'SCRIPT'
#!/usr/bin/env bash
printf 'ssh' >>"$ROUTEROS_SSL_COMMAND_LOG"
for arg in "$@"; do
  printf '\t%s' "$arg" >>"$ROUTEROS_SSL_COMMAND_LOG"
done
printf '\n' >>"$ROUTEROS_SSL_COMMAND_LOG"

if [[ -n "${FAKE_SSH_FAIL_MATCH:-}" &&
      "$*" == *"${FAKE_SSH_FAIL_MATCH}"* ]]; then
  count=0
  if [[ -f "${ROUTEROS_SSL_SSH_MATCH_COUNT_FILE:-}" ]]; then
    IFS= read -r count <"$ROUTEROS_SSL_SSH_MATCH_COUNT_FILE"
  fi
  ((count += 1))
  printf '%s\n' "$count" >"$ROUTEROS_SSL_SSH_MATCH_COUNT_FILE"

  if [[ "${FAKE_SSH_FAIL_MATCH_CALL:-0}" == 0 ||
        "${FAKE_SSH_FAIL_MATCH_CALL}" == "$count" ]]; then
    exit "${FAKE_SSH_FAIL_STATUS:-1}"
  fi
fi

exit "${FAKE_SSH_STATUS:-0}"
SCRIPT

  cat >"${FAKE_BIN}/scp" <<'SCRIPT'
#!/usr/bin/env bash
printf 'scp' >>"$ROUTEROS_SSL_COMMAND_LOG"
for arg in "$@"; do
  printf '\t%s' "$arg" >>"$ROUTEROS_SSL_COMMAND_LOG"
done
printf '\n' >>"$ROUTEROS_SSL_COMMAND_LOG"

count=0
if [[ -f "${ROUTEROS_SSL_SCP_COUNT_FILE:-}" ]]; then
  IFS= read -r count <"$ROUTEROS_SSL_SCP_COUNT_FILE"
fi
((count += 1))
printf '%s\n' "$count" >"$ROUTEROS_SSL_SCP_COUNT_FILE"

if [[ "${FAKE_SCP_FAIL_CALL:-0}" == "$count" ]]; then
  exit "${FAKE_SCP_FAIL_STATUS:-1}"
fi

exit "${FAKE_SCP_STATUS:-0}"
SCRIPT

  chmod 0755 "${FAKE_BIN}/ssh" "${FAKE_BIN}/scp"
}

read_command_log() {
  COMMAND_LOG_CONTENT="$(<"$COMMAND_LOG")"
  export COMMAND_LOG_CONTENT
}

count_logged_commands() {
  local pattern="$1"
  local count=0
  local command

  while IFS= read -r command; do
    if [[ "$command" == *"$pattern"* ]]; then
      ((count += 1))
    fi
  done <"$COMMAND_LOG"

  printf '%s\n' "$count"
}
