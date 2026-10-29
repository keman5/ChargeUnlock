#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
STATE="$HOME/Library/Application Support/ChargeUnlock"
CACHE="$HOME/Library/Caches/ChargeUnlock"
MODE="${1:-install}"
mkdir -p "$STATE" "$CACHE"
# Keep this script's children under one lifetime; never terminate another developer session.
/usr/bin/caffeinate -di -w $$ &
AWAKE_PID=$!
CHILD_PID=""
cleanup() {
  if [[ -n "$CHILD_PID" ]]; then kill -TERM "$CHILD_PID" 2>/dev/null || true; wait "$CHILD_PID" 2>/dev/null || true; fi
  if [[ -n "$AWAKE_PID" ]]; then kill "$AWAKE_PID" 2>/dev/null || true; fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM
run_child() { "$@" & CHILD_PID=$!; local code=0; wait "$CHILD_PID" || code=$?; CHILD_PID=""; return "$code"; }
clear_caches() {
  if command -v go >/dev/null 2>&1; then go clean -cache -testcache; fi
  rm -rf "$ROOT/.artifacts"
}
case "$MODE" in
 test)
  clear_caches
  TMP="$(mktemp -d "$CACHE/check.XXXXXX")"
  trap 'rm -rf "$TMP"; cleanup' EXIT
  xcrun clang -Wall -Wextra -Werror "$ROOT/Tests/lease.c" -o "$TMP/lease"
  "$TMP/lease"
  xcrun swiftc -swift-version 6 "$ROOT/Sources/Core.swift" "$ROOT/Tests/main.swift" -o "$TMP/check"
  "$TMP/check"
  xcrun swiftc -swift-version 6 -parse-as-library "$ROOT/iOS/ChargingPolicy.swift" "$ROOT/Tests/ios-policy.swift" -o "$TMP/ios-policy"
  "$TMP/ios-policy"
  ;;
 ios|ios-install)
  DEVICE="${2:?device UDID required}"
  TEAM="${3:?Apple development team required}"
  [[ "$DEVICE" =~ ^[A-Fa-f0-9-]{24,40}$ && "$TEAM" =~ ^[A-Z0-9]{10}$ ]] || { echo 'Invalid device or team'; exit 2; }
  clear_caches
  "$ROOT/build.sh" test
  mkdir -p "$ROOT/iOS/Resources" "$CACHE/iOS"
  printf 'DEVELOPMENT_TEAM = %s\n' "$TEAM" > "$ROOT/iOS/Signing.local.xcconfig"
  xcrun swiftc -parse-as-library "$ROOT/iOS/Tools/GenerateMedia.swift" -o "$CACHE/iOS/GenerateMedia"
  "$CACHE/iOS/GenerateMedia" "$ROOT/iOS/Resources/KeepAwake.mp4"
  DESTINATION="generic/platform=iOS"
  if [[ "$MODE" == ios-install ]]; then DESTINATION="id=$DEVICE"; fi
  run_child xcrun xcodebuild -project "$ROOT/iOS/ChargeUnlock.xcodeproj" -scheme ChargeUnlock -configuration Debug -destination "$DESTINATION" -destination-timeout 20 -derivedDataPath "$CACHE/iOS" "SYMROOT=$CACHE/iOS/Build/Products" "OBJROOT=$CACHE/iOS/Build/Intermediates.noindex" -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
  APP="$CACHE/iOS/Build/Products/Debug-iphoneos/ChargeUnlock.app"
  codesign --verify --deep --strict "$APP"
  if [[ "$MODE" == ios-install ]]; then
    xcrun devicectl device install app --device "$DEVICE" "$APP"
    xcrun devicectl device process launch --device "$DEVICE" local.chargeunlock.ios
  fi
  ;;
 mac|install)
  clear_caches
  "$ROOT/build.sh" test
  mkdir -p "$ROOT/dist"
  STAGE="$(mktemp -d "$ROOT/dist/stage.XXXXXX")"
  trap 'rm -rf "$STAGE"; cleanup' EXIT
  APP="$STAGE/ChargeUnlock.app"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  xcrun swiftc -swift-version 6 -O -target arm64-apple-macosx14.0 "$ROOT/Sources/"*.swift -o "$APP/Contents/MacOS/ChargeUnlock"
  cp -R "$ROOT/Runner" "$APP/Contents/Resources/Runner"
  cp "$ROOT/build.sh" "$ROOT/README.md" "$APP/Contents/Resources/"
  cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.chargeunlock.mac</string>
<key>CFBundleName</key><string>ChargeUnlock</string>
<key>CFBundleExecutable</key><string>ChargeUnlock</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
  codesign --force --sign - "$APP"
  rm -rf "$ROOT/dist/ChargeUnlock.app"
  mv "$APP" "$ROOT/dist/ChargeUnlock.app"
  if [[ "$MODE" == install ]]; then
    /usr/bin/osascript -e 'tell application id "local.chargeunlock.mac" to quit' >/dev/null 2>&1 || true
    for ((i=0; i<50; i++)); do
      pgrep -f '^/Applications/ChargeUnlock.app/Contents/MacOS/ChargeUnlock$' >/dev/null || break
      sleep 0.1
    done
    if pgrep -f '^/Applications/ChargeUnlock.app/Contents/MacOS/ChargeUnlock$' >/dev/null; then
      echo "ChargeUnlock is still running; quit it before replacing the app." >&2; exit 1
    fi
    rm -rf /Applications/ChargeUnlock.app
    ditto "$ROOT/dist/ChargeUnlock.app" /Applications/ChargeUnlock.app
    open /Applications/ChargeUnlock.app
    echo 'Installed /Applications/ChargeUnlock.app (preferences preserved)'
  fi
  ;;
 runner|run|ios-test)
  DEVICE="${2:?device UDID required}"
  TEAM="${3:?Apple development team required}"
  [[ "$DEVICE" =~ ^[A-Fa-f0-9-]{24,40}$ && "$TEAM" =~ ^[A-Z0-9]{10}$ ]] || { echo 'Invalid device or team'; exit 2; }
  clear_caches
  BUILD="$CACHE/Runner"
  run_child xcrun xcodebuild -project "$ROOT/Runner/ChargeUnlockRunner.xcodeproj" -scheme ChargeUnlockRunner -configuration Debug -destination "id=$DEVICE" -destination-timeout 20 -derivedDataPath "$BUILD" "SYMROOT=$BUILD/Build/Products" "OBJROOT=$BUILD/Build/Intermediates.noindex" -allowProvisioningUpdates -allowProvisioningDeviceRegistration "DEVELOPMENT_TEAM=$TEAM" "PRODUCT_BUNDLE_IDENTIFIER=local.chargeunlock.runner.$TEAM" build-for-testing
  if [[ "$MODE" == ios-test ]]; then
    ORIGINAL="$(find "$BUILD/Build/Products" -maxdepth 1 -name '*.xctestrun' ! -name 'ChargeUnlock-session.xctestrun' -print -quit)"
    [[ -n "$ORIGINAL" ]] || { echo 'Missing test configuration'; exit 1; }
    run_child xcrun xcodebuild test-without-building -xctestrun "$ORIGINAL" -destination "id=$DEVICE" -destination-timeout 20 -only-testing:ChargeUnlockRunner/KeepAwakeTests/testPictureInPictureReturnsHome -parallel-testing-enabled NO
  fi
  if [[ "$MODE" == run ]]; then
    SESSION="${4:?session UUID required}"
    [[ "$SESSION" =~ ^[A-Fa-f0-9-]{36}$ ]] || exit 2
    ORIGINAL="$(find "$BUILD/Build/Products" -maxdepth 1 -name '*.xctestrun' ! -name 'ChargeUnlock-session.xctestrun' -print -quit)"
    [[ -n "$ORIGINAL" ]] || { echo 'Missing test configuration'; exit 1; }
    RUN="$BUILD/Build/Products/ChargeUnlock-session.xctestrun"
    [[ "$ORIGINAL" != "$RUN" ]] || { echo 'Invalid test configuration'; exit 1; }
    cp "$ORIGINAL" "$RUN"
    /usr/libexec/PlistBuddy -c "Add :ChargeUnlockRunner:EnvironmentVariables:CHARGEUNLOCK_SESSION string $SESSION" "$RUN"
    rm -rf "$BUILD/Logs/Test"
    kill "$AWAKE_PID" 2>/dev/null || true
    AWAKE_PID=""
    run_child xcrun xcodebuild test-without-building -xctestrun "$RUN" -destination "id=$DEVICE" -destination-timeout 20 -only-testing:ChargeUnlockRunner/KeepAwakeTests/testKeepAwake -test-timeouts-enabled NO -disableAutomaticPackageResolution -maximum-concurrent-test-device-destinations 1
    rm -f "$RUN"
    rm -rf "$BUILD/Logs/Test"
  fi
  ;;
 *) echo 'Usage: ./build.sh [install|mac|test|ios DEVICE TEAM|ios-install DEVICE TEAM|ios-test DEVICE TEAM|runner DEVICE TEAM|run DEVICE TEAM SESSION]' >&2; exit 2 ;;
esac
