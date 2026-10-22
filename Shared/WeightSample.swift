import Foundation

/// One body-mass reading, mirrored from Apple Health.
struct WeightSample: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var date: Date
    var kg: Double
    /// Health only lets an app delete samples it wrote itself.
    var isFromThisApp: Bool
}

enum AppConfig {
    static let appBundleID = "com.cheeseandpixels.weightwidget"
    static let appGroupID = "group.com.cheeseandpixels.weightwidget"
    static let widgetKind = "WeightWidget"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}

/// Target weight lives in the App Group so the widget can draw it too.
enum TargetWeight {
    private static let key = "targetKg"

    static var kg: Double? {
        get {
            let value = AppConfig.sharedDefaults.double(forKey: key)
            return value > 0 ? value : nil
        }
        set {
            if let newValue, newValue > 0 {
                AppConfig.sharedDefaults.set(newValue, forKey: key)
            } else {
                AppConfig.sharedDefaults.removeObject(forKey: key)
            }
        }
    }
}

/// Copy of the Health data in the App Group container. Health is the source of
/// truth; this exists because the widget can't read HealthKit while the phone is locked.
enum SampleCache {
    private static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupID)?
            .appending(path: "samples.json")
    }

    static func load() -> [WeightSample] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([WeightSample].self, from: data)) ?? []
    }

    static func save(_ samples: [WeightSample]) {
        guard let url, let data = try? JSONEncoder().encode(samples) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
