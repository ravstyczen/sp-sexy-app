import Foundation

/// Polskie nazwy i pomocniki dat — odpowiednik js/utils.js.
enum PL {
    static let dniKrotkie = ["Ndz", "Pon", "Wto", "Śro", "Czw", "Pią", "Sob"]
    static let dniTygodnia = ["Niedziela", "Poniedziałek", "Wtorek", "Środa", "Czwartek", "Piątek", "Sobota"]
    static let miesiaceKrotkie = ["Sty", "Lut", "Mar", "Kwi", "Maj", "Cze",
                                  "Lip", "Sie", "Wrz", "Paź", "Lis", "Gru"]

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: Config.timeZone) ?? .current
        c.firstWeekday = 2 // poniedziałek
        return c
    }
}

extension Date {
    /// Poniedziałek bieżącego tygodnia (00:00).
    func startOfWeek() -> Date {
        let cal = PL.calendar
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: comps) ?? self
    }

    func startOfDay() -> Date {
        PL.calendar.startOfDay(for: self)
    }

    func adding(days: Int) -> Date {
        PL.calendar.date(byAdding: .day, value: days, to: self) ?? self
    }

    var weekdayIndex: Int {
        PL.calendar.component(.weekday, from: self) - 1 // 0 = niedziela
    }

    var dayNumber: Int {
        PL.calendar.component(.day, from: self)
    }

    func isSameDay(as other: Date) -> Bool {
        PL.calendar.isDate(self, inSameDayAs: other)
    }
}

/// Formatery (statyczne, w strefie aplikacji).
enum Fmt {
    static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: Config.timeZone)
        f.locale = Locale(identifier: "pl_PL")
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: Config.timeZone)
        return f
    }()

    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Nagłówek tygodnia: "10 - 16 Lut 2026".
    static func weekHeader(_ weekStart: Date) -> String {
        let weekEnd = weekStart.adding(days: 6)
        let cal = PL.calendar
        let mStart = cal.component(.month, from: weekStart) - 1
        let mEnd = cal.component(.month, from: weekEnd) - 1
        let year = cal.component(.year, from: weekEnd)
        if mStart == mEnd {
            return "\(weekStart.dayNumber) – \(weekEnd.dayNumber) \(PL.miesiaceKrotkie[mEnd]) \(year)"
        }
        return "\(weekStart.dayNumber) \(PL.miesiaceKrotkie[mStart]) – \(weekEnd.dayNumber) \(PL.miesiaceKrotkie[mEnd]) \(year)"
    }

    /// Nagłówek dnia: "Pon 10 Lut".
    static func dayHeader(_ date: Date) -> String {
        let cal = PL.calendar
        let m = cal.component(.month, from: date) - 1
        return "\(PL.dniKrotkie[date.weekdayIndex]) \(date.dayNumber) \(PL.miesiaceKrotkie[m])"
    }
}
