import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class WeightModel {
    /// All readings, oldest first. Starts from the cache so launch is instant.
    private(set) var samples: [WeightSample] = SampleCache.load()
    private(set) var hasLoaded = false
    var errorMessage: String?

    var targetKg: Double? = TargetWeight.kg {
        didSet {
            TargetWeight.kg = targetKg
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var latest: WeightSample? { samples.last }

    private let health = HealthStore.shared
    private var started = false

    func start() async {
        guard !started else { return }
        started = true
        #if DEBUG
        // Launch with -cacheOnly to look at the UI using whatever is in the App Group cache.
        if ProcessInfo.processInfo.arguments.contains("-cacheOnly") { return }
        #endif
        guard health.isAvailable else {
            errorMessage = "Apple Health isn't available on this device."
            return
        }
        do {
            try await health.requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
        }
        health.observeChanges { [weak self] in
            await self?.reload()
        }
        await reload()
    }

    func reload() async {
        do {
            let fresh = try await health.fetch()
            hasLoaded = true
            guard fresh != samples else { return }
            samples = fresh
            SampleCache.save(fresh)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Health is locked or unavailable; keep showing the cached copy.
            hasLoaded = true
        }
    }

    func add(kg: Double, date: Date) async throws {
        try await health.save(kg: kg, date: date)
        await reload()
    }

    func delete(_ sample: WeightSample) async {
        do {
            try await health.delete(id: sample.id)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
