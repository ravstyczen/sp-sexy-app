import Foundation

/// Polskie nazwy i pomocniki dat — odpowiednik js/utils.js.
enum PL {
    static let dniKrotkie = ["Ndz", "Pon", "Wto", "Śro", "Czw", "Pią", "Sob"]
    static let dniTygodnia = ["Niedziela", "Poniedziałek", "Wtorek", "Środa", "Czwartek", "Piątek", "Sobota"]
    static let miesiaceKrotkie = ["Sty", "Lut", "Mar", "Kwi", "Maj", "Cze",
                                  "Lip", "Sie", "Wrz", "Paź", "Lis", "Gru"]
    static let miesiace = ["Styczeń", "Luty", "Marzec", "Kwiecień", "Maj", "Czerwiec",
                           "Lipiec", "Sierpień", "Wrzesień", "Październik", "Listopad", "Grudzień"]

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

/// 42 dni (6 tygodni) siatki miesiąca, zaczynając od poniedziałku.
func monthGridDays(_ date: Date) -> [Date] {
    let cal = PL.calendar
    let comps = cal.dateComponents([.year, .month], from: date)
    guard let first = cal.date(from: comps) else { return [] }
    let start = first.startOfWeek()
    return (0..<42).map { start.adding(days: $0) }
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

    /// Nagłówek miesiąca: "Czerwiec 2026".
    static func monthHeader(_ date: Date) -> String {
        let cal = PL.calendar
        let m = cal.component(.month, from: date) - 1
        let y = cal.component(.year, from: date)
        return "\(PL.miesiace[m]) \(y)"
    }

    /// Nagłówek zakresu N dni: "10 – 13 Cze 2026".
    static func rangeHeader(start: Date, dayCount: Int) -> String {
        let end = start.adding(days: dayCount - 1)
        let cal = PL.calendar
        let mS = cal.component(.month, from: start) - 1
        let mE = cal.component(.month, from: end) - 1
        let year = cal.component(.year, from: end)
        if mS == mE {
            return "\(start.dayNumber) – \(end.dayNumber) \(PL.miesiaceKrotkie[mE]) \(year)"
        }
        return "\(start.dayNumber) \(PL.miesiaceKrotkie[mS]) – \(end.dayNumber) \(PL.miesiaceKrotkie[mE]) \(year)"
    }
}
