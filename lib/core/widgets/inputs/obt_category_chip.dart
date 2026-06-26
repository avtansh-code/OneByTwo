import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';

/// Selectable category chip (foundation plan section 4.2 #3; section 1.6).
///
/// A full-hue category icon on a ~10%-opacity hue bed drawn from the
/// Haldi 8-hue palette ([OBTColors.category]). Keyed on [OBTCategory] so
/// the hue resolves with zero hard-coded hex; the host supplies the
/// [icon] and [label] (decoupled from the domain `ExpenseCategory`).
///
/// Colour is never the sole signal — the category [label] is the
/// announced meaning; the hue and icon are reinforcement.
class OBTCategoryChip extends StatelessWidget {
  /// Creates an [OBTCategoryChip].
  const OBTCategoryChip({
    required this.category,
    required this.icon,
    required this.label,
    required this.selected,
    this.onSelected,
    this.enabled = true,
    super.key,
  });

  /// The palette category driving the hue.
  final OBTCategory category;

  /// The category glyph.
  final IconData icon;

  /// The category label (the announced meaning).
  final String label;

  /// Whether this chip is currently selected.
  final bool selected;

  /// Fires with [category] when tapped. When null the chip is display
  /// only.
  final ValueChanged<OBTCategory>? onSelected;

  /// Whether the chip is interactive.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final hue = obtColors.categoryColor(category);
    final isEnabled = enabled && onSelected != null;

    final Color bed;
    final Color iconColor;
    final Color labelColor;
    final Color border;

    if (!isEnabled) {
      bed = obtColors.disabledFill;
      iconColor = obtColors.disabledText;
      labelColor = obtColors.disabledText;
      border = obtColors.disabledFill;
    } else {
      bed = hue.withValues(alpha: 0.10);
      iconColor = hue;
      labelColor = colors.onSurface;
      border = selected ? hue : colors.outline;
    }

    return Semantics(
      button: true,
      selected: selected,
      enabled: isEnabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: bed,
        borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
        child: InkWell(
          onTap: isEnabled ? () => onSelected!(category) : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
              border: Border.all(color: border, width: selected ? 2 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: labelColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Non-interactive category tile — the legend/detail display form of
/// [OBTCategoryChip] (full-hue icon on a 10%-opacity hue bed).
class OBTCategoryTile extends StatelessWidget {
  /// Creates an [OBTCategoryTile].
  const OBTCategoryTile({
    required this.category,
    required this.icon,
    required this.label,
    super.key,
  });

  /// The palette category driving the hue.
  final OBTCategory category;

  /// The category glyph.
  final IconData icon;

  /// The category label.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final hue = obtColors.categoryColor(category);

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: hue),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
