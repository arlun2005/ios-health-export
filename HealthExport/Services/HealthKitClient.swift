import Foundation
import HealthKit

/// Read-only HealthKit access for the v1 export set.
final class HealthKitClient {
    private let store = HKHealthStore()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func authorizationRequestStatus() async throws -> HKAuthorizationRequestStatus {
        try await store.statusForAuthorizationRequest(toShare: Set<HKSampleType>(), read: ExportableType.allObjectTypes)
    }

    /// Requests read access only. Share types are empty; this app never writes to HealthKit.
    func requestReadAuthorization() async throws {
        try await store.requestAuthorization(toShare: Set<HKSampleType>(), read: ExportableType.allObjectTypes)
    }

    func fetch(
        types: [ExportableType],
        start: Date,
        endExclusive: Date
    ) async throws -> (records: [ExportRecord], summaries: [TypeSummary]) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: endExclusive, options: .strictStartDate)
        var allRecords: [ExportRecord] = []
        var summaries: [TypeSummary] = []

        for type in types {
            try Task.checkCancellation()
            let records = try await fetch(type: type, predicate: predicate)
            let truncated = records.count >= ExportLimits.maxSamplesPerType
            summaries.append(makeSummary(type: type, records: records, truncated: truncated))
            allRecords.append(contentsOf: records)
        }

        return (allRecords, summaries)
    }

    private func fetch(type: ExportableType, predicate: NSPredicate) async throws -> [ExportRecord] {
        switch type {
        case .steps, .heartRate, .activeEnergy:
            guard let quantityType = type.objectType as? HKQuantityType,
                  let unit = type.preferredUnit
            else { return [] }
            return try await quantityRecords(type: type, quantityType: quantityType, unit: unit, predicate: predicate)
        case .sleep:
            return try await sleepRecords(predicate: predicate)
        case .workouts:
            return try await workoutRecords(predicate: predicate)
        }
    }

    private func quantityRecords(
        type: ExportableType,
        quantityType: HKQuantityType,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> [ExportRecord] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: quantityType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: ExportLimits.maxSamplesPerType
        )
        let samples = try await descriptor.result(for: store)
        return samples.map { sample in
            ExportRecord(
                id: sample.uuid,
                type: type,
                startDate: sample.startDate,
                endDate: sample.endDate,
                value: sample.quantity.doubleValue(for: unit),
                unit: type.unitLabel,
                detail: nil,
                durationSeconds: sample.endDate.timeIntervalSince(sample.startDate),
                energyKilocalories: type == .activeEnergy ? sample.quantity.doubleValue(for: .kilocalorie()) : nil,
                distanceMeters: nil,
                source: sample.sourceRevision.source.name,
                device: sample.device?.name
            )
        }
    }

    private func sleepRecords(predicate: NSPredicate) async throws -> [ExportRecord] {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: ExportLimits.maxSamplesPerType
        )
        let samples = try await descriptor.result(for: store)
        return samples.map { sample in
            let stage = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            return ExportRecord(
                id: sample.uuid,
                type: .sleep,
                startDate: sample.startDate,
                endDate: sample.endDate,
                value: Double(sample.value),
                unit: nil,
                detail: sleepLabel(stage),
                durationSeconds: sample.endDate.timeIntervalSince(sample.startDate),
                energyKilocalories: nil,
                distanceMeters: nil,
                source: sample.sourceRevision.source.name,
                device: sample.device?.name
            )
        }
    }

    private func workoutRecords(predicate: NSPredicate) async throws -> [ExportRecord] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: ExportLimits.maxSamplesPerType
        )
        let samples = try await descriptor.result(for: store)
        return samples.map { workout in
            let energy = workoutEnergy(workout)
            let distance = workoutDistance(workout)
            return ExportRecord(
                id: workout.uuid,
                type: .workouts,
                startDate: workout.startDate,
                endDate: workout.endDate,
                value: energy,
                unit: energy == nil ? nil : "kcal",
                detail: String(describing: workout.workoutActivityType),
                durationSeconds: workout.duration,
                energyKilocalories: energy,
                distanceMeters: distance,
                source: workout.sourceRevision.source.name,
                device: workout.device?.name
            )
        }
    }

    private func workoutEnergy(_ workout: HKWorkout) -> Double? {
        if let quantity = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity() {
            return quantity.doubleValue(for: .kilocalorie())
        }
        return workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
    }

    private func workoutDistance(_ workout: HKWorkout) -> Double? {
        let distanceTypes: [HKQuantityType] = [
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming)
        ]
        for type in distanceTypes {
            if let quantity = workout.statistics(for: type)?.sumQuantity() {
                return quantity.doubleValue(for: .meter())
            }
        }
        return workout.totalDistance?.doubleValue(for: .meter())
    }

    private func sleepLabel(_ value: HKCategoryValueSleepAnalysis?) -> String {
        guard let value else { return "unknown" }
        switch value {
        case .inBed: return "inBed"
        case .awake: return "awake"
        case .asleepUnspecified: return "asleepUnspecified"
        case .asleepCore: return "asleepCore"
        case .asleepDeep: return "asleepDeep"
        case .asleepREM: return "asleepREM"
        case .asleep: return "asleep"
        @unknown default: return "unknown"
        }
    }

    private func makeSummary(type: ExportableType, records: [ExportRecord], truncated: Bool) -> TypeSummary {
        if records.isEmpty {
            return emptySummary(type: type, truncated: truncated)
        }
        let suffix = truncated ? " (capped at \(ExportLimits.maxSamplesPerType.formatted()) samples)" : ""
        switch type {
        case .steps:
            let total = records.compactMap(\.value).reduce(0, +)
            return TypeSummary(
                type: type,
                sampleCount: records.count,
                truncated: truncated,
                headline: "\(formatNumber(total, fractionDigits: 0)) steps",
                detail: "\(records.count.formatted()) samples\(suffix)"
            )
        case .heartRate:
            let values = records.compactMap(\.value)
            if let min = values.min(), let max = values.max(), !values.isEmpty {
                let avg = values.reduce(0, +) / Double(values.count)
                return TypeSummary(
                    type: type,
                    sampleCount: records.count,
                    truncated: truncated,
                    headline: "\(formatNumber(avg, fractionDigits: 0)) bpm avg",
                    detail: "Min \(formatNumber(min, fractionDigits: 0)) · max \(formatNumber(max, fractionDigits: 0)) · \(records.count.formatted()) samples\(suffix)"
                )
            }
            return emptySummary(type: type, truncated: truncated)
        case .activeEnergy:
            let total = records.compactMap(\.value).reduce(0, +)
            return TypeSummary(
                type: type,
                sampleCount: records.count,
                truncated: truncated,
                headline: "\(formatNumber(total, fractionDigits: 1)) kcal",
                detail: "\(records.count.formatted()) samples\(suffix)"
            )
        case .sleep:
            let asleepSeconds = records
                .filter { record in
                    guard let detail = record.detail else { return false }
                    return detail.hasPrefix("asleep")
                }
                .compactMap(\.durationSeconds)
                .reduce(0, +)
            let hours = asleepSeconds / 3600
            return TypeSummary(
                type: type,
                sampleCount: records.count,
                truncated: truncated,
                headline: "\(formatNumber(hours, fractionDigits: 1)) hr asleep",
                detail: "\(records.count.formatted()) segments\(suffix)"
            )
        case .workouts:
            let duration = records.compactMap(\.durationSeconds).reduce(0, +) / 60
            return TypeSummary(
                type: type,
                sampleCount: records.count,
                truncated: truncated,
                headline: "\(records.count.formatted()) workouts",
                detail: "\(formatNumber(duration, fractionDigits: 0)) min total\(suffix)"
            )
        }
    }

    private func emptySummary(type: ExportableType, truncated: Bool) -> TypeSummary {
        TypeSummary(
            type: type,
            sampleCount: 0,
            truncated: truncated,
            headline: "No samples",
            detail: "Nothing returned for this type"
        )
    }

    private func formatNumber(_ value: Double, fractionDigits: Int) -> String {
        Formatters.displayNumber(value, fractionDigits: fractionDigits)
    }
}
