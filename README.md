# Weight Widget

A personal iOS app and home-screen widget for tracking body weight, with Apple Health as the only data store. Inspired by [Weight Widgets](https://apps.apple.com/gb/app/weight-widgets/id6761092594).

## Features

- Line graph of weight over Week, Month, 3 Months, 6 Months, Year or All Time, in the app and the widget
- Dashed target-weight line, plus how far you are from the target
- Change over the selected range (latest reading minus the first reading in the range), green when heading towards the target
- Small and medium home-screen widgets; long-press > Edit Widget to choose each widget's range
- Tapping the widget opens the app with the Add Weight sheet up, pre-filled with your last weight
- Scrub the app's graph to see individual values; swipe to delete readings this app added
- Picks up readings from other sources (e.g. a smart scale) via HealthKit background delivery and refreshes the widget

Readings are kept in kg. Longer ranges are averaged per day (3M, 6M) or per week (Y, All) on the graph; the delta always uses the raw readings.

## Structure

| Folder | What |
| --- | --- |
| `App/` | The SwiftUI app (`WeightModel` owns the data) |
| `Widget/` | WidgetKit extension and its range configuration intent |
| `Shared/` | Code compiled into both: HealthKit wrapper, ranges/delta maths, chart, App Group cache |
| `Config/` | Info.plists and entitlements |

The project uses Xcode folder-synced groups, so new files dropped into these folders are picked up automatically.

Health is the source of truth. The app also writes a copy to the App Group container (`SampleCache`), because the widget can't read HealthKit while the phone is locked.

## Building and installing

- Xcode 27+, iOS 26+, iPhone only.
- Bundle ID `com.cheeseandpixels.weightwidget`, App Group `group.com.cheeseandpixels.weightwidget`.
- To install on your phone, plug it in and run from Xcode, or Product > Archive > Distribute App > Release Testing (ad hoc). The phone must be registered as a device on the team.

For UI work in the simulator, launch with the `-cacheOnly` argument (Debug only) to skip HealthKit and show whatever is in the App Group cache.
