#!/usr/bin/env bash

## @fn letsencrypt-routeros.bash
## @brief shell script to setup a RouterOS device to use an SSL certificate
## @details
## It's possible to generate SSL / TLS certificates on a RouterOS device using
## commands on the device itself.  As of September 2024, it's possible to
## setup a RouterOS device to generate and have signed certificates using
## LetsEncrypt.  The downside to this approach is that it involves opening
## port 80 so that LetsEncrypt can call a well-known URL to verify ownership
## of a domain before it will sign a certificate.  Opening port 80 on an
## edge device may not be a risk that everyone is willing to accept.  This
## script allows one to use an alternative verification challenge (e.g.,
## DNS-01) to prove ownership and run certbot locally to generate and have
## signed a key and certificate, then upload those files into a RouterOS
## device.
##
## This process allows one to use LetsEncrypt in conjunction with the www-ssl
## and api-ssl services on a RouterOS device.
##
## While this script was written with LetsEncrypt in mind, there's no reason
## that an arbitrary certificate and private key obtained from any other
## means can't be used.  If you, dear reader, want to use a self-signed cert
## or pay a certificate authority to sign a certificate, please, by all means,
## use this script.
##
## This script was based on the file work by [kiprox](https://github.com/kiprox)
## and GPL3-licensed code uploaded to the
## [kiprox/mikrotik-ssl repo](https://github.com/kiprox/mikrotik-ssl) on
## [GitHub](https://GitHub.com/).
##
## @author Wes Dean

set -euo pipefail

## @var config_file_options[]
## @brief list of configuration files to use
## @details
## This is a list (array) of possible configuration files.  Each is loaded in
## the order in which it was specified.  This imples that the last option is
## the one with the highest priority.  Note: runtime parameters take precedence
## over values in the configuration files.
declare -a config_file_options=(".env" "letsencrypt-routeros.settings")

## @var services[]
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
## @brief display help to the end-user
## @details
## This will try to provide some semi-userful information back to the
## end-user so that they can use the tool as-intended.
## @retval 0 (True) if the help text was displayed
## @retval 1 (False) if something went wrong
## @par Examples
## @code
## usage_help || exit 1
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
## @brief verify that we can connect to the RouterOS device
## @details
## Before we attempt to upload files, import certificates, etc. we want to
## make sure we can connect to the RouterOS device.  This will login via
## SSH and attempt to display some basic system information using a command
## that ought not fail.  If this is unsuccessful, we can be pretty sure that
## we're unable to connect to the RouterOS device.
## @retval 0 (True) if a connection was established
## @retval 1 (Fail) if a connection could not be madei
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
## @brief verify that the local files we'll need are present and accessible
## @details This will verify that the certificate and private portion of
## the key are available and readable.  It doesn't help if we can connect and
## upload one file if the other doesn't exist or isn't readable.  So, to make
## sure we have everything we need, we make sure stuff's there.  If something
## isn't there or isn't readable, we want to report that back as soon as
## possible.
##
## The certificate is specified using the $CERTIFICATE variable; if that's
## not configured, the default is $DOMAIN.pem
##
## The private key is specified using the $KEY variable; if that's not
## configured, the default is $KEY.key
##
## The extra step of verifying if the files are readable is because they are
## often stored in a location that only root can access.
##
## We return a result code of 0 (True) if everything's good to go; otherwise,
## we return a non-zero code indicating what's wrong.
## @retval 0 (True) if everything exists and is readable
## @retval 1 (False) if the certificate is missing
## @retval 2 (False) if the certificate is unreadable
## @retval 3 (False) if the private key is missing
## @retval 4 (False) if the private key is unreadable
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
## @brief upload the certificate to the RouterOS device
## @details
## This is wrapper around upload_file() that specifies the local, remote, and
## certificate names while making it more clear what's going on.
## The return code is that which is passed back from upload_file()
## @param local_file the path/filename of the local file ($CERTIFICATE)
## @param remote_file the path/filename of where the file should be placed
## @param cert_name the name of the certificate once it has been imported
## @retval 0 (True) if the upload and import were successful
## @retval non-zero (False) if the upload or the import were unsuccessful
## @par Examples
## @code
## upload_certificate || exit 1
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
## @brief upload the private portion of the key to the RouterOS device
## @details
## This is wrapper around upload_file() that specifies the local, remote, and
## key names while making it more clear what's going on.
## The return code is that which is passed back from upload_file()
## @param local_file the path/filename of the local file ($KEY)
## @param remote_file the path/filename of where the file should be placed
## @param cert_name the name of the key once it has been imported
## @retval 0 (True) if the upload and import were successful
## @retval non-zero (False) if the upload or the import were unsuccessful
## @par Examples
## @code
## upload_key || exit 1
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
## @brief upload and import a file (certificate or key)
## @details
## This does the bulk of the file transfer and importing of the cert and/or
## key.
##
## First we try to remove the remote certificate / key.  This may fail the first
## time the script is run as there may not be a certificate / key to remove.
##
## By "remove", we mean telling the RouterOS device not to use this
## certificate / key any more.  We're removing the certificate / key, not
## deleting the file that contains it.
##
## Then we attempt to delete the remote file.  This will usually fail because
## one of the last steps is to cleanup the uploaded files.
##
## Then, we upload the local_file from the local system to the RouterOS
## device.  We use SCP to transfer the file.  If this step fails, we abort
## and return an error.
##
## After a short delay, we attempt to import the uploaded file into the
## RouterOS device's certificate store.
## @param local_file the local file to upload
## @param remote_file what to call the file on the remote system
## @param cert_name the name of the file in the certificate store
## @retval 0 (True) if the upload and import were successful
## @retval 1 (False) if the file could not be uploaded
## @retval 2 (False) if the file could not be imported
## @par Examples
## @code
## upload_file \
##   "/etc/letsencrypt/live/example.com/cert.pem" \
##   "example.com.pem" \
##   "example.com.pem_0" \
## || exit 1
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
## @brief delete a file from the RouterOS device
## @details
## This will delete the specified file from the RouterOS device.  The file
## should be removed from the certificate store first.  This DOES NOT remove
## the certificate from the certificate store.
##
## It's possible -- probable -- that this will fail, especially when it is
## called by setup() because cleanup() will remove the file when the script
## is finishing up.
## @retval 0 (True) if an attempt to delete the file was made
## @retval 1 (False) if no filename was passed, it will exit with a code of 1
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

## @configure_services()
## @brief configure the incoming services to use the newly imported cert / key
## @details
## This will loop through the services[] list and attempt to configure them to
## use the certificate and key that were just uploaded and imported.
##
## The certificate and key must have been uploaded and imported prior to using
## this to configure the services to use them.  This does not upload nor
## import the certificate or the private key.
## @param cert_name the name of the certificate in the key store to use
## @retval 0 (True) if the configuration for all services was successful
## @retval non-zero (False) the service that couldn't be configured
## @par Examples
## @code
## configure_services || return $?
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
## @brief perform setup steps
## @details
## This will setup the environment by:
## 1. removing an old uploaded certificate
## 2. removing an old uploaded private key
##
## It's probable that both of these will fail given that the cleanup step at
## the end of this process removes these files.  We're making sure they're
## gone so that there's no ambiguity about the certificate or private key we're
## using.
## @param certificate_file the filename of the remote certificate file
## @param key_file the filename of the remote private key file
## @retval 0 (True) Most situations
## @retval non-zero (False) this shouldn't be possible
## @par Examples
## @code
## setup || true
## @endcode
setup() {
  certificate_file="${1:-$DOMAIN.pem}"
  key_file="${2:-$DOMAIN.key}"

  delete_file "$certificate_file" || true
  delete_file "$key_file" || true
}

## @fn cleanup()
## @brief cleanup after ourselves
## @details
## This will cleanup the environment by:
## 1. removing the uploaded certificate
## 2. removing the uploaded private key
## @param certificate_file the filename of the remote certificate file
## @param key_file the filename of the remote private key file
## @retval 0 (True) Most situations
## @retval 1 if the certificate file couldn't be deleted
## @retval 2 if the private key could not be deleted
## @par Examples
## @code
## cleanup || exit 1
## @endcode
cleanup() {
  certificate_file="${1:-$DOMAIN.pem}"
  key_file="${2:-$DOMAIN.key}"

  delete_file "$certificate_file" || true
  delete_file "$key_file" || true
}

## @fn main()
## @brief the program's primary function
## @details
## This will parse incoming arguments, load configuration from the
## filesystem, call the functions to do the work, and cleanup afterwards.
## @retval 0 (True) if the program was successful
## @retval non-zero (False) if anything failed
## @par Examples
## @code
## main "$@" || exit $?
## @endcode
main() {

  CONFIG_FILE="${CONFIG_FILE:-}"

  if [ -n "${CONFIG_FILE:-}" ] ; then
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
