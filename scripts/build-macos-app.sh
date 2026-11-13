#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_PACKAGE="$ROOT/macos/BookgetApp"
INFO_PLIST="$ROOT/macos/Info.plist"
OUTPUT_DIR="$ROOT/dist/darwin-amd64"
APP_BUNDLE="$OUTPUT_DIR/Bookget.app"
SWIFT_BUILD_DIR="$OUTPUT_DIR/.swift-build"

GO_BIN="${GO:-go}"
SWIFT_BIN="${SWIFT:-swift}"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "错误：此脚本必须在 macOS 上运行。" >&2
    exit 1
fi

if ! command -v "$GO_BIN" >/dev/null 2>&1; then
    echo "错误：找不到 Go 命令：$GO_BIN" >&2
    exit 1
fi
if ! command -v "$SWIFT_BIN" >/dev/null 2>&1; then
    echo "错误：找不到 Swift 命令：$SWIFT_BIN" >&2
    exit 1
fi
if [[ ! -f "$INFO_PLIST" || ! -f "$SWIFT_PACKAGE/Package.swift" ]]; then
    echo "错误：macOS GUI 工程文件不完整。" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
if [[ -e "$APP_BUNDLE" ]]; then
    if [[ "${FORCE:-0}" != "1" ]]; then
        echo "错误：目标已存在：$APP_BUNDLE" >&2
        echo "为避免覆盖现有 App，确认要替换后请运行：FORCE=1 make macos-app" >&2
        exit 1
    fi
    rm -rf "$APP_BUNDLE"
fi

STAGE="$(mktemp -d "$OUTPUT_DIR/.Bookget.app.stage.XXXXXX")"
cleanup() {
    if [[ -n "${STAGE:-}" && -d "$STAGE" ]]; then
        rm -rf "$STAGE"
    fi
}
trap cleanup EXIT

mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources/bin"
cp "$INFO_PLIST" "$STAGE/Contents/Info.plist"

 echo "[1/4] 构建 Go 下载核心（darwin/amd64）…"
GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 "$GO_BIN" build \
    -trimpath -ldflags "-s -w" \
    -o "$STAGE/Contents/Resources/bin/bookget" \
    ./cmd/
chmod 755 "$STAGE/Contents/Resources/bin/bookget"

 echo "[2/4] 构建 SwiftUI GUI（x86_64-apple-macosx14.0）…"
"$SWIFT_BIN" build \
    --package-path "$SWIFT_PACKAGE" \
    --configuration release \
    --triple "x86_64-apple-macosx14.0" \
    --scratch-path "$SWIFT_BUILD_DIR"
BIN_DIR="$("$SWIFT_BIN" build \
    --package-path "$SWIFT_PACKAGE" \
    --configuration release \
    --triple "x86_64-apple-macosx14.0" \
    --scratch-path "$SWIFT_BUILD_DIR" \
    --show-bin-path)"
if [[ ! -x "$BIN_DIR/Bookget" ]]; then
    echo "错误：未找到 Swift GUI 可执行文件：$BIN_DIR/Bookget" >&2
    exit 1
fi
cp "$BIN_DIR/Bookget" "$STAGE/Contents/MacOS/Bookget"
chmod 755 "$STAGE/Contents/MacOS/Bookget"

 echo "[3/4] 检查 Intel 架构和 App Bundle…"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$STAGE/Contents/Info.plist" >/dev/null
lipo "$STAGE/Contents/MacOS/Bookget" -verify_arch x86_64
lipo "$STAGE/Contents/Resources/bin/bookget" -verify_arch x86_64

mv "$STAGE" "$APP_BUNDLE"
STAGE=""

 echo "[4/4] 对本机构建的 App 进行 ad-hoc 签名…"
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
plutil -lint "$APP_BUNDLE/Contents/Info.plist"

 echo
echo "构建完成：$APP_BUNDLE"
echo "GUI 架构："
file "$APP_BUNDLE/Contents/MacOS/Bookget"
echo "Go 下载核心架构："
file "$APP_BUNDLE/Contents/Resources/bin/bookget"
echo "GUI 依赖："
otool -L "$APP_BUNDLE/Contents/MacOS/Bookget"
