// ignore_for_file: avoid_dynamic_calls, omit_local_variable_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/data/matching_repository.dart';
import 'package:onebytwo/features/friends/domain/selected_contact.dart';

// ---------------------------------------------------------------------------
// State hierarchy
// ---------------------------------------------------------------------------

/// State for the match-and-invite flow.
sealed class MatchAndInviteState {
  /// Creates a [MatchAndInviteState].
  const MatchAndInviteState();
}

/// Initial state before any lookup has been performed.
class MatchAndInviteInitial extends MatchAndInviteState {
  /// Creates a [MatchAndInviteInitial].
  const MatchAndInviteInitial();
}

/// A phone lookup is in progress.
class MatchAndInviteLoading extends MatchAndInviteState {
  /// Creates a [MatchAndInviteLoading].
  const MatchAndInviteLoading();
}

/// A registered user was found matching the phone number.
class MatchAndInviteMatchFound extends MatchAndInviteState {
  /// Creates a [MatchAndInviteMatchFound].
  const MatchAndInviteMatchFound({
    required this.displayName,
    required this.photoUrl,
    required this.otherUserId,
  });

  /// The matched user's display name.
  final String displayName;

  /// The matched user's photo URL, if available.
  final String? photoUrl;

  /// The matched user's UID.
  final String otherUserId;
}

/// No registered user matched the phone number.
class MatchAndInviteNoMatch extends MatchAndInviteState {
  /// Creates a [MatchAndInviteNoMatch].
  const MatchAndInviteNoMatch({required this.contactDisplayName});

  /// The contact's display name from the device picker.
  final String contactDisplayName;
}

/// An error occurred during the flow.
class MatchAndInviteError extends MatchAndInviteState {
  /// Creates a [MatchAndInviteError].
  const MatchAndInviteError({required this.message});

  /// A user-facing error message.
  final String message;
}

/// The user has been rate-limited.
class MatchAndInviteRateLimited extends MatchAndInviteState {
  /// Creates a [MatchAndInviteRateLimited].
  const MatchAndInviteRateLimited();
}

/// The user attempted to add themselves as a friend.
class MatchAndInviteSelfAddBlocked extends MatchAndInviteState {
  /// Creates a [MatchAndInviteSelfAddBlocked].
  const MatchAndInviteSelfAddBlocked();
}

/// A friendship already exists between the two users.
class MatchAndInviteDuplicateFriendship extends MatchAndInviteState {
  /// Creates a [MatchAndInviteDuplicateFriendship].
  const MatchAndInviteDuplicateFriendship({required this.existingFriendshipId});

  /// The ID of the existing friendship.
  final String existingFriendshipId;
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Controls the match-and-invite flow after a contact has been selected.
///
/// Manages phone lookup, self-add blocking, duplicate detection,
/// friendship creation, and invite sharing.
class MatchAndInviteController extends StateNotifier<MatchAndInviteState> {
  /// Creates a [MatchAndInviteController].
  MatchAndInviteController({
    required dynamic matchingRepository,
    required dynamic friendshipRepository,
    required String currentUserPhone,
    required String currentUserId,
    required AnalyticsService analyticsService,
    required dynamic shareService,
  }) : _matchingRepository = matchingRepository,
       _friendshipRepository = friendshipRepository,
       _currentUserPhone = currentUserPhone,
       _currentUserId = currentUserId,
       _analyticsService = analyticsService,
       _shareService = shareService,
       super(const MatchAndInviteInitial());

  final dynamic _matchingRepository;
  final dynamic _friendshipRepository;
  final String _currentUserPhone;
  final String _currentUserId;
  final AnalyticsService _analyticsService;
  final dynamic _shareService;

  /// The last contact used for lookup, retained for retry.
  SelectedContact? _lastContact;

  /// Looks up the selected contact's phone number.
  ///
  /// Accepts [dynamic] to allow retry calls from the UI without
  /// requiring a fresh [SelectedContact]. When called with a
  /// [SelectedContact], it is stored for subsequent retries. When
  /// called with any other value, the previously stored contact is
  /// reused.
  Future<void> performLookup(dynamic contact) async {
    if (contact is SelectedContact) {
      _lastContact = contact;
    }
    final resolvedContact = _lastContact;
    if (resolvedContact == null) return;

    // Self-add blocking: check before calling the Cloud Function.
    if (resolvedContact.phoneNumbers.any((p) => p == _currentUserPhone)) {
      state = const MatchAndInviteSelfAddBlocked();
      await _analyticsService.logEvent(name: 'friend_add_blocked_self');
      return;
    }

    state = const MatchAndInviteLoading();

    final MatchResult result =
        await _matchingRepository.lookupUser(resolvedContact.phoneNumbers.first)
            as MatchResult;

    switch (result) {
      case Matched(:final displayName, :final photoUrl, :final otherUserId):
        // Check for duplicate friendship.
        final exists =
            await _friendshipRepository.friendshipExists(
                  _currentUserId,
                  otherUserId,
                )
                as bool;
        if (exists) {
          final sorted = [_currentUserId, otherUserId]..sort();
          final friendshipId = '${sorted[0]}_${sorted[1]}';
          state = MatchAndInviteDuplicateFriendship(
            existingFriendshipId: friendshipId,
          );
          await _analyticsService.logEvent(
            name: 'friend_add_blocked_duplicate',
          );
        } else {
          state = MatchAndInviteMatchFound(
            displayName: displayName,
            photoUrl: photoUrl,
            otherUserId: otherUserId,
          );
          await _analyticsService.logEvent(name: 'friend_lookup_matched');
        }

      case Unmatched():
        state = MatchAndInviteNoMatch(
          contactDisplayName: resolvedContact.displayName,
        );
        await _analyticsService.logEvent(name: 'friend_lookup_unmatched');

      case Failed():
        state = const MatchAndInviteError(message: 'Something went wrong');
        await _analyticsService.logEvent(name: 'friend_lookup_failed');

      case RateLimited():
        state = const MatchAndInviteRateLimited();
        await _analyticsService.logEvent(name: 'friend_lookup_rate_limited');
    }
  }

  /// Adds the matched user as a friend.
  ///
  /// Only operates when the current state is [MatchAndInviteMatchFound].
  Future<void> addFriend() async {
    final currentState = state;
    if (currentState is! MatchAndInviteMatchFound) return;

    try {
      await _friendshipRepository.createFriendship(
        _currentUserId,
        currentState.otherUserId,
      );
      await _analyticsService.logEvent(name: 'friend_added');
    } on Exception {
      state = const MatchAndInviteError(message: 'Something went wrong');
    }
  }

  /// Opens the system share sheet with an invite message.
  ///
  /// Only operates when the current state is [MatchAndInviteNoMatch].
  Future<void> openInviteShareSheet() async {
    final currentState = state;
    if (currentState is! MatchAndInviteNoMatch) return;

    const inviteText =
        'Hey! I use One By Two to split expenses. '
        'Download it and we can settle up easily!';

    await _shareService.share(inviteText);
    await _analyticsService.logEvent(name: 'friend_invite_share_sheet_opened');
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provides the [MatchAndInviteController] and its state.
///
/// Must be overridden in the widget tree with `currentUserPhone` and
/// `currentUserId` values from the authenticated user.
final matchAndInviteControllerProvider =
    StateNotifierProvider<MatchAndInviteController, MatchAndInviteState>((ref) {
      throw UnimplementedError(
        'matchAndInviteControllerProvider must be overridden with '
        'currentUserPhone and currentUserId.',
      );
    });
