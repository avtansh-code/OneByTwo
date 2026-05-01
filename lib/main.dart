import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/app/theme.dart';

void main() {
  runApp(const ProviderScope(child: OneBytwoApp()));
}

/// Root widget for the One By Two application.
class OneBytwoApp extends StatelessWidget {
  /// Creates the root application widget.
  const OneBytwoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneByTwo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const PlaceholderScreen(),
    );
  }
}

/// Temporary placeholder screen for the skeleton PR.
///
/// Replaced by the auth gate in the FR-AU-01 PR.
class PlaceholderScreen extends StatelessWidget {
  /// Creates the placeholder screen.
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'OneByTwo',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
    );
  }
}
