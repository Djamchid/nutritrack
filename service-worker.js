// Service Worker pour NutriTrack
const CACHE_NAME = 'nutritrack-v1';
const urlsToCache = [
  '/',
  '/index.html',
  '/manifest.json',
  // Ajoutez ici vos autres ressources (CSS, JS externes si nécessaire)
];

// Installation du Service Worker
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('Cache ouvert');
        return cache.addAll(urlsToCache);
      })
  );
  // Force le SW à devenir actif immédiatement
  self.skipWaiting();
});

// Activation du Service Worker
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          // Supprime les anciens caches
          if (cacheName !== CACHE_NAME) {
            console.log('Suppression ancien cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  // Prend le contrôle immédiatement
  self.clients.claim();
});

// Interception des requêtes
self.addEventListener('fetch', event => {
  // Stratégie Cache First pour les ressources statiques
  event.respondWith(
    caches.match(event.request)
      .then(response => {
        // Retourne la ressource en cache si elle existe
        if (response) {
          return response;
        }

        // Sinon, fait la requête réseau
        return fetch(event.request).then(response => {
          // Ne met en cache que les requêtes réussies
          if (!response || response.status !== 200 || response.type !== 'basic') {
            return response;
          }

          // Clone la réponse car elle ne peut être utilisée qu'une fois
          const responseToCache = response.clone();

          caches.open(CACHE_NAME)
            .then(cache => {
              cache.put(event.request, responseToCache);
            });

          return response;
        });
      })
      .catch(() => {
        // En cas d'erreur réseau, on peut retourner une page offline personnalisée
        // Pour cette app, on utilise le cache existant
        console.log('Erreur réseau - Mode offline');
      })
  );
});

// Gestion des messages du client
self.addEventListener('message', event => {
  if (event.data.action === 'skipWaiting') {
    self.skipWaiting();
  }
});

// Synchronisation en arrière-plan (optionnel pour futures fonctionnalités)
self.addEventListener('sync', event => {
  if (event.tag === 'sync-nutrition-data') {
    event.waitUntil(syncNutritionData());
  }
});

async function syncNutritionData() {
  // Future implémentation pour synchroniser avec un serveur
  console.log('Synchronisation des données nutrition...');
}