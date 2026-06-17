import Foundation

/// Klient Google Sheets API — odpowiednik js/api-sheets.js. Kolumny A–K.
struct SheetsService {
    let auth: GoogleAuth

    private let base = "https://sheets.googleapis.com/v4/spreadsheets"
    private var rangeAll: String { "\(Config.sheetName)!A2:L" }
    private var rangeAppend: String { "\(Config.sheetName)!A:L" }

    func getFlightLog() async throws -> [FlightLogEntry] {
        let token = try await auth.validAccessToken()
        let range = encode(rangeAll)
        let url = URL(string: "\(base)/\(Config.spreadsheetID)/values/\(range)")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: req)
        struct Resp: Codable { let values: [[String]]? }
        let r = try JSONDecoder().decode(Resp.self, from: data)

        return (r.values ?? []).map { row in
            func g(_ i: Int) -> String { i < row.count ? row[i] : "" }
            return FlightLogEntry(
                date: g(0), pilot: g(1), hoursBefore: g(2), hoursAfter: g(3),
                fuelAdded: g(4), oilAdded: g(5), fuelCost: g(6), fuelLevel: g(7),
                remarks: g(8), isOps: g(9), isJoint: g(10), isImportant: g(11)
            )
        }
    }

    func getLastEntry() async throws -> FlightLogEntry? {
        try await getFlightLog().last
    }

    func append(_ e: FlightLogEntry) async throws {
        let token = try await auth.validAccessToken()
        let range = encode(rangeAppend)
        var comps = URLComponents(string: "\(base)/\(Config.spreadsheetID)/values/\(range):append")!
        comps.queryItems = [.init(name: "valueInputOption", value: "USER_ENTERED")]

        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let values = [[
            e.date, e.pilot, e.hoursBefore, e.hoursAfter, e.fuelAdded,
            e.oilAdded, e.fuelCost, e.fuelLevel, e.remarks, e.isOps, e.isJoint, e.isImportant
        ]]
        req.httpBody = try JSONSerialization.data(withJSONObject: ["values": values])

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "Sheets", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private func encode(_ range: String) -> String {
        range.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? range
    }
}
