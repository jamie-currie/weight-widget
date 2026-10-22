# Weight Widget

A personal iOS app and home-screen widget for tracking body weight, with Apple Health as the only data store. Inspired by [Weight Widgets](https://apps.apple.com/gb/app/weight-widgets/id6761092594).

## Features

- Line graph of weight over Week, Month, Quarter, Year or All Time, in the app and the widget. In the app, swipe the graph (or use the arrows) to step back through earlier windows
- Dashed target-weight line, plus how far you are from the target
- Average weight over the selected range (the calendar week, month, quarter or year so far, or all time) and its change from the preceding window (labelled "vs last week", "vs last month" and so on), with the average drawn as a dotted line on the graph. Each window also counts the line's value where it crosses the window's start and end, interpolated from the nearest readings either side. The change is green when down, amber when up, grey under 0.05 kg. A window with no readings is estimated from those edges, so the change only goes missing when there's nothing to estimate from
- Small and medium home-screen widgets; long-press > Edit Widget to choose each widget's range
- Tapping the widget opens the app; Add Weight is pre-filled with your last weight
- Scrub the app's graph to see individual values; swipe to delete readings this app added
- Picks up readings from other sources (e.g. a smart scale) via HealthKit background delivery and refreshes the widget

Readings are kept in kg. Longer ranges are averaged per day (Q) or per week (Y, All) on the graph. Range averages and deltas first average each local calendar day, so several weigh-ins on one day count once. Unit tests for this are in `Tests/` (scheme `WeightWidgetTests`).
