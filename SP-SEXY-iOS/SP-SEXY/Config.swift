import SwiftUI

/// Statyczna konfiguracja aplikacji — odpowiednik js/config.js z wersji webowej.
enum Config {

    // MARK: - OAuth (natywny klient iOS)

    /// ⚠️ UZUPEŁNIJ: Identyfikator klienta OAuth typu **iOS** z Google Cloud Console.
    ///
    /// Web client z wersji PWA NIE zadziała w aplikacji natywnej — trzeba utworzyć
    /// nowy klient typu „iOS” (Credentials → Create OAuth client ID → iOS) i podać
    /// Bundle ID zgodny z PRODUCT_BUNDLE_IDENTIFIER projektu (domyślnie `pl.spsexy.reservations`).
    ///
    /// Klient iOS nie ma sekretu — autoryzacja odbywa się przez PKCE.
    static let iosClientID = "902642689687-XXXXXXXXXXXXXXXXXXXX.apps.googleusercontent.com"

    /// Schemat przekierowania = odwrócony identyfikator klienta (konwencja Google).
    /// Ten sam schemat musi być wpisany w Info.plist (CFBundleURLTypes).
    static var reversedClientScheme: String {
        let id = iosClientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(id)"
    }

    static var redirectURI: String { "\(reversedClientScheme):/oauth2redirect" }

    // MARK: - Backend Google

    static let calendarID = "ae8294ce4cbed552d5bcb354e67e2facbd83322eeaeb75f1e7198d587aa41bda@group.calendar.google.com"
    static let spreadsheetID = "1xtnqM_q6tpQ54pL-CTNwfQOSpYbyu-8LqVlqDJobG9M"
    static let sheetName = "2026"

    static let scopes = "openid email profile https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/spreadsheets"

    static let timeZone = "Europe/Warsaw"

    static let calendarStartHour = 6
    static let calendarEndHour = 21

    // MARK: - Piloci (whitelist)

    static let pilots: [Pilot] = [
        Pilot(id: "rafal",  name: "Rafał Styczeń", email: "rafal.styczen@gmail.com", colorId: "9",
              color: Color(red: 0.361, green: 0.486, blue: 0.980)),   // #5c7cfa
        Pilot(id: "michal", name: "Michał Bubka",  email: "michal.bubka@gmail.com", colorId: "5",
              color: Color(red: 0.878, green: 0.647, blue: 0.149))    // #e0a526
    ]

    static func pilot(email: String) -> Pilot? {
        pilots.first { $0.email.lowercased() == email.lowercased() }
    }

    static func pilot(id: String?) -> Pilot? {
        guard let id else { return nil }
        return pilots.first { $0.id == id }
    }
}
