import XCTest
@testable import HealthExport

final class ExportFileBuilderTests: XCTestCase {
    func testCSVEscapesCommasQuotesAndNewlines() {
        XCTAssertEqual(ExportFileBuilder.escapeCSV("Apple Watch"), "Apple Watch")
        XCTAssertEqual(ExportFileBuilder.escapeCSV("Watch, Series 9"), "\"Watch, Series 9\"")
        XCTAssertEqual(ExportFileBuilder.escapeCSV("He said \"ok\""), "\"He said \"\"ok\"\"\"")
        XCTAssertEqual(ExportFileBuilder.escapeCSV("line\nbreak"), "\"line\nbreak\"")
    }

    func testCSVIncludesHeaderEvenWhenEmpty() {
        let payload = makePayload(records: [])
        let csv = ExportFileBuilder.csvString(from: payload)
        let header = ExportFileBuilder.csvHeader.joined(separator: ",")
        XCTAssertTrue(csv.hasPrefix(header + "\n"))
        XCTAssertEqual(csv.split(separator: "\n").count, 1)
    }

    func testCSVLineContainsTypeAndISO8601Dates() throws {
        let start = Date(timeIntervalSince1970: 1_737_244_800)
        let record = ExportRecord(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            type: .steps,
            startDate: start,
            endDate: start.addingTimeInterval(60),
            value: 120,
            unit: "count",
            detail: nil,
            durationSeconds: 60,
            energyKilocalories: nil,
            distanceMeters: nil,
            source: "Apple Watch",
            device: "Apple Watch"
        )
        let line = ExportFileBuilder.csvLine(for: record)
        XCTAssertTrue(line.contains("steps"))
        XCTAssertTrue(line.contains("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        XCTAssertTrue(line.contains("T"))
        XCTAssertTrue(line.contains("120"))
        XCTAssertFalse(line.split(separator: ",").isEmpty)
    }

    func testJSONContainsMetadataAndRecords() throws {
        let start = Date(timeIntervalSince1970: 1_737_244_800)
        let record = ExportRecord(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            type: .heartRate,
            startDate: start,
            endDate: start.addingTimeInterval(1),
            value: 72.5,
            unit: "count/min",
            detail: nil,
            durationSeconds: 1,
            energyKilocalories: nil,
            distanceMeters: nil,
            source: "Apple Watch",
            device: nil
        )
        let data = try ExportFileBuilder.jsonData(from: makePayload(records: [record], types: [.heartRate]))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["app"] as? String, "Health Export")
        XCTAssertEqual(object["sampleCount"] as? Int, 1)
        XCTAssertEqual(object["types"] as? [String], ["heartRate"])
        let records = try XCTUnwrap(object["records"] as? [[String: Any]])
        XCTAssertEqual(records.first?["type"] as? String, "heartRate")
        XCTAssertEqual(records.first?["value"] as? Double, 72.5)
        XCTAssertNotNil(object["exportedAt"] as? String)
        XCTAssertNotNil(object["note"] as? String)
    }

    func testWriteCreatesCSVAndJSONFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HealthExportTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let files = try ExportFileBuilder.write(makePayload(records: []), to: directory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: files.csvURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: files.jsonURL.path))
        XCTAssertTrue(files.csvURL.lastPathComponent.hasSuffix(".csv"))
        XCTAssertTrue(files.jsonURL.lastPathComponent.hasSuffix(".json"))
        XCTAssertTrue(files.csvURL.lastPathComponent.hasPrefix("HealthExport_"))
    }

    private func makePayload(
        records: [ExportRecord],
        types: [ExportableType] = ExportableType.allCases
    ) -> ExportPayload {
        let start = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01 00:00:00 UTC
        return ExportPayload(
            exportedAt: start,
            startDate: start,
            endDateInclusive: start,
            types: types,
            records: records,
            summaries: [],
            truncatedTypes: []
        )
    }
}
