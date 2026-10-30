#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$HOME/Library/Caches/ChargeUnlock/Release"
MODE="${1:-appstore-check}"
mkdir -p "$CACHE"
/usr/bin/caffeinate -di -w $$ &
AWAKE_PID=$!
trap 'kill "$AWAKE_PID" 2>/dev/null || true' EXIT
if command -v go >/dev/null 2>&1; then go clean -cache -testcache; fi
rm -rf "$ROOT/.artifacts"
if [[ "$MODE" == appstore-check ]]; then
  "$ROOT/build.sh" test
  plutil -lint "$ROOT/iOS/Info.plist" "$ROOT/iOS/PrivacyInfo.xcprivacy"
  asc metadata validate --dir "$ROOT/metadata" --check-urls --output table
  if rg -n 'NSSelectorFromString|\.perform\(suspend\)|Sparkle' "$ROOT/iOS" -g '*.swift' -g '!AppInformation.swift'; then echo 'Review unexpected dynamic/private updater code' >&2; exit 1; fi
  asc apps list --bundle-id local.chargeunlock.ios --output table
  asc certificates list --certificate-type DISTRIBUTION --fields name,expirationDate --output table
elif [[ "$MODE" == appstore-archive ]]; then
  "$ROOT/build.sh" appstore-check
  mkdir -p "$ROOT/iOS/Resources"
  xcrun swiftc -parse-as-library "$ROOT/iOS/Tools/GenerateMedia.swift" -o "$CACHE/GenerateMedia"
  "$CACHE/GenerateMedia" "$ROOT/iOS/Resources/KeepAwake.mp4"
  asc xcode archive --project "$ROOT/iOS/ChargeUnlock.xcodeproj" --scheme ChargeUnlock --configuration Release --archive-path "$CACHE/PlugLit.xcarchive" --overwrite \
    --xcodebuild-flag=-destination --xcodebuild-flag=generic/platform=iOS \
    --xcodebuild-flag=CODE_SIGN_STYLE=Manual --xcodebuild-flag=CODE_SIGN_IDENTITY=Apple\ Distribution \
    --xcodebuild-flag=DEVELOPMENT_TEAM=B3ZTS6G82B --xcodebuild-flag=PROVISIONING_PROFILE_SPECIFIER=PlugLit\ App\ Store
  codesign --verify --deep --strict "$CACHE/PlugLit.xcarchive/Products/Applications/ChargeUnlock.app"
  asc xcode export --archive-path "$CACHE/PlugLit.xcarchive" --ipa-path "$CACHE/PlugLit.ipa" --signing-style manual --team-id B3ZTS6G82B --overwrite
elif [[ "$MODE" == appstore-screenshots ]]; then
  SIMULATOR="${2:?simulator UDID required}"
  "$ROOT/build.sh" simulator-install "$SIMULATOR"
  SHOTS="$ROOT/release/screenshots/zh-Hans"
  mkdir -p "$SHOTS"
  xcrun simctl status_bar "$SIMULATOR" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
  for PAGE in home guide feedback about; do
    xcrun simctl terminate "$SIMULATOR" local.chargeunlock.ios || true
    xcrun simctl launch "$SIMULATOR" local.chargeunlock.ios -AppleLanguages '(zh-Hans)' -AppleLocale zh_CN -pluglitGuideSeen YES --preview-page "$PAGE"
    sleep 2
    xcrun simctl io "$SIMULATOR" screenshot "$SHOTS/$PAGE.png"
  done
  xcrun simctl status_bar "$SIMULATOR" clear
  mkdir -p "$ROOT/release/screenshots/upload/zh-Hans"
  # The simulator cannot run PiP; use real guide and feedback screens for the store.
  for PAGE in guide feedback about; do
    sips -s format jpeg -s formatOptions 95 "$SHOTS/$PAGE.png" --out "$ROOT/release/screenshots/upload/zh-Hans/$PAGE.jpg" >/dev/null
  done
elif [[ "$MODE" == appstore-upload ]]; then
  APP_ID="${ASC_APP_ID:?Set the verified App Store Connect app ID}"
  asc publish appstore --app "$APP_ID" --ipa "$CACHE/PlugLit.ipa" --version 0.4.0 --dry-run --output table
  asc publish appstore --app "$APP_ID" --ipa "$CACHE/PlugLit.ipa" --version 0.4.0 --wait --confirm
else
  echo 'Usage: release/build.sh [appstore-check|appstore-archive|appstore-upload]' >&2; exit 2
fi
