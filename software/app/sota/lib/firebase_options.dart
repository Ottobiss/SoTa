import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    appId: '1:703479480700:android:22db98ec8b2517411264f9',
    projectId: 'sota-pillbox',
    messagingSenderId: '703479480700',
    apiKey: '',
  );
}
