import Foundation

enum DateRangePreset: String, CaseIterable, Identifiable, Sendable {
    case last7Days
    case last30Days
    case last90Days
    case yearToDate
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last7Days: "7 days"
        case .last30Days: "30 days"
        case .last90Days: "90 days"
        case .yearToDate: "Year to date"
        case .custom: "Custom"
        }
    }
}

struct DateRangeSelection: Equatable, Sendable {
    var preset: DateRangePreset = .last7Days
    var customStart: Date = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
    var customEnd: Date = .now

    /// Inclusive calendar-day start (beginning of local day).
    func startDate(calendar: Calendar = .current, now: Date = .now) -> Date {
        calendar.startOfDay(for: bounds(calendar: calendar, now: now).start)
    }

    /// Exclusive end: beginning of the day after the inclusive end date.
    func endDateExclusive(calendar: Calendar = .current, now: Date = .now) -> Date {
        let endDay = calendar.startOfDay(for: bounds(calendar: calendar, now: now).end)
        return calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
    }

    /// Inclusive end-of-range calendar day (for display and file names).
    func inclusiveEndDate(calendar: Calendar = .current, now: Date = .now) -> Date {
        calendar.startOfDay(for: bounds(calendar: calendar, now: now).end)
    }

    var isValid: Bool {
        startDate() < endDateExclusive()
    }

    private func bounds(calendar: Calendar, now: Date) -> (start: Date, end: Date) {
        let today = calendar.startOfDay(for: now)
        let start: Date
        let end: Date

        switch preset {
        case .last7Days:
            start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            end = today
        case .last30Days:
            start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            end = today
        case .last90Days:
            start = calendar.date(byAdding: .day, value: -89, to: today) ?? today
            end = today
        case .yearToDate:
            start = calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1)) ?? today
            end = today
        case .custom:
            let today = calendar.startOfDay(for: now)
            start = min(calendar.startOfDay(for: customStart), today)
            end = min(calendar.startOfDay(for: customEnd), today)
        }

        if start <= end {
            return (start, end)
        }
        return (end, start)
    }
}
