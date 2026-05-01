import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/features/auth/presentation/phone_entry_screen.dart';

/// Whether to use the Firebase Auth Emulator.
///
/// Pass `--dart-define=USE_EMULATOR=true` to `flutter run` to enable:
///   flutter run --dart-define=USE_EMULATOR=true
const _useEmulator = bool.fromEnvironment('USE_EMULATOR');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  if (_useEmulator) {
    const host = String.fromEnvironment(
      'EMULATOR_HOST',
      defaultValue: 'localhost',
    );
    debugPrint('[OneByTwo] Connecting to auth emulator $host:9099...');
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    debugPrint('[OneByTwo] Auth emulator connected.');
    debugPrint('[OneByTwo] Connecting to Firestore emulator $host:8080...');
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    debugPrint('[OneByTwo] Firestore emulator connected.');
    debugPrint('[OneByTwo] Connecting to Storage emulator $host:9199...');
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    debugPrint('[OneByTwo] Storage emulator connected.');
  }
  runApp(const ProviderScope(child: OneBytwoApp()));
}

/// Root widget for the One By Two application.
class OneBytwoApp extends StatelessWidget {
  /// Creates the root application widget.
  const OneBytwoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneByTwo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const PhoneEntryScreen(),
    );
  }
}
