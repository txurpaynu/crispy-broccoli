import Foundation

enum DateMath {
    static var calendar: Calendar { Calendar.current }

    /// Next yearly occurrence of `date` (month/day), on or after today.
    static func nextOccurrence(of date: Date, repeatsYearly: Bool, from reference: Date = Date()) -> Date? {
        let cal = calendar
        let today = cal.startOfDay(for: reference)
        guard repeatsYearly else {
            return cal.startOfDay(for: date) >= today ? date : nil
        }
        var comps = cal.dateComponents([.month, .day], from: date)
        comps.year = cal.component(.year, from: today)
        // 29 February falls back to 28 February in non-leap years.
        if comps.month == 2 && comps.day == 29, !isLeap(comps.year ?? 2000) { comps.day = 28 }
        guard var candidate = cal.date(from: comps) else { return nil }
        if candidate < today {
            comps.year = (comps.year ?? 0) + 1
            if comps.month == 2, let y = comps.year {
                comps.day = cal.component(.day, from: date) == 29 && !isLeap(y) ? 28 : cal.component(.day, from: date)
            }
            candidate = cal.date(from: comps) ?? candidate
        }
        return candidate
    }

    static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    static func daysUntil(_ date: Date, from reference: Date = Date()) -> Int {
        let cal = calendar
        return cal.dateComponents([.day], from: cal.startOfDay(for: reference), to: cal.startOfDay(for: date)).day ?? 0
    }

    static func relativeDayText(_ date: Date) -> String {
        let d = daysUntil(date)
        switch d {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case 2...6: return "In \(d) days"
        default: return date.formatted(.dateTime.day().month(.abbreviated))
        }
    }

    static func durationText(seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60, s = seconds % 60
        return s == 0 ? "\(m) min" : "\(m)m \(s)s"
    }

    static func minutesText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    static func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    static func dayRange(_ date: Date) -> (Date, Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    static func yearRange(_ year: Int) -> (Date, Date) {
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? Date()
        return (start, end)
    }

    static func year(of date: Date) -> Int { calendar.component(.year, from: date) }
}

/// Fixed-format helpers for backup files. These use the Gregorian calendar,
/// POSIX locale and the *current* time zone, so a day file always matches the
/// day the user saw in the app. Timestamps inside files are ISO 8601 with offset.
enum DayKey {
    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM"
        return f
    }()

    private static let headingFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()

    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone.current
        return f
    }()

    static func key(for date: Date) -> String {
        return keyFormatter.string(from: date)
    }

    static func date(fromKey key: String) -> Date? {
        return keyFormatter.date(from: key)
    }

    /// "2026/November/2026-11-16.md"
    static func relativePath(for key: String) -> String {
        guard let date = date(fromKey: key) else { return "Unsorted/\(key).md" }
        let year = String(key.prefix(4))
        return "\(year)/\(monthFormatter.string(from: date))/\(key).md"
    }

    static func heading(for key: String) -> String {
        guard let date = date(fromKey: key) else { return key }
        return headingFormatter.string(from: date)
    }

    static func isoString(_ date: Date) -> String { iso.string(from: date) }

    static func parseISO(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if let d = iso.date(from: trimmed) { return d }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: trimmed)
    }
}
