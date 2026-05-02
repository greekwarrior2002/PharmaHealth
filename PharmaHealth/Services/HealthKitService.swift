import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Snapshot of recent HealthKit data displayed in the Health Overview.
/// All values are optional so the view can show "—" for any metric the user
/// hasn't granted permission for or has no data for.
struct HealthOverviewSnapshot: Equatable {
    var stepsToday: Int?
    var restingHeartRate: Double?
    var heartRate: Double?
    var sleepHoursLastNight: Double?
    var activeEnergyToday: Double?
    var weightLatest: Double?
    var spo2Latest: Double?
    var glucoseLatest: Double?
    var bodyTempLatest: Double?
    var systolicLatest: Double?
    var diastolicLatest: Double?
}

/// Service that authorizes and reads a small, useful slice of HealthKit data.
/// Designed to be call-once-per-screen-appear so we never poll HealthKit in
/// the background and we never run continuous queries (battery).
@MainActor
final class HealthKitService: ObservableObject {

    @Published private(set) var snapshot = HealthOverviewSnapshot()
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?

    #if canImport(HealthKit)
    private let store: HKHealthStore?

    init() {
        self.store = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    /// Read-only types we ask for. Designed to be modest; users can revoke
    /// any of them in Settings → Health without breaking the screen.
    private var readTypes: Set<HKObjectType> {
        var set: Set<HKObjectType> = []
        for id: HKQuantityTypeIdentifier in [
            .stepCount, .heartRate, .restingHeartRate,
            .activeEnergyBurned, .bodyMass, .oxygenSaturation,
            .bloodGlucose, .bodyTemperature,
            .bloodPressureSystolic, .bloodPressureDiastolic
        ] {
            if let t = HKObjectType.quantityType(forIdentifier: id) { set.insert(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            set.insert(sleep)
        }
        return set
    }

    func requestAuthorization() async {
        guard let store else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    /// Refresh all metrics. Call when the overview screen appears, not on a
    /// timer. Each metric is fetched independently so a single failure won't
    /// blank the entire screen.
    func refresh() async {
        guard let store else { return }
        isLoading = true
        defer { isLoading = false }

        var snap = HealthOverviewSnapshot()
        snap.stepsToday = (try? await sumTodayDouble(.stepCount, unit: .count(), in: store)).map { Int($0) }
        snap.activeEnergyToday = try? await sumTodayDouble(.activeEnergyBurned, unit: .kilocalorie(), in: store)
        snap.heartRate = try? await mostRecent(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), in: store)
        snap.restingHeartRate = try? await mostRecent(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), in: store)
        snap.weightLatest = try? await mostRecent(.bodyMass, unit: .gramUnit(with: .kilo), in: store)
        if let raw = try? await mostRecent(.oxygenSaturation, unit: .percent(), in: store) {
            snap.spo2Latest = raw * 100
        }
        snap.glucoseLatest = try? await mostRecent(.bloodGlucose, unit: HKUnit(from: "mg/dL"), in: store)
        snap.bodyTempLatest = try? await mostRecent(.bodyTemperature, unit: .degreeCelsius(), in: store)
        snap.systolicLatest = try? await mostRecent(.bloodPressureSystolic, unit: .millimeterOfMercury(), in: store)
        snap.diastolicLatest = try? await mostRecent(.bloodPressureDiastolic, unit: .millimeterOfMercury(), in: store)
        snap.sleepHoursLastNight = try? await sleepLastNightHours(in: store)

        snapshot = snap
    }

    // MARK: - Quantity helpers

    private func sumTodayDouble(
        _ id: HKQuantityTypeIdentifier,
        unit: HKUnit,
        in store: HKHealthStore
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(
                quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum
            ) { _, stats, error in
                if let error = error { cont.resume(throwing: error); return }
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    private func mostRecent(
        _ id: HKQuantityTypeIdentifier,
        unit: HKUnit,
        in store: HKHealthStore
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else {
            throw NSError(domain: "HealthKit", code: -1)
        }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let s = samples?.first as? HKQuantitySample else {
                    cont.resume(throwing: NSError(domain: "HealthKit", code: -2))
                    return
                }
                cont.resume(returning: s.quantity.doubleValue(for: unit))
            }
            store.execute(q)
        }
    }

    private func sleepLastNightHours(in store: HKHealthStore) async throws -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let cal = Calendar.current
        let now = Date.now
        // "Last night" = 6pm yesterday → noon today (broad).
        let start = cal.date(bySettingHour: 18, minute: 0, second: 0,
                             of: cal.date(byAdding: .day, value: -1, to: now)!)!
        let end = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, results, error in
                if let error = error { cont.resume(throwing: error); return }
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let totalSeconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        return totalSeconds / 3600.0
    }
    #else
    init() {}
    func requestAuthorization() async {}
    func refresh() async {}
    #endif
}
