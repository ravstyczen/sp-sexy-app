import { CONFIG } from './config.js';
import { apiCall } from './auth.js';
import { formatDate } from './utils.js';

/** Pobierz eventy na dany tydzień (Pon-Ndz) */
export async function getWeekEvents(weekStart) {
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekEnd.getDate() + 7);

    const response = await apiCall(() =>
        gapi.client.calendar.events.list({
            calendarId: CONFIG.CALENDAR_ID,
            timeMin: weekStart.toISOString(),
            timeMax: weekEnd.toISOString(),
            singleEvents: true,
            orderBy: 'startTime',
            timeZone: CONFIG.TIMEZONE,
        })
    );

    return (response.result.items || []).map(event => parseEvent(event));
}

/** Utwórz rezerwację */
export async function createReservation(pilot, startDate, endDate, isAllDay) {
    const resource = {
        summary: `[SP-SEXY] ${pilot.name}`,
        description: 'Rezerwacja SP-SEXY',
        colorId: pilot.colorId,
        extendedProperties: {
            private: {
                pilotId: pilot.id,
                pilotEmail: pilot.email,
            }
        }
    };

    if (isAllDay) {
        resource.start = { date: formatDate(startDate) };
        // All-day end date jest exclusive w Google Calendar API
        const endExclusive = new Date(endDate);
        endExclusive.setDate(endExclusive.getDate() + 1);
        resource.end = { date: formatDate(endExclusive) };
    } else {
        resource.start = {
            dateTime: startDate.toISOString(),
            timeZone: CONFIG.TIMEZONE,
        };
        resource.end = {
            dateTime: endDate.toISOString(),
            timeZone: CONFIG.TIMEZONE,
        };
    }

    const response = await apiCall(() =>
        gapi.client.calendar.events.insert({
            calendarId: CONFIG.CALENDAR_ID,
            resource: resource,
        })
    );

    return parseEvent(response.result);
}

/** Aktualizuj rezerwację */
export async function updateReservation(eventId, pilot, startDate, endDate, isAllDay) {
    const resource = {
        summary: `[SP-SEXY] ${pilot.name}`,
        colorId: pilot.colorId,
        extendedProperties: {
            private: {
                pilotId: pilot.id,
                pilotEmail: pilot.email,
            }
        }
    };

    if (isAllDay) {
        resource.start = { date: formatDate(startDate) };
        const endExclusive = new Date(endDate);
        endExclusive.setDate(endExclusive.getDate() + 1);
        resource.end = { date: formatDate(endExclusive) };
    } else {
        resource.start = {
            dateTime: startDate.toISOString(),
            timeZone: CONFIG.TIMEZONE,
        };
        resource.end = {
            dateTime: endDate.toISOString(),
            timeZone: CONFIG.TIMEZONE,
        };
    }

    const response = await apiCall(() =>
        gapi.client.calendar.events.patch({
            calendarId: CONFIG.CALENDAR_ID,
            eventId: eventId,
            resource: resource,
        })
    );

    return parseEvent(response.result);
}

/** Usuń rezerwację */
export async function deleteReservation(eventId) {
    await apiCall(() =>
        gapi.client.calendar.events.delete({
            calendarId: CONFIG.CALENDAR_ID,
            eventId: eventId,
        })
    );
}

/** Parsuj event z API do wewnętrznego formatu */
function parseEvent(event) {
    const isAllDay = !!event.start.date;
    const pilotId = event.extendedProperties?.private?.pilotId || null;
    const pilot = CONFIG.PILOTS.find(p => p.id === pilotId) ||
                  CONFIG.PILOTS.find(p => event.summary?.includes(p.name)) ||
                  null;

    let start, end;
    if (isAllDay) {
        start = new Date(event.start.date + 'T00:00:00');
        end = new Date(event.end.date + 'T00:00:00');
        // End jest exclusive - cofnij o 1 dzień
        end.setDate(end.getDate() - 1);
    } else {
        start = new Date(event.start.dateTime);
        end = new Date(event.end.dateTime);
    }

    return {
        id: event.id,
        title: event.summary || '',
        start,
        end,
        isAllDay,
        pilot,
        pilotId: pilot?.id || null,
        colorId: event.colorId,
    };
}
