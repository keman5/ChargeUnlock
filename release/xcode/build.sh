#!/bin/bash
set -euo pipefail
ARCHIVE="${1:?path to completed Xcode 27.1 xip required}"
TARGET="/Applications/Xcode-27.1.app"
[[ "$ARCHIVE" = /* && "$ARCHIVE" == *.xip && -f "$ARCHIVE" && -s "$ARCHIVE" ]] || { echo 'Expected a completed local .xip archive' >&2; exit 2; }
[[ ! -e "$TARGET" ]] || { echo "Already exists: $TARGET; inspect it instead of overwriting" >&2; exit 2; }
mkdir -p "$HOME/Library/Caches/ChargeUnlock"
STAGE="$(mktemp -d "$HOME/Library/Caches/ChargeUnlock/xcode-install.XXXXXX")"
/usr/bin/caffeinate -di -w $$ &
AWAKE_PID=$!
trap 'kill "$AWAKE_PID" 2>/dev/null || true; rm -rf "$STAGE"' EXIT
cd "$STAGE"
# xip validates the archive signature before expansion; do not bypass validation.
/usr/bin/xip --expand "$ARCHIVE"
APP="$STAGE/Xcode.app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" == com.apple.dt.Xcode ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" == 27.1 ]]
/usr/bin/codesign --verify --deep --strict -R='anchor apple' "$APP"
/usr/sbin/spctl --assess --type execute "$APP"
/bin/mv -n "$APP" "$TARGET"
[[ ! -e "$APP" ]] || { echo 'Destination changed during install; not overwritten' >&2; exit 1; }
echo "Installed $TARGET; existing Xcode selection preserved."
DEVELOPER_DIR="$TARGET/Contents/Developer" /usr/bin/xcodebuild -version
