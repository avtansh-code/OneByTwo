import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';

import 'core/logging/app_logger.dart';
import 'firebase_options.dart';

/// Initialises the app: logging, Firebase, and other core services.
///
/// This function should be called before [runApp] in `main()`.
///
/// Initialisation order:
/// 1. Flutter bindings
/// 2. Logging system
/// 3. Firebase core (via [DefaultFirebaseOptions])
/// 4. Firestore offline persistence with unlimited cache
/// 5. Crashlytics fatal error handler
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise the logging system.
  await AppLogger.initialize();

  // Fail fast if Firebase config is still the placeholder.
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options.projectId == 'PLACEHOLDER-PROJECT-ID') {
    throw StateError(
      'Firebase is not configured. Run `flutterfire configure` and copy '
      'the generated file to lib/firebase_options.local.dart. '
      'See README for details.',
    );
  }

  // Initialise Firebase with platform-specific options.
  await Firebase.initializeApp(options: options);

  // Enable Firestore offline persistence with unlimited cache size.
  // This ensures the app works fully offline and syncs when connectivity
  // is restored.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Route all Flutter framework errors through Crashlytics so they are
  // captured in the Firebase console.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  AppLogger.info('Bootstrap', 'App initialised successfully');
}
