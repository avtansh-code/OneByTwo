// ignore_for_file: one_member_abstracts

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Abstraction over the system share sheet for testability.
abstract class ShareServiceBase {
  /// Opens the system share sheet with the given [text].
  Future<void> share(String text);
}

/// Production implementation that delegates to the share_plus package.
///
/// Uses the platform's system share sheet only (invariant 3).
class ShareService implements ShareServiceBase {
  @override
  Future<void> share(String text) async {
    await Share.share(text);
  }
}

/// Provides a [ShareServiceBase] instance.
final shareServiceProvider = Provider<ShareServiceBase>(
  (ref) => ShareService(),
);
