# SP-SEXY Rezerwacje i Dziennik Lotów

Aplikacja PWA do zarządzania rezerwacjami samolotu **Bristell SP-SEXY** oraz prowadzenia dziennika lotów.

## Funkcje

### Rezerwacje
- Tygodniowy widok kalendarza (Pon-Ndz, 06:00-21:00)
- Rezerwacje godzinowe lub całodniowe
- Pole "Trasa" z planowaną trasą lotu (np. EPKA-EPPO)
- Wykrywanie kolizji terminów
- Kolorowanie wg pilota (niebieski = Rafał, złoty = Michał)
- Nawigacja między tygodniami + przycisk "Dziś"
- Dane przechowywane w Google Calendar

### Dziennik Lotów
- Formularz nowego wpisu z automatycznym uzupełnianiem:
  - Data (dziś), Pilot (zalogowany), Motogodziny przed (z ostatniego lotu)
- Pola: motogodziny przed/po, paliwo dolane, olej dolany, koszt paliwa, stan paliwa, uwagi
- Historia wpisów w tabeli (najnowsze na górze)
- Dane przechowywane w Google Sheets

### Aplikacja
- Progressive Web App — instalacja na iPhone (Dodaj do ekranu początkowego)
- Google Sign-In z whitelistą pilotów
- Tryb offline (cache app shell)
- Strefa czasowa: Europe/Warsaw

## Technologia

- Vanilla JavaScript (ES Modules, bez frameworka, bez build step)
- Google Identity Services (OAuth 2.0 Token Model)
- Google Calendar API + Google Sheets API
- Service Worker z cache-first dla app shell
- Mobile-first CSS (Grid, Flexbox, CSS Custom Properties)
- Hosting: GitHub Pages

## Struktura plików

```
├── index.html              # SPA shell
├── manifest.json           # PWA manifest
├── sw.js                   # Service worker
├── offline.html            # Strona offline
├── css/
│   └── styles.css          # Style (dark gray + gold accent)
├── js/
│   ├── app.js              # Kontroler, routing, nawigacja
│   ├── auth.js             # Google Sign-In, whitelist pilotów
│   ├── config.js           # Klucze API, konfiguracja
│   ├── api-calendar.js     # Google Calendar API (CRUD)
│   ├── api-sheets.js       # Google Sheets API (odczyt/zapis)
│   ├── view-reservations.js # Widok kalendarza tygodniowego
│   ├── view-flight-log.js  # Widok dziennika lotów
│   └── utils.js            # Daty, lokalizacja PL, toast
└── icons/
    ├── icon-192.png        # Ikona PWA
    ├── icon-512.png        # Ikona PWA (duża)
    └── apple-touch-icon.png # Ikona iOS
```

## Konfiguracja Google Cloud

1. Utwórz projekt w [Google Cloud Console](https://console.cloud.google.com/)
2. Włącz API: **Google Calendar API**, **Google Sheets API**
3. Skonfiguruj **OAuth consent screen** (dodaj pilotów jako test users)
4. Utwórz **OAuth 2.0 Client ID** (Web) — dodaj domenę GitHub Pages do authorized JavaScript origins
5. Utwórz **API Key** — ogranicz do domeny GitHub Pages (HTTP referrers)
6. Utwórz współdzielony kalendarz Google i arkusz Sheets
7. Uzupełnij dane w `js/config.js`

## Piloci

| Pilot | Kolor |
|-------|-------|
| Rafał Styczeń | Niebieski |
| Michał Bubka | Złoty |

## Licencja

Projekt prywatny — użytek wewnętrzny.
