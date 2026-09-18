import Foundation

enum ExportLimits {
    /// Caps each type so a long range of high-frequency samples (especially heart rate) stays memory-safe.
    static let maxSamplesPerType = 50_000
}

struct ExportRecord: Identifiable, Hashable, Sendable {
    var id: UUID
    var type: ExportableType
    var startDate: Date
    var endDate: Date
    var value: Double?
    var unit: String?
    var detail: String?
    var durationSeconds: Double?
    var energyKilocalories: Double?
    var distanceMeters: Double?
    var source: String?
    var device: String?
}

struct TypeSummary: Identifiable, Hashable, Sendable {
    var type: ExportableType
    var sampleCount: Int
    var truncated: Bool
    var headline: String
    var detail: String

    var id: ExportableType { type }
}

struct ExportPayload: Sendable {
    var exportedAt: Date
    var startDate: Date
    var endDateInclusive: Date
    var types: [ExportableType]
    var records: [ExportRecord]
    var summaries: [TypeSummary]
    var truncatedTypes: [ExportableType]

    var totalSampleCount: Int { records.count }
    var isEmpty: Bool { records.isEmpty }
}

struct PreparedExportFiles: Sendable {
    var csvURL: URL
    var jsonURL: URL
}

enum HealthExportError: LocalizedError, Sendable {
    case healthDataUnavailable
    case authorizationFailed(String)
    case queryFailed(String)
    case noTypesSelected
    case invalidDateRange
    case exportWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            "Apple Health is not available on this device."
        case .authorizationFailed(let message):
            "Could not request Apple Health access. \(message)"
        case .queryFailed(let message):
            "Could not load Health data. \(message)"
        case .noTypesSelected:
            "Select at least one data type to export."
        case .invalidDateRange:
            "Choose a date range that starts before it ends."
        case .exportWriteFailed(let message):
            "Could not create the export files. \(message)"
        }
    }
}
