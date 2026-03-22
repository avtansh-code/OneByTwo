import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../network/connectivity_service.dart';

/// An offline banner widget that displays at the top of the screen when
/// the device has no network connectivity.
///
/// Wraps its [child] and conditionally shows a warning banner above it.
/// The banner animates in/out smoothly when connectivity changes.
///
/// Usage:
/// ```dart
/// OfflineBanner(
///   connectivityService: connectivityService,
///   child: MyPageContent(),
/// )
/// ```
class OfflineBanner extends StatefulWidget {
  /// Creates an [OfflineBanner].
  const OfflineBanner({
    super.key,
    required this.connectivityService,
    required this.child,
  });

  /// The connectivity service to listen to for online/offline changes.
  final ConnectivityService connectivityService;

  /// The widget to display below the optional offline banner.
  final Widget child;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOnline = true;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
    _subscription = widget.connectivityService.onConnectivityChanged.listen((
      online,
    ) {
      if (mounted) {
        setState(() => _isOnline = online);
      }
    });
  }

  Future<void> _checkInitialStatus() async {
    final online = await widget.connectivityService.isConnected;
    if (mounted) {
      setState(() => _isOnline = online);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _isOnline
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: const SizedBox.shrink(),
          secondChild: Material(
            color: theme.colorScheme.errorContainer,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 18,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.offlineBanner,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
