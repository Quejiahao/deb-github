# deb-github

[English](README.md)

使用 GitHub 发布的安装包构建 Debian APT 软件源。

## 无需 root 的验证

在 Bash 中从本仓库下载公钥并核对指纹。校验成功后继续。如果还要启用系统源，请在同一个 shell 中执行后续命令。

```bash
kumarino_tmp=$(mktemp -d)
curl -fsSL https://raw.githubusercontent.com/Quejiahao/deb-github/master/output/pubkey \
  -o "$kumarino_tmp/download.asc" &&
  test "$(gpg --homedir "$kumarino_tmp" --batch --with-colons --show-keys \
    "$kumarino_tmp/download.asc" | awk -F: '$1 == "fpr" {print $10}')" \
    = 'D79A0C0C69ACC0D3E09AA02A9056CB4DBB1122C4' &&
  mv "$kumarino_tmp/download.asc" "$kumarino_tmp/kumarino.asc"
```

用临时 APT 索引验证仓库并查看软件包版本。

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

## 启用系统源

由管理员使用上一步校验过的公钥。如果旧的 `kumarino.list` 含有 `trusted=yes` 条目，先用
`sudoedit /etc/apt/sources.list.d/kumarino.list` 禁用该条目。下面的配置也可替换已禁用的 `kumarino.sources`。

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

## 工作原理

[`main.py`](main.py) 根据 [`config.yml`](config.yml) 中的软件仓库生成
`Release` 和 `Packages` 索引。
[GitHub Actions 工作流](.github/workflows/build.yml) 在 `master` 上签名并验证索引，再发布到
`gh-pages`。Cloudflare Pages 提供索引，并根据 [`_redirects`](output/_redirects)
将安装包下载请求重定向到原始的 GitHub 发布页面。

## 维护

使用仓库的 Actions Secret `KUMARINO_APT_SIGNING_KEY` 保存配套的专用私钥。
已登录 GitHub CLI 的仓库管理员可从包含签名私钥的 GnuPG 密钥环执行以下命令。

```bash
set -o pipefail
gpg --batch --armor --export-secret-keys D79A0C0C69ACC0D3E09AA02A9056CB4DBB1122C4 |
  gh secret set KUMARINO_APT_SIGNING_KEY --repo Quejiahao/deb-github
```

轮换签名密钥时，同步更新 `output/pubkey` 和两份 README 中的指纹。
工作流与 Cloudflare 部署完成后，使用上面的临时 APT 配置验证生产源。
