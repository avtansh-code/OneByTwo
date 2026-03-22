import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/features/auth/screens/welcome_screen.dart';
import '../../presentation/features/home/screens/home_screen.dart';
import 'route_names.dart';
import 'route_paths.dart';

/// App router configuration with GoRouter.
///
/// Implements auth-based redirect: unauthenticated users are sent to the
/// welcome screen; authenticated users are sent to the home screen.
///
/// Most screens use placeholder widgets until they are implemented in
/// later sprints.
abstract final class AppRouter {
  /// Creates and returns the [GoRouter] instance.
  ///
  /// [isAuthenticated] controls the initial redirect behaviour.
  static GoRouter router({required bool isAuthenticated}) {
    return GoRouter(
      initialLocation: isAuthenticated ? RoutePaths.home : RoutePaths.welcome,
      debugLogDiagnostics: true,
      redirect: (BuildContext context, GoRouterState state) {
        final isAtAuth = state.matchedLocation.startsWith('/welcome');

        if (!isAuthenticated && !isAtAuth) {
          return RoutePaths.welcome;
        }
        if (isAuthenticated && isAtAuth) {
          return RoutePaths.home;
        }
        return null;
      },
      routes: [
        // ── Auth flow ──────────────────────────────────────────────
        GoRoute(
          path: RoutePaths.welcome,
          name: RouteNames.welcome,
          builder: (context, state) => const WelcomeScreen(),
          routes: [
            GoRoute(
              path: RoutePaths.phoneInput,
              name: RouteNames.phoneInput,
              builder: (context, state) =>
                  const _PlaceholderScreen(title: 'Phone Input'),
              routes: [
                GoRoute(
                  path: RoutePaths.otpVerification,
                  name: RouteNames.otpVerification,
                  builder: (context, state) =>
                      const _PlaceholderScreen(title: 'OTP Verification'),
                ),
              ],
            ),
            GoRoute(
              path: RoutePaths.profileSetup,
              name: RouteNames.profileSetup,
              builder: (context, state) =>
                  const _PlaceholderScreen(title: 'Profile Setup'),
            ),
          ],
        ),

        // ── Splash ─────────────────────────────────────────────────
        GoRoute(
          path: RoutePaths.splash,
          name: RouteNames.splash,
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Splash'),
        ),

        // ── Home (main shell) ──────────────────────────────────────
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (context, state) => const HomeScreen(),
        ),

        // ── Groups ─────────────────────────────────────────────────
        GoRoute(
          path: RoutePaths.createGroup,
          name: RouteNames.createGroup,
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Create Group'),
        ),
        GoRoute(
          path: RoutePaths.groupDetail,
          name: RouteNames.groupDetail,
          builder: (context, state) {
            final groupId = state.pathParameters['groupId']!;
            return _PlaceholderScreen(title: 'Group Detail', subtitle: groupId);
          },
          routes: [
            GoRoute(
              path: 'settings',
              name: RouteNames.groupSettings,
              builder: (context, state) {
                final groupId = state.pathParameters['groupId']!;
                return _PlaceholderScreen(
                  title: 'Group Settings',
                  subtitle: groupId,
                );
              },
            ),
          ],
        ),

        // ── Expenses ───────────────────────────────────────────────
        GoRoute(
          path: RoutePaths.addExpense,
          name: RouteNames.addExpense,
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Add Expense'),
        ),
        GoRoute(
          path: RoutePaths.expenseDetail,
          name: RouteNames.expenseDetail,
          builder: (context, state) {
            final expenseId = state.pathParameters['expenseId']!;
            return _PlaceholderScreen(
              title: 'Expense Detail',
              subtitle: expenseId,
            );
          },
        ),

        // ── Friends ────────────────────────────────────────────────
        GoRoute(
          path: RoutePaths.addFriend,
          name: RouteNames.addFriend,
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Add Friend'),
        ),
        GoRoute(
          path: RoutePaths.friendDetail,
          name: RouteNames.friendDetail,
          builder: (context, state) {
            final friendId = state.pathParameters['friendId']!;
            return _PlaceholderScreen(
              title: 'Friend Detail',
              subtitle: friendId,
            );
          },
        ),

        // ── Settle Up ─────────────────────────────────────────────
        GoRoute(
          path: RoutePaths.settleUp,
          name: RouteNames.settleUp,
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Settle Up'),
        ),

        // ── Activity ───────────────────────────────────────────────
        GoRoute(
          path: RoutePaths.activityFeed,
          name: RouteNames.activityFeed,
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Activity Feed'),
        ),

        // ── Analytics ──────────────────────────────────────────────
        GoRoute(
          path: RoutePaths.analytics,
          name: RouteNames.analytics,
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Analytics'),
        ),

        // ── Search ─────────────────────────────────────────────────
        GoRoute(
          path: RoutePaths.search,
          name: RouteNames.search,
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Search'),
        ),

        // ── Notifications ──────────────────────────────────────────
        GoRoute(
          path: RoutePaths.notifications,
          name: RouteNames.notifications,
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Notifications'),
        ),

        // ── Settings ───────────────────────────────────────────────
        GoRoute(
          path: RoutePaths.settings,
          name: RouteNames.settings,
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Settings'),
        ),
        GoRoute(
          path: RoutePaths.profileEdit,
          name: RouteNames.profileEdit,
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Edit Profile'),
        ),
      ],
    );
  }
}

/// Temporary placeholder screen used for routes not yet implemented.
///
/// Displays the screen [title] and optional [subtitle] in the centre.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, this.subtitle});

  /// Display name for this placeholder.
  final String title;

  /// Optional secondary text (e.g., an entity ID).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            Text(
              'Coming soon',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
