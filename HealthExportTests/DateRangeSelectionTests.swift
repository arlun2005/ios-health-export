import XCTest
@testable import HealthExport

final class DateRangeSelectionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 15, minute: 30))!
    }

    func testLast7DaysIncludesTodayAndSixPriorDays() {
        var selection = DateRangeSelection()
        selection.preset = .last7Days
        let start = selection.startDate(calendar: calendar, now: now)
        let end = selection.inclusiveEndDate(calendar: calendar, now: now)
        let exclusive = selection.endDateExclusive(calendar: calendar, now: now)

        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: start), DateComponents(year: 2026, month: 9, day: 12))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: end), DateComponents(year: 2026, month: 9, day: 18))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: exclusive), DateComponents(year: 2026, month: 9, day: 19))
        XCTAssertTrue(selection.isValid)
    }

    func testCustomRangeSwapsInvertedDates() {
        var selection = DateRangeSelection()
        selection.preset = .custom
        selection.customStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))!
        selection.customEnd = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!

        let start = selection.startDate(calendar: calendar, now: now)
        let end = selection.inclusiveEndDate(calendar: calendar, now: now)
        XCTAssertEqual(calendar.component(.day, from: start), 10)
        XCTAssertEqual(calendar.component(.day, from: end), 18, "Custom end is clamped to today when it is in the future")
    }

    func testYearToDateStartsJanuaryFirst() {
        var selection = DateRangeSelection()
        selection.preset = .yearToDate
        let start = selection.startDate(calendar: calendar, now: now)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: start), DateComponents(year: 2026, month: 1, day: 1))
    }

    func testFileBaseNameUsesYearMonthDay() {
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        let end = Date(timeIntervalSince1970: 1_767_312_000)
        let name = ExportFileBuilder.fileBaseName(start: start, endInclusive: end)
        XCTAssertTrue(name.hasPrefix("HealthExport_"))
        XCTAssertTrue(name.contains("_to_"))
        let regex = try! NSRegularExpression(pattern: #"^HealthExport_\d{4}-\d{2}-\d{2}_to_\d{4}-\d{2}-\d{2}$"#)
        XCTAssertEqual(regex.numberOfMatches(in: name, range: NSRange(location: 0, length: name.utf16.count)), 1)
    }
}
