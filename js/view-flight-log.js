import { getCurrentPilot } from './auth.js';
import { getFlightLog, getLastEntry, appendFlightLogEntry } from './api-sheets.js';
import { formatDate, showToast, showLoading, hideLoading } from './utils.js';

/** Renderuj widok Dziennika Lotów */
export async function renderFlightLog(container) {
    container.innerHTML = `
        <div class="flight-log-container">
            <div class="segment-control">
                <button class="segment-btn active" data-segment="new">Nowy wpis</button>
                <button class="segment-btn" data-segment="history">Historia</button>
            </div>
            <div id="flight-log-content"></div>
        </div>
    `;

    const segmentBtns = container.querySelectorAll('.segment-btn');
    segmentBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            segmentBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            if (btn.dataset.segment === 'new') {
                renderNewEntryForm();
            } else {
                renderHistory();
            }
        });
    });

    renderNewEntryForm();
}

async function renderNewEntryForm() {
    const content = document.getElementById('flight-log-content');
    const pilot = getCurrentPilot();
    const today = formatDate(new Date());

    content.innerHTML = `
        <form id="flight-log-form">
            <div class="form-group">
                <label>Data</label>
                <input type="date" id="fl-date" value="${today}">
            </div>
            <div class="form-group">
                <label>Pilot</label>
                <input type="text" id="fl-pilot" value="${pilot.name}" readonly>
            </div>
            <div class="form-row">
                <div class="form-group">
                    <label>Motogodziny przed lotem</label>
                    <input type="number" id="fl-hours-before" inputmode="decimal" step="0.1" placeholder="np. 145.3">
                </div>
                <div class="form-group">
                    <label>Motogodziny po locie</label>
                    <input type="number" id="fl-hours-after" inputmode="decimal" step="0.1" placeholder="np. 146.8" required>
                </div>
            </div>
            <div class="form-row">
                <div class="form-group">
                    <label>Paliwo dolane (L)</label>
                    <input type="number" id="fl-fuel" inputmode="decimal" step="0.1" value="0">
                </div>
                <div class="form-group">
                    <label>Olej dolany (L)</label>
                    <input type="number" id="fl-oil" inputmode="decimal" step="0.1" value="0">
                </div>
            </div>
            <div class="form-row">
                <div class="form-group">
                    <label>Koszt paliwa (PLN)</label>
                    <input type="number" id="fl-fuel-cost" inputmode="decimal" step="0.01" value="0">
                </div>
                <div class="form-group">
                    <label>Stan paliwa (L)</label>
                    <input type="number" id="fl-fuel-level" inputmode="decimal" step="0.1" placeholder="np. 60">
                </div>
            </div>
            <div class="form-group">
                <label>Uwagi (lot i stan samolotu)</label>
                <textarea id="fl-remarks" placeholder="Uwagi dotyczące lotu i stanu samolotu..."></textarea>
            </div>
            <div class="form-actions">
                <button type="submit" class="btn btn-primary" style="flex:1">Zapisz wpis</button>
            </div>
        </form>
    `;

    // Auto-fill motogodziny z ostatniego wpisu
    showLoading();
    try {
        const lastEntry = await getLastEntry();
        if (lastEntry && lastEntry.hoursAfter) {
            document.getElementById('fl-hours-before').value = lastEntry.hoursAfter;
        }
    } catch (err) {
        console.error('Nie udało się pobrać ostatniego wpisu:', err);
    } finally {
        hideLoading();
    }

    // Obsługa zapisu
    document.getElementById('flight-log-form').addEventListener('submit', async (e) => {
        e.preventDefault();

        const hoursBefore = document.getElementById('fl-hours-before').value;
        const hoursAfter = document.getElementById('fl-hours-after').value;

        if (!hoursAfter) {
            showToast('Podaj motogodziny po locie', 'error');
            return;
        }

        if (hoursBefore && parseFloat(hoursAfter) <= parseFloat(hoursBefore)) {
            showToast('Motogodziny po locie muszą być większe niż przed', 'error');
            return;
        }

        const entry = {
            date: document.getElementById('fl-date').value,
            pilot: document.getElementById('fl-pilot').value,
            hoursBefore: hoursBefore,
            hoursAfter: hoursAfter,
            fuelAdded: document.getElementById('fl-fuel').value,
            oilAdded: document.getElementById('fl-oil').value,
            fuelLevel: document.getElementById('fl-fuel-level').value,
            fuelCost: document.getElementById('fl-fuel-cost').value,
            remarks: document.getElementById('fl-remarks').value,
        };

        showLoading();
        try {
            await appendFlightLogEntry(entry);
            showToast('Wpis zapisany pomyślnie', 'success');

            // Przełącz na historię
            const btns = document.querySelectorAll('.segment-btn');
            btns.forEach(b => b.classList.remove('active'));
            btns[1].classList.add('active');
            await renderHistory();
        } catch (err) {
            console.error(err);
            showToast('Błąd zapisu wpisu', 'error');
        } finally {
            hideLoading();
        }
    });
}

async function renderHistory() {
    const content = document.getElementById('flight-log-content');

    showLoading();
    try {
        const entries = await getFlightLog();

        if (entries.length === 0) {
            content.innerHTML = `
                <div class="empty-state">
                    <div class="empty-icon">&#128209;</div>
                    <p>Brak wpisów w dzienniku lotów.</p>
                    <p>Dodaj pierwszy wpis po locie!</p>
                </div>
            `;
            return;
        }

        // Odwróć - najnowsze na górze
        const reversed = [...entries].reverse();

        content.innerHTML = `
            <div class="history-table-wrapper">
                <table class="history-table">
                    <thead>
                        <tr>
                            <th>Data</th>
                            <th>Pilot</th>
                            <th>Przed</th>
                            <th>Po</th>
                            <th>Paliwo (L)</th>
                            <th>Olej (L)</th>
                            <th>Koszt (PLN)</th>
                            <th>Stan pal.</th>
                            <th>Uwagi</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${reversed.map(e => `
                            <tr>
                                <td>${e.date}</td>
                                <td>${e.pilot}</td>
                                <td>${e.hoursBefore}</td>
                                <td>${e.hoursAfter}</td>
                                <td>${e.fuelAdded}</td>
                                <td>${e.oilAdded}</td>
                                <td>${e.fuelCost}</td>
                                <td>${e.fuelLevel}</td>
                                <td>${e.remarks || '-'}</td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            </div>
        `;

        // Zapisz do cache
        try {
            localStorage.setItem('cache_flight_log', JSON.stringify(entries));
        } catch (e) { /* ignore */ }

    } catch (err) {
        // Spróbuj cache
        const cached = localStorage.getItem('cache_flight_log');
        if (cached) {
            const entries = JSON.parse(cached).reverse();
            content.innerHTML = `
                <p style="text-align:center;padding:8px;color:#f6bf26;font-size:13px;">Dane z pamięci podręcznej</p>
                <div class="history-table-wrapper">
                    <table class="history-table">
                        <thead>
                            <tr>
                                <th>Data</th>
                                <th>Pilot</th>
                                <th>Przed</th>
                                <th>Po</th>
                                <th>Paliwo (L)</th>
                                <th>Koszt (PLN)</th>
                                <th>Olej (L)</th>
                                <th>Stan pal.</th>
                                <th>Uwagi</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${entries.map(e => `
                                <tr>
                                    <td>${e.date}</td>
                                    <td>${e.pilot}</td>
                                    <td>${e.hoursBefore}</td>
                                    <td>${e.hoursAfter}</td>
                                    <td>${e.fuelAdded}</td>
                                    <td>${e.fuelCost}</td>
                                    <td>${e.oilAdded}</td>
                                    <td>${e.fuelLevel}</td>
                                    <td>${e.remarks || '-'}</td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                </div>
            `;
        } else {
            content.innerHTML = '<div class="empty-state"><p>Błąd ładowania historii.</p></div>';
        }
        console.error(err);
    } finally {
        hideLoading();
    }
}
