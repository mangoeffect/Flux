#!/usr/bin/env bash
# 从 frp 官方 GitHub Releases 拉取 frpc 二进制,供开发调试与打包内置使用。
# 桌面端运行时也可在应用内"版本管理"页直接下载(支持镜像),本脚本用于离线打包场景。
#
# 用法:
#   scripts/fetch_frpc.sh <os> <arch> [version] [out_dir]
#   例: scripts/fetch_frpc.sh windows amd64              # 最新版 → third_party/frpc/windows-amd64/
#       scripts/fetch_frpc.sh linux arm64 0.71.0 /tmp/x  # 指定版本与输出目录
#
# 可用环境变量:
#   FRP_MIRROR  GitHub 下载镜像前缀,默认 https://github.com (如 ghproxy 类镜像)
set -euo pipefail

OS="${1:?用法: fetch_frpc.sh <windows|linux|darwin> <amd64|arm64|386|arm> [version] [out_dir]}"
ARCH="${2:?缺少 arch}"
VERSION="${3:-}"
OUT_DIR="${4:-third_party/frpc/${OS}-${ARCH}}"
MIRROR="${FRP_MIRROR:-https://github.com}"

if [[ -z "$VERSION" ]]; then
  echo "查询 frp 最新版本..."
  VERSION=$(curl -fsSL https://api.github.com/repos/fatedier/frp/releases/latest \
    | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"v\([0-9.]*\)"/\1/')
  [[ -n "$VERSION" ]] || { echo "无法获取最新版本号,请显式传入 version"; exit 1; }
fi

# Windows 发行包是 zip,其余平台是 tar.gz
if [[ "$OS" == "windows" ]]; then
  EXT="zip"
else
  EXT="tar.gz"
fi
ARCHIVE="frp_${VERSION}_${OS}_${ARCH}.${EXT}"
BASE="${MIRROR}/fatedier/frp/releases/download/v${VERSION}"
if [[ "$MIRROR" == "https://github.com" ]]; then
  URL="https://github.com/fatedier/frp/releases/download/v${VERSION}/${ARCHIVE}"
else
  URL="${BASE}/${ARCHIVE}"
fi

mkdir -p "$OUT_DIR"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "下载 ${URL}"
curl -fL --retry 3 -o "${TMP}/${ARCHIVE}" "$URL"
if [[ "$EXT" == "zip" ]]; then
  unzip -qo "${TMP}/${ARCHIVE}" -d "$TMP"
else
  tar -xzf "${TMP}/${ARCHIVE}" -C "$TMP"
fi
BIN="frp_${VERSION}_${OS}_${ARCH}/frpc"
[[ "$OS" == "windows" ]] && BIN="${BIN}.exe"

cp "${TMP}/${BIN}" "${OUT_DIR}/"
[[ "$OS" == "windows" ]] && chmod +x "${OUT_DIR}/frpc.exe"
echo "完成: ${OUT_DIR}/frpc$( [[ "$OS" == "windows" ]] && echo '.exe' ) (v${VERSION})"
