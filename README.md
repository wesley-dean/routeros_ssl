[![MegaLinter](https://github.com/wesley-dean/routeros_ssl/actions/workflows/megalinter.yml/badge.svg)](https://github.com/wesley-dean/routeros_ssl/actions/workflows/megalinter.yml)
[![Dependabot Updates](https://github.com/wesley-dean/routeros_ssl/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/wesley-dean/routeros_ssl/actions/workflows/dependabot/dependabot-updates)
[![MegaLinter](https://github.com/wesley-dean/routeros_ssl/actions/workflows/megalinter.yml/badge.svg)](https://github.com/wesley-dean/routeros_ssl/actions/workflows/megalinter.yml)

# wesley-dean/routeros_ssl

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

## Where to Find the Source Code

The source code for this tool is hosted on [GitHub](https://github.com/) at
[wesley-dean/routeros_ssl](https://github.com/wesley-dean/routeros_ssl/).

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

Because the tool uses SSH to interact with RouterOS-based devices, the SSH
service must be enabled on the RouterOS device and an administrative user that
will be used is able to connect using SSH.  The port to which the SSH service
is bound -- typically port 22 -- must be known and accessible via the network
where this script will be run.

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

1. configuration files
2. command line options

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
- `ROUTEROS_SSH_OPTIONS`: these are any additional options to pass along to
  `ssh` or `scp` (e.g., `-o PubkeyAcceptedAlgorithms=ssh-rsa`)

#### Command Line Options

Additionally, the script accepts several options at runtime as command line
options:

- -C [path / filename to the signed certificate; `CERTIFICATE`]
- -d [domain associated with the certificate; `DOMAIN`]
- -h show usage directions
- -H [hostname of the RouterOS device; `ROUTEROS_HOST`]
- -K [path / filename to the certificate private key; `KEY`]
- -k [path / filename to the SSH private key; `$ROUTEROS_PRIVATE_KEY`]
- -o [additional options to pass to ssh/scp; `$ROUTEROS_SSH_OPTIONS`]
- -p [port on the RouterOS device where SSH is listening; `$ROUTEROS_SSH_PORT`]
- -u [username of the user on the RouterOS device; `$ROUTEROS_USER`]

Lastly, options may be provided positionally:

1. `ROUTEROS_USER`
2. `ROUTEROS_HOST`
3. `ROUTEROS_SSH_PORT`
4. `ROUTEROS_PRIVATE_KEY`
5. `DOMAIN`

For example:

```bash
$ letsencrypt-routeros.bash admin 192.168.1.1 22 ~/.ssh/id_rsa example.com
```

### Usage

Assuming that the previously-mentioned requirements are met:
- a signed certificate and its private key are available
- the RouterOS device to be configured has SSH enabled
- an administrative user has key-based authentication configured
- that the private portion of the SSH key is available

the script may be invoked the same was as most other Bash scripts.  It may be
invoked on an ad-hoc basis from the command line, via cron script, as a
[post-validation hook](https://eff-certbot.readthedocs.io/en/stable/using.html#pre-and-post-validation-hooks)
run by Certbot, as a containerized service, etc..

#### Containerized Usage

A containerized image is available to expedite installation and usage.  The
image is compatible with Docker, Podman, and more, is available on DockerHub and
GitHub Container Registry:

- DockerHub:
  [docker.io/wesleydean/routeros_ssl](https://hub.docker.com/r/wesleydean/routeros_ssl)
- GHCR:
  [ghcr.io/wesley-dean/routeros_ssl](https://github.com/wesley-dean/routeros_ssl/pkgs/container/routeros_ssl)

The tool, a Bash script, uses OpenSSH to interact with RouterOS devices; it
doesn't require additional network access, special tooling, capabilities, etc.
access to hosting providers, etc..

The tool doesn't generate or sign certificates or private keys.  It only
uploads, imports, and configures existing signed certificates (and their
private keys).  Therefore, the directory where the certificates and their
private keys must be provided to the container.  Typically certbot will use
symbolic links (symlinks) to reference the current version of a certificate and
its key; therefore, it's recommended to bind-mount the volume above the `live`
directory (e.g., `/etc/letsencrypt`).

It's also possible to mount specific files (the `cert.pem` and `privkey.pem`
files generated by certbot, for example) and update the `CERTIFICATE` and `KEY`
parameters, respectively.

It's also possible to avoid using bind mounts by creating a named volume and
mounting that.  The certificate and its private key would need to be managed
by another process.

It's encouraged to use environment variables to configure the container at
runtime.  In the event that this would prove difficult to manage, one may also
mount the directory where the configuration file is located and set the
working directory for the container to where the configuration file would be
exposed on the container's filesystem.

##### Running the Image

A container may be substantiated with:

```bash
docker run \
  --rm \
  -it \
  -v "/etc/letsencrypt/:/etc/letsencrypt:ro" \
  -v "${PWD}:/var/run/routeros-ssl/:ro" \
  -w "/var/run/routeros-ssl/" \
  docker.io/wesleydean/routeros_ssl:latest
```

The image is rebuilt when pull requests are merged into the repository's
`main` branch and are tagged `edge`.  Images are tagged with `latest` when a
release is created.  Therefore, `latest` is generally stable.  There are also
images tagged on commits, major, major.minor, and major.minor.patch releases.

For reliability and repeatability, tagging to specific hashes is the
recommended approach (rather than `latest`)

###### Lets Encrypt Directory Permissions Issues

The container runs as a non-privileged user (user 1000 aka `user`).  By
default, `/etc/letsencrypt` is usually inaccessible by non-privileged users.
Therefore, one may either:

1. run the container as a privileged user (i.e., add `-u root`) to the command)
2. allow user 1000 to access be able to access the contents of
  `/etc/letsencrypt` with either `chown` and/or `chmod`

There are risks associated with each approach.  Please consider reviewing the
[certbot documentation on file locations and permissions](https://eff-certbot.readthedocs.io/en/stable/using.html#where-are-my-certificates)
for more information.

##### Building the Image

One may build the image locally without extraneous considerations:

```bash
docker build -t routeros_ssl .
```

## Very Special Thanks

This script was based on the file work by [kiprox](https://github.com/kiprox)
and GPL3-licensed code uploaded to the
[kiprox/mikrotik-ssl repo](https://github.com/kiprox/mikrotik-ssl) on
[GitHub](https://GitHub.com/).

### Changes From the Original Script

Efforts were made to retain compatibility with the original script with
minimal changing required.  The logic used with the original script remains
unchanged (with few small exceptions), so there is likely very little reason
to change tools.

1. the updated tool now refreshes the private key on the RouterOS device; this
  should help in instances where the certificate is being changed (e.g., when
  moving to/from a wildcard certificate)
2. the updated tool now supports `.env` as a configuration file in addition to
  `letsencrypt-routeros.settings` file that was previously supported
3. additional error handling and reporting was added such for most steps,
  failures result in the script throwing an error and exiting with a non-zero
  result code
4. flags may be passed at the command line to configure the tool in addition to
  the positional variables that were previously supported
5. it's now possible to specify the `CERTIFICATE` and `KEY` at runtime using
  either a configuration file or the flag-based command line options
6. the tool may be sourced so that the individual functions may be called in
  the context of larger and/or more involved scripts
7. support for `www-ssl` and `api-ssl` was added to the existing SSTP
  support
8. the updated tool supports containerization with images published to DockerHub
