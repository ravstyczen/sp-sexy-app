import Foundation

/// Klient Google Calendar API — odpowiednik js/api-calendar.js.
struct CalendarService {
    let auth: GoogleAuth

    private var eventsURLBase: String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "@"))
        let id = Config.calendarID.addingPercentEncoding(withAllowedCharacters: allowed) ?? Config.calendarID
        return "https://www.googleapis.com/calendar/v3/calendars/\(id)/events"
    }

    // MARK: - Pobieranie

    func fetchWeek(weekStart: Date) async throws -> [Reservation] {
        try await fetchRange(from: weekStart, to: weekStart.adding(days: 7))
    }

    /// Pobierz rezerwacje z dowolnego zakresu [from, to).
    func fetchRange(from start: Date, to end: Date) async throws -> [Reservation] {
        let token = try await auth.validAccessToken()

        var comps = URLComponents(string: eventsURLBase)!
        comps.queryItems = [
            .init(name: "timeMin", value: Fmt.iso.string(from: start)),
            .init(name: "timeMax", value: Fmt.iso.string(from: end)),
            .init(name: "singleEvents", value: "true"),
            .init(name: "orderBy", value: "startTime"),
            .init(name: "timeZone", value: Config.timeZone)
        ]

        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try parse(data)
    }

    // MARK: - Zapis

    func create(pilot: Pilot, start: Date, end: Date, isAllDay: Bool,
                route: String, isOps: Bool, isVacation: Bool, isJoint: Bool) async throws {
        let token = try await auth.validAccessToken()
        var req = URLRequest(url: URL(string: eventsURLBase)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body(
            pilot: pilot, start: start, end: end, isAllDay: isAllDay,
            route: route, isOps: isOps, isVacation: isVacation, isJoint: isJoint))
        try await send(req)
    }

    func update(id: String, pilot: Pilot, start: Date, end: Date, isAllDay: Bool,
                route: String, isOps: Bool, isVacation: Bool, isJoint: Bool) async throws {
        let token = try await auth.validAccessToken()
        var req = URLRequest(url: URL(string: "\(eventsURLBase)/\(id)")!)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body(
            pilot: pilot, start: start, end: end, isAllDay: isAllDay,
            route: route, isOps: isOps, isVacation: isVacation, isJoint: isJoint))
        try await send(req)
    }

    func delete(id: String) async throws {
        let token = try await auth.validAccessToken()
        var req = URLRequest(url: URL(string: "\(eventsURLBase)/\(id)")!)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        try await send(req)
    }

    // MARK: - Pomocnicze

    @discardableResult
    private func send(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "Calendar", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return data
    }

    private func body(pilot: Pilot, start: Date, end: Date, isAllDay allDayIn: Bool,
                      route: String, isOps: Bool, isVacation: Bool, isJoint: Bool) -> [String: Any] {
        let isAllDay = allDayIn || isVacation

        var resource: [String: Any] = [
            "summary": isVacation ? "[URLOP] \(pilot.name)" : "[SP-SEXY] \(pilot.name)",
            "description": isVacation ? "Urlop pilota"
                : (route.isEmpty ? "Rezerwacja SP-SEXY" : "Trasa: \(route)"),
            "colorId": pilot.colorId,
            "extendedProperties": [
                "private": [
                    "pilotId": pilot.id,
                    "pilotEmail": pilot.email,
                    "route": isVacation ? "" : route,
                    "isOps": (!isVacation && isOps) ? "1" : "",
                    "isVacation": isVacation ? "1" : "",
                    "isJoint": (!isVacation && isJoint) ? "1" : ""
                ]
            ]
        ]

        if isAllDay {
            resource["start"] = ["date": Fmt.dayKey.string(from: start)]
            // koniec all-day jest exclusive w API Google → +1 dzień
            let endExclusive = end.adding(days: 1)
            resource["end"] = ["date": Fmt.dayKey.string(from: endExclusive)]
        } else {
            resource["start"] = ["dateTime": Fmt.iso.string(from: start), "timeZone": Config.timeZone]
            resource["end"] = ["dateTime": Fmt.iso.string(from: end), "timeZone": Config.timeZone]
        }
        return resource
    }

    // MARK: - Parsowanie odpowiedzi

    private func parse(_ data: Data) throws -> [Reservation] {
        let resp = try JSONDecoder().decode(GEventsResponse.self, from: data)
        return (resp.items ?? []).compactMap { e in
            let priv = e.extendedProperties?.privateProps ?? [:]
            let isAllDay = e.start.date != nil

            var start: Date
            var end: Date
            if isAllDay {
                guard let s = e.start.date, let eDate = e.end.date,
                      let sd = Fmt.dayKey.date(from: s), let ed = Fmt.dayKey.date(from: eDate) else { return nil }
                start = sd
                end = ed.adding(days: -1)   // koniec exclusive → cofnij o dzień
            } else {
                guard let s = e.start.dateTime, let eDate = e.end.dateTime,
                      let sd = Fmt.iso.date(from: s) ?? parseFlexibleISO(s),
                      let ed = Fmt.iso.date(from: eDate) ?? parseFlexibleISO(eDate) else { return nil }
                start = sd
                end = ed
            }

            return Reservation(
                id: e.id,
                title: e.summary ?? "",
                route: priv["route"] ?? "",
                isOps: priv["isOps"] == "1",
                isVacation: priv["isVacation"] == "1",
                isJoint: priv["isJoint"] == "1",
                start: start,
                end: end,
                isAllDay: isAllDay,
                pilotId: priv["pilotId"]
            )
        }
    }

    /// Zapas dla dateTime ze strefą z ułamkami sekund.
    private func parseFlexibleISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s)
    }
}

// MARK: - Modele odpowiedzi Google Calendar

private struct GEventsResponse: Codable {
    let items: [GEvent]?
}

private struct GEvent: Codable {
    let id: String
    let summary: String?
    let start: GDate
    let end: GDate
    let extendedProperties: GExtended?
}

private struct GDate: Codable {
    let date: String?
    let dateTime: String?
}

private struct GExtended: Codable {
    let privateProps: [String: String]?
    enum CodingKeys: String, CodingKey { case privateProps = "private" }
}
