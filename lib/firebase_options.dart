// ⚠️  이 파일은 플레이스홀더입니다.
// 실제 Firebase 프로젝트 연결을 위해서는 다음 단계를 수행해주세요:
//
// 1. Firebase 콘솔(console.firebase.google.com)에서 새 프로젝트를 생성하세요.
// 2. Flutter 앱을 등록하세요 (패키지명: mind_diary 또는 실제 패키지명).
// 3. 터미널에서 아래 명령어를 실행하세요:
//    dart pub global activate flutterfire_cli
//    flutterfire configure
// 4. 생성된 firebase_options.dart 파일로 이 파일을 교체하세요.
//
// 그 전까지는 Firebase 기능이 비활성화되고 로컬 모드로만 동작합니다.

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
          'DefaultFirebaseOptions: 이 플랫폼은 지원되지 않습니다. '
          'flutterfire configure를 먼저 실행해주세요.',
        );
    }
  }

  // TODO: flutterfire configure 실행 후 아래 값들을 실제 값으로 교체하세요.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
    iosBundleId: 'YOUR_IOS_BUNDLE_ID',
  );
}
