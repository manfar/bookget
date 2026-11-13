#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_PACKAGE="$ROOT/macos/BookgetApp"
INFO_PLIST="$ROOT/macos/Info.plist"
ICON_SOURCE="$ROOT/macos/Resources/bookget-icon.png"
OUTPUT_DIR="$ROOT/dist/darwin-universal"
APP_BUNDLE="$OUTPUT_DIR/Bookget.app"
SWIFT_BUILD_DIR="$OUTPUT_DIR/.swift-build"
GO_BIN="${GO:-go}"
SWIFT_BIN="${SWIFT:-swift}"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "错误：此脚本必须在 macOS 上运行。" >&2
    exit 1
fi
for tool in "$GO_BIN" "$SWIFT_BIN" lipo sips iconutil codesign; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "错误：缺少构建工具：$tool" >&2
        exit 1
    }
done
[[ -f "$INFO_PLIST" && -f "$SWIFT_PACKAGE/Package.swift" && -f "$ICON_SOURCE" ]] || {
    echo "错误：macOS GUI 工程或图标资源不完整。" >&2
    exit 1
}

mkdir -p "$OUTPUT_DIR"
if [[ -e "$APP_BUNDLE" && "${FORCE:-0}" != "1" ]]; then
    echo "错误：目标已存在：$APP_BUNDLE" >&2
    echo "确认替换后运行：FORCE=1 make macos-app" >&2
    exit 1
fi

STAGE="$(mktemp -d "$OUTPUT_DIR/.Bookget.app.stage.XXXXXX")"
WORK="$(mktemp -d "$OUTPUT_DIR/.Bookget-build.XXXXXX")"
BACKUP=""
cleanup() {
    [[ -n "${STAGE:-}" && -d "$STAGE" ]] && rm -rf "$STAGE"
    [[ -n "${WORK:-}" && -d "$WORK" ]] && rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources/bin" "$WORK/icon.iconset"
cp "$INFO_PLIST" "$STAGE/Contents/Info.plist"

echo "[1/5] 构建 Go 下载核心（Intel + Apple Silicon）…"
for ARCH in amd64 arm64; do
    GOOS=darwin GOARCH="$ARCH" CGO_ENABLED=0 "$GO_BIN" build \
        -trimpath -ldflags "-s -w" \
        -o "$WORK/bookget-$ARCH" ./cmd/
done
lipo -create "$WORK/bookget-amd64" "$WORK/bookget-arm64" \
    -output "$STAGE/Contents/Resources/bin/bookget"
chmod 755 "$STAGE/Contents/Resources/bin/bookget"

echo "[2/5] 构建 SwiftUI GUI（x86_64 + arm64）…"
for ARCH in x86_64 arm64; do
    TRIPLE="$ARCH-apple-macosx14.0"
    SCRATCH="$SWIFT_BUILD_DIR/$ARCH"
    "$SWIFT_BIN" build --package-path "$SWIFT_PACKAGE" \
        --configuration release --triple "$TRIPLE" --scratch-path "$SCRATCH"
    BIN_DIR="$("$SWIFT_BIN" build --package-path "$SWIFT_PACKAGE" \
        --configuration release --triple "$TRIPLE" --scratch-path "$SCRATCH" \
        --show-bin-path)"
    [[ -x "$BIN_DIR/Bookget" ]] || {
        echo "错误：未找到 $ARCH GUI 可执行文件：$BIN_DIR/Bookget" >&2
        exit 1
    }
    cp "$BIN_DIR/Bookget" "$WORK/Bookget-$ARCH"
done
lipo -create "$WORK/Bookget-x86_64" "$WORK/Bookget-arm64" \
    -output "$STAGE/Contents/MacOS/Bookget"
chmod 755 "$STAGE/Contents/MacOS/Bookget"

echo "[3/5] 使用仓库现有 favicon 生成临时 macOS 应用图标…"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" "$ICON_SOURCE" --out "$WORK/icon.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" "$ICON_SOURCE" --out "$WORK/icon.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/icon.iconset" -o "$STAGE/Contents/Resources/AppIcon.icns"

echo "[4/5] 验证架构和应用包…"
lipo "$STAGE/Contents/MacOS/Bookget" -verify_arch x86_64 arm64
lipo "$STAGE/Contents/Resources/bin/bookget" -verify_arch x86_64 arm64
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$STAGE/Contents/Info.plist" >/dev/null
plutil -lint "$STAGE/Contents/Info.plist"

# 先完成全部构建和检查，再替换旧 App，避免失败时破坏已有应用。
if [[ -e "$APP_BUNDLE" ]]; then
    BACKUP="$OUTPUT_DIR/.Bookget.app.backup.$$"
    mv "$APP_BUNDLE" "$BACKUP"
fi
if ! mv "$STAGE" "$APP_BUNDLE"; then
    if [[ -n "$BACKUP" && -e "$BACKUP" ]]; then mv "$BACKUP" "$APP_BUNDLE"; fi
    exit 1
fi
STAGE=""

if ! codesign --force --deep --sign - "$APP_BUNDLE"; then
    rm -rf "$APP_BUNDLE"
    if [[ -n "$BACKUP" && -e "$BACKUP" ]]; then mv "$BACKUP" "$APP_BUNDLE"; fi
    exit 1
fi
if ! codesign --verify --deep --strict "$APP_BUNDLE"; then
    rm -rf "$APP_BUNDLE"
    if [[ -n "$BACKUP" && -e "$BACKUP" ]]; then mv "$BACKUP" "$APP_BUNDLE"; fi
    exit 1
fi
[[ -z "$BACKUP" ]] || rm -rf "$BACKUP"

echo "[5/5] 构建完成：$APP_BUNDLE"
echo "GUI 架构：$(lipo -archs "$APP_BUNDLE/Contents/MacOS/Bookget")"
echo "Go 核心架构：$(lipo -archs "$APP_BUNDLE/Contents/Resources/bin/bookget")"
echo "签名：本地 ad-hoc；未进行 Developer ID 签名和 Apple 公证。"
