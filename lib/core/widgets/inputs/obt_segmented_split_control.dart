import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

/// Segmented split-method control with live sum validation (foundation
/// plan section 4.2 #5; DC-03 AC-4).
///
/// Renders the method selector — `Equally` / `Unequal` / `%` / `Shares` /
/// `Exact` — with the reserved methods present but disabled ("Coming
/// soon", announced disabled, not wired), plus the live "adds up" /
/// over-under validation summary.
///
/// All split amounts are **integer paise**: the balanced test is the
/// exact integer equality `allocatedPaise == totalPaise` (no float, no
/// `/100`) and every rupee figure is rendered via [formatInrFromPaise]
/// (Invariant 1). When the splits do not sum exactly to the total the
/// red over/under state shows and [onNext] is disabled; when they sum
/// exactly the green "adds up" state shows.
class OBTSegmentedSplitControl extends StatefulWidget {
  /// Creates an [OBTSegmentedSplitControl].
  const OBTSegmentedSplitControl({
    required this.selected,
    required this.enabledMethods,
    required this.onMethodSelected,
    required this.totalPaise,
    required this.allocatedPaise,
    this.onBalancedChanged,
    this.onNext,
    super.key,
  });

  /// The currently selected method.
  final SplitMethod selected;

  /// The methods that are interactive; the rest render disabled
  /// ("Coming soon").
  final Set<SplitMethod> enabledMethods;

  /// Fires with the tapped method.
  final ValueChanged<SplitMethod> onMethodSelected;

  /// The expense total in integer paise.
  final int totalPaise;

  /// The running sum of the host's split rows in integer paise.
  final int allocatedPaise;

  /// Notified when the balanced state (`allocatedPaise == totalPaise`)
  /// changes.
  final ValueChanged<bool>? onBalancedChanged;

  /// Optional Next CTA; enabled only when balanced.
  final VoidCallback? onNext;

  @override
  State<OBTSegmentedSplitControl> createState() =>
      _OBTSegmentedSplitControlState();
}

class _OBTSegmentedSplitControlState extends State<OBTSegmentedSplitControl> {
  static const List<(SplitMethod, String)> _segments = <(SplitMethod, String)>[
    (SplitMethod.equal, 'Equally'),
    (SplitMethod.unequal, 'Unequal'),
    (SplitMethod.percentage, '%'),
    (SplitMethod.shares, 'Shares'),
    (SplitMethod.exact, 'Exact'),
  ];

  bool? _lastBalanced;

  bool get _balanced => widget.allocatedPaise == widget.totalPaise;

  @override
  void initState() {
    super.initState();
    _notifyBalanced();
  }

  @override
  void didUpdateWidget(OBTSegmentedSplitControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _notifyBalanced();
  }

  void _notifyBalanced() {
    final balanced = _balanced;
    if (_lastBalanced == balanced) return;
    _lastBalanced = balanced;
    final callback = widget.onBalancedChanged;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(balanced);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildTrack(theme),
        const SizedBox(height: 16),
        _buildValidationSummary(theme),
        if (widget.onNext != null) ...<Widget>[
          const SizedBox(height: 16),
          _buildNext(theme),
        ],
      ],
    );
  }

  Widget _buildTrack(ThemeData theme) {
    final colors = theme.colorScheme;
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: <Widget>[
            for (final segment in _segments)
              Expanded(
                child: _Segment(
                  method: segment.$1,
                  label: segment.$2,
                  selected: widget.selected == segment.$1,
                  enabled: widget.enabledMethods.contains(segment.$1),
                  obtColors: obtColors,
                  onTap: () => widget.onMethodSelected(segment.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationSummary(ThemeData theme) {
    final colors = theme.colorScheme;
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final diff = (widget.allocatedPaise - widget.totalPaise).abs();
    final over = widget.allocatedPaise > widget.totalPaise;

    final Color signal;
    final IconData icon;
    final String message;
    if (_balanced) {
      signal = obtColors.balancePositive;
      icon = Icons.check_circle_outline;
      message = 'Splits add up';
    } else {
      signal = colors.error;
      icon = Icons.error_outline;
      message = over
          ? 'Over by ${formatInrFromPaise(diff)}'
          : 'Short by ${formatInrFromPaise(diff)}';
    }

    return Semantics(
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: signal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: signal),
            ),
          ),
          Text(
            formatInrFromPaise(widget.allocatedPaise),
            style: OBTText.amount(context).copyWith(color: signal),
          ),
        ],
      ),
    );
  }

  Widget _buildNext(ThemeData theme) {
    return FilledButton(
      onPressed: _balanced ? widget.onNext : null,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        disabledBackgroundColor:
            (theme.extension<OBTColors>() ?? OBTColors.light).disabledFill,
        disabledForegroundColor:
            (theme.extension<OBTColors>() ?? OBTColors.light).disabledText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        ),
      ),
      child: const Text('Next'),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.method,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.obtColors,
    required this.onTap,
  });

  final SplitMethod method;
  final String label;
  final bool selected;
  final bool enabled;
  final OBTColors obtColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final Color labelColor;
    if (!enabled) {
      labelColor = obtColors.disabledText;
    } else if (selected) {
      labelColor = colors.onSurface;
    } else {
      labelColor = colors.onSurfaceVariant;
    }

    final content = AnimatedContainer(
      duration: AppTheme.motionDurationShort,
      curve: AppTheme.motionCurve,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected && enabled ? colors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        boxShadow: selected && enabled ? obtColors.rowShadow : null,
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(color: labelColor),
        ),
      ),
    );

    if (!enabled) {
      return Tooltip(
        message: 'Coming soon',
        child: Semantics(
          button: true,
          enabled: false,
          label: '$label, coming soon',
          excludeSemantics: true,
          child: content,
        ),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: content,
      ),
    );
  }
}
