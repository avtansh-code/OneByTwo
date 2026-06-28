import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';

/// FR-SH-04 no-mail-client fallback dialog for the Contact Support flow.
///
/// Shown when `canLaunchUrl(mailto:)` is false (no mail client
/// configured). Displays the support address as selectable text with a
/// "Copy Address" action that writes it to the clipboard and confirms
/// with a snackbar. Implements wireframe section 4b
/// (`docs/design/04-wireframes/profile-and-support.md`).
class ContactSupportFallbackDialog extends StatelessWidget {
  /// Creates a [ContactSupportFallbackDialog] for [supportEmailAddress].
  const ContactSupportFallbackDialog({
    required this.supportEmailAddress,
    super.key,
  });

  /// The support address to display and copy.
  final String supportEmailAddress;

  /// Snackbar copy shown after a successful clipboard write.
  static const String copiedConfirmation = 'Email address copied';

  /// Shows the fallback dialog. Returns when the dialog is dismissed
  /// (Close, "Copy Address", scrim tap, or back gesture).
  static Future<void> show(
    BuildContext context, {
    required String supportEmailAddress,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ContactSupportFallbackDialog(
        supportEmailAddress: supportEmailAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final link = obtColors.link;
    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusCard)),
      ),
      semanticLabel: 'Alert: No mail app found',
      icon: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: obtColors.warning.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mail_outline,
          size: 26,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Semantics(header: true, child: const Text('No mail app found')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "We couldn't open a mail app on your device. Copy our support "
            'address and reach us anytime:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Support email address: $supportEmailAddress',
            child: SelectableText(
              supportEmailAddress,
              style: theme.textTheme.bodyLarge?.copyWith(color: link),
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () => _copyAddress(context),
          child: const Text('Copy email'),
        ),
      ],
    );
  }

  Future<void> _copyAddress(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await Clipboard.setData(ClipboardData(text: supportEmailAddress));
    navigator.pop();
    // The wireframe specifies a 4000 ms snackbar, which is also the
    // framework default duration, so it is left implicit here.
    messenger.showSnackBar(const SnackBar(content: Text(copiedConfirmation)));
  }
}
