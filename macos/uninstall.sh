#!/bin/bash
set -euo pipefail
app="$HOME/Applications/Codex 皮肤与动画.app"
[ -e "$app" ] || exit 0
[ ! -L "$app" ] || { echo 'Refusing a symlink.' >&2; exit 1; }
id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")"
[ "$id" = community.codex-dressed-launcher ] || { echo 'Unrelated app; refusing removal.' >&2; exit 1; }
rm -rf "$app"
echo 'Launcher removed. Client, Dream Skin, media, themes, and launcher config/logs are preserved.'
