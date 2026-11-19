# deb-github

[简体中文](README_zh.md)

Build a Debian APT repository from packages on GitHub.

## Verify without root

In Bash, download the public key from this repository and check its fingerprint.
Continue after the check succeeds. Keep the same shell open if you also plan to
enable the system source.

```bash
kumarino_tmp=$(mktemp -d)
curl -fsSL https://raw.githubusercontent.com/Quejiahao/deb-github/master/output/pubkey \
  -o "$kumarino_tmp/download.asc" &&
  test "$(gpg --homedir "$kumarino_tmp" --batch --with-colons --show-keys \
    "$kumarino_tmp/download.asc" | awk -F: '$1 == "fpr" {print $10}')" \
    = 'D79A0C0C69ACC0D3E09AA02A9056CB4DBB1122C4' &&
  mv "$kumarino_tmp/download.asc" "$kumarino_tmp/kumarino.asc"
```

Verify the repository and inspect package versions with temporary APT indexes.

```bash
mkdir -p "$kumarino_tmp/apt.conf.d" "$kumarino_tmp/lists/partial"
cat > "$kumarino_tmp/kumarino.sources" <<EOF
Types: deb
URIs: https://deb-github.kumarino.com/
Suites: stable
Components: main
Signed-By: $kumarino_tmp/kumarino.asc D79A0C0C69ACC0D3E09AA02A9056CB4DBB1122C4
EOF

cat > "$kumarino_tmp/apt.conf" <<EOF
Dir::Etc::Main "/dev/null";
Dir::Etc::Parts "$kumarino_tmp/apt.conf.d";
Dir::Etc::sourcelist "$kumarino_tmp/kumarino.sources";
Dir::Etc::sourceparts "$kumarino_tmp/apt.conf.d";
Dir::State::lists "$kumarino_tmp/lists";
Dir::Cache::pkgcache "";
Dir::Cache::srcpkgcache "";
Debug::NoLocking "true";
APT::Update::Error-Mode "any";
EOF

APT_CONFIG="$kumarino_tmp/apt.conf" apt-get update &&
  APT_CONFIG="$kumarino_tmp/apt.conf" apt-cache policy code-server mihomo
```

## Enable the system source

An administrator can use the verified key from the previous section. If an old
`kumarino.list` contains a `trusted=yes` entry, disable that entry with
`sudoedit /etc/apt/sources.list.d/kumarino.list` before enabling the new source.
This configuration also replaces a disabled `kumarino.sources`.

```bash
(
  set -e
  sudo install -d -m 0755 /etc/apt/keyrings
  sudo install -m 0644 "$kumarino_tmp/kumarino.asc" /etc/apt/keyrings/kumarino.asc
  sudo tee /etc/apt/sources.list.d/kumarino.sources >/dev/null <<'EOF'
Types: deb
URIs: https://deb-github.kumarino.com/
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/kumarino.asc D79A0C0C69ACC0D3E09AA02A9056CB4DBB1122C4
EOF
  sudo apt-get update
  apt-cache policy code-server mihomo
)
```

## How it works

[`main.py`](main.py) builds the `Release` and `Packages` indexes for the
repositories in [`config.yml`](config.yml). The
[GitHub Actions workflow](.github/workflows/build.yml) signs and verifies the
indexes on `master` before publishing to `gh-pages`. Cloudflare Pages serves
the indexes and uses [`_redirects`](output/_redirects) to send package downloads
to the original GitHub releases.

## Maintenance

Set the matching dedicated private key as the repository Actions secret
`KUMARINO_APT_SIGNING_KEY`. From a GnuPG keyring containing the signing key,
an authenticated repository administrator can upload it with the following
command.

```bash
set -o pipefail
gpg --batch --armor --export-secret-keys D79A0C0C69ACC0D3E09AA02A9056CB4DBB1122C4 |
  gh secret set KUMARINO_APT_SIGNING_KEY --repo Quejiahao/deb-github
```

For a key rotation, update `output/pubkey` and the fingerprint in both READMEs.
After the workflow and Cloudflare deployment finish, verify the live archive
using the temporary APT configuration above.
