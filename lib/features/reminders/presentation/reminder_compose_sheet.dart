import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';

/// Pre-filled, editable reminder-compose bottom sheet (Haldi 24 · "Send a
/// reminder"). The user reviews / edits a friendly nudge before sending;
/// the free text is handed back to the caller, which passes it to the
/// `sendReminderNotification` callable as the optional `message` (FR-SE-09).
///
/// This is a notification compose surface only — it never targets a
/// specific messaging app (Invariant 3) and carries no monetary value of
/// its own (the amount is rendered via [formatInrFromPaise]).
class ReminderComposeSheet extends StatefulWidget {
  /// Creates a [ReminderComposeSheet].
  const ReminderComposeSheet({
    required this.recipientName,
    required this.suggestedAmountPaise,
    super.key,
  });

  /// The recipient's display name (the friend who owes the user).
  final String recipientName;

  /// The amount the recipient owes, in integer paise (Invariant 1).
  final int suggestedAmountPaise;

  /// Opens the compose sheet and resolves to the composed message when the
  /// user taps "Send reminder", or `null` if dismissed.
  static Future<String?> show(
    BuildContext context, {
    required String recipientName,
    required int suggestedAmountPaise,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReminderComposeSheet(
        recipientName: recipientName,
        suggestedAmountPaise: suggestedAmountPaise,
      ),
    );
  }

  @override
  State<ReminderComposeSheet> createState() => _ReminderComposeSheetState();
}

class _ReminderComposeSheetState extends State<ReminderComposeSheet> {
  late final TextEditingController _controller;

  String get _firstName {
    final trimmed = widget.recipientName.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text:
          'Hey $_firstName, just a gentle nudge about the '
          '${formatInrFromPaise(widget.suggestedAmountPaise)} '
          'whenever you get a chance. Thanks!',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusSheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Grabber.
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Send a reminder',
                          style: theme.textTheme.headlineMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$_firstName owes you '
                  '${formatInrFromPaise(widget.suggestedAmountPaise)}.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: OBTColors.metaText(theme),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'YOUR MESSAGE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: OBTColors.metaText(theme),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  maxLines: 3,
                  minLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusChipInput,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: OBTColors.metaText(theme),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'You can nudge $_firstName once every 24 hours.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: OBTColors.metaText(theme),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusButton,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.send, size: 19),
                  label: const Text('Send reminder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
