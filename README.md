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
