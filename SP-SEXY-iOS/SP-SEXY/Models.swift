import SwiftUI

/// Pilot z whitelisty.
struct Pilot: Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    let colorId: String          // colorId kalendarza Google
    let color: Color             // kolor w UI
}

/// Rezerwacja = wydarzenie w kalendarzu Google.
struct Reservation: Identifiable, Hashable {
    let id: String
    var title: String
    var route: String
    var isOps: Bool
    var isVacation: Bool
    var isJoint: Bool
    var start: Date
    var end: Date
    var isAllDay: Bool
    var pilotId: String?

    var pilot: Pilot? { Config.pilot(id: pilotId) }
}

/// Wpis w dzienniku lotów (wiersz arkusza Google Sheets, kolumny A–K).
struct FlightLogEntry: Identifiable {
    var id = UUID()
    var date: String          // A
    var pilot: String         // B
    var hoursBefore: String   // C
    var hoursAfter: String    // D
    var fuelAdded: String     // E
    var oilAdded: String      // F
    var fuelCost: String      // G
    var fuelLevel: String     // H
    var remarks: String       // I
    var isOps: String         // J  ("TAK"/"")
    var isJoint: String       // K  ("TAK"/"")
    var isImportant: String   // L  ("TAK"/"")
}
