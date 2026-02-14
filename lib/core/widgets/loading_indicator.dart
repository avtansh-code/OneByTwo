import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

/// A centered loading indicator with optional message.
/// 
/// Displays a circular progress indicator with an optional message below it.
/// Used for full-screen loading states.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    this.message,
    super.key,
  });

  /// Optional message to display below the loading indicator
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: AppTypography.bodyDefault(context),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// A small inline loading indicator.
/// 
/// Used for inline loading states within cards or list items.
class InlineLoadingIndicator extends StatelessWidget {
  const InlineLoadingIndicator({
    this.size = 16.0,
    this.strokeWidth = 2.0,
    super.key,
  });

  /// Size of the progress indicator
  final double size;

  /// Width of the progress indicator stroke
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
      ),
    );
  }
}
