import { CONFIG } from './config.js';
import { getCurrentPilot } from './auth.js';
import { getWeekEvents, createReservation, updateReservation, deleteReservation } from './api-calendar.js';
import {
    getWeekStart, formatDate, formatTime, formatShortDate, formatWeekHeader,
    addDays, getWeekDays, isSameDay, showToast, showLoading, hideLoading,
    DNI_KROTKIE
} from './utils.js';

let currentWeekStart = getWeekStart(new Date());
let events = [];

/** Renderuj widok rezerwacji */
export async function renderReservations(container) {
    container.innerHTML = `
        <div class="calendar-nav">
            <button id="btn-prev-week">&larr; Poprz.</button>
            <div>
                <span class="week-label" id="week-label"></span>
                <button class="btn-today" id="btn-today">Dziś</button>
            </div>
            <button id="btn-next-week">Nast. &rarr;</button>
        </div>
        <div class="legend">
            <div class="legend-item"><div class="legend-dot rafal"></div>Rafał Styczeń</div>
            <div class="legend-item"><div class="legend-dot michal"></div>Michał Bubka</div>
        </div>
        <div class="calendar-wrapper" id="calendar-wrapper"></div>
        <button class="fab" id="btn-new-reservation" title="Nowa rezerwacja">+</button>
    `;

    document.getElementById('btn-prev-week').addEventListener('click', () => changeWeek(-1));
    document.getElementById('btn-next-week').addEventListener('click', () => changeWeek(1));
    document.getElementById('btn-today').addEventListener('click', goToday);
    document.getElementById('btn-new-reservation').addEventListener('click', () => openReservationModal());

    await loadWeek();
}

async function loadWeek() {
    document.getElementById('week-label').textContent = formatWeekHeader(currentWeekStart);

    showLoading();
    try {
        events = await getWeekEvents(currentWeekStart);
        renderCalendarGrid();
    } catch (err) {
        // Spróbuj załadować z cache
        const cached = localStorage.getItem(`cache_events_${formatDate(currentWeekStart)}`);
        if (cached) {
            events = JSON.parse(cached).map(e => ({
                ...e,
                start: new Date(e.start),
                end: new Date(e.end),
            }));
            renderCalendarGrid();
            showToast('Dane z pamięci podręcznej', 'info');
        } else {
            showToast('Błąd ładowania rezerwacji', 'error');
            console.error(err);
        }
    } finally {
        hideLoading();
    }

    // Zapisz do cache
    try {
        localStorage.setItem(`cache_events_${formatDate(currentWeekStart)}`, JSON.stringify(events));
    } catch (e) { /* ignore */ }
}

function renderCalendarGrid() {
    const wrapper = document.getElementById('calendar-wrapper');
    const days = getWeekDays(currentWeekStart);
    const today = new Date();
    const startHour = CONFIG.CALENDAR_START_HOUR;
    const endHour = CONFIG.CALENDAR_END_HOUR;
    const hours = endHour - startHour;

    // All-day events
    const allDayEvents = events.filter(e => e.isAllDay);
    const timedEvents = events.filter(e => !e.isAllDay);

    let html = '<div class="calendar-grid">';

    // === Nagłówki dni ===
    html += '<div class="calendar-corner"></div>';
    for (let i = 0; i < 7; i++) {
        const d = days[i];
        const isToday = isSameDay(d, today);
        html += `<div class="calendar-day-header ${isToday ? 'today' : ''}">
            <div class="day-name">${DNI_KROTKIE[d.getDay()]}</div>
            <div class="day-num">${d.getDate()}</div>
        </div>`;
    }

    // === All-day row ===
    html += '<div class="allday-row-label">Cały<br>dzień</div>';
    for (let i = 0; i < 7; i++) {
        const d = days[i];
        const dayAllDay = allDayEvents.filter(e => {
            return d >= e.start && d <= e.end;
        });
        html += `<div class="allday-cell" data-date="${formatDate(d)}" data-allday="1">`;
        dayAllDay.forEach(e => {
            const pilotClass = e.pilotId === 'rafal' ? 'pilot-rafal' : 'pilot-michal';
            html += `<div class="allday-event ${pilotClass}" data-event-id="${e.id}">${e.title}</div>`;
        });
        html += '</div>';
    }

    // === Godziny ===
    for (let h = startHour; h < endHour; h++) {
        // Etykieta godziny
        html += `<div class="calendar-time">${String(h).padStart(2, '0')}:00</div>`;

        // Komórki dla każdego dnia
        for (let i = 0; i < 7; i++) {
            const d = days[i];
            const cellDate = formatDate(d);
            html += `<div class="calendar-cell" data-date="${cellDate}" data-hour="${h}" id="cell-${cellDate}-${h}"></div>`;
        }
    }

    html += '</div>';
    wrapper.innerHTML = html;

    // Umieść timed events na siatce
    timedEvents.forEach(event => placeTimedEvent(event, days, startHour, endHour));

    // Event listeners
    wrapper.querySelectorAll('.calendar-cell').forEach(cell => {
        cell.addEventListener('click', (e) => {
            if (e.target.classList.contains('calendar-event')) return;
            const date = cell.dataset.date;
            const hour = parseInt(cell.dataset.hour);
            openReservationModal(null, date, hour);
        });
    });

    wrapper.querySelectorAll('.allday-cell').forEach(cell => {
        cell.addEventListener('click', (e) => {
            if (e.target.classList.contains('allday-event')) return;
            const date = cell.dataset.date;
            openReservationModal(null, date, null, true);
        });
    });

    wrapper.querySelectorAll('.allday-event, .calendar-event').forEach(el => {
        el.addEventListener('click', (e) => {
            e.stopPropagation();
            const eventId = el.dataset.eventId;
            const event = events.find(ev => ev.id === eventId);
            if (event) openReservationModal(event);
        });
    });
}

function placeTimedEvent(event, days, startHour, endHour) {
    // Znajdź dzień i godzinę początkową
    const eventDay = days.findIndex(d => isSameDay(d, event.start));
    if (eventDay === -1) return;

    const dayDate = formatDate(days[eventDay]);
    const eventStartHour = event.start.getHours();
    const eventStartMin = event.start.getMinutes();
    const eventEndHour = event.end.getHours();
    const eventEndMin = event.end.getMinutes();

    // Clamp do widocznego zakresu
    const visibleStart = Math.max(eventStartHour, startHour);
    const visibleEnd = Math.min(eventEndHour + (eventEndMin > 0 ? 1 : 0), endHour);

    if (visibleStart >= endHour || visibleEnd <= startHour) return;

    // Umieść w pierwszej widocznej komórce
    const cell = document.getElementById(`cell-${dayDate}-${visibleStart}`);
    if (!cell) return;

    const cellHeight = cell.offsetHeight || 44;
    const topOffset = visibleStart === eventStartHour ? (eventStartMin / 60) * cellHeight : 0;

    // Oblicz wysokość (w pikselach)
    const durationMinutes = (event.end - event.start) / 60000;
    const durationCells = durationMinutes / 60;
    const height = Math.max(durationCells * cellHeight - 2, 18);

    const pilotClass = event.pilotId === 'rafal' ? 'pilot-rafal' : 'pilot-michal';

    const el = document.createElement('div');
    el.className = `calendar-event ${pilotClass}`;
    el.dataset.eventId = event.id;
    el.style.top = `${topOffset}px`;
    el.style.height = `${height}px`;
    el.textContent = `${formatTime(event.start)} ${event.title}`;
    el.title = `${event.title}\n${formatTime(event.start)} - ${formatTime(event.end)}`;

    cell.appendChild(el);
}

function changeWeek(offset) {
    currentWeekStart = addDays(currentWeekStart, offset * 7);
    loadWeek();
}

function goToday() {
    currentWeekStart = getWeekStart(new Date());
    loadWeek();
}

// === MODAL REZERWACJI ===

function openReservationModal(existingEvent = null, prefillDate = null, prefillHour = null, prefillAllDay = false) {
    const isEdit = !!existingEvent;
    const pilot = getCurrentPilot();

    // Domyślne wartości
    let selectedPilotId = isEdit ? (existingEvent.pilotId || pilot.id) : pilot.id;
    let isAllDay = isEdit ? existingEvent.isAllDay : prefillAllDay;
    let date = isEdit
        ? formatDate(existingEvent.start)
        : (prefillDate || formatDate(new Date()));
    let timeFrom = isEdit && !existingEvent.isAllDay
        ? formatTime(existingEvent.start)
        : (prefillHour !== null ? `${String(prefillHour).padStart(2, '0')}:00` : '08:00');
    let timeTo = isEdit && !existingEvent.isAllDay
        ? formatTime(existingEvent.end)
        : (prefillHour !== null ? `${String(prefillHour + 1).padStart(2, '0')}:00` : '10:00');

    const pilotsOptions = CONFIG.PILOTS.map(p =>
        `<option value="${p.id}" ${p.id === selectedPilotId ? 'selected' : ''}>${p.name}</option>`
    ).join('');

    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay';
    overlay.innerHTML = `
        <div class="modal">
            <h2 class="modal-title">${isEdit ? 'Edycja rezerwacji' : 'Nowa rezerwacja'}</h2>
            <div class="form-group">
                <label>Pilot</label>
                <select id="modal-pilot">${pilotsOptions}</select>
            </div>
            <div class="form-group">
                <label>Typ rezerwacji</label>
                <div class="radio-group">
                    <label><input type="radio" name="res-type" value="hours" ${!isAllDay ? 'checked' : ''}> Godziny</label>
                    <label><input type="radio" name="res-type" value="allday" ${isAllDay ? 'checked' : ''}> Cały dzień</label>
                </div>
            </div>
            <div class="form-group">
                <label>Data</label>
                <input type="date" id="modal-date" value="${date}">
            </div>
            <div class="form-row" id="time-fields" ${isAllDay ? 'style="display:none"' : ''}>
                <div class="form-group">
                    <label>Od</label>
                    <input type="time" id="modal-time-from" value="${timeFrom}" step="1800">
                </div>
                <div class="form-group">
                    <label>Do</label>
                    <input type="time" id="modal-time-to" value="${timeTo}" step="1800">
                </div>
            </div>
            <div class="form-actions">
                <button class="btn btn-secondary" id="modal-cancel">Anuluj</button>
                ${isEdit ? '<button class="btn btn-danger" id="modal-delete">Usuń</button>' : ''}
                <button class="btn btn-primary" id="modal-save">Zapisz</button>
            </div>
        </div>
    `;

    document.body.appendChild(overlay);

    // Toggle pola godzin
    overlay.querySelectorAll('input[name="res-type"]').forEach(radio => {
        radio.addEventListener('change', () => {
            const timeFields = overlay.querySelector('#time-fields');
            timeFields.style.display = radio.value === 'allday' ? 'none' : '';
        });
    });

    // Zamknij
    overlay.querySelector('#modal-cancel').addEventListener('click', () => overlay.remove());
    overlay.addEventListener('click', (e) => {
        if (e.target === overlay) overlay.remove();
    });

    // Zapisz
    overlay.querySelector('#modal-save').addEventListener('click', async () => {
        const pilotId = overlay.querySelector('#modal-pilot').value;
        const selectedPilot = CONFIG.PILOTS.find(p => p.id === pilotId);
        const resType = overlay.querySelector('input[name="res-type"]:checked').value;
        const dateVal = overlay.querySelector('#modal-date').value;

        if (!dateVal) {
            showToast('Podaj datę', 'error');
            return;
        }

        showLoading();
        try {
            if (resType === 'allday') {
                const start = new Date(dateVal + 'T00:00:00');
                const end = new Date(dateVal + 'T23:59:59');

                if (isEdit) {
                    await updateReservation(existingEvent.id, selectedPilot, start, end, true);
                } else {
                    await createReservation(selectedPilot, start, end, true);
                }
            } else {
                const fromVal = overlay.querySelector('#modal-time-from').value;
                const toVal = overlay.querySelector('#modal-time-to').value;

                if (!fromVal || !toVal) {
                    hideLoading();
                    showToast('Podaj godzinę od i do', 'error');
                    return;
                }

                if (fromVal >= toVal) {
                    hideLoading();
                    showToast('Godzina "Do" musi być po "Od"', 'error');
                    return;
                }

                const start = new Date(`${dateVal}T${fromVal}:00`);
                const end = new Date(`${dateVal}T${toVal}:00`);

                // Sprawdź kolizje
                const conflict = events.find(e =>
                    !e.isAllDay &&
                    e.id !== (existingEvent?.id) &&
                    isSameDay(e.start, start) &&
                    start < e.end && end > e.start
                );

                if (conflict) {
                    hideLoading();
                    const ok = confirm(`Ten termin koliduje z rezerwacją: ${conflict.title} (${formatTime(conflict.start)}-${formatTime(conflict.end)}). Kontynuować?`);
                    if (!ok) return;
                    showLoading();
                }

                if (isEdit) {
                    await updateReservation(existingEvent.id, selectedPilot, start, end, false);
                } else {
                    await createReservation(selectedPilot, start, end, false);
                }
            }

            overlay.remove();
            showToast(isEdit ? 'Rezerwacja zaktualizowana' : 'Rezerwacja utworzona', 'success');
            await loadWeek();
        } catch (err) {
            console.error(err);
            showToast('Błąd zapisu rezerwacji', 'error');
        } finally {
            hideLoading();
        }
    });

    // Usuń (tylko edycja)
    if (isEdit) {
        overlay.querySelector('#modal-delete').addEventListener('click', async () => {
            if (!confirm('Czy na pewno chcesz usunąć tę rezerwację?')) return;

            showLoading();
            try {
                await deleteReservation(existingEvent.id);
                overlay.remove();
                showToast('Rezerwacja usunięta', 'success');
                await loadWeek();
            } catch (err) {
                console.error(err);
                showToast('Błąd usuwania rezerwacji', 'error');
            } finally {
                hideLoading();
            }
        });
    }
}
