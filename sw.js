// Service Worker for Paper Planes
const CACHE_VERSION = 'v1';

self.addEventListener('install', event => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', event => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', event => {
  // Pass through all requests - no caching for now
  // This allows the app to work while we set up proper caching later
});

self.addEventListener('message', event => {
  // Handle messages from the main thread
  if (event.data.type === 'register') {
    // Handle registration messages
  }
});
