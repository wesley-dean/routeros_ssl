#!/usr/bin/env bash
# shellcheck shell=bash

## @file letsencrypt-routeros.bash
## @brief Uploads an existing TLS certificate and private key to RouterOS.
## @details
## This script transfers an existing certificate and its private key to a
## MikroTik RouterOS device over SSH/SCP, imports both files into the RouterOS
## certificate store, and configures selected TLS-capable services to use the
## imported certificate.  Certificate issuance and ACME validation remain
## outside this program.
##
## The root script is the historical public executable and sourceable entry
## point.  Configuration files are sourced as trusted Bash code, and remote
## operations can modify certificate, file, and service state on the target
## RouterOS device.  Callers are responsible for supplying appropriate
## credentials, certificate material, and network reachability.
##
## The current implementation intentionally remains behavior-compatible while
## its documentation and build tooling are modernized.  Function-level
## warnings identify legacy behavior where the executable contract and the
## intended contract currently differ.
## @author Wes Dean
## @see doc/adr/README.md
## @par Examples
## @code
## ./letsencrypt-routeros.bash admin router.example.com 22 ~/.ssh/id_rsa example.com
## ./letsencrypt-routeros.bash -u admin -H router.example.com -p 22 \
##   -k ~/.ssh/id_rsa -d example.com
## @endcode

set -euo pipefail

## @var config_file_options
## @brief list of configuration files to use
## @details
## This is a list (array) of possible configuration files.  Each is loaded in
## the order in which it was specified.  This imples that the last option is
## the one with the highest priority.  Note: runtime parameters take precedence
## over values in the configuration files.
declare -a config_file_options=(".env" "letsencrypt-routeros.settings")

## @var services
## @brief the list of services we want to attempt to configure
## @details
## This is the list of services to attempt to configure.  These generally
## don't need to be changed.  They're in an array because I didn't want to
## write the same code a bunch of times.  If Mikrotik adds new core services
## that require SSL / TLS certificates, they can be added here.
declare -a services=("www-ssl" "api-ssl" "sstp")

## @var ROUTEROS_SSH_OPTIONS
## @brief any extra arguments to pass to ssh / scp
declare ROUTEROS_SSH_OPTIONS="${ROUTEROS_SSH_OPTIONS:-}"

## @var ROUTEROS_USER
## @brief the RouterOS device's administrative user's username
declare ROUTEROS_USER="${ROUTEROS_USER:-admin}"

## @var ROUTEROS_PRIVATE_KEY
## @brief path/filename to the ssh private key to use to connect to the device
declare ROUTEROS_PRIVATE_KEY="${ROUTEROS_PRIVATE_KEY:-}"

## @var ROUTEROS_HOST
## @brief the hostname / IP address of the RouterOS device to update
declare ROUTEROS_HOST="${ROUTEROS_HOST:-}"

## @var DOMAIN
## @brief the domain to use with the certificate
declare DOMAIN="${DOMAIN:-}"

## @var CERTIFICATE
## @brief path/filename to the signed certificate to upload
declare CERTIFICATE="${CERTIFICATE:-/etc/letsencrypt/$DOMAIN/live/cert.pem}"

## @var KEY
## @brief path/filename to the private key associated with the certificate
declare KEY="${KEY:-/etc/letsencrypt/$DOMAIN/live/privkey.pem}"

## @fn usage_help()
## @brief Writes command usage and configuration-file names.
## @details
## Prints the positional and option-oriented invocation forms followed by the
## supported configuration-file candidates.  The function performs no
## validation and does not change configuration state.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Usage text and supported configuration-file names are written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
##
## @returns Human-readable usage text.
## @retval 0 The usage text was written successfully.
## @note A non-zero status from an underlying output operation may propagate.
## @par Examples
## @code
## usage_help
## @endcode
usage_help() {
  echo "
$0 [RouterOS User] [RouterOS Host] [SSH Port] [SSH Private Key] [Domain]

or

$0
  -d [Domain]
  -h [RouterOS Host]
  -k [SSH Private Key]
  -p [RouterOS SSH Port]
  -u [RouterOS User]
  -o [RouterOS SSH Options]

or use a configuration file:"

  for config_file in "${config_file_options[@]}"; do
    echo "* $config_file"
  done
}

## @fn verify_connection()
## @brief Verifies that the configured RouterOS SSH connection is usable.
## @details
## Executes `/system resource print` through the prepared RouterOS SSH command.
## A successful remote command is treated as evidence that authentication and
## command execution are available before mutating remote certificate state.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Connection progress and any remote command output are written to STDOUT.
## @par STDERR
## Connection diagnostics and SSH diagnostics may be written to STDERR.
##
## @returns Human-readable connection progress and remote command output.
## @retval 0 The RouterOS command completed successfully.
## @retval 1 The RouterOS command could not be completed.
## @par Examples
## @code
## verify_connection || exit 1
## @endcode
verify_connection() {
  echo "Checking connection to RouterOS"
  if $routeros_ssh "/system resource print"; then
    echo "  Connected."
  else
    echo -e "
Error in: $routeros_ssh

More info: https://wiki.mikrotik.com/wiki/Use_SSH_to_execute_commands_(DSA_key_login)
" 1>&2
    return 1
  fi
}

## @fn verify_requirements()
## @brief Verifies that the local certificate and private key are accessible.
## @details
## Checks that the configured certificate and private-key paths exist as files
## and are readable before any remote mutation begins.  The checks are ordered
## so certificate failures are reported before private-key failures.
## @warning The legacy implementation reports an unreadable private key but
## currently falls through with a successful status.  Runtime correction is
## intentionally deferred from the documentation/build modernization change.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## File-check progress is written to STDOUT.
## @par STDERR
## Missing or unreadable file diagnostics are written to STDERR.
##
## @returns Human-readable requirement-check progress.
## @retval 0 The checks reached the end of the function.
## @retval 1 The certificate file does not exist.
## @retval 2 The certificate file is not readable.
## @retval 3 The private-key file does not exist.
## @par Examples
## @code
## verify_requirements || exit 1
## @endcode
verify_requirements() {
  echo "Looking for '$CERTIFICATE'"

  if [ -f "$CERTIFICATE" ]; then
    echo "Found"
  else
    echo "CERTIFICATE '$CERTIFICATE' NOT FOUND" 1>&2
    return 1
  fi

  if [ -r "$CERTIFICATE" ]; then
    echo "Readable"
  else
    echo "CERTIFICATE '$CERTIFICATE' NOT READABLE" 1>&2
    return 2
  fi

  echo "Looking for key '$KEY'"

  if [ -f "$KEY" ]; then
    echo "Found"
  else
    echo "KEY '$KEY' NOT FOUND" 1>&2
    return 3
  fi

  if [ -r "$KEY" ]; then
    echo "Readable"
  else
    echo "KEY '$KEY' NOT READABLE" 1>&2
  fi
}

## @fn upload_certificate()
## @brief Uploads and imports the configured certificate.
## @details
## Supplies certificate-specific defaults to upload_file() and reports progress
## around that operation.  The default remote filename is `$DOMAIN.pem`, and
## the default imported certificate name is `$DOMAIN.pem_0`.
##
## @param local_file Local certificate path; defaults to `CERTIFICATE`.
## @param remote_file RouterOS upload filename; defaults to `$DOMAIN.pem`.
## @param cert_name RouterOS certificate name; defaults to `$DOMAIN.pem_0`.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Certificate-processing progress and upload_file() output are written.
## @par STDERR
## upload_file() diagnostics may be written to STDERR.
##
## @returns Human-readable certificate-processing progress.
## @retval 0 The certificate was processed successfully.
## @note Non-zero statuses from upload_file() are propagated unchanged.
## @par Examples
## @code
## upload_certificate "$CERTIFICATE" "$DOMAIN.pem" "$DOMAIN.pem_0"
## @endcode
upload_certificate() {
  local_file="${1:-$CERTIFICATE}"
  remote_file="${2:-$DOMAIN.pem}"
  cert_name="${3:-$DOMAIN.pem_0}"
  echo "Processing certificate"

  upload_file "$local_file" "$remote_file" "$cert_name" || return $?

  echo "Finished processing certificate"
}

## @fn upload_key()
## @brief Uploads and imports the configured private key.
## @details
## Supplies private-key-specific defaults to upload_file() and reports progress
## around that operation.  The default remote filename is `$DOMAIN.key`, and
## the default imported name is `$DOMAIN.key_0`.
## @warning The legacy implementation does not explicitly propagate a failing
## upload_file() status before writing its final progress line.  In caller
## contexts that suppress errexit, that final output may mask the failure.
##
## @param local_file Local private-key path; defaults to `KEY`.
## @param remote_file RouterOS upload filename; defaults to `$DOMAIN.key`.
## @param cert_name RouterOS key import name; defaults to `$DOMAIN.key_0`.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Private-key processing progress and upload_file() output are written.
## @par STDERR
## upload_file() diagnostics may be written to STDERR.
##
## @returns Human-readable private-key processing progress.
## @retval 0 The function reaches its final progress output successfully.
## @note upload_file() may produce a non-zero status that is not preserved by
## the current wrapper in every calling context.
## @par Examples
## @code
## upload_key "$KEY" "$DOMAIN.key" "$DOMAIN.key_0"
## @endcode
upload_key() {
  local_file="${1:-$KEY}"
  remote_file="${2:-$DOMAIN.key}"
  cert_name="${3:-$DOMAIN.key_0}"
  echo "Processing certificate"

  upload_file "$local_file" "$remote_file" "$cert_name"

  echo "Finished processing key"
}

## @fn upload_file()
## @brief Uploads one local file and imports it into RouterOS.
## @details
## Removes an existing certificate-store entry with the requested name, copies
## the local file to the RouterOS device with SCP, waits briefly, and invokes
## the RouterOS certificate import command.  Failure to remove the previous
## certificate is reported but does not stop the replacement attempt.
##
## This function mutates remote certificate state and uploads a temporary file.
## The caller is responsible for later cleanup of the uploaded file.
##
## @param local_file Local path to the certificate or private-key file.
## @param remote_file Filename to use for the RouterOS upload.
## @param cert_name Existing RouterOS certificate-store name to remove.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Upload/import progress and remote command output may be written to STDOUT.
## @par STDERR
## Removal, SCP, SSH, and import diagnostics may be written to STDERR.
##
## @returns Human-readable upload and import progress.
## @retval 0 The file was uploaded and imported successfully.
## @retval 1 SCP could not upload the file.
## @retval 2 RouterOS could not import the uploaded file.
## @par Examples
## @code
## upload_file \
##   "/etc/letsencrypt/live/example.com/cert.pem" \
##   "example.com.pem" \
##   "example.com.pem_0"
## @endcode
upload_file() {
  local_file="${1?Error: no local file provided}"
  remote_file="${2?Error: no remote file provided}"
  cert_name="${3?Error: no cert_name provided}"

  echo "Processing $local_file => $remote_file [$cert_name]"

  echo "Remove previous cert ($cert_name)"
  if $routeros_ssh "/certificate remove [find name=$cert_name]"; then
    echo "  Previous cert removed."
  else
    echo "  Could not remove previous cert" 1>&2
  fi

  echo "Upload file to RouterOS"
  if $routeros_scp "$local_file" "$ROUTEROS_USER"@"$ROUTEROS_HOST":"$remote_file"; then
    echo "  New file uploaded."
  else
    echo "  Could not upload new file" 1>&2
    return 1
  fi

  sleep 2

  echo "Import $remote_file to $cert_name"
  if $routeros_ssh "/certificate import file-name=$remote_file passphrase=\"\""; then
    echo "  File imported."
  else
    echo "  Could not import file file" 1>&2
    return 2
  fi

  echo "Done processing $local_file"
}

## @fn delete_file()
## @brief Attempts to remove an uploaded file from the RouterOS filesystem.
## @details
## Runs the RouterOS `/file remove` command for the supplied filename.  This
## removes the uploaded file only; it does not remove an imported certificate
## from the RouterOS certificate store.
## @warning A remote deletion failure is reported but the legacy implementation
## does not preserve that non-zero status because the diagnostic output becomes
## the function's final command.
##
## @param filename RouterOS filename to remove.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Deletion progress and remote command output may be written to STDOUT.
## @par STDERR
## Remote deletion diagnostics may be written to STDERR.
##
## @returns Human-readable deletion progress.
## @retval 0 The function reaches the end after attempting deletion.
## @note Omitting `filename` triggers the required-parameter expansion error.
## @par Examples
## @code
## delete_file "$DOMAIN.pem"
## @endcode
delete_file() {
  filename="${1?Error: no filename specified}"

  echo "Delete file '$filename'"
  if $routeros_ssh "/file remove $filename"; then
    echo "  File deleted."
  else
    echo "  Could not delete file" 1>&2
  fi
}

## @fn configure_services()
## @brief Configures supported RouterOS services to use an imported certificate.
## @details
## Iterates over the global `services` array and assigns the supplied
## certificate name to each supported service.  `www-ssl` and `api-ssl` are
## configured through `/ip service`; `sstp` is configured through the SSTP
## server interface.
## @warning An unknown service causes the legacy implementation to exit the
## current shell with status 100 instead of returning to the caller.
##
## @param cert_name RouterOS certificate-store name; defaults to `$DOMAIN.pem_0`.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Service-configuration progress and remote output may be written to STDOUT.
## @par STDERR
## Service failures and remote diagnostics may be written to STDERR.
##
## @returns Human-readable service-configuration progress.
## @retval 0 All configured services were updated successfully.
## @retval 1 The `www-ssl` service could not be configured.
## @retval 2 The `api-ssl` service could not be configured.
## @retval 3 The `sstp` service could not be configured.
## @par Examples
## @code
## configure_services "$DOMAIN.pem_0" || exit 1
## @endcode
configure_services() {
  cert_name="${1:-$DOMAIN.pem_0}"

  echo "Configuring services"
  service_number=0

  for service in "${services[@]}"; do

    echo "Configuring $service to use $cert_name"

    case "$service" in
      www-ssl | api-ssl)
        if $routeros_ssh "/ip service set $service certificate=$cert_name"; then
          echo "  Service configuration complete."
        else
          echo "  Could not configure service" 1>&2
          return $((service_number + 1))
        fi
           ;;
      sstp)
        if $routeros_ssh "/interface sstp-server server set certificate=$cert_name"; then
          echo "  SSTP configuration complete."
        else
          echo "  Could not configure SSTP." 1>&2
          return $((service_number + 1))
        fi
          ;;
      *)
        echo "Unknown service '$service'" 1>&2
                                                 exit 100
                                                          ;;
    esac
    service_number=$((service_number + 1))
  done
}

## @fn setup()
## @brief Attempts to remove stale uploaded certificate and key files.
## @details
## Calls delete_file() for the certificate and private-key upload names before
## new files are copied to the RouterOS device.  Deletion failures are
## deliberately suppressed by the current legacy implementation.
##
## @param certificate_file RouterOS certificate upload filename.
## @param key_file RouterOS private-key upload filename.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## delete_file() progress may be written to STDOUT.
## @par STDERR
## delete_file() diagnostics may be written to STDERR.
##
## @returns Human-readable remote-file cleanup progress.
## @retval 0 The cleanup attempts completed or their failures were suppressed.
## @par Examples
## @code
## setup "$DOMAIN.pem" "$DOMAIN.key"
## @endcode
setup() {
  certificate_file="${1:-$DOMAIN.pem}"
  key_file="${2:-$DOMAIN.key}"

  delete_file "$certificate_file" || true
  delete_file "$key_file" || true
}

## @fn cleanup()
## @brief Attempts to remove uploaded certificate and key files after use.
## @details
## Calls delete_file() for the certificate and private-key upload names after
## service configuration.  Deletion failures are suppressed by the current
## legacy implementation, so the caller cannot presently distinguish them
## through this function's status.
##
## @param certificate_file RouterOS certificate upload filename.
## @param key_file RouterOS private-key upload filename.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## delete_file() progress may be written to STDOUT.
## @par STDERR
## delete_file() diagnostics may be written to STDERR.
##
## @returns Human-readable remote-file cleanup progress.
## @retval 0 The cleanup attempts completed or their failures were suppressed.
## @par Examples
## @code
## cleanup "$DOMAIN.pem" "$DOMAIN.key"
## @endcode
cleanup() {
  certificate_file="${1:-$DOMAIN.pem}"
  key_file="${2:-$DOMAIN.key}"

  delete_file "$certificate_file" || true
  delete_file "$key_file" || true
}

## @fn main()
## @brief Orchestrates configuration loading, validation, upload, and cleanup.
## @details
## Loads the selected configuration file, parses command-line options, resolves
## remaining positional configuration, prepares SSH/SCP command strings, checks
## local requirements and connectivity, uploads certificate material, updates
## RouterOS services, and attempts remote-file cleanup.
##
## Configuration files are sourced as trusted Bash code.  Several failure
## paths use `exit` rather than `return`; callers that source this file and
## invoke main() therefore expose their shell to those exits.
##
## @param arguments[] Command-line options and positional configuration values.
##
## @par STDIN
## Nothing is intentionally read from STDIN.
## @par STDOUT
## Progress messages and remote command output may be written to STDOUT.
## @par STDERR
## Configuration, validation, SSH/SCP, import, and service diagnostics may be
## written to STDERR.
##
## @returns Human-readable orchestration progress and remote command output.
## @retval 0 The complete workflow reached the end successfully.
## @retval 1 Configuration loading or local requirement validation failed.
## @retval 2 RouterOS connectivity verification failed.
## @retval 3 Initial remote-file cleanup failed.
## @retval 4 Certificate upload/import failed.
## @retval 5 Private-key upload/import failed.
## @retval 6 RouterOS service configuration failed.
## @retval 7 Final remote-file cleanup failed.
## @note Legacy option and cleanup behavior can make some documented branches
## unreachable or report statuses differently than intended.
## @par Examples
## @code
## main admin router.example.com 22 ~/.ssh/id_rsa example.com
## @endcode
main() {

  CONFIG_FILE="${CONFIG_FILE:-}"

  if [ -n "${CONFIG_FILE:-}" ]; then
    for config_file in "${config_file_options[@]}"; do
      [ -f "$config_file" ] && CONFIG_FILE="$config_file"
    done
  fi

  if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  else
    echo "Could not load CONFIG_FILE '$CONFIG_FILE'" 1>&2
    exit 1
  fi

  while getopts "C:d:H:hK:k:o:p:u:i?" opt; do
    case "$opt" in
      C) CERTIFICATE="$OPTARG" ;;
      d) DOMAIN="$OPTARG" ;;
      H) ROUTEROS_HOST="$OPTARG" ;;
      h) usage_help && exit 0 ;;
      K) KEY="$OPTARG" ;;
      k) ROUTEROS_PRIVATE_KEY="$OPTARG" ;;
      o) ROUTEROS_SSH_OPTIONS="$OPTARG" ;;
      p) ROUTEROS_SSH_PORT="$OPTARG" ;;
      u) ROUTEROS_USER="$OPTARG" ;;
      ?) usage_help 1>&2 && exit 0 ;;
    esac
  done

  [ -z "$ROUTEROS_USER" ] && ROUTEROS_USER="${1?Error: no username provided}"
  [ -z "$ROUTEROS_HOST" ] && ROUTEROS_HOST="${2?Error: no hostname provided}"
  [ -z "$ROUTEROS_SSH_PORT" ] && ROUTEROS_SSH_PORT="${3?Error: no port provided}"
  [ -z "$ROUTEROS_PRIVATE_KEY" ] && ROUTEROS_PRIVATE_KEY="${4?Error: no key provided}"
  [ -z "$DOMAIN" ] && DOMAIN="${5?Error: no domain provided}"

  CERTIFICATE="${CERTIFICATE:-/etc/letsencrypt/live/$DOMAIN/cert.pem}"
  KEY="${KEY:-/etc/letsencrypt/live/$DOMAIN/privkey.pem}"

  routeros_ssh="ssh -i $ROUTEROS_PRIVATE_KEY $ROUTEROS_USER@$ROUTEROS_HOST -p $ROUTEROS_SSH_PORT $ROUTEROS_SSH_OPTIONS"
  routeros_scp="scp -q -P $ROUTEROS_SSH_PORT -i $ROUTEROS_PRIVATE_KEY $ROUTEROS_SSH_OPTIONS"

  verify_requirements || exit 1
  verify_connection || exit 2
  setup "$DOMAIN.pem" "$DOMAIN.key" || exit 3

  upload_certificate "$CERTIFICATE" "$DOMAIN.pem" "$DOMAIN.pem_0" || exit 4
  upload_key "$KEY" "$DOMAIN.key" "$DOMAIN.key_0" || exit 5

  configure_services "$DOMAIN.pem_0" || exit 6

  cleanup "$DOMAIN.pem" "$DOMAIN.key" || exit 7
}

# if we're not being sourced and there's a function named `main`, run it
[[ "$0" == "${BASH_SOURCE[0]}" ]] && [ "$(type -t "main")" == "function" ] && main "$@"
