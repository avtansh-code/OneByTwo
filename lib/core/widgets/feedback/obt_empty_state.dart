import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';

/// Shared empty-state scaffold (foundation plan section 4.2 #7).
///
/// A flat-illustration holder, a headline, an optional supporting line,
/// and a single call to action. Consolidates the ad-hoc `Icon` + text
/// empties across the app and hosts the brand flat illustrations.
///
/// The CTA is the canonical ink-on-marigold affordance: a [FilledButton]
/// filled [ColorScheme.primary] with an **ink** [ColorScheme.onPrimary]
/// label (never white — the DC-01 contrast rule). The illustration is
/// decorative ([ExcludeSemantics]); the CTA carries its own label.
class OBTEmptyState extends StatelessWidget {
  /// Creates an [OBTEmptyState].
  const OBTEmptyState({
    required this.illustration,
    required this.headline,
    this.supportingText,
    this.ctaLabel,
    this.onCta,
    super.key,
  });

  /// The flat illustration shown above the headline (brand art or icon).
  final Widget illustration;

  /// The primary headline copy.
  final String headline;

  /// Optional secondary supporting line.
  final String? supportingText;

  /// Optional CTA label; when null (or [onCta] is null) no button shows.
  final String? ctaLabel;

  /// Optional CTA callback.
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCta = ctaLabel != null && onCta != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(child: illustration),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                headline,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            if (supportingText != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                supportingText!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: OBTColors.metaText(theme),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (showCta) ...<Widget>[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onCta,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                  ),
                ),
                child: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
