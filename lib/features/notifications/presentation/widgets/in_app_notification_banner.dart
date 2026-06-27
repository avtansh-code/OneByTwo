import 'dart:async';

import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';

/// Foreground in-app notification banner (FR-AC-03, wireframes §2).
///
/// Visuals:
///   - Surface-coloured card, 16dp corner radius, 4dp elevation.
///   - 32dp category icon (receipt / tick-circle / bell tinted by type).
///   - Title + body text columns.
///   - Min 64dp height (satisfies 48dp tap target per AC-20).
///
/// Behaviour:
///   - Slides down from top with 300ms ease-in-out on appear.
///   - Auto-dismisses after 4 seconds.
///   - Tap → invokes [onTap] with the payload.
///   - Swipe up → invokes [onDismiss].
///   - Auto-dismiss timer pauses if the screen reader is active
///     (`MediaQuery.accessibleNavigation`) per wireframes §2.4.
class InAppNotificationBanner extends StatefulWidget {
  /// Creates an [InAppNotificationBanner].
  const InAppNotificationBanner({
    required this.payload,
    required this.onTap,
    required this.onDismiss,
    super.key,
  });

  /// The parsed FCM payload to render.
  final NotificationPayload payload;

  /// Invoked when the user taps the banner. The host is responsible
  /// for hiding the overlay and dispatching to the deep-link handler.
  final void Function(NotificationPayload payload) onTap;

  /// Invoked when the user swipes the banner up OR the 4-second
  /// auto-dismiss timer fires. The host should remove the OverlayEntry.
  final VoidCallback onDismiss;

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  Timer? _autoDismissTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
        );
    _animController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleAutoDismiss();
  }

  void _scheduleAutoDismiss() {
    _autoDismissTimer?.cancel();
    final accessibleNav = MediaQuery.of(context).accessibleNavigation;
    if (accessibleNav) {
      // Screen reader active — do NOT auto-dismiss; the user needs
      // unbounded time to hear the announcement.
      return;
    }
    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      if (!_dismissed && mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _autoDismissTimer?.cancel();
    widget.onDismiss();
  }

  void _onTap() {
    if (_dismissed) return;
    _dismissed = true;
    _autoDismissTimer?.cancel();
    widget.onTap(widget.payload);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final isDark = theme.brightness == Brightness.dark;
    final iconData = _iconForType(widget.payload.type);
    final iconColor = _iconColorForType(widget.payload.type, theme, obtColors);
    final semanticLabel =
        '${widget.payload.title}. ${widget.payload.body}. '
        'Tap to view details. Swipe up to dismiss.';

    return Semantics(
      label: semanticLabel,
      liveRegion: true,
      button: true,
      child: SlideTransition(
        position: _slideAnim,
        child: Dismissible(
          key: ValueKey(widget.payload.itemId ?? widget.payload.contextId),
          direction: DismissDirection.up,
          onDismissed: (_) => _dismiss(),
          child: GestureDetector(
            onTap: _onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              constraints: const BoxConstraints(minHeight: 64),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                boxShadow: obtColors.rowShadow,
                border: isDark
                    ? Border.all(color: theme.colorScheme.outline)
                    : null,
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(iconData, size: 32, color: iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.payload.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.payload.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: OBTColors.metaText(theme),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.expenseAdded:
      case NotificationType.expenseEdited:
      case NotificationType.expenseDeleted:
        return Icons.receipt_long;
      case NotificationType.settlementReceived:
        return Icons.check_circle;
      case NotificationType.reminder:
      case NotificationType.groupInvite:
        return Icons.notifications_active;
    }
  }

  Color _iconColorForType(
    NotificationType type,
    ThemeData theme,
    OBTColors obtColors,
  ) {
    switch (type) {
      case NotificationType.expenseAdded:
      case NotificationType.expenseEdited:
      case NotificationType.expenseDeleted:
        return theme.colorScheme.primary;
      case NotificationType.settlementReceived:
        // Haldi success/positive token (DC-09 re-point of the old #2A9D8F):
        // the settlement-received event reuses the balance-positive hue,
        // matching the OBTSettleUpSheet success check.
        return obtColors.balancePositive;
      case NotificationType.reminder:
        // Haldi caution token (DC-09 re-point of the old #F4A261): a reminder
        // is a nudge/cooldown, so it takes the saffron warning hue.
        return obtColors.warning;
      case NotificationType.groupInvite:
        return theme.colorScheme.primary;
    }
  }
}
