import { CONFIG } from './config.js';
import { apiCall } from './auth.js';

const RANGE_ALL = `${CONFIG.SHEET_NAME}!A2:I`;
const RANGE_APPEND = `${CONFIG.SHEET_NAME}!A:I`;

/** Pobierz cały dziennik lotów */
export async function getFlightLog() {
    const response = await apiCall(() =>
        gapi.client.sheets.spreadsheets.values.get({
            spreadsheetId: CONFIG.SPREADSHEET_ID,
            range: RANGE_ALL,
        })
    );

    const rows = response.result.values || [];
    return rows.map(row => ({
        date: row[0] || '',
        pilot: row[1] || '',
        hoursBefore: row[2] || '',
        hoursAfter: row[3] || '',
        fuelAdded: row[4] || '',
        oilAdded: row[5] || '',
        fuelCost: row[6] || '',
        fuelLevel: row[7] || '',
        remarks: row[8] || '',
    }));
}

/** Pobierz ostatni wpis (dla auto-fill motogodzin) */
export async function getLastEntry() {
    const entries = await getFlightLog();
    if (entries.length === 0) return null;
    return entries[entries.length - 1];
}

/** Dodaj nowy wpis do dziennika */
export async function appendFlightLogEntry(entry) {
    const values = [[
        entry.date,
        entry.pilot,
        entry.hoursBefore,
        entry.hoursAfter,
        entry.fuelAdded,
        entry.oilAdded,
        entry.fuelCost,
        entry.fuelLevel,
        entry.remarks,
    ]];

    await apiCall(() =>
        gapi.client.sheets.spreadsheets.values.append({
            spreadsheetId: CONFIG.SPREADSHEET_ID,
            range: RANGE_APPEND,
            valueInputOption: 'USER_ENTERED',
            resource: { values },
        })
    );
}
