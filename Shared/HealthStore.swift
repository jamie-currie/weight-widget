import Foundation
import HealthKit

/// Thin wrapper over HealthKit body-mass samples.
final class HealthStore: @unchecked Sendable {
    static let shared = HealthStore()

    private let store = HKHealthStore()
    private let bodyMass = HKQuantityType(.bodyMass)
    private let kilograms = HKUnit.gramUnit(with: .kilo)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [bodyMass], read: [bodyMass])
    }

    /// Readings since `start` (or all of them), oldest first.
    func fetch(since start: Date? = nil) async throws -> [WeightSample] {
        let predicate = start.map { HKQuery.predicateForSamples(withStart: $0, end: nil) }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMass, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let results = try await descriptor.result(for: store)
        return results.map {
            WeightSample(
                id: $0.uuid,
                date: $0.startDate,
                kg: $0.quantity.doubleValue(for: kilograms),
                isFromThisApp: $0.sourceRevision.source.bundleIdentifier == AppConfig.appBundleID
            )
        }
    }

    func save(kg: Double, date: Date) async throws {
        let quantity = HKQuantity(unit: kilograms, doubleValue: kg)
        let sample = HKQuantitySample(type: bodyMass, quantity: quantity, start: date, end: date)
        try await store.save(sample)
    }

    func delete(id: UUID) async throws {
        _ = try await store.deleteObjects(of: bodyMass, predicate: HKQuery.predicateForObject(with: id))
    }

    /// Calls `onChange` whenever body-mass data changes in Health, including
    /// in the background (e.g. a smart scale syncing a new reading).
    func observeChanges(_ onChange: @escaping @Sendable () async -> Void) {
        let query = HKObserverQuery(sampleType: bodyMass, predicate: nil) { _, completion, error in
            guard error == nil else { completion(); return }
            Task {
                await onChange()
                completion()
            }
        }
        store.execute(query)
        store.enableBackgroundDelivery(for: bodyMass, frequency: .immediate) { _, _ in }
    }
}
