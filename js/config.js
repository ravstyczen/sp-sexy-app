// ============================================================
// KONFIGURACJA - Uzupełnij po utworzeniu projektu Google Cloud
// ============================================================

export const CONFIG = {
    // Google Cloud OAuth 2.0 Client ID
    CLIENT_ID: '902642689687-ndjcf0ibb6gtoni919jabiipj3lknq8f.apps.googleusercontent.com',

    // Google Cloud API Key
    API_KEY: 'AIzaSyD2gW5VBQU6YmoGI_992ppuA9bW6_iwxbY',

    // ID współdzielonego kalendarza Google (np. abc123@group.calendar.google.com)
    CALENDAR_ID: 'ae8294ce4cbed552d5bcb354e67e2facbd83322eeaeb75f1e7198d587aa41bda@group.calendar.google.com',

    // ID arkusza Google Sheets (z URL: docs.google.com/spreadsheets/d/SPREADSHEET_ID/edit)
    SPREADSHEET_ID: '1xtnqM_q6tpQ54pL-CTNwfQOSpYbyu-8LqVlqDJobG9M',

    // Nazwa arkusza w Google Sheets
    SHEET_NAME: '2026',

    // Zakresy uprawnień Google API
    SCOPES: 'openid email profile https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/spreadsheets',

    // Discovery docs dla gapi
    DISCOVERY_DOCS: [
        'https://www.googleapis.com/discovery/v1/apis/calendar/v3/rest',
        'https://sheets.googleapis.com/$discovery/rest?version=v4'
    ],

    // Strefa czasowa
    TIMEZONE: 'Europe/Warsaw',

    // Godziny wyświetlane w kalendarzu
    CALENDAR_START_HOUR: 6,
    CALENDAR_END_HOUR: 21,

    // Piloci - uzupełnij prawdziwe emaile Google
    PILOTS: [
        {
            id: 'rafal',
            name: 'Rafał Styczeń',
            email: 'rafal.styczen@gmail.com',
            colorId: '9'   // blueberry (niebieski)
        },
        {
            id: 'michal',
            name: 'Michał Bubka',
            email: 'michal.bubka@gmail.com',
            colorId: '5'   // banana (żółty)
        }
    ]
};
