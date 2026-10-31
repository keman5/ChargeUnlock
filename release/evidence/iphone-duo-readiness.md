# iPhone Duo readiness — 2026-10-31

- Installed device definition: `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`, model `iPhone19,4`, minimum runtime `27.1.0`.
- Only installed runtime: iOS 26.5 (23F77). Both installed Xcode selections report this same runtime inventory.
- Actual creation attempt with iOS 26.5 failed with CoreSimulator error 403, `Incompatible device`; no Duo simulator or screenshot was created.
- Current asc screenshot matrix includes `APP_IPHONE_DUO`: 1398×2034, 2007×2853 and landscape reversals. Preserve native captures; do not stretch existing phone images into Duo screenshots.
- Current application uses safe-area constraints, scroll views and container-width layout. Player layer updates to preview bounds in `viewDidLayoutSubviews`. These are useful foundations, not proof of Duo compatibility. `Info.plist` currently declares portrait only.
- After installing a compatible runtime, check compact and expanded layouts, transitions without restarting playback, safe areas, long localized text, keyboard avoidance, and any desired landscape support. Fix observed layout issues before producing screenshots.
- App Store version 0.5 remains WAITING_FOR_REVIEW. No metadata, screenshots or review submissions were changed during this inspection.
- No new application build or physical-device test was performed.
