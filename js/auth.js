import { CONFIG } from './config.js';

let tokenClient = null;
let currentPilot = null;
let accessToken = null;

/** Czeka na załadowanie gapi */
function waitForGapi() {
    return new Promise((resolve) => {
        if (window.gapi) {
            resolve();
        } else {
            const check = setInterval(() => {
                if (window.gapi) {
                    clearInterval(check);
                    resolve();
                }
            }, 100);
        }
    });
}

/** Czeka na załadowanie GIS */
function waitForGis() {
    return new Promise((resolve) => {
        if (window.google?.accounts?.oauth2) {
            resolve();
        } else {
            const check = setInterval(() => {
                if (window.google?.accounts?.oauth2) {
                    clearInterval(check);
                    resolve();
                }
            }, 100);
        }
    });
}

/** Inicjalizuje gapi client */
function initGapiClient() {
    return new Promise((resolve, reject) => {
        gapi.load('client', async () => {
            try {
                await gapi.client.init({
                    apiKey: CONFIG.API_KEY,
                    discoveryDocs: CONFIG.DISCOVERY_DOCS,
                });
                resolve();
            } catch (err) {
                reject(err);
            }
        });
    });
}

/** Inicjalizuje cały system auth */
export async function initAuth() {
    await waitForGapi();
    await initGapiClient();
    await waitForGis();

    return new Promise((resolve) => {
        tokenClient = google.accounts.oauth2.initTokenClient({
            client_id: CONFIG.CLIENT_ID,
            scope: CONFIG.SCOPES,
            callback: '', // ustawiane dynamicznie
        });
        resolve();
    });
}

/** Dekoduj payload z JWT tokenu (bez weryfikacji - tylko odczyt) */
function decodeJwtPayload(token) {
    try {
        const base64Url = token.split('.')[1];
        const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
        const jsonPayload = decodeURIComponent(
            atob(base64).split('').map(c =>
                '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)
            ).join('')
        );
        return JSON.parse(jsonPayload);
    } catch (e) {
        return null;
    }
}

/** Pobierz email użytkownika - próbuj różne metody */
async function getUserEmail(tokenResponse) {
    // Metoda 1: ID token z odpowiedzi GIS (jeśli scope zawiera openid)
    if (tokenResponse.id_token) {
        const payload = decodeJwtPayload(tokenResponse.id_token);
        if (payload?.email) {
            console.log('Email z id_token:', payload.email);
            return payload.email;
        }
    }

    // Metoda 2: Google People API (nie wymaga dodatkowego scope)
    try {
        const res = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
            headers: { Authorization: `Bearer ${tokenResponse.access_token}` }
        });
        const data = await res.json();
        console.log('Userinfo response:', data);
        if (data.email) return data.email;
    } catch (e) {
        console.warn('Userinfo failed:', e);
    }

    // Metoda 3: People API via gapi
    try {
        const res = await gapi.client.request({
            path: 'https://people.googleapis.com/v1/people/me?personFields=emailAddresses',
        });
        const emails = res.result?.emailAddresses;
        if (emails?.length > 0) {
            console.log('Email z People API:', emails[0].value);
            return emails[0].value;
        }
    } catch (e) {
        console.warn('People API failed:', e);
    }

    return null;
}

/** Logowanie - zwraca Promise z obiektem pilota */
export function signIn() {
    return new Promise((resolve, reject) => {
        tokenClient.callback = async (response) => {
            if (response.error) {
                reject(new Error(response.error));
                return;
            }

            accessToken = response.access_token;
            gapi.client.setToken({ access_token: accessToken });

            try {
                console.log('Token response keys:', Object.keys(response));

                const email = await getUserEmail(response);

                if (!email) {
                    reject(new Error('Nie udało się pobrać adresu email. Sprawdź uprawnienia aplikacji w Google Cloud Console.'));
                    return;
                }

                console.log('Zalogowany jako:', email);

                // Sprawdź whitelist
                const pilot = CONFIG.PILOTS.find(p => p.email.toLowerCase() === email.toLowerCase());
                if (!pilot) {
                    google.accounts.oauth2.revoke(accessToken);
                    gapi.client.setToken(null);
                    accessToken = null;
                    reject(new Error(`Konto ${email} nie ma dostępu do aplikacji.`));
                    return;
                }

                currentPilot = pilot;
                resolve(pilot);
            } catch (err) {
                console.error('Login error details:', err);
                reject(err);
            }
        };

        tokenClient.requestAccessToken({ prompt: 'consent' });
    });
}

/** Wylogowanie */
export function signOut() {
    if (accessToken) {
        google.accounts.oauth2.revoke(accessToken);
        gapi.client.setToken(null);
    }
    accessToken = null;
    currentPilot = null;
}

/** Obecny pilot */
export function getCurrentPilot() {
    return currentPilot;
}

/** Czy zalogowany */
export function isAuthenticated() {
    return currentPilot !== null && accessToken !== null;
}

/** Wrapper API call z obsługą 401 */
export async function apiCall(fn) {
    try {
        return await fn();
    } catch (err) {
        if (err?.status === 401 || err?.result?.error?.code === 401) {
            // Token wygasł - odśwież
            return new Promise((resolve, reject) => {
                tokenClient.callback = async (response) => {
                    if (response.error) {
                        reject(new Error('Sesja wygasła. Zaloguj się ponownie.'));
                        return;
                    }
                    accessToken = response.access_token;
                    gapi.client.setToken({ access_token: accessToken });
                    try {
                        resolve(await fn());
                    } catch (retryErr) {
                        reject(retryErr);
                    }
                };
                tokenClient.requestAccessToken({ prompt: '' });
            });
        }
        throw err;
    }
}
