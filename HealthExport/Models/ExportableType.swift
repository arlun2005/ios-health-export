import Foundation
import HealthKit

/// HealthKit sample types included in the v1 export set.
enum ExportableType: String, CaseIterable, Identifiable, Codable, Sendable {
    case steps
    case heartRate
    case activeEnergy
    case sleep
    case workouts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steps: "Steps"
        case .heartRate: "Heart Rate"
        case .activeEnergy: "Active Energy"
        case .sleep: "Sleep Analysis"
        case .workouts: "Workouts"
        }
    }

    var subtitle: String {
        switch self {
        case .steps: "Step count samples"
        case .heartRate: "Beats per minute"
        case .activeEnergy: "Active calories burned"
        case .sleep: "Sleep stages and time in bed"
        case .workouts: "Workout sessions"
        }
    }

    var systemImage: String {
        switch self {
        case .steps: "figure.walk"
        case .heartRate: "heart.fill"
        case .activeEnergy: "flame.fill"
        case .sleep: "bed.double.fill"
        case .workouts: "figure.run"
        }
    }

    var objectType: HKObjectType {
        switch self {
        case .steps: HKQuantityType(.stepCount)
        case .heartRate: HKQuantityType(.heartRate)
        case .activeEnergy: HKQuantityType(.activeEnergyBurned)
        case .sleep: HKCategoryType(.sleepAnalysis)
        case .workouts: HKObjectType.workoutType()
        }
    }

    var preferredUnit: HKUnit? {
        switch self {
        case .steps: .count()
        case .heartRate: HKUnit.count().unitDivided(by: .minute())
        case .activeEnergy: .kilocalorie()
        case .sleep, .workouts: nil
        }
    }

    var unitLabel: String? {
        switch self {
        case .steps: "count"
        case .heartRate: "count/min"
        case .activeEnergy: "kcal"
        case .sleep, .workouts: nil
        }
    }

    static var allObjectTypes: Set<HKObjectType> {
        Set(allCases.map(\.objectType))
    }
}
