#!/usr/bin/env bash
# Vercel 构建脚本
# Vercel 的 Linux 构建环境上没有 typst 和 uv，需要现装。

set -euo pipefail

echo "==> 安装 typst"
TYPST_VERSION="0.14.2"
curl -fsSL "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-x86_64-unknown-linux-musl.tar.xz" -o /tmp/typst.tar.xz
mkdir -p /tmp/typst-extract
tar -xJf /tmp/typst.tar.xz -C /tmp/typst-extract
export PATH="/tmp/typst-extract/typst-x86_64-unknown-linux-musl:${PATH}"
typst --version

echo "==> 安装 uv"
curl -fsSL https://astral.sh/uv/install.sh | sh
export PATH="${HOME}/.local/bin:${PATH}"
uv --version

echo "==> 构建博客"
uv run blog.py build --force
