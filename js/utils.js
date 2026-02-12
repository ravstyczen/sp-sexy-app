// Polskie nazwy
export const DNI_TYGODNIA = ['Niedziela', 'Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota'];
export const DNI_KROTKIE = ['Ndz', 'Pon', 'Wto', 'Śro', 'Czw', 'Pią', 'Sob'];
export const MIESIACE = [
    'Styczeń', 'Luty', 'Marzec', 'Kwiecień', 'Maj', 'Czerwiec',
    'Lipiec', 'Sierpień', 'Wrzesień', 'Październik', 'Listopad', 'Grudzień'
];

/** Poniedziałek bieżącego tygodnia */
export function getWeekStart(date) {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);
    d.setDate(diff);
    d.setHours(0, 0, 0, 0);
    return d;
}

/** YYYY-MM-DD */
export function formatDate(date) {
    const d = new Date(date);
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
}

/** HH:MM */
export function formatTime(date) {
    const d = new Date(date);
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

/** Format: "12 Lut" */
export function formatShortDate(date) {
    const d = new Date(date);
    const months = ['Sty', 'Lut', 'Mar', 'Kwi', 'Maj', 'Cze', 'Lip', 'Sie', 'Wrz', 'Paź', 'Lis', 'Gru'];
    return `${d.getDate()} ${months[d.getMonth()]}`;
}

/** Dodaj dni do daty */
export function addDays(date, days) {
    const d = new Date(date);
    d.setDate(d.getDate() + days);
    return d;
}

/** Pokaż toast */
export function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = message;
    container.appendChild(toast);

    requestAnimationFrame(() => toast.classList.add('show'));

    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

/** Pokaż/ukryj loading */
export function showLoading() {
    document.getElementById('loading').classList.remove('hidden');
}

export function hideLoading() {
    document.getElementById('loading').classList.add('hidden');
}

/** Daty tygodnia jako tablica 7 dni od poniedziałku */
export function getWeekDays(weekStart) {
    const days = [];
    for (let i = 0; i < 7; i++) {
        days.push(addDays(weekStart, i));
    }
    return days;
}

/** Czy dwie daty to ten sam dzień */
export function isSameDay(d1, d2) {
    return d1.getFullYear() === d2.getFullYear() &&
           d1.getMonth() === d2.getMonth() &&
           d1.getDate() === d2.getDate();
}

/** Tekst nagłówka tygodnia: "10 - 16 Lut 2026" */
export function formatWeekHeader(weekStart) {
    const weekEnd = addDays(weekStart, 6);
    const startStr = weekStart.getDate();
    const endStr = weekEnd.getDate();
    const months = ['Sty', 'Lut', 'Mar', 'Kwi', 'Maj', 'Cze', 'Lip', 'Sie', 'Wrz', 'Paź', 'Lis', 'Gru'];

    if (weekStart.getMonth() === weekEnd.getMonth()) {
        return `${startStr} - ${endStr} ${months[weekEnd.getMonth()]} ${weekEnd.getFullYear()}`;
    }
    return `${startStr} ${months[weekStart.getMonth()]} - ${endStr} ${months[weekEnd.getMonth()]} ${weekEnd.getFullYear()}`;
}
