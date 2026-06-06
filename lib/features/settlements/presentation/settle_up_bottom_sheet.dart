import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/core/widgets/inputs/obt_amount_input.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/application/settle_up_controller.dart';
import 'package:onebytwo/features/settlements/application/settle_up_state.dart';
import 'package:onebytwo/features/settlements/application/settle_up_telemetry.dart';
import 'package:onebytwo/features/settlements/presentation/widgets/settle_up_header.dart';

/// Root host for the Settle Up bottom sheet (SCR-23 / FR-SE-05).
///
/// Reads the [settleUpControllerProvider] keyed by a [SettleUpArgs]
/// tuple. The body renders the header → amount input → date picker →
/// optional note → Record Settlement button.
///
/// On `SettleUpSuccess` the sheet auto-dismisses via [Navigator.pop]
/// and shows a "Settlement recorded." snackbar. On `SettleUpError` it
/// stays open and shows an error snackbar with the typed message.
///
/// Telemetry single-fire discipline (Architect Notes §2.7):
/// `settle_up_screen_viewed` fires exactly once on first paint of the
/// body via a post-frame callback, gated by `_loggedView`.
class SettleUpBottomSheet extends ConsumerStatefulWidget {
  /// Creates a [SettleUpBottomSheet].
  const SettleUpBottomSheet({
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    required this.otherDisplayName,
    required this.suggestedAmountPaise,
    this.currentUserPhotoUrl,
    this.otherUserPhotoUrl,
    super.key,
  });

  /// Friendship document ID (`uid-a_uid-b`).
  final String friendshipId;

  /// Authenticated user UID.
  final String currentUserUid;

  /// Friend UID.
  final String otherUserUid;

  /// Friend display name (for the header).
  final String otherDisplayName;

  /// Pre-fill amount in paise.
  final int suggestedAmountPaise;

  /// Optional current user avatar URL.
  final String? currentUserPhotoUrl;

  /// Optional friend avatar URL.
  final String? otherUserPhotoUrl;

  @override
  ConsumerState<SettleUpBottomSheet> createState() =>
      _SettleUpBottomSheetState();
}

class _SettleUpBottomSheetState extends ConsumerState<SettleUpBottomSheet> {
  bool _loggedView = false;

  SettleUpArgs get _args => SettleUpArgs(
    friendshipId: widget.friendshipId,
    currentUserUid: widget.currentUserUid,
    otherUserUid: widget.otherUserUid,
    otherDisplayName: widget.otherDisplayName,
    suggestedAmountPaise: widget.suggestedAmountPaise,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _logViewedOnce());
  }

  void _logViewedOnce() {
    if (_loggedView) return;
    _loggedView = true;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: SettleUpTelemetry.screenViewed,
            parameters: <String, Object>{
              SettleUpTelemetry.paramContextType: 'friendship',
              SettleUpTelemetry.paramSource: 'friend_detail',
              SettleUpTelemetry.paramFriendshipIdHash: hashFriendshipId(
                widget.friendshipId,
              ),
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SettleUpState>(
      settleUpControllerProvider(_args),
      _onStateChanged,
    );

    final state = ref.watch(settleUpControllerProvider(_args));

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SettleUpState state) {
    // Guard against the Saving → Success transition: the listener in
    // _onStateChanged pops the sheet on the same frame, but without
    // this short-circuit the body would render once with a fall-back
    // date / empty note (cosmetic only, but avoidable). Per code-review
    // §R2 — keep the divergent render out of the build tree entirely.
    if (state is SettleUpSuccess) {
      return const _SuccessPlaceholder();
    }

    final draft = switch (state) {
      SettleUpEditing(:final draft) => draft,
      SettleUpSaving(:final draft) => draft,
      SettleUpError(:final draft) => draft,
      SettleUpSuccess() => null,
    };

    final validationErrors = switch (state) {
      SettleUpEditing(:final validationErrors) => validationErrors,
      _ => const <String, String>{},
    };

    final isSaving = state is SettleUpSaving;
    final isSaveEnabled = switch (state) {
      SettleUpEditing(:final isSaveEnabled) => isSaveEnabled,
      SettleUpError() => true,
      _ => false,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        _SheetTitle(onDismiss: () => _onDismiss(context)),
        SettleUpHeader(
          payerDisplayName: 'You',
          payerPhotoUrl: widget.currentUserPhotoUrl,
          payeeDisplayName: widget.otherDisplayName,
          payeePhotoUrl: widget.otherUserPhotoUrl,
          suggestedAmountPaise: widget.suggestedAmountPaise,
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AmountField(
                  initialPaise: widget.suggestedAmountPaise,
                  errorText: validationErrors['amount'],
                  enabled: !isSaving,
                  onChanged: (paise) => ref
                      .read(settleUpControllerProvider(_args).notifier)
                      .setAmount(paise),
                ),
                const SizedBox(height: 16),
                _DateField(
                  date: draft?.date ?? DateTime.now(),
                  enabled: !isSaving,
                  onPicked: (picked) => ref
                      .read(settleUpControllerProvider(_args).notifier)
                      .setDate(picked),
                ),
                const SizedBox(height: 16),
                _NoteField(
                  initialNote: draft?.note,
                  errorText: validationErrors['note'],
                  enabled: !isSaving,
                  onChanged: (note) => ref
                      .read(settleUpControllerProvider(_args).notifier)
                      .setNote(note.isEmpty ? null : note),
                ),
                const SizedBox(height: 24),
                _RecordButton(
                  enabled: isSaveEnabled && !isSaving,
                  saving: isSaving,
                  onPressed: () => ref
                      .read(settleUpControllerProvider(_args).notifier)
                      .save(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onStateChanged(SettleUpState? previous, SettleUpState next) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    if (next is SettleUpSuccess && previous is! SettleUpSuccess) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Settlement recorded.')),
      );
      Navigator.of(context).maybePop();
    } else if (next is SettleUpError && previous is! SettleUpError) {
      messenger.showSnackBar(SnackBar(content: Text(next.message)));
    }
  }

  void _onDismiss(BuildContext context) {
    Navigator.of(context).maybePop();
  }
}

// ---------------------------------------------------------------------------
// Sheet chrome
// ---------------------------------------------------------------------------

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Settle Up',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, semanticLabel: 'Close'),
            tooltip: 'Close',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body fields
// ---------------------------------------------------------------------------

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.initialPaise,
    required this.onChanged,
    required this.enabled,
    this.errorText,
  });

  final int initialPaise;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return OBTAmountInput(
      initialAmountPaise: initialPaise,
      onChanged: onChanged,
      autoFocus: false,
      enabled: enabled,
      errorText: errorText,
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.enabled,
    required this.onPicked,
  });

  final DateTime date;
  final bool enabled;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd();
    return InkWell(
      onTap: enabled
          ? () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) onPicked(picked);
            }
          : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          enabled: enabled,
        ),
        child: Text(fmt.format(date), style: theme.textTheme.bodyLarge),
      ),
    );
  }
}

class _NoteField extends StatefulWidget {
  /// Optional note field for the Settle Up bottom sheet.
  ///
  /// The 200-character cap is enforced at TWO layers
  /// (defence-in-depth per code-review §R3):
  ///
  /// 1. `TextField.maxLength: 200` blocks input past 200 chars in the
  ///    UI immediately.
  /// 2. `SettleUpDraft.validate()` blocks Save at the model layer
  ///    with the user-facing message "Note must be 200 characters or
  ///    fewer.".
  ///
  /// Both layers are intentional. Removing either would weaken the
  /// guard (the UI cap prevents the validator ever firing in normal
  /// use; the validator catches any path that bypasses the UI cap,
  /// such as a future programmatic note injection).
  const _NoteField({
    required this.initialNote,
    required this.onChanged,
    required this.enabled,
    this.errorText,
  });

  final String? initialNote;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? errorText;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void didUpdateWidget(covariant _NoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reconcile the controller text when the parent rebuilds with a
    // different initialNote. Today the only mutation path is this
    // widget's own onChanged so the controller is already in sync,
    // but FR-SE-09 (Send Reminder) or any future PR that seeds a
    // default note from outside will need this guard. Per code-review
    // §R1 — close the latent footgun now.
    final newNote = widget.initialNote ?? '';
    if (newNote != oldWidget.initialNote && newNote != _controller.text) {
      _controller.value = TextEditingValue(
        text: newNote,
        selection: TextSelection.collapsed(offset: newNote.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      maxLength: 200,
      maxLines: 2,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: 'Note (optional)',
        hintText: 'e.g. UPI payment, cash',
        errorText: widget.errorText,
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.enabled,
    required this.saving,
    required this.onPressed,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      child: saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Record Settlement'),
    );
  }
}

/// Minimal placeholder rendered while the listener pops the sheet on
/// the Saving → Success transition. The listener fires
/// `Navigator.of(context).maybePop()` on the same frame as the state
/// emit, so the placeholder is only visible for at most one paint;
/// using it avoids the cosmetic "draft reset" frame that the full body
/// switch would otherwise produce (per code-review §R2).
///
/// A static `SizedBox` (rather than a spinner) is intentional: a
/// `CircularProgressIndicator` would tick forever and trap
/// `pumpAndSettle` in widget tests. The placeholder never animates,
/// so the test driver can settle reliably and the user only ever sees
/// an empty pane for one frame before `maybePop()` closes the sheet.
class _SuccessPlaceholder extends StatelessWidget {
  const _SuccessPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 120);
  }
}
