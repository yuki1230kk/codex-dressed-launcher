#!/bin/bash
set -euo pipefail
source_root="$(cd "$(dirname "$0")/.." && pwd)"
config="${1:?Usage: bash macos/install.sh /absolute/path/config.json}"
app="$HOME/Applications/Codex 皮肤与动画.app"
state="$HOME/Library/Application Support/CodexDressedLauncher"
[ ! -e "$app" ] || { echo 'Entry already exists. Uninstall this launcher before reinstalling; configuration will be preserved.' >&2; exit 1; }
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Launcher.app/Contents/MacOS" "$stage/Launcher.app/Contents/Resources"
swiftc -O -module-cache-path "$stage/module-cache" -framework AppKit -framework AVFoundation "$source_root/macos/main.swift" -o "$stage/Launcher.app/Contents/MacOS/DressedLauncher"
"$stage/Launcher.app/Contents/MacOS/DressedLauncher" --self-test
"$stage/Launcher.app/Contents/MacOS/DressedLauncher" --check-config "$config"
cp "$source_root/macos/launch-once.sh" "$stage/Launcher.app/Contents/Resources/"
cat > "$stage/Launcher.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>community.codex-dressed-launcher</string>
<key>CFBundleName</key><string>Codex 皮肤与动画</string>
<key>CFBundleExecutable</key><string>DressedLauncher</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$stage/Launcher.app"
codesign --verify --strict "$stage/Launcher.app"
mkdir -p "$HOME/Applications" "$state"
if [ -e "$state/config.json" ]; then
  echo 'Existing config.json preserved. Edit it manually to change settings.'
else
  cp "$config" "$state/config.json"
fi
ditto "$stage/Launcher.app" "$app"
printf 'Installed: %s\nConfig: %s/config.json\n' "$app" "$state"
