#!/usr/bin/env bash
set -euo pipefail

release_dir="${1:?Pass the directory containing Release}"
public_key="${2:?Pass the repository public key}"
: "${KUMARINO_APT_SIGNING_KEY:?Configure the Kumarino APT signing key}"

export GNUPGHOME
GNUPGHOME="$(mktemp -d)"
trap 'gpgconf --kill gpg-agent; rm -rf -- "$GNUPGHOME"' EXIT

fingerprint="$(gpg --batch --with-colons --show-keys "$public_key" |
  awk -F: '$1 == "pub" { primary = 1 } $1 == "fpr" && primary { print $10; primary = 0 }')"
if [[ -z "$fingerprint" || "$fingerprint" == *$'\n'* ]]; then
  echo 'Expected exactly one primary key in the repository public key' >&2
  exit 1
fi

printf '%s\n' "$KUMARINO_APT_SIGNING_KEY" | gpg --batch --import
unset KUMARINO_APT_SIGNING_KEY
keyring="$GNUPGHOME/archive-keyring.gpg"
gpg --batch --dearmor --output "$keyring" "$public_key"

release="$release_dir/Release"
gpg --batch --local-user "$fingerprint" --output "$GNUPGHOME/InRelease" \
  --clearsign "$release"
gpg --batch --local-user "$fingerprint" --output "$GNUPGHOME/Release.gpg" \
  --armor --detach-sign "$release"

gpgv --keyring "$keyring" --output "$GNUPGHOME/verified-release" "$GNUPGHOME/InRelease"
cmp "$release" "$GNUPGHOME/verified-release"
gpgv --keyring "$keyring" "$GNUPGHOME/Release.gpg" "$release"

install -m 0644 "$GNUPGHOME/InRelease" "$GNUPGHOME/Release.gpg" "$release_dir"
