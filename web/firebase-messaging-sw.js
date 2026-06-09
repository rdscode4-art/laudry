// Firebase Cloud Messaging Service Worker
// Required for background push notifications on web

importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCeV8lhg-hUWwG5ge6a47UxcTW2JS_6Mgo',
  authDomain: 'rideal-laundry.firebaseapp.com',
  projectId: 'rideal-laundry',
  storageBucket: 'rideal-laundry.firebasestorage.app',
  messagingSenderId: '1070622456974',
  // Replace with real web appId from Firebase Console
  appId: '1:1070622456974:web:561ab90e05086c7b185ddf',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[SW] Background message:', payload);
  const title = payload.notification?.title || 'New Order';
  const body  = payload.notification?.body  || '';
  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
  });
});
