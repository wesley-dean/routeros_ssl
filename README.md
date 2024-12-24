# routeros_ssl

This is a shell script to copy SSL / TLS certificates from one system, import
them into the RouterOS certificate store, and configure HTTP-related services
to use them.

While the initial intent and core focus was using certificates signed by
[Let's Encrypt](https://letsencrypt.org/), there's no dependency on Let's
Encrypt, ACME, Certbot, or any particular certificate signing authority.  The
certificates can even be self-signed, if desired.

This shell script is written to support
[RouterOS devices](https://mikrotik.com/software/) produced by
[Mikrotik](https://mikrotik.com/).  It's extremely unlikely that it will work
with any other platform.

## What it Does

This is a shell script written in Bash that uploads certificate and private
key files, imports them into RouterOS's certificate store, and configures
HTTP-related services to use them.

## What it Does Not Do

This script will not generate keys or certificates, not will it
cryptographically sign anything.  All of that it outside of the scope for this
tool.

## Why Use This Tool

Version 7 of RouterOS, since roughly September of 2024, supports using
Let's Encrypt services natively.  However, it requires the use of the ACME
HTTP-01 challenge format which requires port 80 of the device to be
accessible from the Internet.  There's no technical reason why one can't do
this; however, exposing port 80 to the Internet on an edge device may have
negative consequences with regards to one's risk profile.  That is, it's
entirely possible so long as one is prepared to accept the risk.

## How to Use This Tool

### Requirements

This tool makes use of [OpenSSH](https://openssh.org/) which is developed and
maintained by the makers of [OpenBSD](https://openbsd.org/).  The tool is
essentially a Bash script, so it requires
[GNU Bash](https://gnu.org/software/bash/).  

The tool uses key-based authentication for logging in to the RouterOS device
with SSH.  Therefore, the public portion of the key must be previously
associated with the RouterOS user that will be used to upload the files,
import them, and configure services to use them.  It's highly recommended that
the RouterOS device's host key be stored in the local user's `.ssh/known_hosts`
file prior to running the script.

Lastly, the tool requires a
signed SSL / TLS certificate and its corresponding private key.  The tool will
default to the standard location where Let's Encrypt would locally store
keys (privkey.pem) and signed certificates (cert.pem), namely:

`/etc/letsencrypt/live/$DOMAIN/`

These are requirements that need to exist before the script is run.  Without
them, the script will fail.

Again, this script will not generate nor sign certificates -- they need to
exist first.

### Configuration

The tool can be configured by several mechanisms:

1. configuration file
2. environment variable
3. command line option

#### Configuration Files

The tool will look for `.env` and `letsencrypt-routeros.settings` in the
current directory, in that order.  If both files exist, the `.env` file is
read first, then the `letsencrypt-routeros.settings` file.  Parameters in
`.env` file are overridden by everything else.  It is recommended that only
one of the two files is present to simplify debugging.

Both of these files are sourced as Bash scripts.  Therefore, the entirety of
the Bash scripting language is available for use.  That said, it's likely for
the best to use structures typically found in a `.env` file:

```bash
# comment
PARAMETER="value"
```

The supported parameters include:

- `ROUTEROS_USER`: the username for the account on the RouterOS device to use
  to upload the files, import them, and configure services.  This is likely
  a user with administrative privileges.  It's recommended for audit purposes
  that this be a service account with minimally-scoped privileges.
- `ROUTEROS_HOST`: this is the hostname or IP address of the RouterOS device
  that is being configured.
- `ROUTEROS_SSH_PORT`: this is the port on the RouterOS device where the SSH
  service is bound listening for incoming connections.  The standard port for
  SSH is 22, but it may be different depending on the installation.
- `ROUTEROS_PRIVATE_KEY`: this is the location on the local system that has the
  private portion of an SSH key used to authenticate to the RouterOS user that
  was previously mentioned.  The public portion of this key must be associated
  with the RouterOS user account.
- `DOMAIN`: this is the domain that is being supported by this certificate.  It
  must be compatible with the domain name used with the certificate -- it can
  be the exact hostname or the certificate can be a wildcard certificate that
  includes this hostname.  It is used to name the private key and certificate
  in the RouterOS certificate store as well as the default location of the
  private key and certificate on the local system.
- `CERTIFICATE`: this is the path and filename of the signed certificate,
  typically found at `/etc/letsencrypt/live/$DOMAIN/cert.pem`
- `KEY`: this is the path and filename of the private key, typically found at
  `/etc/letsencrypt/live/$DOMAIN/privkey.pem`
