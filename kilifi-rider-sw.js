/**
 * KilifiHub Rider Service Worker
 * 
 * This service worker enables:
 * 1. Push notifications when the browser tab is closed
 * 2. Background sync for location updates
 * 3. PWA "Add to Home Screen" functionality
 * 
 * INSTALL: Place this file at /kilifi-rider-sw.js in your WordPress root
 */

const CACHE_NAME = 'kilifi-rider-v1';
const OFFLINE_URL = '/rider-dashboard/';

// Install event — cache essential resources
self.addEventListener('install', function(event) {
    event.waitUntil(
        caches.open(CACHE_NAME).then(function(cache) {
            return cache.addAll([
                '/rider-dashboard/',
                '/wp-admin/admin-ajax.php'
            ]);
        })
    );
    self.skipWaiting();
});

// Activate event — clean old caches
self.addEventListener('activate', function(event) {
    event.waitUntil(
        caches.keys().then(function(cacheNames) {
            return Promise.all(
                cacheNames.filter(function(name) {
                    return name !== CACHE_NAME;
                }).map(function(name) {
                    return caches.delete(name);
                })
            );
        })
    );
    self.clients.claim();
});

// Fetch event — network-first strategy (always try fresh data for riders)
self.addEventListener('fetch', function(event) {
    // Only handle same-origin requests
    if (!event.request.url.startsWith(self.location.origin)) return;
    
    event.respondWith(
        fetch(event.request).catch(function() {
            return caches.match(event.request).then(function(response) {
                return response || caches.match(OFFLINE_URL);
            });
        })
    );
});

// Push notification event — shows notification when server sends push
self.addEventListener('push', function(event) {
    if (!event.data) return;
    
    try {
        var data = event.data.json();
        var options = {
            body: data.body || 'You have a new delivery order!',
            icon: data.icon || '/wp-content/uploads/kilifi-icon-192.png',
            badge: '/wp-content/uploads/kilifi-badge.png',
            tag: data.tag || 'kilifi-order',
            requireInteraction: true,
            vibrate: [200, 100, 200, 100, 200],
            data: {
                order_id: data.order_id || 0,
                url: data.url || '/rider-dashboard/'
            },
            actions: [
                { action: 'accept', title: 'Accept Order' },
                { action: 'decline', title: 'Decline' }
            ]
        };
        
        event.waitUntil(
            self.registration.showNotification(data.title || 'New Order!', options)
        );
    } catch(e) {
        // Fallback for non-JSON push data
        event.waitUntil(
            self.registration.showNotification('KilifiHub', {
                body: 'You have a new delivery order!',
                icon: '/wp-content/uploads/kilifi-icon-192.png',
                requireInteraction: true,
                vibrate: [200, 100, 200]
            })
        );
    }
});

// Notification click event — open the rider dashboard
self.addEventListener('notificationclick', function(event) {
    event.notification.close();
    
    var urlToOpen = '/rider-dashboard/';
    
    if (event.notification.data && event.notification.data.url) {
        urlToOpen = event.notification.data.url;
    }
    
    if (event.action === 'accept' || event.action === 'decline') {
        urlToOpen += (urlToOpen.indexOf('?') > -1 ? '&' : '?') + 'action=' + event.action;
        if (event.notification.data.order_id) {
            urlToOpen += '&order_id=' + event.notification.data.order_id;
        }
    }
    
    event.waitUntil(
        self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
            // Focus existing tab if open
            for (var i = 0; i < clientList.length; i++) {
                if (clientList[i].url.indexOf('rider-dashboard') > -1 && 'focus' in clientList[i]) {
                    return clientList[i].focus();
                }
            }
            // Otherwise open new tab
            if (self.clients.openWindow) {
                return self.clients.openWindow(urlToOpen);
            }
        })
    );
});
