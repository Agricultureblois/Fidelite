const CACHE_NAME = "agriculture-fidelite-v2026-07-03-2";
const ASSETS = ["./", "./index.html", "./manifest.json", "./logo-agriculture.jpg"];
self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(ASSETS)));
  self.skipWaiting();
});
self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key)))));
  self.clients.claim();
});
self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.mode === "navigate" || request.destination === "document") {
    event.respondWith(fetch(request).then(response => {
      const copy = response.clone();
      caches.open(CACHE_NAME).then(cache => cache.put(request, copy));
      return response;
    }).catch(() => caches.match(request).then(cached => cached || caches.match("./index.html"))));
    return;
  }
  event.respondWith(caches.match(request).then(cached => cached || fetch(request)));
});
