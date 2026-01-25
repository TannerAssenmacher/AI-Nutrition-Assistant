// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    apiKey: dotenv.env['GOOGLE_API_KEY_WEB']!,
    appId: '1:468473644377:web:13d28a9e81135191267848',
    messagingSenderId: '468473644377',
    projectId: 'ai-nutrition-assistant-e2346',
    authDomain: 'ai-nutrition-assistant-e2346.firebaseapp.com',
    storageBucket: 'ai-nutrition-assistant-e2346.firebasestorage.app',
    measurementId: 'G-SZ5M6VM4FR',
  );

  static final FirebaseOptions android = FirebaseOptions(
    apiKey: _require('GOOGLE_API_KEY_ANDROID'),
    appId: '1:468473644377:android:0da8f2de23872a8f267848',
    messagingSenderId: '468473644377',
    projectId: 'ai-nutrition-assistant-e2346',
    storageBucket: 'ai-nutrition-assistant-e2346.firebasestorage.app',
  );

  static final FirebaseOptions ios = FirebaseOptions(
    apiKey: dotenv.env['GOOGLE_API_KEY_IOS']!,
    appId: '1:468473644377:ios:7686922e87701012267848',
    messagingSenderId: '468473644377',
    projectId: 'ai-nutrition-assistant-e2346',
    storageBucket: 'ai-nutrition-assistant-e2346.firebasestorage.app',
    iosBundleId: 'com.ainios.myapp',
  );

  static final FirebaseOptions macos = FirebaseOptions(
    apiKey: dotenv.env['GOOGLE_API_KEY_MACOS']!,
    appId: '1:468473644377:ios:f4d65ac6e7d52171267848',
    messagingSenderId: '468473644377',
    projectId: 'ai-nutrition-assistant-e2346',
    storageBucket: 'ai-nutrition-assistant-e2346.firebasestorage.app',
    iosBundleId: 'com.ainmacos.app',
  );

  static final FirebaseOptions windows = FirebaseOptions(
    apiKey: dotenv.env['GOOGLE_API_KEY_WEB']!, // reuse web key if needed
    appId: '1:468473644377:web:c92d26cd4e74b40c267848',
    messagingSenderId: '468473644377',
    projectId: 'ai-nutrition-assistant-e2346',
    authDomain: 'ai-nutrition-assistant-e2346.firebaseapp.com',
    storageBucket: 'ai-nutrition-assistant-e2346.firebasestorage.app',
    measurementId: 'G-2WNBSDWFJF',
  );

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError('Missing env var $key for FirebaseOptions');
    }
    return value;
  }
}
