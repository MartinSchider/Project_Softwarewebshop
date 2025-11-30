import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDLp71rMQ0b9u0leuyhvuZ8twvHGnyaCfE',
    appId: '1:758309582569:web:a0fb5cffbfcfcbc4d26278',
    messagingSenderId: '758309582569',
    projectId: 'softwarewebshop-7ff5a',
    authDomain: 'softwarewebshop-7ff5a.firebaseapp.com',
    storageBucket: 'softwarewebshop-7ff5a.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCngHMzhIGnbPQESq533VddiUaJr9WIhp4',
    appId: '1:758309582569:android:d1a38c58cd7c7342d26278',
    messagingSenderId: '758309582569',
    projectId: 'softwarewebshop-7ff5a',
    storageBucket: 'softwarewebshop-7ff5a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCngHMzhIGnbPQESq533VddiUaJr9WIhp4',
    appId: '1:758309582569:ios:4edc7671af0228fcd26278',
    messagingSenderId: '758309582569',
    projectId: 'softwarewebshop-7ff5a',
    storageBucket: 'softwarewebshop-7ff5a.firebasestorage.app',
    iosBundleId: 'com.example.webshop',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCngHMzhIGnbPQESq533VddiUaJr9WIhp4',
    appId: '1:758309582569:ios:4edc7671af0228fcd26278',
    messagingSenderId: '758309582569',
    projectId: 'softwarewebshop-7ff5a',
    storageBucket: 'softwarewebshop-7ff5a.firebasestorage.app',
    iosBundleId: 'com.example.webshop',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCngHMzhIGnbPQESq533VddiUaJr9WIhp4',
    appId: '1:758309582569:web:dd39fc38c9212cdfd26278',
    messagingSenderId: '758309582569',
    projectId: 'softwarewebshop-7ff5a',
    authDomain: 'softwarewebshop-7ff5a.firebaseapp.com',
    storageBucket: 'softwarewebshop-7ff5a.firebasestorage.app',
  );
}
