# iPhone Duo readiness — 2026-10-31

## Modal content width — 375 pt

- Guide, Feedback, About rows, and Privacy/Terms text now have a centered maximum content width of 375 pt. Guide and Feedback retain 20 pt side padding outside that content width and shrink within the safe area on narrower screens; Feedback retains its keyboard layout guide.
- Root `build.sh simulator-install` passed tests, built and installed the update on PlugLit-Duo. Native inner captures confirm the narrower Guide, Feedback and About content; `privacy-inner-width-375.jpg` covers the shared legal-document layout.
- This layout update is local and is not in submitted build 11. Physical-device PiP and the full large-text/keyboard matrix were not repeated for this width-only change.

## Expanded home width

- Latest user adjustment: home content is capped at 375 pt (423 pt including the existing 24 pt padding on each side), centered within the safe area. Root `build.sh simulator-install` passed tests, build and installation; native `home-inner-width-375.jpg` confirms the expanded layout. This focused adjustment does not repeat folding, keyboard, large-text or physical-device PiP verification.
- Further narrowed the home content from 560 pt to 420 pt (468 pt including padding) after user feedback. Root `build.sh simulator-install` tests/build/install passed; native `home-inner-width-420.jpg` and `home-outer-width-420.jpg` verify the expanded layout and folded return. Existing 560 pt evidence below is historical. This focused change does not revalidate physical-device PiP.
- Refreshed all six inner store candidates via `build.sh appstore-duo-screenshots`; native dimensions/no-alpha assertions and both locale ASC validations passed. Relaunched to the normal home screen afterward; no remote changes.
- Limited the home scroll view to 608 pt including its 24 pt side padding, giving cards and buttons a maximum content width of 560 pt. It stays centered within the safe area and shrinks with the available width when folded.
- Root `build.sh simulator-install` passed the existing tests, built and installed the change on PlugLit-Duo. Verified Open → Closed → Open using Device Hub; native evidence: `home-inner-width.jpg` and `home-outer-width.jpg`. Refreshed the six inner screenshot candidates to reflect the narrower home behind the sheets.
- This is a local layout update; it is not in submitted build 11. Physical Duo PiP remains unverified.

## Installed and initial Duo verification

- Local screenshot preparation completed after the user unlocked the Mac. Twelve native JPEG captures (en-US and zh-Hans × outer and inner × guide/feedback/about) are saved under `release/screenshots/0.5/duo/`; outer 1398×2034 and inner 2853×2007, without alpha. All twelve were visually inspected and all four ASC `APP_IPHONE_DUO` sets have zero errors/warnings. Validation receipts are under `release/evidence/duo/validation-*.json`.
- Exercised Closed → Partially Open → Open with the feedback keyboard visible, then Open → Closed with a synthetic `qa@example.invalid` field value retained. Keyboard screenshots show the email field above the keyboard. No feedback was sent; the app was terminated and relaunched afterward.
- German long text at `accessibility-medium` was checked on outer and inner displays, including wrapping, scrolling to lower guide sections and folding back. Evidence: `guide-german-large-*.jpg`; original content size `large` restored. This is focused coverage, not every Dynamic Type size or localization.
- Device Hub UI from the existing Xcode application operated the iOS 27.1 runtime; compilation and installation used Xcode 27.1 via DEVELOPER_DIR. The earlier Mac lock block was resolved through user unlock, not bypassed.
- These are local review candidates, not uploaded assets; inner modal backgrounds visibly retain the simulator's unsupported-PiP state. Physical Duo PiP and playback continuity across folding remain unverified. Safe-area source changes are only in the local Debug installation, not the submitted build 11. No review withdrawal, store screenshot replacement, or region changes were performed.
- The direct download completed in 4m57s at 25.2 MiB/s average. The 7,851,737,088-byte archive passed Apple's catalog SHA-256; Apple's nested asset format required `aa patch -dst` rather than ordinary `aa extract`.
- CoreSimulator imported iOS 27.1 `24A94425`, runtime image `1B9128CA-3402-4D07-867E-8CDB081F368A`, with `signatureState=Verified`, `state=Ready`, and `isAvailable=true`. Receipt: `release/evidence/duo/runtime-verification.json`. Global Xcode still points to `/Applications/Xcode.app/Contents/Developer`.
- Created `PlugLit-Duo` (`403FC8B6-9D7C-4A8F-963B-81B3C693D04C`). The first boot reported a data-migration failure, but SpringBoard subsequently ran and the root script successfully built, installed, and launched the application. Do not count that initial bootstatus result as a clean boot.
- Native display 1 is outer 1398×2034, display 3 is inner 2007×2853 (landscape 2853×2007 after opening). Device Hub's Open action changed the running guide from outer to inner layout.
- Observed the inner screen's right-side system status area covering the home Guide button. Main, Guide, and Feedback used the same full-view horizontal constraints; changed those scroll bounds and Guide's bottom button to safe-area leading/trailing anchors. Rebuilt through root `build.sh simulator-install`; before/after native home images confirm both top buttons now remain visible.
- Screenshot capture entry: `DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer ./build.sh appstore-duo-screenshots <UDID> <display-ID> <outer|inner>`. Uses native JPEG captures, waits for presentation animation, and asserts correct dimensions and no alpha. No upload or review-state changes.

## Official direct download recovery (2026-10-31 afternoon)

- The original xcodebuild process ran for over five hours. Its redirected log had been unlinked by cache cleanup; growing output and a live PID did not establish actual download progress. The final percentage of that old download could not be recovered.
- Refreshing Apple's catalog now selects iOS 27.1 build `24A94425`, replacing the earlier `24A94232`. The resumed system download reached 91.6 MB / 7.85 GB before it was stopped to use the faster official path.
- `./build.sh simulator-runtime-direct` downloads the exact arm64 asset URL from Apple's refreshed MobileAsset catalog at `updates.cdn-apple.com`. Small range requests measured 10–15 MB/s and the full download initially sustained 27–29 MiB/s. No third-party mirror or system proxy/security setting changes were used.
- The script verifies the full length and Apple catalog SHA-256, extracts with Apple's `aa`, and imports through `simctl runtime add` with the system signature checks enabled. It asserts the exact build is available after installation. Installation is not yet confirmed at this entry.
- New persistent log: `~/Library/Logs/ChargeUnlock/ios-27.1-runtime-direct.log`; resumable archive: `~/Downloads/PlugLit-runtime/24A94425/runtime.aar`. Check the active script/Python/curl process before retrying; do not restart the old system download concurrently.

## Runtime installation started

- Added and ran `./build.sh simulator-runtime-install`, which selects the separate Xcode 27.1 for this process, downloads Apple's arm64 iOS 27.1 (24A94232) runtime and asserts that it becomes available in CoreSimulator. The global Xcode selection is unchanged.
- Official download is 7.85 GB; installation is still in progress. Log: `~/Library/Caches/ChargeUnlock/ios-27.1-runtime-install.log`. Check the existing download process before starting another copy. The script owns a caffeinate assertion until it exits.
- Apple documentation and current `asc screenshots sizes --display-type APP_IPHONE_DUO` agree on outer 1398×2034 and inner 2007×2853, plus landscape reversals. No alpha channels. Use native Duo captures rather than resized screenshots from another model.
- Apple's October 2026 documentation says Duo screenshots become required in April 2027 for apps built with iOS 27.1 SDK or later; uploading them displays an optimization badge. This does not replace layout testing.
- Current remote 0.5 remains WAITING_FOR_REVIEW. No remote screenshots or submission state were changed. Prepare local captures first; no withdrawal is needed merely to install this runtime.
- References: https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components and https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications and https://developer.apple.com/iphone-duo/prepare/

## Baseline before installation

- Installed device definition: `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`, model `iPhone19,4`, minimum runtime `27.1.0`.
- Only installed runtime: iOS 26.5 (23F77). Both installed Xcode selections report this same runtime inventory.
- Actual creation attempt with iOS 26.5 failed with CoreSimulator error 403, `Incompatible device`; no Duo simulator or screenshot was created.
- Current asc screenshot matrix includes `APP_IPHONE_DUO`: 1398×2034, 2007×2853 and landscape reversals. Preserve native captures; do not stretch existing phone images into Duo screenshots.
- Current application uses safe-area constraints, scroll views and container-width layout. Player layer updates to preview bounds in `viewDidLayoutSubviews`. These are useful foundations, not proof of Duo compatibility. `Info.plist` currently declares portrait only.
- After installing a compatible runtime, check compact and expanded layouts, transitions without restarting playback, safe areas, long localized text, keyboard avoidance, and any desired landscape support. Fix observed layout issues before producing screenshots.
- App Store version 0.5 remains WAITING_FOR_REVIEW. No metadata, screenshots or review submissions were changed during this inspection.
- No new application build or physical-device test was performed.
