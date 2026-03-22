// ignore: unused_import, Needed when Firebase initialisation is uncommented.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'core/logging/app_logger.dart';
// ignore: unused_import, Needed when Firebase initialisation is uncommented.
import 'firebase_options.dart';

/// Initialises the app: logging, Firebase, and other core services.
///
/// This function should be called before [runApp] in `main()`.
/// Firebase initialisation is commented out until `firebase_options.dart`
/// contains real configuration values from `flutterfire configure`.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise the logging system.
  await AppLogger.initialize();

  // TODO(firebase): Uncomment when firebase_options.dart has real config
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  // TODO(firebase): Enable Firestore offline persistence
  // FirebaseFirestore.instance.settings = const Settings(
  //   persistenceEnabled: true,
  //   cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  // );

  // TODO(firebase): Enable Crashlytics
  // FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  AppLogger.info('Bootstrap', 'App initialised successfully');
}
