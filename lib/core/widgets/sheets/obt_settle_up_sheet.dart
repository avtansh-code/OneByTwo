import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';
import 'package:onebytwo/core/widgets/branding/obt_gradient_avatar.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/core/widgets/inputs/obt_amount_input.dart';

/// Settle-up bottom sheet (foundation plan section 4.2 #6).
///
/// Shows **exactly one** pre-filled suggested payment (recipient +
/// amount) read from the server `simplifiedBalances` projection — it
/// **never** renders a who-paid-whom debt graph and **never** writes the
/// projection (Invariant 2). The focal amount uses
/// [OBTText.amountHero] (issue #128 §B ruling); the editable amount
/// delegates to [OBTAmountInput] keeping the `onChanged(int paise)`
/// contract (Invariant 1).
///
/// The "Pay via UPI" row is **present but inert** — tagged "Coming soon",
/// labelled, announced disabled, and not wired (foundation plan §5). On a
/// successful record the success moment fires a check plus a single
/// [HapticFeedback] pulse.
class OBTSettleUpSheet extends StatefulWidget {
  /// Creates an [OBTSettleUpSheet].
  const OBTSettleUpSheet({
    required this.payerDisplayName,
    required this.payeeDisplayName,
    required this.suggestedAmountPaise,
    required this.onAmountChanged,
    required this.onRecord,
    this.payerPhotoUrl,
    this.payeePhotoUrl,
    this.isLoading = false,
    this.isSaving = false,
    this.isSuccess = false,
    this.onDone,
    this.amountErrorText,
    super.key,
  });

  /// The paying party's display name (typically "You").
  final String payerDisplayName;

  /// The receiving party's display name.
  final String payeeDisplayName;

  /// The single suggested payment amount in integer paise, read from the
  /// projection. Zero/negative renders the settled guard.
  final int suggestedAmountPaise;

  /// Fires with the edited amount in integer paise.
  final ValueChanged<int> onAmountChanged;

  /// Fires when the user records the payment.
  final VoidCallback onRecord;

  /// Optional payer avatar URL.
  final String? payerPhotoUrl;

  /// Optional payee avatar URL.
  final String? payeePhotoUrl;

  /// When true, the suggestion is still resolving — a skeleton shows.
  final bool isLoading;

  /// When true, the record action is in flight (CTA disabled).
  final bool isSaving;

  /// When true, the success moment is shown (check + single haptic).
  final bool isSuccess;

  /// Optional "Done" handler for the success moment. When provided, a
  /// "Done" button dismisses the sheet immediately (the host also keeps a
  /// timed auto-dismiss fallback).
  final VoidCallback? onDone;

  /// Optional inline amount error message.
  final String? amountErrorText;

  @override
  State<OBTSettleUpSheet> createState() => _OBTSettleUpSheetState();
}

class _OBTSettleUpSheetState extends State<OBTSettleUpSheet> {
  bool _hapticFired = false;

  @override
  void initState() {
    super.initState();
    if (widget.isSuccess) _fireSuccessHaptic();
  }

  @override
  void didUpdateWidget(OBTSettleUpSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isSuccess && widget.isSuccess) {
      _fireSuccessHaptic();
    }
  }

  void _fireSuccessHaptic() {
    if (_hapticFired) return;
    _hapticFired = true;
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget body;
    if (widget.isSuccess) {
      body = _buildSuccess(theme);
    } else if (widget.isLoading) {
      body = _buildLoading(theme);
    } else if (widget.suggestedAmountPaise <= 0) {
      body = _buildSettled(theme);
    } else {
      body = _buildEditing(theme);
    }

    return Material(
      color: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusSheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[const _Grabber(), body],
          ),
        ),
      ),
    );
  }

  Widget _buildEditing(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text('Settle up', style: theme.textTheme.headlineMedium),
        ),
        const SizedBox(height: 16),
        _SuggestedPaymentHeader(
          payerDisplayName: widget.payerDisplayName,
          payeeDisplayName: widget.payeeDisplayName,
          payerPhotoUrl: widget.payerPhotoUrl,
          payeePhotoUrl: widget.payeePhotoUrl,
          suggestedAmountPaise: widget.suggestedAmountPaise,
        ),
        const SizedBox(height: 20),
        OBTAmountInput(
          initialAmountPaise: widget.suggestedAmountPaise,
          onChanged: widget.onAmountChanged,
          autoFocus: false,
          errorText: widget.amountErrorText,
        ),
        const SizedBox(height: 16),
        const _UpiComingSoonRow(),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: widget.isSaving ? null : widget.onRecord,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
          ),
          child: Text(widget.isSaving ? 'Recording…' : 'Record payment'),
        ),
      ],
    );
  }

  Widget _buildSettled(ThemeData theme) {
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle, size: 48, color: obtColors.balanceZero),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text('Settled up', style: theme.textTheme.headlineMedium),
          ),
          const SizedBox(height: 4),
          Text(
            'Nothing to pay ${widget.payeeDisplayName}.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: OBTColors.metaText(theme),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Semantics(
        liveRegion: true,
        label: 'Loading…',
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            OBTSkeletonCircle(diameter: 48),
            SizedBox(height: 16),
            OBTSkeleton(width: 160, height: 40),
            SizedBox(height: 16),
            OBTSkeleton(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Cream check disc — the brand "high five" moment.
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: obtColors.balancePositive.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 60,
              color: obtColors.balancePositive,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              "You're all settled up — high five!",
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Recorded '
            '${formatInrFromPaise(widget.suggestedAmountPaise)} '
            'paid to ${widget.payeeDisplayName}.',
            style: OBTText.rupeeAware(
              theme,
              theme.textTheme.bodyMedium?.copyWith(
                color: OBTColors.metaText(theme),
              ),
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.onDone != null) ...<Widget>[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.onDone,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                ),
              ),
              child: const Text('Done'),
            ),
          ],
        ],
      ),
    );
  }
}

/// The "Suggested from simplified debts" provenance pill shown above the
/// settle-up amount — a tonal marigold chip that reinforces the
/// single-suggestion contract (Invariant 2).
class _SuggestedFromDebtsPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.auto_awesome, size: 16, color: obtColors.link),
            const SizedBox(width: 6),
            Text(
              'Suggested from simplified debts',
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.labelMedium?.copyWith(
                color: obtColors.link,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedPaymentHeader extends StatelessWidget {
  const _SuggestedPaymentHeader({
    required this.payerDisplayName,
    required this.payeeDisplayName,
    required this.payerPhotoUrl,
    required this.payeePhotoUrl,
    required this.suggestedAmountPaise,
  });

  final String payerDisplayName;
  final String payeeDisplayName;
  final String? payerPhotoUrl;
  final String? payeePhotoUrl;
  final int suggestedAmountPaise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _Avatar(name: payerDisplayName, photoUrl: payerPhotoUrl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.arrow_forward,
                color: theme.colorScheme.primary,
              ),
            ),
            _Avatar(name: payeeDisplayName, photoUrl: payeePhotoUrl),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '$payerDisplayName pay $payeeDisplayName',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: OBTColors.metaText(theme),
          ),
        ),
        const SizedBox(height: 10),
        // The single-suggestion provenance pill (Invariant 2: one
        // pre-filled simplified payment, never a debt graph).
        _SuggestedFromDebtsPill(),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatInrFromPaise(suggestedAmountPaise),
            style: OBTText.amountHero(context),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    // The Haldi 54 dp rounded-square gradient avatar (reused brand widget).
    return OBTGradientAvatar(size: 54, displayName: name, photoUrl: photoUrl);
  }
}

class _UpiComingSoonRow extends StatelessWidget {
  const _UpiComingSoonRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    return Semantics(
      enabled: false,
      label: 'Pay via UPI. Coming soon.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: obtColors.disabledFill,
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 20,
              color: obtColors.disabledText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pay via UPI',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: obtColors.disabledText,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                'Coming soon',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: obtColors.disabledText,
                ),
              ),
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
