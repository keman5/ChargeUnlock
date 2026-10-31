#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
CACHE="$HOME/Library/Caches/ChargeUnlock"
MODE="${1:-test}"
mkdir -p "$CACHE"
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
 simulator-runtime-direct)
  export DEVELOPER_DIR="/Applications/Xcode-27.1.app/Contents/Developer"
  clear_caches
  run_child /bin/bash "$ROOT/release/runtime/build.sh"
  ;;
 simulator-runtime-install)
  export DEVELOPER_DIR="/Applications/Xcode-27.1.app/Contents/Developer"
  run_child xcodebuild -downloadPlatform iOS -buildVersion 27.1 -architectureVariant arm64
  xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=json.load(sys.stdin)["runtimes"]; assert any(x["version"] == "27.1" and x["isAvailable"] for x in r), "iOS 27.1 runtime is not available"; print("PASS: iOS 27.1 runtime installed and available")'
  ;;
 xcode-install)
  "$ROOT/release/xcode/build.sh" "${2:?path to completed Xcode 27.1 xip required}"
  ;;
 test)
  clear_caches
  TMP="$(mktemp -d "$CACHE/check.XXXXXX")"
  trap 'rm -rf "$TMP"; cleanup' EXIT
  xcrun swiftc -swift-version 6 -parse-as-library "$ROOT/iOS/Localization.swift" "$ROOT/iOS/ChargingPolicy.swift" "$ROOT/Tests/ios-policy.swift" -o "$TMP/ios-policy"
  "$TMP/ios-policy"
  xcrun swiftc -swift-version 6 -parse-as-library "$ROOT/iOS/BatteryOverlay.swift" "$ROOT/Tests/battery-overlay.swift" -o "$TMP/battery-overlay"
  "$TMP/battery-overlay"
  xcrun swiftc -swift-version 6 -parse-as-library "$ROOT/iOS/Localization.swift" "$ROOT/iOS/AppInformation.swift" "$ROOT/Tests/app-information.swift" -o "$TMP/app-information"
  "$TMP/app-information"
  xcrun swiftc -swift-version 6 -parse-as-library "$ROOT/iOS/DiagnosticReport.swift" "$ROOT/Tests/diagnostics.swift" -o "$TMP/diagnostics"
  "$TMP/diagnostics"
  xcrun swiftc -swift-version 6 -parse-as-library "$ROOT/Tests/localization.swift" -o "$TMP/localization"
  "$TMP/localization" "$ROOT/iOS"
  ;;
 ios|ios-install|ios-legacy-install)
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
  elif [[ "$MODE" == ios-legacy-install ]]; then
    ios-deploy --id "$DEVICE" --bundle "$APP" --timeout 30
  fi
  ;;
 simulator|simulator-install)
  clear_caches
  "$ROOT/build.sh" test
  mkdir -p "$ROOT/iOS/Resources" "$CACHE/iOS"
  xcrun swiftc -parse-as-library "$ROOT/iOS/Tools/GenerateMedia.swift" -o "$CACHE/iOS/GenerateMedia"
  "$CACHE/iOS/GenerateMedia" "$ROOT/iOS/Resources/KeepAwake.mp4"
  run_child xcrun xcodebuild -project "$ROOT/iOS/ChargeUnlock.xcodeproj" -scheme ChargeUnlock -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath "$CACHE/Simulator" CODE_SIGNING_ALLOWED=NO build
  if [[ "$MODE" == simulator-install ]]; then
    SIMULATOR="${2:?simulator UDID required}"
    xcrun simctl install "$SIMULATOR" "$CACHE/Simulator/Build/Products/Debug-iphonesimulator/ChargeUnlock.app"
    xcrun simctl launch "$SIMULATOR" local.chargeunlock.ios
  fi
  ;;
 feedback-network-check)
  clear_caches
  xcrun swiftc -parse-as-library "$ROOT/Tests/feedback-network.swift" -o "$CACHE/feedback-network-check"
  "$CACHE/feedback-network-check"
  ;;
 website|website-deploy)
  clear_caches
  "$ROOT/website/build.sh" "${MODE#website}"
  ;;
 appstore-check|appstore-archive|appstore-upload|appstore-screenshots|appstore-duo-screenshots|appstore-shot-assets|appstore-shot-upload)
  "$ROOT/release/build.sh" "$@"
  ;;
 *) echo 'Usage: ./build.sh [test|simulator|simulator-install UDID|simulator-runtime-install|simulator-runtime-direct|ios DEVICE TEAM|ios-install DEVICE TEAM|ios-legacy-install DEVICE TEAM|feedback-network-check|website|website-deploy|appstore-check|appstore-archive|appstore-upload|appstore-screenshots UDID|appstore-duo-screenshots UDID DISPLAY outer-or-inner|appstore-shot-assets|appstore-shot-upload|xcode-install XIP_PATH]' >&2; exit 2 ;;
esac
