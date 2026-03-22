import 'package:flutter/material.dart';

import 'package:one_by_two/core/l10n/generated/app_localizations.dart';
import 'package:one_by_two/core/theme/app_colors.dart';

/// Possible sync states for a document or write operation.
enum SyncStatus {
  /// The data is fully synced with the server.
  synced,

  /// A local write is waiting to be acknowledged by the server.
  pending,

  /// The sync attempt failed.
  error,
}

/// Small badge showing the current sync status of a document.
///
/// Visual encoding:
/// - [SyncStatus.synced] — ✓ green checkmark
/// - [SyncStatus.pending] — ↑ amber upload icon
/// - [SyncStatus.error] — ⚠ red warning icon
///
/// Typically placed next to a list item or card to indicate whether
/// the displayed data has been persisted to Firestore.
class ConnectivityBadge extends StatelessWidget {
  /// Creates a [ConnectivityBadge].
  const ConnectivityBadge({super.key, required this.status, this.size = 16});

  /// The current sync status to display.
  final SyncStatus status;

  /// Icon size in logical pixels. Defaults to 16.
  final double size;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final l10n = AppLocalizations.of(context);

    final (IconData icon, Color color, String tooltip) = switch (status) {
      SyncStatus.synced => (
        Icons.check_circle_rounded,
        appColors.syncSuccessColor,
        l10n.synced,
      ),
      SyncStatus.pending => (
        Icons.cloud_upload_outlined,
        appColors.syncPendingColor,
        l10n.syncing,
      ),
      SyncStatus.error => (
        Icons.warning_amber_rounded,
        appColors.syncErrorColor,
        l10n.syncFailed,
      ),
    };

    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: size, color: color),
    );
  }
}
