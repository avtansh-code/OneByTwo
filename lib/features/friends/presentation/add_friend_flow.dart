import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/match_and_invite_controller.dart';
import 'package:onebytwo/features/friends/data/friendship_repository.dart';
import 'package:onebytwo/features/friends/data/matching_repository.dart';
import 'package:onebytwo/features/friends/data/share_service.dart';
import 'package:onebytwo/features/friends/domain/selected_contact.dart';
import 'package:onebytwo/features/friends/presentation/add_friend_screen.dart';
import 'package:onebytwo/features/friends/presentation/match_and_invite_screen.dart';

/// Drives the reachable add-friend journey (FR-FR-01 / FR-FR-02,
/// SCR-10).
///
/// Presents [AddFriendScreen]; when the user selects a contact or types
/// a number, that screen pops a [SelectedContact]. This helper then
/// pushes [MatchAndInviteScreen] with a scoped
/// [matchAndInviteControllerProvider] override wired to the live
/// repositories and the authenticated user's identity, and kicks off
/// the phone lookup.
///
/// This seam is the single place that turns a selected contact into a
/// friendship. Without it the match-and-invite screen is unreachable
/// and no friendship is ever created — the defect recorded as audit S6.
///
/// [currentUserId] and [currentUserPhone] come from the authenticated
/// user (`currentUserIdProvider` / `currentUserPhoneProvider`). The
/// phone is E.164 (`+91...`) and is used by the controller to block
/// self-adds. They are passed by value (read before any navigation) so
/// the flow survives the caller's widget being torn down across the
/// `await` — e.g. when the Add-Expense context picker dismisses itself
/// before opening the flow.
Future<void> openAddFriendFlow({
  required BuildContext context,
  required String currentUserId,
  required String currentUserPhone,
}) async {
  final navigator = Navigator.of(context);

  final selected = await navigator.push<SelectedContact?>(
    MaterialPageRoute<SelectedContact?>(
      builder: (_) => const AddFriendScreen(),
    ),
  );

  // The user backed out of the add-friend screen without choosing a
  // contact — nothing to look up.
  if (selected == null) return;

  await navigator.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ProviderScope(
        overrides: [
          matchAndInviteControllerProvider.overrideWith((ref) {
            final controller = MatchAndInviteController(
              matchingRepository: ref.watch(matchingRepositoryProvider),
              friendshipRepository: ref.watch(friendshipRepositoryProvider),
              currentUserPhone: currentUserPhone,
              currentUserId: currentUserId,
              analyticsService: ref.watch(analyticsServiceProvider),
              shareService: ref.watch(shareServiceProvider),
            );
            // Kick off the phone lookup as soon as the screen mounts so
            // the user lands on a result (match / no-match) state.
            unawaited(controller.performLookup(selected));
            return controller;
          }),
        ],
        child: const MatchAndInviteScreen(),
      ),
    ),
  );
}
