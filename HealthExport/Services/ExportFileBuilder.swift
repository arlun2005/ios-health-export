import Foundation
import UniformTypeIdentifiers

enum Formatters {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static let fileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func displayNumber(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func csvNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

enum ExportFileBuilder {
    static let csvHeader = [
        "uuid",
        "type",
        "startDate",
        "endDate",
        "value",
        "unit",
        "detail",
        "durationSeconds",
        "energyKilocalories",
        "distanceMeters",
        "source",
        "device"
    ]

    static func fileBaseName(start: Date, endInclusive: Date) -> String {
        "HealthExport_\(Formatters.fileDate.string(from: start))_to_\(Formatters.fileDate.string(from: endInclusive))"
    }

    static func csvString(from payload: ExportPayload) -> String {
        var lines: [String] = [csvHeader.joined(separator: ",")]
        lines.reserveCapacity(payload.records.count + 1)
        for record in payload.records {
            lines.append(csvLine(for: record))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func jsonData(from payload: ExportPayload) throws -> Data {
        let document = JSONDocument(payload: payload)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Formatters.iso8601.string(from: date))
        }
        return try encoder.encode(document)
    }

    static func write(_ payload: ExportPayload, to directory: URL) throws -> PreparedExportFiles {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = fileBaseName(start: payload.startDate, endInclusive: payload.endDateInclusive)
        let csvURL = directory.appendingPathComponent("\(base).csv")
        let jsonURL = directory.appendingPathComponent("\(base).json")

        let csv = csvString(from: payload)
        guard let csvData = csv.data(using: .utf8) else {
            throw HealthExportError.exportWriteFailed("CSV encoding failed.")
        }
        try csvData.write(to: csvURL, options: .atomic)
        try jsonData(from: payload).write(to: jsonURL, options: .atomic)
        try? setContentType(csvURL, type: .commaSeparatedText)
        try? setContentType(jsonURL, type: .json)
        return PreparedExportFiles(csvURL: csvURL, jsonURL: jsonURL)
    }

    static func csvLine(for record: ExportRecord) -> String {
        let fields: [String] = [
            record.id.uuidString,
            record.type.rawValue,
            Formatters.iso8601.string(from: record.startDate),
            Formatters.iso8601.string(from: record.endDate),
            record.value.map(Formatters.csvNumber) ?? "",
            record.unit ?? "",
            record.detail ?? "",
            record.durationSeconds.map(Formatters.csvNumber) ?? "",
            record.energyKilocalories.map(Formatters.csvNumber) ?? "",
            record.distanceMeters.map(Formatters.csvNumber) ?? "",
            record.source ?? "",
            record.device ?? ""
        ]
        return fields.map(escapeCSV).joined(separator: ",")
    }

    private static func setContentType(_ url: URL, type: UTType) throws {
        var values = URLResourceValues()
        values.contentType = type
        var writableURL = url
        try writableURL.setResourceValues(values)
    }

    static func escapeCSV(_ value: String) -> String {
        if value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

private struct JSONDocument: Encodable {
    var app: String
    var version: String
    var note: String
    var exportedAt: Date
    var startDate: Date
    var endDateInclusive: Date
    var types: [String]
    var truncatedTypes: [String]
    var sampleCount: Int
    var records: [JSONRecord]

    init(payload: ExportPayload) {
        app = "Health Export"
        version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        note = "Raw HealthKit samples. Read access is privacy-preserving: missing rows can mean no data or denied permission. Dates are UTC ISO-8601."
        exportedAt = payload.exportedAt
        startDate = payload.startDate
        endDateInclusive = payload.endDateInclusive
        types = payload.types.map(\.rawValue)
        truncatedTypes = payload.truncatedTypes.map(\.rawValue)
        sampleCount = payload.totalSampleCount
        records = payload.records.map(JSONRecord.init)
    }
}

private struct JSONRecord: Encodable {
    var uuid: String
    var type: String
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

    init(_ record: ExportRecord) {
        uuid = record.id.uuidString
        type = record.type.rawValue
        startDate = record.startDate
        endDate = record.endDate
        value = record.value
        unit = record.unit
        detail = record.detail
        durationSeconds = record.durationSeconds
        energyKilocalories = record.energyKilocalories
        distanceMeters = record.distanceMeters
        source = record.source
        device = record.device
    }
}
