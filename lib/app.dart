import 'package:flutter/material.dart';

import 'core/l10n/generated/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget of the OneByTwo app.
///
/// Sets up [MaterialApp.router] with GoRouter, Material 3 theming,
/// and localization delegates. Authentication state is currently
/// hardcoded to `false`; it will be wired to an auth provider in a
/// later sprint.
class OneByTwoApp extends StatelessWidget {
  /// Creates the [OneByTwoApp].
  const OneByTwoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(sprint-1): Read isAuthenticated from an auth Riverpod provider.
    const isAuthenticated = false;

    return MaterialApp.router(
      title: 'One By Two',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: AppRouter.router(isAuthenticated: isAuthenticated),
      debugShowCheckedModeBanner: false,
    );
  }
}
