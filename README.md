# Weight Widget

A personal iOS app and home-screen widget for tracking body weight, with Apple Health as the only data store. Inspired by [Weight Widgets](https://apps.apple.com/gb/app/weight-widgets/id6761092594).

## Features

- Line graph of weight over Week, Month, 3 Months, 6 Months, Year or All Time, in the app and the widget
- Dashed target-weight line, plus how far you are from the target
- Average weight over the selected range (last 7, 30, 90, 180 or 365 days, or all time) and its change from the preceding window of the same length (labelled "vs last week", "vs last month" and so on), with the average drawn as a dotted line on the graph. The change is green when down, amber when up, grey under 0.05 kg. Hidden when either window has too few days of readings (`TrendRequirements` in `Shared/WeightTrend.swift`)
- Small and medium home-screen widgets; long-press > Edit Widget to choose each widget's range
- Tapping the widget opens the app with the Add Weight sheet up, pre-filled with your last weight
- Scrub the app's graph to see individual values; swipe to delete readings this app added
- Picks up readings from other sources (e.g. a smart scale) via HealthKit background delivery and refreshes the widget

Readings are kept in kg. Longer ranges are averaged per day (3M, 6M) or per week (Y, All) on the graph. Range averages and deltas first average each local calendar day, so several weigh-ins on one day count once. Unit tests for this are in `Tests/` (scheme `WeightWidgetTests`).
