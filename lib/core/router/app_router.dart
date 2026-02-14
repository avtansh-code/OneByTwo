import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../presentation/features/auth/screens/otp_verification_screen.dart';
import '../../presentation/features/auth/screens/phone_input_screen.dart';
import '../../presentation/features/auth/screens/welcome_screen.dart';
import '../../presentation/providers/auth_providers.dart';

part 'app_router.g.dart';

/// Router configuration provider
@riverpod
GoRouter appRouter(AppRouterRef ref) {
  // Watch auth state for redirects
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
    redirect: (context, state) {
      // Check if we're on an auth screen
      final isOnAuthScreen = state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/phone-input' ||
          state.matchedLocation == '/otp-verification';

      // Get auth status - handle loading state
      final isAuthenticated = authState.asData?.value != null;

      // If user is not authenticated and not on auth screen, redirect to welcome
      if (!isAuthenticated && !isOnAuthScreen) {
        return '/welcome';
      }

      // If user is authenticated and on auth screen, redirect to home
      if (isAuthenticated && isOnAuthScreen) {
        return '/';
      }

      // No redirect needed
      return null;
    },
    routes: [
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
      
      // Main app routes
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const _PlaceholderScreen(title: 'Home'),
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );
}

/// Placeholder screen for initial setup
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});
  
  final String title;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.construction,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'OneByTwo',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Split expenses. Not friendships.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Architecture scaffolding complete ✓',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
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
