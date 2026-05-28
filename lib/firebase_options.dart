// Firebase 설정 파일
// ─────────────────────────────────────────────────────────────────────────────
// 아래 2가지 값만 Firebase 콘솔에서 확인해서 채워넣으면 됩니다:
//
//  ① messagingSenderId  →  Firebase 콘솔 → 프로젝트 설정 → "프로젝트 번호" (숫자)
//  ② appId              →  Firebase 콘솔 → 프로젝트 설정 → 내 앱 → 앱 ID
//                           (예: 1:123456789:android:abc123...)
//
// 그 전까지는 Firebase 기능 없이 앱이 정상 동작합니다 (로컬 모드).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: 지원하지 않는 플랫폼입니다.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCol4EQSaZwPsc__IHIr2e_DLy6rYZQhgc',
    authDomain: 'abalkyo.firebaseapp.com',
    projectId: 'abalkyo',
    storageBucket: 'abalkyo.firebasestorage.app',
    messagingSenderId: 'YOUR_PROJECT_NUMBER',   // ← ① 프로젝트 번호
    appId: 'YOUR_WEB_APP_ID',                  // ← ② 웹 앱 ID
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCol4EQSaZwPsc__IHIr2e_DLy6rYZQhgc',
    projectId: 'abalkyo',
    storageBucket: 'abalkyo.firebasestorage.app',
    messagingSenderId: 'YOUR_PROJECT_NUMBER',   // ← ① 프로젝트 번호
    appId: 'YOUR_ANDROID_APP_ID',              // ← ② Android 앱 ID
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCol4EQSaZwPsc__IHIr2e_DLy6rYZQhgc',
    projectId: 'abalkyo',
    storageBucket: 'abalkyo.firebasestorage.app',
    messagingSenderId: 'YOUR_PROJECT_NUMBER',   // ← ① 프로젝트 번호
    appId: 'YOUR_IOS_APP_ID',                  // ← ② iOS 앱 ID
    iosBundleId: 'com.minddiary.app',
  );
}
