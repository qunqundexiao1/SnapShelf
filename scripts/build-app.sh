#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
swift build -c release
task_bin_dir="$(swift build -c release --show-bin-path)"
task_app="$task_root/build/SnapShelf.app"
mkdir -p "$task_app/Contents/MacOS" "$task_app/Contents/Resources"
cp "$task_bin_dir/SnapShelf" "$task_app/Contents/MacOS/SnapShelf"
cp Resources/Info.plist "$task_app/Contents/Info.plist"
swift scripts/make-icon.swift "$task_root/build/AppIcon.iconset"
iconutil -c icns "$task_root/build/AppIcon.iconset" -o "$task_app/Contents/Resources/AppIcon.icns"
# Finder / iCloud can attach this attribute to bundles in Documents.
xattr -r -d com.apple.FinderInfo "$task_app" 2>/dev/null || true
codesign --force --sign - --identifier com.local.snapshelf "$task_app"
codesign --verify --deep --strict "$task_app"
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$task_app" "$task_root/build/SnapShelf-macOS.zip"
printf '已生成：%s\n' "$task_app"
