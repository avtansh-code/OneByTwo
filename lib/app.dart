import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/router_provider.dart';

/// Root widget of the OneByTwo app.
///
/// Watches [appRouterProvider] via Riverpod to obtain a [GoRouter] instance
/// configured for the current auth state. The router handles redirecting
/// between the auth flow and the main app.
///
/// When the auth state changes (sign-in / sign-out), the provider creates
/// a new [GoRouter] so that route-level redirects fire automatically.
///
/// Fix: Previously watched [authStateProvider] and called
/// `AppRouter.router()` inline in `build()`, creating a new GoRouter on
/// every widget rebuild (including spurious loading→data transitions).
/// Now the router is managed by [appRouterProvider] which only recreates
/// when the auth state value actually changes.
class OneByTwoApp extends ConsumerWidget {
  /// Creates the [OneByTwoApp].
  const OneByTwoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
