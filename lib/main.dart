import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/features/auth/presentation/phone_entry_screen.dart';
import 'package:onebytwo/firebase_options.dart';

/// Whether to connect to Firebase Emulator Suite.
///
/// Set to `true` for local development. The emulator ports match
/// `firebase.json` and `scripts/dev/start-emulators.sh`.
const useEmulators = true;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (useEmulators) {
    // localhost works on iOS Simulator; Android emulator needs 10.0.2.2.
    final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';

    FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8081);
    FirebaseStorage.instance.useStorageEmulator(host, 9199);
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
