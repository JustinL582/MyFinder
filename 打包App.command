#!/bin/bash
# 把 MyFinder 打包成可双击启动的 macOS .app（release 编译 + 图标 + ad-hoc 签名）。
# 双击本文件即可重新打包；产物为本目录下的 MyFinder.app。
set -euo pipefail
cd "$(dirname "$0")"

ROOT="$(pwd)"
SRC="$ROOT/MyFinderTool2.fresh"
ICNS="$ROOT/MyFinder.icns"
APP="$ROOT/MyFinder.app"

echo "▸ 编译 release ..."
( cd "$SRC" && swift build -c release )
BIN="$SRC/.build/release/MyFinder"

echo "▸ 组装 $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MyFinder"
[ -f "$ICNS" ] && cp "$ICNS" "$APP/Contents/Resources/MyFinder.icns"
# 本地化资源（en / zh-Hans），Bundle.main 会按系统语言自动选用
[ -d "$ROOT/Resources" ] && cp -R "$ROOT"/Resources/*.lproj "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MyFinder</string>
  <key>CFBundleDisplayName</key><string>自建 Finder</string>
  <key>CFBundleIdentifier</key><string>com.myfinder.app</string>
  <key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
  <key>CFBundleLocalizations</key><array><string>zh-Hans</string><string>en</string></array>
  <key>CFBundleExecutable</key><string>MyFinder</string>
  <key>CFBundleIconFile</key><string>MyFinder</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "▸ ad-hoc 签名 ..."
codesign --force --deep -s - "$APP" >/dev/null 2>&1 || echo "  (签名跳过)"

echo "✓ 完成：$APP"
