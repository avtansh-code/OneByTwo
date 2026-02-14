import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../presentation/features/auth/screens/otp_verification_screen.dart';
import '../../presentation/features/auth/screens/phone_input_screen.dart';
import '../../presentation/features/auth/screens/splash_screen.dart';
import '../../presentation/features/auth/screens/welcome_screen.dart';
import '../../presentation/features/home/screens/activity_screen.dart';
import '../../presentation/features/home/screens/home_screen.dart';
import '../../presentation/features/home/widgets/main_shell.dart';
import '../../presentation/features/profile/screens/profile_screen.dart';
import '../../presentation/features/profile/screens/settings_screen.dart';
import '../../presentation/providers/auth_providers.dart';

part 'app_router.g.dart';

/// Router configuration provider
@riverpod
GoRouter appRouter(AppRouterRef ref) {
  // Watch auth state for redirects
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/home',
    redirect: (context, state) {
      final location = state.uri.path;
      
      // Public routes that don't need auth
      final isOnAuthScreen = location == '/welcome' ||
          location == '/phone-input' ||
          location == '/otp-verification';
      
      // Protected routes that require auth
      final isOnProtectedRoute = location.startsWith('/home') ||
          location.startsWith('/activity') ||
          location.startsWith('/profile') ||
          location.startsWith('/settings');

      // Handle loading state - show splash
      if (authState.isLoading) {
        return '/splash';
      }

      // Get auth status
      final isAuthenticated = authState.asData?.value != null;

      // If not authenticated and trying to access protected route
      if (!isAuthenticated && isOnProtectedRoute) {
        return '/welcome';
      }

      // If authenticated and on auth screen, redirect to home
      if (isAuthenticated && isOnAuthScreen) {
        return '/home';
      }

      // If on splash and auth state is loaded, redirect appropriately
      if (location == '/splash' && !authState.isLoading) {
        return isAuthenticated ? '/home' : '/welcome';
      }

      // No redirect needed
      return null;
    },
    routes: [
      // Splash screen
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Auth routes
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/phone-input',
        name: 'phone-input',
        builder: (context, state) => const PhoneInputScreen(),
      ),
      GoRoute(
        path: '/otp-verification',
        name: 'otp-verification',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final verificationId = extra?['verificationId'] as String? ?? '';
          final phoneNumber = extra?['phoneNumber'] as String? ?? '';
          
          return OtpVerificationScreen(
            verificationId: verificationId,
            phoneNumber: phoneNumber,
          );
        },
      ),
      
      // Main app routes with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/activity',
            name: 'activity',
            builder: (context, state) => const ActivityScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      
      // Settings route (not in bottom nav shell)
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );
}

/// Error screen for routing errors
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error});
  
  final Exception? error;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Navigation Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
