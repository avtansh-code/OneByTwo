import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Welcome/Landing screen for the app
/// 
/// This is the first screen users see when launching the app.
/// Shows app branding and a call-to-action to get started.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // App Logo
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 120,
                color: colorScheme.primary,
              ),
              
              const SizedBox(height: 32),
              
              // App Name
              Text(
                'One By Two',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Tagline
              Text(
                'Split expenses. Not friendships.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(),
              
              // Get Started Button
              FilledButton(
                onPressed: () => context.push('/phone-input'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
