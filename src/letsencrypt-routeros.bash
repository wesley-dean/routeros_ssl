#!/usr/bin/env bash
# shellcheck shell=bash
## @file src/letsencrypt-routeros.bash
## @brief Uploads an existing TLS certificate and private key to RouterOS.
## @details
## Transfers an existing certificate and private key to a MikroTik RouterOS
## device over SSH/SCP, imports both files, and configures supported TLS
## services to use the imported certificate.
##
## Configuration files are trusted executable Bash.  The maintained source may
## be run after `make deps`; generated consumer artifacts embed bashlog and are
## standalone.
## @author Wes Dean
## @see doc/adr/README.md

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  set -euo pipefail
fi

## @var config_file_options
## @brief Default configuration files, in increasing precedence order.
declare -a config_file_options=(".env" "letsencrypt-routeros.settings")

## @var services
## @brief RouterOS services configured to use the imported certificate.
declare -a services=("www-ssl" "api-ssl" "sstp")

## @var ROUTEROS_SSH_OPTIONS
## @brief Additional whitespace-delimited OpenSSH option tokens.
declare ROUTEROS_SSH_OPTIONS="${ROUTEROS_SSH_OPTIONS:-}"

## @var ROUTEROS_USER
## @brief RouterOS administrative username.
declare ROUTEROS_USER="${ROUTEROS_USER:-}"

## @var ROUTEROS_PRIVATE_KEY
## @brief Local SSH private-key path.
declare ROUTEROS_PRIVATE_KEY="${ROUTEROS_PRIVATE_KEY:-}"

## @var ROUTEROS_HOST
## @brief RouterOS hostname or IP address.
declare ROUTEROS_HOST="${ROUTEROS_HOST:-}"

## @var ROUTEROS_SSH_PORT
## @brief RouterOS SSH port.
declare ROUTEROS_SSH_PORT="${ROUTEROS_SSH_PORT:-}"

## @var DOMAIN
## @brief Domain identifier used for certificate paths and RouterOS names.
declare DOMAIN="${DOMAIN:-}"

## @var CERTIFICATE
## @brief Local signed-certificate path.
declare CERTIFICATE="${CERTIFICATE:-}"

## @var KEY
## @brief Local TLS private-key path.
declare KEY="${KEY:-}"

## @var routeros_ssh
## @brief Prepared argv array for SSH calls.
declare -a routeros_ssh=()

## @var routeros_scp
## @brief Prepared argv array for SCP calls.
declare -a routeros_scp=()

# Maintained source loads the prepared dependency.  Built artifacts embed
# bashlog before this source, so this branch is skipped for consumers.
if ! declare -F bashlog_error > /dev/null 2>&1; then
  __routeros_ssl_source_path="${BASH_SOURCE[0]}"
  __routeros_ssl_source_dir="${__routeros_ssl_source_path%/*}"
  if [[ "${__routeros_ssl_source_dir}" == "${__routeros_ssl_source_path}" ]]; then
    __routeros_ssl_source_dir=.
  fi
  __routeros_ssl_source_dir="$(
    cd -- "${__routeros_ssl_source_dir}" && pwd
  )"
  __routeros_ssl_bashlog="${__routeros_ssl_source_dir}/../vendor/bashlog.dev.bash"

  if [[ ! -r "${__routeros_ssl_bashlog}" ]]; then
    printf '%s\n' \
      'Missing vendor/bashlog.dev.bash; run make deps or use a built artifact.' \
      >&2
    if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
      exit 1
    fi
    return 1
  fi

  # shellcheck disable=SC1090
  source "${__routeros_ssl_bashlog}"
  unset __routeros_ssl_source_path __routeros_ssl_source_dir
  unset __routeros_ssl_bashlog
fi

## @fn usage_help()
## @brief Writes command usage and configuration-file names.
## @details
## Describes positional arguments, supported short options, and default
## configuration-file discovery.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Usage text is written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns Human-readable usage text.
## @retval 0 Usage text was written.
usage_help() {
  printf '%s\n' \
    "$0 [RouterOS User] [RouterOS Host] [SSH Port] [SSH Private Key] [Domain]" \
    "" \
    "or" \
    "" \
    "$0" \
    "  -C [Certificate]" \
    "  -d [Domain]" \
    "  -h" \
    "  -H [RouterOS Host]" \
    "  -K [Certificate Private Key]" \
    "  -k [SSH Private Key]" \
    "  -o [RouterOS SSH Options]" \
    "  -p [RouterOS SSH Port]" \
    "  -u [RouterOS User]" \
    "" \
    "or use configuration files:"

  local config_file
  for config_file in "${config_file_options[@]}"; do
    printf '* %s\n' "${config_file}"
  done
}

## @fn load_configuration()
## @brief Loads explicit or discovered trusted Bash configuration.
## @details
## If CONFIG_FILE is non-empty, only that file is sourced.  Otherwise existing
## default files are sourced in array order, so later files have higher
## precedence.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Configuration errors are logged to STDERR.
##
## @returns Nothing is written to STDOUT.
## @retval 0 Configuration loading succeeded or no default files existed.
## @retval 1 An explicit configuration file could not be loaded.
load_configuration() {
  local explicit_config="${CONFIG_FILE:-}"
  local config_file

  if [[ -n "${explicit_config}" ]]; then
    if [[ ! -f "${explicit_config}" ]]; then
      bashlog_error 'Could not load CONFIG_FILE %s' "${explicit_config}"
      return 1
    fi
    # shellcheck disable=SC1090
    source "${explicit_config}"
    return 0
  fi

  for config_file in "${config_file_options[@]}"; do
    if [[ -f "${config_file}" ]]; then
      # shellcheck disable=SC1090
      source "${config_file}"
    fi
  done
}

## @fn resolve_configuration()
## @brief Resolves option/configuration values and positional fallbacks.
## @details
## Values already set by the environment, configuration files, or command-line
## options win.  Remaining positional values fill user, host, port, SSH key,
## and domain in that order.  The user defaults to admin only after positional
## resolution.  Certificate paths are derived only after DOMAIN is known.
##
## @param arguments[] Remaining positional command-line arguments.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Missing required values are logged to STDERR.
##
## @returns Nothing is written to STDOUT.
## @retval 0 Required configuration was resolved.
## @retval 1 A required value is missing or extra positionals were supplied.
resolve_configuration() {
  if (($# > 5)); then
    bashlog_error 'Too many positional arguments'
    return 1
  fi

  ROUTEROS_USER="${ROUTEROS_USER:-${1:-admin}}"
  ROUTEROS_HOST="${ROUTEROS_HOST:-${2:-}}"
  ROUTEROS_SSH_PORT="${ROUTEROS_SSH_PORT:-${3:-}}"
  ROUTEROS_PRIVATE_KEY="${ROUTEROS_PRIVATE_KEY:-${4:-}}"
  DOMAIN="${DOMAIN:-${5:-}}"

  if [[ -z "${ROUTEROS_HOST}" ]]; then
    bashlog_error 'No RouterOS hostname was provided'
    return 1
  fi
  if [[ -z "${ROUTEROS_SSH_PORT}" ]]; then
    bashlog_error 'No RouterOS SSH port was provided'
    return 1
  fi
  if [[ -z "${ROUTEROS_PRIVATE_KEY}" ]]; then
    bashlog_error 'No SSH private key was provided'
    return 1
  fi
  if [[ -z "${DOMAIN}" ]]; then
    bashlog_error 'No certificate domain was provided'
    return 1
  fi

  CERTIFICATE="${CERTIFICATE:-/etc/letsencrypt/live/${DOMAIN}/cert.pem}"
  KEY="${KEY:-/etc/letsencrypt/live/${DOMAIN}/privkey.pem}"
}

## @fn validate_routeros_name()
## @brief Validates a value before RouterOS command interpolation.
## @details
## Accepts only ASCII letters, digits, underscore, dot, and hyphen.  The first
## character must be alphanumeric or underscore.  This intentionally rejects
## RouterOS syntax metacharacters instead of attempting command-language
## escaping.
##
## @param value Candidate RouterOS-safe value.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns Nothing is written to STDOUT.
## @retval 0 The value is safe for the supported interpolation sites.
## @retval 1 The value is empty or contains a disallowed character.
validate_routeros_name() {
  local value="${1:-}"
  [[ "${value}" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]]
}

## @fn validate_configuration()
## @brief Validates configuration used at local and RouterOS command boundaries.
## @details
## Validates the username, host, numeric SSH port, and domain before remote
## commands are constructed.  Domain-derived remote filenames and certificate
## names inherit the validated domain grammar.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Validation failures are logged to STDERR.
##
## @returns Nothing is written to STDOUT.
## @retval 0 Configuration is valid.
## @retval 1 Configuration is invalid.
validate_configuration() {
  if [[ ! "${ROUTEROS_USER}" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]]; then
    bashlog_error 'Unsafe RouterOS username: %s' "${ROUTEROS_USER}"
    return 1
  fi

  if [[ ! "${ROUTEROS_HOST}" =~ ^[A-Za-z0-9_.:%-]+$ ]]; then
    bashlog_error 'Unsafe RouterOS host: %s' "${ROUTEROS_HOST}"
    return 1
  fi

  if [[ ! "${ROUTEROS_SSH_PORT}" =~ ^[0-9]+$ ]] \
                                                || ((ROUTEROS_SSH_PORT < 1 || ROUTEROS_SSH_PORT > 65535)); then
    bashlog_error 'Invalid RouterOS SSH port: %s' "${ROUTEROS_SSH_PORT}"
    return 1
  fi

  if ! validate_routeros_name "${DOMAIN}"; then
    bashlog_error 'Unsafe certificate domain identifier: %s' "${DOMAIN}"
    return 1
  fi
}

## @fn build_transport_commands()
## @brief Builds argv-safe SSH and SCP command arrays.
## @details
## Tokenizes ROUTEROS_SSH_OPTIONS on shell whitespace without eval and appends
## the resulting tokens to both OpenSSH command arrays.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns Nothing is written to STDOUT.
## @retval 0 Transport command arrays were constructed.
build_transport_commands() {
  local -a extra_options=()

  if [[ -n "${ROUTEROS_SSH_OPTIONS}" ]]; then
    read -r -a extra_options <<< "${ROUTEROS_SSH_OPTIONS}"
  fi

  # Keep each array mutation on a complete physical line while Bash-Minifier
  # cannot parse multiline compound array assignments:
  # https://github.com/Zuzzuc/Bash-minifier/issues/12
  routeros_ssh=(ssh)
  routeros_ssh+=(-i "${ROUTEROS_PRIVATE_KEY}")
  routeros_ssh+=(-p "${ROUTEROS_SSH_PORT}")
  routeros_ssh+=("${extra_options[@]}")
  routeros_ssh+=("${ROUTEROS_USER}@${ROUTEROS_HOST}")

  routeros_scp=(scp)
  routeros_scp+=(-q)
  routeros_scp+=(-P "${ROUTEROS_SSH_PORT}")
  routeros_scp+=(-i "${ROUTEROS_PRIVATE_KEY}")
  routeros_scp+=("${extra_options[@]}")
}

## @fn verify_connection()
## @brief Verifies the configured RouterOS SSH connection.
## @details
## Executes a non-mutating RouterOS resource command through the prepared SSH
## argv array.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Connection progress and remote output are written to STDOUT.
## @par STDERR
## Connection failures are logged to STDERR.
##
## @returns Human-readable connection progress.
## @retval 0 The RouterOS command completed successfully.
## @retval 1 The RouterOS command failed.
verify_connection() {
  printf '%s\n' 'Checking connection to RouterOS'
  if "${routeros_ssh[@]}" "/system resource print"; then
    printf '%s\n' '  Connected.'
    return 0
  fi

  bashlog_error \
    'Could not connect to RouterOS host=%s port=%s' \
    "${ROUTEROS_HOST}" "${ROUTEROS_SSH_PORT}"
  return 1
}

## @fn verify_requirements()
## @brief Verifies that local certificate material is accessible.
## @details
## Checks existence and readability for the certificate and TLS private key.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Requirement-check progress is written to STDOUT.
## @par STDERR
## Requirement failures are logged to STDERR.
##
## @returns Human-readable requirement-check progress.
## @retval 0 Both files exist and are readable.
## @retval 1 The certificate does not exist.
## @retval 2 The certificate is not readable.
## @retval 3 The private key does not exist.
## @retval 4 The private key is not readable.
verify_requirements() {
  printf "Looking for '%s'\n" "${CERTIFICATE}"
  if [[ ! -f "${CERTIFICATE}" ]]; then
    bashlog_error "CERTIFICATE '%s' NOT FOUND" "${CERTIFICATE}"
    return 1
  fi
  if [[ ! -r "${CERTIFICATE}" ]]; then
    bashlog_error "CERTIFICATE '%s' NOT READABLE" "${CERTIFICATE}"
    return 2
  fi
  printf '%s\n' 'Found' 'Readable'

  printf "Looking for key '%s'\n" "${KEY}"
  if [[ ! -f "${KEY}" ]]; then
    bashlog_error "KEY '%s' NOT FOUND" "${KEY}"
    return 3
  fi
  if [[ ! -r "${KEY}" ]]; then
    bashlog_error "KEY '%s' NOT READABLE" "${KEY}"
    return 4
  fi
  printf '%s\n' 'Found' 'Readable'
}

## @fn upload_certificate()
## @brief Uploads and imports the configured certificate.
## @details
## Applies certificate-specific defaults and delegates to upload_file().
##
## @param local_file Local certificate path; defaults to CERTIFICATE.
## @param remote_file RouterOS upload filename; defaults to DOMAIN.pem.
## @param cert_name RouterOS certificate name; defaults to DOMAIN.pem_0.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Processing progress is written to STDOUT.
## @par STDERR
## upload_file() diagnostics may be written to STDERR.
##
## @returns Human-readable processing progress.
## @retval 0 The certificate was processed successfully.
## @note Non-zero statuses from upload_file() are propagated unchanged.
upload_certificate() {
  local local_file="${1:-${CERTIFICATE}}"
  local remote_file="${2:-${DOMAIN}.pem}"
  local cert_name="${3:-${DOMAIN}.pem_0}"

  printf '%s\n' 'Processing certificate'
  upload_file "${local_file}" "${remote_file}" "${cert_name}" || return $?
  printf '%s\n' 'Finished processing certificate'
}

## @fn upload_key()
## @brief Uploads and imports the configured TLS private key.
## @details
## Applies key-specific defaults and preserves upload_file() failure status.
##
## @param local_file Local private-key path; defaults to KEY.
## @param remote_file RouterOS upload filename; defaults to DOMAIN.key.
## @param cert_name RouterOS key name; defaults to DOMAIN.key_0.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Processing progress is written to STDOUT.
## @par STDERR
## upload_file() diagnostics may be written to STDERR.
##
## @returns Human-readable processing progress.
## @retval 0 The private key was processed successfully.
## @note Non-zero statuses from upload_file() are propagated unchanged.
upload_key() {
  local local_file="${1:-${KEY}}"
  local remote_file="${2:-${DOMAIN}.key}"
  local cert_name="${3:-${DOMAIN}.key_0}"

  printf '%s\n' 'Processing key'
  upload_file "${local_file}" "${remote_file}" "${cert_name}" || return $?
  printf '%s\n' 'Finished processing key'
}

## @fn upload_file()
## @brief Uploads one local file and imports it into RouterOS.
## @details
## Best-effort removal of an existing certificate-store entry precedes SCP.
## SCP completion is synchronous, so no fixed sleep is required before import.
##
## @param local_file Local certificate or private-key path.
## @param remote_file RouterOS upload filename.
## @param cert_name Existing RouterOS certificate-store name to replace.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Upload and import progress is written to STDOUT.
## @par STDERR
## Removal warnings and transfer/import errors are logged to STDERR.
##
## @returns Human-readable upload and import progress.
## @retval 0 The file was uploaded and imported successfully.
## @retval 1 SCP failed.
## @retval 2 RouterOS import failed.
## @retval 64 A RouterOS-interpolated name is unsafe.
upload_file() {
  local local_file="${1?Error: no local file provided}"
  local remote_file="${2?Error: no remote file provided}"
  local cert_name="${3?Error: no cert_name provided}"

  if ! validate_routeros_name "${remote_file}" \
                                               || ! validate_routeros_name "${cert_name}"; then
    bashlog_error 'Unsafe RouterOS filename or certificate name'
    return 64
  fi

  printf 'Processing %s => %s [%s]\n' \
    "${local_file}" "${remote_file}" "${cert_name}"

  printf 'Remove previous cert (%s)\n' "${cert_name}"
  if "${routeros_ssh[@]}" \
    "/certificate remove [find name=\"${cert_name}\"]"; then
    printf '%s\n' '  Previous cert removed.'
  else
    bashlog_warning 'Could not remove previous certificate %s' "${cert_name}"
  fi

  printf '%s\n' 'Upload file to RouterOS'
  if "${routeros_scp[@]}" \
    "${local_file}" \
    "${ROUTEROS_USER}@${ROUTEROS_HOST}:${remote_file}"; then
    printf '%s\n' '  New file uploaded.'
  else
    bashlog_error 'Could not upload new file %s' "${remote_file}"
    return 1
  fi

  printf 'Import %s to %s\n' "${remote_file}" "${cert_name}"
  if "${routeros_ssh[@]}" \
    "/certificate import file-name=\"${remote_file}\" passphrase=\"\""; then
    printf '%s\n' '  File imported.'
  else
    bashlog_error 'Could not import uploaded file %s' "${remote_file}"
    return 2
  fi

  printf 'Done processing %s\n' "${local_file}"
}

## @fn delete_file()
## @brief Removes an uploaded file from the RouterOS filesystem.
## @details
## Uses a name lookup so an absent file is a no-op while transport/RouterOS
## failures remain observable.
##
## @param filename RouterOS filename to remove.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Deletion progress is written to STDOUT.
## @par STDERR
## Deletion failures are logged to STDERR.
##
## @returns Human-readable deletion progress.
## @retval 0 The deletion command completed successfully.
## @retval 1 The deletion command failed.
## @retval 64 The filename is unsafe.
delete_file() {
  local filename="${1?Error: no filename specified}"

  if ! validate_routeros_name "${filename}"; then
    bashlog_error 'Unsafe RouterOS filename: %s' "${filename}"
    return 64
  fi

  printf "Delete file '%s'\n" "${filename}"
  if "${routeros_ssh[@]}" "/file remove [find name=\"${filename}\"]"; then
    printf '%s\n' '  File deleted.'
    return 0
  fi

  bashlog_error 'Could not delete RouterOS file %s' "${filename}"
  return 1
}

## @fn configure_services()
## @brief Configures supported RouterOS services to use a certificate.
## @details
## Updates www-ssl, api-ssl, and SSTP using the supplied safe certificate name.
##
## @param cert_name RouterOS certificate name; defaults to DOMAIN.pem_0.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Service progress is written to STDOUT.
## @par STDERR
## Service failures are logged to STDERR.
##
## @returns Human-readable service-configuration progress.
## @retval 0 All configured services were updated.
## @retval 1 www-ssl configuration failed.
## @retval 2 api-ssl configuration failed.
## @retval 3 SSTP configuration failed.
## @retval 64 A service or certificate name is unsupported.
configure_services() {
  local cert_name="${1:-${DOMAIN}.pem_0}"
  local service
  local service_number=0

  if ! validate_routeros_name "${cert_name}"; then
    bashlog_error 'Unsafe RouterOS certificate name: %s' "${cert_name}"
    return 64
  fi

  printf '%s\n' 'Configuring services'
  for service in "${services[@]}"; do
    printf 'Configuring %s to use %s\n' "${service}" "${cert_name}"

    case "${service}" in
      www-ssl | api-ssl)
        if ! "${routeros_ssh[@]}" \
          "/ip service set ${service} certificate=\"${cert_name}\""; then
          bashlog_error 'Could not configure service %s' "${service}"
          return $((service_number + 1))
        fi
        printf '%s\n' '  Service configuration complete.'
        ;;
      sstp)
        if ! "${routeros_ssh[@]}" \
          "/interface sstp-server server set certificate=\"${cert_name}\""; then
          bashlog_error 'Could not configure SSTP'
          return $((service_number + 1))
        fi
        printf '%s\n' '  SSTP configuration complete.'
        ;;
      *)
        bashlog_error 'Unknown service %s' "${service}"
        return 64
        ;;
    esac

    ((service_number += 1))
  done
}

## @fn remove_remote_files()
## @brief Attempts both remote-file deletions and preserves failure status.
## @details
## Each deletion is attempted even when the other fails so cleanup is
## best-effort but observable.
##
## @param certificate_file RouterOS certificate upload filename.
## @param key_file RouterOS private-key upload filename.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## delete_file() progress is written to STDOUT.
## @par STDERR
## delete_file() diagnostics are written to STDERR.
##
## @returns Human-readable deletion progress.
## @retval 0 Both deletion commands completed successfully.
## @retval 1 One or both deletion commands failed.
remove_remote_files() {
  local certificate_file="${1:-${DOMAIN}.pem}"
  local key_file="${2:-${DOMAIN}.key}"
  local status=0

  delete_file "${certificate_file}" || status=1
  delete_file "${key_file}" || status=1
  return "${status}"
}

## @fn setup()
## @brief Removes stale uploaded certificate and key files.
## @details
## Delegates to remove_remote_files() before a new upload begins.
##
## @param certificate_file RouterOS certificate upload filename.
## @param key_file RouterOS private-key upload filename.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Cleanup progress is written to STDOUT.
## @par STDERR
## Cleanup failures are logged to STDERR.
##
## @returns Human-readable cleanup progress.
## @retval 0 Both stale-file deletion commands completed.
## @retval 1 One or both deletion commands failed.
setup() {
  remove_remote_files "${1:-${DOMAIN}.pem}" "${2:-${DOMAIN}.key}"
}

## @fn cleanup()
## @brief Removes uploaded certificate and key files after processing.
## @details
## Delegates to remove_remote_files() after success or a partial failure.
##
## @param certificate_file RouterOS certificate upload filename.
## @param key_file RouterOS private-key upload filename.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Cleanup progress is written to STDOUT.
## @par STDERR
## Cleanup failures are logged to STDERR.
##
## @returns Human-readable cleanup progress.
## @retval 0 Both uploaded-file deletion commands completed.
## @retval 1 One or both deletion commands failed.
cleanup() {
  remove_remote_files "${1:-${DOMAIN}.pem}" "${2:-${DOMAIN}.key}"
}

## @fn main()
## @brief Orchestrates configuration, transfer, import, service update, cleanup.
## @details
## Loads trusted configuration, applies CLI and positional precedence, validates
## the command boundary, checks local requirements/connectivity, performs the
## update, and always attempts final cleanup after upload processing begins.
##
## @param arguments[] Command-line options and positional configuration values.
##
## @par STDIN
## Nothing is intentionally read from STDIN.
## @par STDOUT
## Progress and remote output may be written to STDOUT.
## @par STDERR
## Errors and warnings are emitted through bashlog.
##
## @returns Human-readable orchestration progress.
## @retval 0 The complete workflow succeeded.
## @retval 1 Configuration or local requirements failed.
## @retval 2 RouterOS connectivity verification failed.
## @retval 3 Initial remote-file cleanup failed.
## @retval 4 Certificate upload/import failed.
## @retval 5 Private-key upload/import failed.
## @retval 6 RouterOS service configuration failed.
## @retval 7 Final remote-file cleanup failed.
main() {
  local arg
  local opt
  local primary_status=0
  local cleanup_status=0
  local certificate_remote
  local key_remote

  for arg in "$@"; do
    if [[ "${arg}" == "-h" ]]; then
      usage_help
      return 0
    fi
  done

  load_configuration || return 1

  OPTIND=1
  while getopts ":C:d:H:hK:k:o:p:u:" opt; do
    case "${opt}" in
      C) CERTIFICATE="${OPTARG}" ;;
      d) DOMAIN="${OPTARG}" ;;
      H) ROUTEROS_HOST="${OPTARG}" ;;
      h)
        usage_help
        return 0
        ;;
      K) KEY="${OPTARG}" ;;
      k) ROUTEROS_PRIVATE_KEY="${OPTARG}" ;;
      o) ROUTEROS_SSH_OPTIONS="${OPTARG}" ;;
      p) ROUTEROS_SSH_PORT="${OPTARG}" ;;
      u) ROUTEROS_USER="${OPTARG}" ;;
      :)
        bashlog_error 'Option -%s requires an argument' "${OPTARG}"
        return 1
        ;;
      \?)
        bashlog_error 'Unknown option -%s' "${OPTARG}"
        usage_help >&2
        return 1
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  resolve_configuration "$@" || return 1
  validate_configuration || return 1
  build_transport_commands

  verify_requirements || return 1
  verify_connection || return 2

  certificate_remote="${DOMAIN}.pem"
  key_remote="${DOMAIN}.key"

  setup "${certificate_remote}" "${key_remote}" || return 3

  if ! upload_certificate \
    "${CERTIFICATE}" "${certificate_remote}" "${DOMAIN}.pem_0"; then
    primary_status=4
  elif ! upload_key "${KEY}" "${key_remote}" "${DOMAIN}.key_0"; then
    primary_status=5
  elif ! configure_services "${DOMAIN}.pem_0"; then
    primary_status=6
  fi

  if ! cleanup "${certificate_remote}" "${key_remote}"; then
    cleanup_status=7
  fi

  if ((primary_status != 0)); then
    if ((cleanup_status != 0)); then
      bashlog_error \
        'Cleanup also failed after primary workflow status %s' \
        "${primary_status}"
    fi
    return "${primary_status}"
  fi

  return "${cleanup_status}"
}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  main "$@"
else
  return 0
fi
