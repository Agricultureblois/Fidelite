// Service worker minimal : ne met RIEN en cache.
// Son seul rôle est de rendre l'app installable (Chrome exige un service worker
// avec un gestionnaire de requêtes pour proposer le bouton "Installer" sur Android).
// Volontairement sans cache : les téléphones ne peuvent donc pas garder une version périmée.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // Nettoie d'éventuels caches laissés par d'anciennes versions.
    const keys = await caches.keys();
    await Promise.all(keys.map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  // On ne touche ni aux requêtes Supabase (POST, autre origine) ni au CDN.
  if (event.request.method !== 'GET') return;
  if (new URL(event.request.url).origin !== self.location.origin) return;
  // Même origine : on va toujours chercher la version en ligne, jamais un cache.
  event.respondWith(fetch(event.request));
});
