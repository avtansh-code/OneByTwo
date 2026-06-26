import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';

/// Generic 3-step bottom-sheet shell (foundation plan section 4.2 #4).
///
/// Renders the grabber, the title + `(N/total)` header with a close
/// affordance, the **visual stepper** indicator (replacing the old
/// `(N/3)` text-only counter), and the active step body in a scroll host
/// with an optional footer. Presentational only — the controller and
/// per-step business logic stay in the feature; the inert "Make
/// recurring" toggle (step 3) lives in the host-supplied step body, not
/// in this shell.
class OBTStepperSheet extends StatelessWidget {
  /// Creates an [OBTStepperSheet].
  const OBTStepperSheet({
    required this.currentStep,
    required this.totalSteps,
    required this.title,
    required this.stepBodies,
    this.onClose,
    this.footer,
    super.key,
  });

  /// The active step, 1-based.
  final int currentStep;

  /// Total number of steps.
  final int totalSteps;

  /// The sheet title.
  final String title;

  /// One widget per step; `stepBodies[currentStep - 1]` is shown.
  final List<Widget> stepBodies;

  /// Optional close callback (the header close button).
  final VoidCallback? onClose;

  /// Optional footer (e.g. Back / Next buttons).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedStep = currentStep.clamp(1, totalSteps);
    final body = stepBodies[clampedStep - 1];

    return Material(
      color: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusSheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _Grabber(),
            _Header(
              title: title,
              currentStep: clampedStep,
              totalSteps: totalSteps,
              onClose: onClose,
            ),
            _StepperIndicator(currentStep: clampedStep, totalSteps: totalSteps),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: body,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outline,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.currentStep,
    required this.totalSteps,
    required this.onClose,
  });

  final String title;
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleLarge),
                Text(
                  'Step $currentStep of $totalSteps',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: OBTColors.metaText(theme),
                  ),
                ),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

class _StepperIndicator extends StatelessWidget {
  const _StepperIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Step $currentStep of $totalSteps',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: <Widget>[
            for (var i = 0; i < totalSteps; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < currentStep
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
