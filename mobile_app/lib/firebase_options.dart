// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not supported in the parent app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCSB47PrU3QtpVRcTNodmmGTWD3pjOlPLk',
    appId: '1:866620427848:android:b3a888d2d5d7639c5a927d',
    messagingSenderId: '866620427848',
    projectId: 'mealconnect-cfed5',
    storageBucket: 'mealconnect-cfed5.firebasestorage.app',
  );
}
