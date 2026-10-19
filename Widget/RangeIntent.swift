import AppIntents
import WidgetKit

extension WeightRange: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Time Range" }

    static var caseDisplayRepresentations: [WeightRange: DisplayRepresentation] {
        [
            .week: "Week",
            .month: "Month",
            .threeMonths: "3 Months",
            .sixMonths: "6 Months",
            .year: "Year",
            .all: "All Time",
        ]
    }
}

struct RangeIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Time Range" }
    static var description: IntentDescription { "Choose how much history the widget shows." }

    @Parameter(title: "Range", default: .month)
    var range: WeightRange
}
