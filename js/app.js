import { initAuth, signIn, signOut, getCurrentPilot, isAuthenticated, tryAutoLogin } from './auth.js';
import { renderReservations } from './view-reservations.js';
import { renderFlightLog } from './view-flight-log.js';
import { showToast, showLoading, hideLoading } from './utils.js';

let currentView = 'reservations';

/** Inicjalizacja aplikacji */
async function init() {
    // Rejestracja Service Worker
    if ('serviceWorker' in navigator) {
        try {
            await navigator.serviceWorker.register('sw.js');
        } catch (err) {
            console.warn('SW registration failed:', err);
        }
    }

    // Prompt instalacji na iOS
    showInstallPrompt();

    // Inicjalizacja auth + próba auto-logowania
    showLoading();
    try {
        await initAuth();

        // Spróbuj zalogować automatycznie (bez popupu)
        const pilot = await tryAutoLogin();
        if (pilot) {
            showMainScreen(pilot);
        }
    } catch (err) {
        console.error('Auth init error:', err);
        showToast('Błąd inicjalizacji. Odśwież stronę.', 'error');
    } finally {
        hideLoading();
    }

    // Przycisk logowania
    document.getElementById('btn-login').addEventListener('click', handleLogin);

    // Przycisk wylogowania
    document.getElementById('btn-logout').addEventListener('click', handleLogout);

    // Zakładki
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', () => switchView(tab.dataset.view));
    });
}

async function handleLogin() {
    showLoading();
    try {
        const pilot = await signIn();
        showMainScreen(pilot);
    } catch (err) {
        console.error('Login error:', err);
        const errorEl = document.getElementById('login-error');
        errorEl.textContent = err.message || 'Błąd logowania. Spróbuj ponownie.';
        errorEl.classList.remove('hidden');
    } finally {
        hideLoading();
    }
}

function handleLogout() {
    signOut();
    document.getElementById('main-screen').classList.remove('active');
    document.getElementById('login-screen').classList.add('active');
    document.getElementById('login-error').classList.add('hidden');
    document.getElementById('content').innerHTML = '';
}

function showMainScreen(pilot) {
    document.getElementById('login-screen').classList.remove('active');
    document.getElementById('main-screen').classList.add('active');
    document.getElementById('pilot-name').textContent = pilot.name;

    // Załaduj domyślny widok
    switchView('reservations');
}

async function switchView(view) {
    currentView = view;
    const content = document.getElementById('content');

    // Aktualizuj aktywną zakładkę
    document.querySelectorAll('.tab').forEach(t => {
        t.classList.toggle('active', t.dataset.view === view);
    });

    // Ukryj FAB w dzienniku lotów
    const existingFab = document.querySelector('.fab');
    if (existingFab) existingFab.remove();

    content.innerHTML = '';

    if (view === 'reservations') {
        await renderReservations(content);
    } else if (view === 'flight-log') {
        await renderFlightLog(content);
    }
}

/** Prompt instalacji na iOS */
function showInstallPrompt() {
    // Tylko na iOS, nie w standalone mode
    const isIos = /iphone|ipad|ipod/.test(navigator.userAgent.toLowerCase());
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches ||
                         window.navigator.standalone;

    if (!isIos || isStandalone) return;

    // Sprawdź czy już zamknięto
    if (localStorage.getItem('install_prompt_dismissed')) return;

    const prompt = document.getElementById('install-prompt');
    prompt.classList.remove('hidden');

    document.getElementById('install-prompt-close').addEventListener('click', () => {
        prompt.classList.add('hidden');
        localStorage.setItem('install_prompt_dismissed', '1');
    });
}

// Start
init();
