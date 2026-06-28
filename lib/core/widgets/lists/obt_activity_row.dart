import 'package:flutter/material.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';
import 'package:onebytwo/features/activity/domain/activity_event_type.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';

/// SCR-25 component 14 — a single row in the activity feed.
///
/// Displays a leading coloured icon (per the SCR-25 Event Type Mapping
/// table), a primary text line, a relative-timestamp secondary line,
/// and an optional trailing amount formatted via `formatInrFromPaise`.
///
/// The widget consumes the typed [ActivityFeedItem] plus the current
/// user's UID (for the settlement directional copy — "You settled up
/// with X" vs "X settled up with you") and the resolved other-party
/// display name. Derivation lives inside the widget per architect
/// §2.6.
///
/// Tap handling is delegated to [onTap]; the parent screen owns the
/// telemetry and deep-link navigation contract (FR-AC-02).
///
/// **Invariant compliance.**
/// - Invariant 1 (paise): every amount goes through
///   `formatInrFromPaise`. The boundary-contract grep at
///   `test/features/activity/activity_boundary_contract_test.dart`
///   enforces.
class OBTActivityRow extends StatelessWidget {
  /// Creates an [OBTActivityRow].
  const OBTActivityRow({
    required this.item,
    required this.currentUserUid,
    required this.otherPartyDisplayName,
    required this.onTap,
    required this.secondaryText,
    super.key,
  });

  /// The activity-feed item to render.
  final ActivityFeedItem item;

  /// The signed-in user's UID. Used to disambiguate settlement
  /// directional copy.
  final String currentUserUid;

  /// The other-party display name (resolved via `userProfileProvider`).
  /// Used in the primary text for expense rows (e.g. "Priya added
  /// 'Dinner'") and for settlement rows.
  final String otherPartyDisplayName;

  /// The relative-timestamp string (e.g. "2 hours ago"). The parent
  /// computes this from `formatRelativeTimestamp` so the widget stays
  /// timezone-agnostic.
  final String secondaryText;

  /// Tap handler. Invoked when the row is activated.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colour = _colourFor(item.type, theme);
    final icon = _iconFor(item.type);
    final primary = _primaryText();
    final amountPaise = _amountPaise();
    final semanticLabel = _semanticLabel(primary, amountPaise);

    // #128 §C2: colour is reserved for BALANCE signals, so the trailing
    // amount renders in neutral ink for expense events; only a settlement
    // keeps the green success hue. The leading event icon keeps its per-event
    // colour (below) unchanged.
    final amountColour = item.type == ActivityEventType.settlementRecorded
        ? scheme.tertiary
        : scheme.onSurface;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: colour.withValues(alpha: 0.12),
                    child: Icon(icon, color: colour, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primary,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        secondaryText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: OBTColors.metaText(theme),
                        ),
                      ),
                    ],
                  ),
                ),
                if (amountPaise != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatInrFromPaise(amountPaise),
                        style: OBTText.amount(
                          context,
                        ).copyWith(color: amountColour),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ActivityEventType type) {
    switch (type) {
      case ActivityEventType.expenseAdded:
        return Icons.receipt_long;
      case ActivityEventType.expenseEdited:
        return Icons.edit;
      case ActivityEventType.expenseDeleted:
        return Icons.delete;
      case ActivityEventType.settlementRecorded:
        return Icons.check_circle;
    }
  }

  Color _colourFor(ActivityEventType type, ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (type) {
      case ActivityEventType.expenseAdded:
        return scheme.primary;
      case ActivityEventType.expenseEdited:
        return scheme.secondary;
      case ActivityEventType.expenseDeleted:
        return scheme.error;
      case ActivityEventType.settlementRecorded:
        // Use the tertiary slot for "success" since the design tokens
        // do not map a dedicated `success` colour to colorScheme. The
        // green semantic is preserved by the OBT theme's tertiary
        // mapping.
        return scheme.tertiary;
    }
  }

  String _primaryText() {
    final authorUid = item.payload['authorUid'] as String? ?? '';
    final description = item.payload['description'] as String? ?? '';

    switch (item.type) {
      case ActivityEventType.expenseAdded:
        final actor = authorUid == currentUserUid
            ? 'You'
            : otherPartyDisplayName;
        return "$actor added '$description'";
      case ActivityEventType.expenseEdited:
        final actor = authorUid == currentUserUid
            ? 'You'
            : otherPartyDisplayName;
        return "$actor edited '$description'";
      case ActivityEventType.expenseDeleted:
        final actor = authorUid == currentUserUid
            ? 'You'
            : otherPartyDisplayName;
        return "$actor deleted '$description'";
      case ActivityEventType.settlementRecorded:
        final fromUserId = item.payload['fromUserId'] as String? ?? '';
        if (fromUserId == currentUserUid) {
          return 'You settled up with $otherPartyDisplayName';
        }
        return '$otherPartyDisplayName settled up with you';
    }
  }

  int? _amountPaise() {
    final raw = item.payload['amountPaise'];
    if (raw is int) return raw;
    return null;
  }

  String _semanticLabel(String primary, int? amountPaise) {
    final parts = <String>[primary, secondaryText];
    if (amountPaise != null) {
      parts.add(formatInrFromPaise(amountPaise));
    }
    parts.add('Tap to view details.');
    return parts.join('. ');
  }
}
