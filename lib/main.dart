import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/features/auth/presentation/phone_entry_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[OneByTwo] Initialising Firebase...');
  await Firebase.initializeApp();
  debugPrint('[OneByTwo] Firebase initialised.');
  if (kDebugMode) {
    debugPrint('[OneByTwo] Connecting to auth emulator localhost:9099...');
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    debugPrint('[OneByTwo] Auth emulator connected.');
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
