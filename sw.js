const CACHE_NAME = 'sp-sexy-v1';
const APP_SHELL = [
    './',
    'index.html',
    'offline.html',
    'css/styles.css',
    'js/app.js',
    'js/auth.js',
    'js/config.js',
    'js/api-calendar.js',
    'js/api-sheets.js',
    'js/view-reservations.js',
    'js/view-flight-log.js',
    'js/utils.js',
    'icons/icon-192.png',
    'icons/icon-512.png',
    'icons/apple-touch-icon.png'
];

self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => cache.addAll(APP_SHELL))
            .then(() => self.skipWaiting())
    );
});

self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys().then(keys =>
            Promise.all(
                keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
            )
        ).then(() => self.clients.claim())
    );
});

self.addEventListener('fetch', event => {
    const url = new URL(event.request.url);

    // Google API - nie cachujemy
    if (url.hostname.includes('googleapis.com') ||
        url.hostname.includes('accounts.google.com') ||
        url.hostname.includes('gstatic.com')) {
        return;
    }

    event.respondWith(
        caches.match(event.request).then(cached => {
            return cached || fetch(event.request).catch(() => {
                if (event.request.mode === 'navigate') {
                    return caches.match('offline.html');
                }
            });
        })
    );
});
