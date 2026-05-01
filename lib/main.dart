import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/features/auth/presentation/phone_entry_screen.dart';

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
      home: const PhoneEntryScreen(),
    );
  }
}
