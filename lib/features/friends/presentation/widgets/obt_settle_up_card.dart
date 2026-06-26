import 'dart:async';

import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';

/// Settle Up CTA card (FR-SE-07 / SCR-23 / design-system §13) — with
/// the FR-SE-09 receiving-direction variant.
///
/// Renders a payer-avatar → arrow → payee-avatar row with a centred
/// suggested amount and a Settle Up / Send Reminder call-to-action.
///
/// **Settling-direction** (default; [isReceivingDirection] == false):
/// the authenticated user owes the friend; the CTA reads "Settle Up"
/// and fires [onSettleUp].
///
/// **Receiving-direction** (FR-SE-09; [isReceivingDirection] == true):
/// the friend owes the authenticated user; the CTA reads "Send
/// Reminder" and fires [onSendReminder]. When [nextAllowedAt] is in
/// the future, the button is disabled and a live countdown caption
/// is shown ("Next reminder in 23h 59m").
///
/// Hosts:
/// - Friend Detail screen — both directional branches.
/// - Home Dashboard (FR-HD-02 — deferred; planned future use site).
/// - Group Detail (FR-GR-04 — deferred; planned future use site).
///
/// Architectural placement (FR-SE-09 Architect Notes §2.7): the
/// widget lives under `lib/features/friends/presentation/widgets/`
/// — extraction to `lib/core/widgets/cards/` remains DEFERRED until
/// a second host needs it (precedent: `OBTAmountInput` in PR #38).
///
/// Invariant compliance:
/// - **Invariant 1 (paise)**: [suggestedAmountPaise] is `int`; display
///   uses `formatInrFromPaise()`. No inline `/100` math.
/// - **Invariant 2 (`simplifiedBalances` read-only)**: this widget is
///   presentational and never touches Firestore.
class OBTSettleUpCard extends StatefulWidget {
  /// Creates an [OBTSettleUpCard].
  const OBTSettleUpCard({
    required this.payerDisplayName,
    required this.payerPhotoUrl,
    required this.payeeDisplayName,
    required this.payeePhotoUrl,
    required this.suggestedAmountPaise,
    required this.onSettleUp,
    this.isReceivingDirection = false,
    this.onSendReminder,
    this.nextAllowedAt,
    super.key,
  });

  /// Display name of the payer (the user who pays the settlement).
  final String payerDisplayName;

  /// Avatar URL of the payer (nullable).
  final String? payerPhotoUrl;

  /// Display name of the payee (the user who receives the settlement).
  final String payeeDisplayName;

  /// Avatar URL of the payee (nullable).
  final String? payeePhotoUrl;

  /// The simplified-debts suggestion amount in paise.
  final int suggestedAmountPaise;

  /// Fires when the user taps the Settle Up CTA. The host is
  /// responsible for opening the Settle Up bottom sheet (or
  /// equivalent) and for firing the `settle_up_tapped` telemetry
  /// event. Ignored on the receiving-direction branch.
  final VoidCallback onSettleUp;

  /// When true, the card renders in the receiving-direction variant
  /// (FR-SE-09): CTA reads "Send Reminder"; tapping fires
  /// [onSendReminder] (which MUST be provided when this is true).
  final bool isReceivingDirection;

  /// Fires when the user taps the Send Reminder CTA on the
  /// receiving-direction variant. Required when
  /// [isReceivingDirection] is true.
  final VoidCallback? onSendReminder;

  /// Server-returned earliest time at which the next reminder may be
  /// sent. When in the future, the receiving-direction button is
  /// disabled with a live countdown caption. Ignored on the
  /// settling-direction branch.
  final DateTime? nextAllowedAt;

  @override
  State<OBTSettleUpCard> createState() => _OBTSettleUpCardState();
}

class _OBTSettleUpCardState extends State<OBTSettleUpCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _maybeStartTick();
  }

  @override
  void didUpdateWidget(covariant OBTSettleUpCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextAllowedAt != widget.nextAllowedAt) {
      _tick?.cancel();
      _tick = null;
      _maybeStartTick();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _maybeStartTick() {
    final next = widget.nextAllowedAt;
    if (!widget.isReceivingDirection || next == null) return;
    if (next.isBefore(DateTime.now())) return;
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  bool get _isReminderCooling {
    if (!widget.isReceivingDirection) return false;
    final next = widget.nextAllowedAt;
    if (next == null) return false;
    return next.isAfter(DateTime.now());
  }

  String _cooldownCaption() {
    final next = widget.nextAllowedAt!;
    final remaining = next.difference(DateTime.now());
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    if (h > 0) return 'Next reminder in ${h}h ${m}m';
    if (m > 0) return 'Next reminder in ${m}m';
    return 'Next reminder shortly';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReceiving = widget.isReceivingDirection;
    final cooling = _isReminderCooling;
    final ctaLabel = isReceiving ? 'Send Reminder' : 'Settle Up';
    final ctaIcon = isReceiving
        ? Icons.notifications_active_outlined
        : Icons.handshake_outlined;
    final VoidCallback? ctaOnPressed;
    if (isReceiving) {
      ctaOnPressed = cooling ? null : widget.onSendReminder;
    } else {
      ctaOnPressed = widget.onSettleUp;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AvatarLabel(
                  displayName: widget.payerDisplayName,
                  photoUrl: widget.payerPhotoUrl,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    color: theme.colorScheme.primary,
                    semanticLabel: isReceiving ? 'owes' : 'pays',
                  ),
                ),
                _AvatarLabel(
                  displayName: widget.payeeDisplayName,
                  photoUrl: widget.payeePhotoUrl,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatInrFromPaise(widget.suggestedAmountPaise),
              style: OBTText.amount(context),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: ctaOnPressed,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                  ),
                ),
                icon: Icon(ctaIcon),
                label: Text(ctaLabel),
              ),
            ),
            if (cooling) ...[
              const SizedBox(height: 8),
              Text(
                _cooldownCaption(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: OBTColors.metaText(theme),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarLabel extends StatelessWidget {
  const _AvatarLabel({required this.displayName, required this.photoUrl});

  final String displayName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.surface,
          backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
              ? NetworkImage(photoUrl!)
              : null,
          child: (photoUrl == null || photoUrl!.isEmpty)
              ? Text(_initials(displayName), style: theme.textTheme.titleSmall)
              : null,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
