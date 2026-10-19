# Weight Widget

iOS app + WidgetKit extension that tracks body weight in Apple Health. See `README.md` for features and structure.

- Build check: `xcodebuild -project WeightWidget.xcodeproj -scheme WeightWidget -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- Apple Health is the only real data store. Don't add a separate database; `SampleCache` is just a mirror for the widget.
- Files in `App/`, `Widget/` and `Shared/` are auto-included (folder-synced groups). `Shared/` goes into both targets, so don't import WidgetKit-only or app-only types there.
- Units are kg throughout.
