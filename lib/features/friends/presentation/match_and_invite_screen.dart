import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';
import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/features/friends/application/match_and_invite_controller.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';

/// Screen that displays the match-and-invite flow after a contact has been
/// selected from the device picker (SCR-10 / Haldi 10), rebuilt for the
/// Haldi visual system (DC-06).
///
/// The bare `Center(Text())` guard states (rate-limited, self-add,
/// duplicate) become Haldi-styled guard panels; the looking-up spinner
/// becomes a shimmer skeleton; the match-found path is a confirm-add card;
/// and the no-match path is an `OBTEmptyState` invite that hands off to the
/// **OS system share sheet only** (`controller.openInviteShareSheet` ->
/// `ShareServiceBase.share`), never an app-specific target (Invariant 3,
/// SRS sections 3.4, 4.11, 12.2).
class MatchAndInviteScreen extends ConsumerWidget {
  /// Creates a [MatchAndInviteScreen].
  const MatchAndInviteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchAndInviteControllerProvider);
    final controller = ref.read(matchAndInviteControllerProvider.notifier);

    ref.listen<MatchAndInviteState>(matchAndInviteControllerProvider, (
      previous,
      next,
    ) {
      if (next is MatchAndInviteAdded) {
        // D6: refresh the just-added friend's cached profile so the friends
        // list resolves their display name immediately (no relaunch).
        ref.invalidate(userProfileProvider(next.otherUserId));
        // D5: confirm the add and return to the previous screen (the friends
        // list / caller), where the new friend now appears.
        final messenger = ScaffoldMessenger.of(context);
        final name = next.displayName;
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(content: Text('$name added as a friend')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Add Friend')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: switch (state) {
            MatchAndInviteInitial() => const SizedBox.shrink(),
            MatchAndInviteLoading(:final phoneNumber) => _LookingUpState(
              phoneNumber: phoneNumber,
            ),
            MatchAndInviteMatchFound(:final displayName, :final photoUrl) =>
              _MatchFoundCard(
                displayName: displayName,
                photoUrl: photoUrl,
                onAddFriend: controller.addFriend,
              ),
            MatchAndInviteAdded() => const Center(
              child: CircularProgressIndicator(),
            ),
            MatchAndInviteNoMatch(:final contactDisplayName) => _NoMatchInvite(
              contactDisplayName: contactDisplayName,
              onSendInvite: controller.openInviteShareSheet,
            ),
            MatchAndInviteError(:final message) => _ErrorCard(
              message: message,
              onRetry: () => controller.performLookup(null),
            ),
            MatchAndInviteRateLimited() => const _GuardState(
              icon: Icons.timer_outlined,
              title: 'Too many attempts',
              body: 'Please try again later.',
            ),
            MatchAndInviteSelfAddBlocked() => const _GuardState(
              icon: Icons.person_outline,
              title: "That's you!",
              body: 'You cannot add yourself as a friend.',
            ),
            MatchAndInviteDuplicateFriendship() => const _GuardState(
              icon: Icons.how_to_reg_outlined,
              title: "You're already friends",
              body: 'You and this person are already connected on One By Two.',
            ),
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

/// The looking-up state (Haldi 10a): the disabled mobile-number input the
/// lookup was launched from, a "Looking up this number…" line with a
/// rotating `sync` icon, then a shimmer result-card skeleton (no spinner).
/// The spin freezes under Reduce Motion.
class _LookingUpState extends StatefulWidget {
  const _LookingUpState({required this.phoneNumber});

  /// The number being looked up (E.164 or local); shown in the input row.
  final String phoneNumber;

  @override
  State<_LookingUpState> createState() => _LookingUpStateState();
}

class _LookingUpStateState extends State<_LookingUpState>
    with SingleTickerProviderStateMixin {
  AnimationController? _spin;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect Reduce Motion: only animate the sync icon when animations
    // are enabled, mirroring the skeleton's reduced-motion contract.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!reduceMotion && _spin == null) {
      _spin = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      )..repeat();
    } else if (reduceMotion) {
      _spin?.stop();
    }
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  /// Strips the country digits and groups the 10-digit local number as
  /// "98765 43210" for display.
  String _localNumber(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    if (digits.length == 10) {
      return '${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return digits;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final meta = OBTColors.metaText(theme);
    final syncIcon = Icon(Icons.sync, size: 18, color: meta);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Overline label — the input the lookup was launched from.
        Text(
          'BY MOBILE NUMBER',
          style: theme.textTheme.labelSmall?.copyWith(
            color: meta,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        // Disabled number input + disabled "Add" (the lookup is in flight).
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
                  border: Border.all(color: colors.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: <Widget>[
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        border: Border(
                          right: BorderSide(color: colors.outline),
                        ),
                      ),
                      child: Text('+91', style: theme.textTheme.titleMedium),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _localNumber(widget.phoneNumber),
                        style: OBTText.amount(context).copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            ExcludeSemantics(
              child: Container(
                width: 60,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: obtColors.disabledFill,
                  borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
                ),
                child: Text(
                  'Add',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: obtColors.disabledText,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 34),
        // "Looking up this number…" with a rotating sync icon.
        Semantics(
          liveRegion: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_spin != null)
                RotationTransition(turns: _spin!, child: syncIcon)
              else
                syncIcon,
              const SizedBox(width: 8),
              Text(
                'Looking up this number…',
                style: theme.textTheme.bodyMedium?.copyWith(color: meta),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Shimmer result-card skeleton (no spinner).
        DecoratedBox(
          key: const Key('match_lookup_skeleton'),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: obtColors.rowShadow,
            border: theme.brightness == Brightness.dark
                ? Border.all(color: colors.outline)
                : null,
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: OBTSkeletonRow(
              spec: OBTSkeletonRowSpec(leadingDiameter: 48),
              announce: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchFoundCard extends StatelessWidget {
  const _MatchFoundCard({
    required this.displayName,
    required this.photoUrl,
    required this.onAddFriend,
  });

  final String displayName;
  final String? photoUrl;
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: obtColors.balancePositive,
                ),
                const SizedBox(width: 8),
                Text(
                  'We found them on One By Two',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: obtColors.balancePositive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 40,
              backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
              onBackgroundImageError: hasPhoto
                  ? (Object _, StackTrace? __) {
                      // Silently fall back; the initial is the placeholder.
                    }
                  : null,
              child: hasPhoto ? null : Text(initial),
            ),
            const SizedBox(height: 16),
            Text(displayName, style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAddFriend,
              child: const Text('Add as friend'),
            ),
          ],
        ),
      ),
    );
  }
}

/// No-match invite: an [OBTEmptyState] whose CTA hands the one-time invite
/// to the OS system share sheet (Invariant 3 — never an app-specific
/// target). [onSendInvite] is `controller.openInviteShareSheet`.
class _NoMatchInvite extends StatelessWidget {
  const _NoMatchInvite({
    required this.contactDisplayName,
    required this.onSendInvite,
  });

  final String contactDisplayName;
  final VoidCallback onSendInvite;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OBTEmptyState(
      illustration: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person_add_alt_1, size: 52, color: colors.primary),
      ),
      headline: 'Not on One By Two yet',
      supportingText:
          "$contactDisplayName isn't on One By Two yet. Send a one-time "
          'invite link to get them started.',
      ctaLabel: 'Invite to One By Two',
      onCta: onSendInvite,
    );
  }
}

/// A Haldi-styled guard panel for the rate-limited / self-add /
/// duplicate-friendship states (replacing the bare `Center(Text())`).
class _GuardState extends StatelessWidget {
  const _GuardState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: colors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: OBTColors.metaText(theme),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
