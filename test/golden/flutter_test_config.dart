import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// Auto-discovered by `flutter test` for every test under `test/golden/`.
///
/// Loads the bundled Haldi fonts once, here, in real async — before the
/// individual `testWidgets` bodies run under their fake-async clock, where the
/// font files' I/O would never complete. The per-test `loadHaldiFonts` calls
/// then hit the in-memory guard and return without touching the file system.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadHaldiFonts();
  await testMain();
}
