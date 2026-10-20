# Weight Widget

iOS app + WidgetKit extension that tracks body weight in Apple Health. See `README.md` for features.

- Build check: `xcodebuild -project WeightWidget.xcodeproj -scheme WeightWidget -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- Apple Health is the only real data store. Don't add a separate database; `SampleCache` is just a mirror in the App Group container, because the widget can't read HealthKit while the phone is locked.
- Files in `App/`, `Widget/` and `Shared/` are auto-included (folder-synced groups). `Shared/` goes into both targets, so don't import WidgetKit-only or app-only types there.
- Units are kg throughout.
- For UI work in the simulator, launch with the `-cacheOnly` argument (Debug only) to skip HealthKit and show whatever is in the App Group cache.

## Structure

| Folder | What |
| --- | --- |
| `App/` | The SwiftUI app (`WeightModel` owns the data) |
| `Widget/` | WidgetKit extension and its range configuration intent |
| `Shared/` | Code compiled into both: HealthKit wrapper, ranges/delta maths, chart, App Group cache |
| `Config/` | Info.plists and entitlements |
