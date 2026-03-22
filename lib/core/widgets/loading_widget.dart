import 'package:flutter/material.dart';

/// Standard full-screen loading indicator with an optional message.
///
/// Centers a [CircularProgressIndicator] vertically and horizontally.
/// If [message] is provided, it is displayed below the spinner.
class LoadingIndicator extends StatelessWidget {
  /// Creates a [LoadingIndicator].
  ///
  /// [message] is an optional description shown below the spinner
  /// (e.g. "Loading expenses…").
  const LoadingIndicator({super.key, this.message});

  /// Optional text displayed beneath the progress indicator.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline loading indicator for small spaces (e.g. inside buttons or chips).
///
/// Renders a compact [CircularProgressIndicator] with configurable
/// [size] and [strokeWidth].
class InlineLoadingIndicator extends StatelessWidget {
  /// Creates an [InlineLoadingIndicator].
  ///
  /// Defaults to a 16 × 16 spinner with a 2 px stroke.
  const InlineLoadingIndicator({
    super.key,
    this.size = 16,
    this.strokeWidth = 2,
  });

  /// Diameter of the circular indicator in logical pixels.
  final double size;

  /// Thickness of the circular indicator stroke.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: strokeWidth),
    );
  }
}
