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
    databaseURL: 'https://abalkyo-default-rtdb.firebaseio.com',
    projectId: 'abalkyo',
    storageBucket: 'abalkyo.firebasestorage.app',
    messagingSenderId: '188811688938',
    appId: '1:188811688938:web:84f904dc98013386c3d093',
    measurementId: 'G-1WCT32VS3X',
  );

  // Android appId: Firebase 콘솔 → 프로젝트 설정 → 앱 추가 → Android
  //   패키지명 com.minddiary.app 으로 등록 후 google-services.json 다운로드
  //   android/app/google-services.json 의 mobilesdk_app_id 값을 여기에도 복사
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCol4EQSaZwPsc__IHIr2e_DLy6rYZQhgc',
    projectId: 'abalkyo',
    databaseURL: 'https://abalkyo-default-rtdb.firebaseio.com',
    storageBucket: 'abalkyo.firebasestorage.app',
    messagingSenderId: '188811688938',
    appId: '1:188811688938:android:REPLACE_WITH_ANDROID_APP_ID',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCol4EQSaZwPsc__IHIr2e_DLy6rYZQhgc',
    projectId: 'abalkyo',
    databaseURL: 'https://abalkyo-default-rtdb.firebaseio.com',
    storageBucket: 'abalkyo.firebasestorage.app',
    messagingSenderId: '188811688938',
    appId: '1:188811688938:ios:REPLACE_WITH_IOS_APP_ID',
    iosBundleId: 'com.minddiary.app',
  );
}
