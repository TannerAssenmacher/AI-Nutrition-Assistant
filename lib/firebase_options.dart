// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

const String _firebaseApiKey = 'AIzaSyC3ffg9dqgDmQ-FNO7O5IJ_uBdybOoCWrA';

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
          'FirebaseOptions not configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'FirebaseOptions not supported for this platform.',
        );
    }
  }

  static final FirebaseOptions web = FirebaseOptions(
    apiKey: _firebaseApiKey,
    appId: '1:468473644377:web:13d28a9e81135191267848',
    messagingSenderId: '468473644377',
    projectId: 'ai-nutrition-assistant-e2346',
    authDomain: 'ai-nutrition-assistant-e2346.firebaseapp.com',
    storageBucket: 'ai-nutrition-assistant-e2346.firebasestorage.app',
    measurementId: 'G-SZ5M6VM4FR',
  );

  static final FirebaseOptions android = FirebaseOptions(
    apiKey: _firebaseApiKey,
    appId: '1:468473644377:android:0da8f2de23872a8f267848',
    messagingSenderId: '468473644377',
    projectId: 'ai-nutrition-assistant-e2346',
    storageBucket: 'ai-nutrition-assistant-e2346.firebasestorage.app',
  );

  static final FirebaseOptions ios = FirebaseOptions(
    apiKey: _firebaseApiKey,
    appId: '1:468473644377:ios:5b61e9875f43caa1267848',
    messagingSenderId: '468473644377',
    projectId: 'ai-nutrition-assistant-e2346',
    storageBucket: 'ai-nutrition-assistant-e2346.firebasestorage.app',
    iosBundleId: 'com.example.aiNutritionAssistant',
  );

  static final FirebaseOptions macos = FirebaseOptions(
    apiKey: _firebaseApiKey,
    appId: '1:468473644377:ios:f4d65ac6e7d52171267848',
    messagingSenderId: '468473644377',
    projectId: 'ai-nutrition-assistant-e2346',
    storageBucket: 'ai-nutrition-assistant-e2346.firebasestorage.app',
    iosBundleId: 'com.ainmacos.app',
  );

  static final FirebaseOptions windows = FirebaseOptions(
    apiKey: _firebaseApiKey,
    appId: '1:468473644377:web:c92d26cd4e74b40c267848',
    messagingSenderId: '468473644377',
    projectId: 'ai-nutrition-assistant-e2346',
    authDomain: 'ai-nutrition-assistant-e2346.firebaseapp.com',
    storageBucket: 'ai-nutrition-assistant-e2346.firebasestorage.app',
    measurementId: 'G-2WNBSDWFJF',
  );
}
