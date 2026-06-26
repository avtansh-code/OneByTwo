import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/providers/phone_auth_provider.dart';
import 'package:onebytwo/core/widgets/branding/obt_brand.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';

/// Splash screen displayed during cold-start auth state resolution (SCR-01).
///
/// Shows the ÷ brand mark + "OneByTwo" wordmark and tagline on a full-bleed
/// marigold gradient (the Haldi brand moment, DC-04), with a three-dot
/// loader. Everything on the marigold fill is rendered in **ink**
/// (`onPrimary`) — never white, which would fail the AA contrast gate. If
/// auth state has not resolved after 1500 ms, a "Having trouble?" recovery
/// link appears that signs the user out and returns to phone entry.
///
/// See `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md` (SCR-01)
/// and `docs/design/04-wireframes/auth-flow.md` section 1.
class SplashScreen extends ConsumerStatefulWidget {
  /// Creates a [SplashScreen].
  const SplashScreen({
    this.timeoutDuration = const Duration(milliseconds: 1500),
    super.key,
  });

  /// Duration before showing the "Having trouble?" recovery option.
  @visibleForTesting
  final Duration timeoutDuration;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _showRecovery = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(widget.timeoutDuration, () {
      if (mounted) {
        setState(() => _showRecovery = true);
      }
    });
    // Fire app_launched telemetry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'app_launched',
            parameters: {
              'platform': Theme.of(context).platform == TargetPlatform.iOS
                  ? 'iOS'
                  : 'Android',
            },
          );
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _onRecoveryTap() async {
    final authRepo = ref.read(phoneAuthRepositoryProvider);
    await authRepo.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Everything on the marigold gradient is ink (onPrimary), never white.
    final ink = theme.colorScheme.onPrimary;

    return Scaffold(
      body: OBTSplashGradient(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand lockup — ÷ mark + OneByTwo wordmark, ink on marigold.
                OBTBrandLockup(color: ink),
                const SizedBox(height: 24),
                // Tagline.
                Text(
                  'Split it. Settle it. Simple.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: ink.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 32),
                if (!_showRecovery)
                  // Three-dot loader.
                  Semantics(
                    liveRegion: true,
                    label: 'Loading, please wait',
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ink,
                      ),
                    ),
                  )
                else
                  // Recovery option after timeout.
                  Semantics(
                    liveRegion: true,
                    child: Column(
                      children: [
                        Text(
                          'Having trouble?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: ink.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _onRecoveryTap,
                          style: TextButton.styleFrom(foregroundColor: ink),
                          child: Text(
                            'Sign out and start over',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: ink,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
