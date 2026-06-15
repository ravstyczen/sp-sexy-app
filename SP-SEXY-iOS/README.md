# SP-SEXY — natywna aplikacja iOS

Natywna (SwiftUI) wersja aplikacji do rezerwacji samolotu **SP-SEXY**. Przepisana
z wersji webowej (PWA) na czystego Swifta — bez WebView, bez zewnętrznych SDK.
Korzysta z tego samego backendu: **Google Calendar** (rezerwacje) i **Google Sheets**
(dziennik lotów).

## Funkcje

- **Trwałe logowanie** — OAuth 2.0 + PKCE przez `ASWebAuthenticationSession`,
  refresh token w Keychain. Logowanie nie jest wymagane przy każdym uruchomieniu
  (główna poprawa względem PWA).
- **Rezerwacje** — widok tygodniowy (agenda dzień po dniu), 4 typy:
  Godziny / Cały dzień / Wiele dni / Urlop. Pola: pilot, trasa, **Lot OPS**,
  **Lot wspólny**. Kolory pilotów, znaczniki `OPS` / `WSP`, urlop wyróżniony.
- **Dziennik lotów** — formularz nowego wpisu (z auto-uzupełnieniem motogodzin
  z ostatniego lotu) + historia. Kolumny A–K arkusza, w tym OPS i Wspólny.

## Wymagania

- **Xcode 16+** (projekt używa „file-system synchronized groups", `objectVersion 77`).
- iPhone z **iOS 16+**.
- Konto Apple Developer (wystarczy darmowe — do instalacji na własnym telefonie).
- Dostęp do projektu Google Cloud, w którym działa wersja webowa.

## Konfiguracja (jednorazowa)

Aplikacja natywna **nie może** użyć Web Client ID z wersji PWA — Google wymaga
osobnego klienta typu **iOS**.

### 1. Utwórz klienta OAuth typu iOS

1. [Google Cloud Console](https://console.cloud.google.com/) → ten sam projekt co PWA.
2. **APIs & Services → Credentials → Create Credentials → OAuth client ID**.
3. Application type: **iOS**.
4. Bundle ID: `pl.spsexy.reservations`
   (lub własny — wtedy zmień też `PRODUCT_BUNDLE_IDENTIFIER` w Xcode).
5. Skopiuj wygenerowany **iOS client ID**, np.
   `902642689687-abc123def456.apps.googleusercontent.com`.

### 2. Wpisz client ID w dwóch miejscach

**`SP-SEXY/Config.swift`** — pole `iosClientID`:
```swift
static let iosClientID = "902642689687-abc123def456.apps.googleusercontent.com"
```

**`SP-SEXY/Info.plist`** — schemat URL (CFBundleURLSchemes) =
**odwrócony** client ID (część przed `.apps...` na końcu):
```
com.googleusercontent.apps.902642689687-abc123def456
```

> Zasada: client ID to `NUMER.apps.googleusercontent.com`, a schemat to
> `com.googleusercontent.apps.NUMER`. Oba muszą się zgadzać, inaczej
> przekierowanie po logowaniu nie wróci do aplikacji.

### 3. Otwórz i uruchom

```bash
open SP-SEXY.xcodeproj
```

1. W Xcode zaznacz target **SP-SEXY → Signing & Capabilities** i wybierz swój
   zespół (Apple ID). Xcode sam podpisze aplikację.
2. Podłącz iPhone (lub wybierz symulator).
3. ⌘R.

## Architektura

```
SP-SEXY/
├── SPSEXYApp.swift          punkt wejścia (@main)
├── Config.swift             stałe: client ID, kalendarz, arkusz, piloci
├── Models.swift             Pilot, Reservation, FlightLogEntry
├── DateHelpers.swift        polskie nazwy/daty (odpowiednik utils.js)
├── Auth/
│   ├── GoogleAuth.swift     OAuth + PKCE + odświeżanie tokenów
│   └── Keychain.swift       bezpieczne przechowywanie tokenów
├── Services/
│   ├── CalendarService.swift   Google Calendar REST (api-calendar.js)
│   └── SheetsService.swift     Google Sheets REST (api-sheets.js)
└── Views/
    ├── ContentView.swift        router login/main + menu wylogowania
    ├── LoginView.swift
    ├── ReservationsView.swift    agenda tygodnia + wiersz rezerwacji
    ├── ReservationEditView.swift formularz rezerwacji (4 typy)
    └── FlightLogView.swift       nowy wpis + historia
```

Brak zależności zewnętrznych — tylko frameworki systemowe (SwiftUI,
AuthenticationServices, CryptoKit, Security).

## Uwaga o kluczach

`Config.swift` zawiera ID kalendarza i arkusza (tak jak wersja webowa). Klient
iOS OAuth nie ma sekretu — bezpieczeństwo opiera się na PKCE i tym, że tylko
adresy e-mail z whitelisty (`Config.pilots`) mogą się zalogować.
