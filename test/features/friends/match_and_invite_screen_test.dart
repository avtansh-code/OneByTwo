// Match-and-invite screen widget tests.
//
// Tests the presentation layer for the matching and invite screen,
// verifying correct rendering for each controller state and that
// user interactions dispatch the correct controller methods.
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is created.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/friends/application/match_and_invite_controller.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';
import 'package:onebytwo/features/friends/presentation/match_and_invite_screen.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Fake controller that allows setting state directly for widget tests.
class FakeMatchAndInviteController extends StateNotifier<MatchAndInviteState>
    implements MatchAndInviteController {
  /// Creates a fake controller with the given initial state.
  FakeMatchAndInviteController(super.initialState);

  /// Whether [performLookup] was called.
  bool performLookupCalled = false;

  /// Whether [addFriend] was called.
  bool addFriendCalled = false;

  /// Whether [openInviteShareSheet] was called.
  bool openInviteShareSheetCalled = false;

  @override
  Future<void> performLookup(dynamic contact) async {
    performLookupCalled = true;
  }

  @override
  Future<void> addFriend() async {
    addFriendCalled = true;
  }

  @override
  Future<void> openInviteShareSheet() async {
    openInviteShareSheetCalled = true;
  }

  /// Sets the state directly for testing.
  // ignore: use_setters_to_change_properties
  void setState(MatchAndInviteState newState) {
    state = newState;
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Wraps the given widget in a [MaterialApp] with [ProviderScope] overrides.
Widget _buildTestApp({required FakeMatchAndInviteController fakeController}) {
  return ProviderScope(
    overrides: [
      matchAndInviteControllerProvider.overrideWith((_) => fakeController),
    ],
    child: const MaterialApp(home: MatchAndInviteScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MatchAndInviteScreen', () {
    testWidgets('Loading state renders a loading indicator', (tester) async {
      final controller = FakeMatchAndInviteController(
        const MatchAndInviteLoading(),
      );

      await tester.pumpWidget(_buildTestApp(fakeController: controller));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('MatchFound state renders confirmation card with '
        'display name and add-friend button', (tester) async {
      final controller = FakeMatchAndInviteController(
        const MatchAndInviteMatchFound(
          displayName: 'Priya Sharma',
          photoUrl: null,
          otherUserId: 'uid-xyz',
        ),
      );

      await tester.pumpWidget(_buildTestApp(fakeController: controller));
      await tester.pump();

      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Add as friend'),
        findsOneWidget,
      );
    });

    testWidgets('MatchFound state renders photo when photoUrl is '
        'provided', (tester) async {
      final controller = FakeMatchAndInviteController(
        const MatchAndInviteMatchFound(
          displayName: 'Priya Sharma',
          photoUrl: 'https://example.com/photo.jpg',
          otherUserId: 'uid-xyz',
        ),
      );

      await tester.pumpWidget(_buildTestApp(fakeController: controller));
      await tester.pump();

      // Verify an image-related widget is present (CircleAvatar or
      // Image.network). The exact widget depends on implementation.
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('NoMatch state renders invite card with contact name '
        'and send-invite button', (tester) async {
      final controller = FakeMatchAndInviteController(
        const MatchAndInviteNoMatch(contactDisplayName: 'Priya Sharma'),
      );

      await tester.pumpWidget(_buildTestApp(fakeController: controller));
      await tester.pump();

      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Send invite'),
        findsOneWidget,
      );
    });

    testWidgets('Error state renders error message with retry button', (
      tester,
    ) async {
      final controller = FakeMatchAndInviteController(
        const MatchAndInviteError(message: 'Something went wrong'),
      );

      await tester.pumpWidget(_buildTestApp(fakeController: controller));
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    });

    testWidgets('RateLimited state renders try-again-later message', (
      tester,
    ) async {
      final controller = FakeMatchAndInviteController(
        const MatchAndInviteRateLimited(),
      );

      await tester.pumpWidget(_buildTestApp(fakeController: controller));
      await tester.pump();

      expect(find.textContaining('try again later'), findsOneWidget);
    });

    testWidgets('SelfAddBlocked state renders cannot-add-yourself message', (
      tester,
    ) async {
      final controller = FakeMatchAndInviteController(
        const MatchAndInviteSelfAddBlocked(),
      );

      await tester.pumpWidget(_buildTestApp(fakeController: controller));
      await tester.pump();

      expect(find.textContaining('cannot add yourself'), findsOneWidget);
    });

    testWidgets('DuplicateFriendship state renders appropriate message', (
      tester,
    ) async {
      final controller = FakeMatchAndInviteController(
        const MatchAndInviteDuplicateFriendship(
          existingFriendshipId: 'uid-aaa_uid-bbb',
        ),
      );

      await tester.pumpWidget(_buildTestApp(fakeController: controller));
      await tester.pump();

      expect(find.textContaining('already friends'), findsOneWidget);
    });

    testWidgets('tapping Add as friend calls controller.addFriend', (
      tester,
    ) async {
      final controller = FakeMatchAndInviteController(
        const MatchAndInviteMatchFound(
          displayName: 'Priya Sharma',
          photoUrl: null,
          otherUserId: 'uid-xyz',
        ),
      );

      await tester.pumpWidget(_buildTestApp(fakeController: controller));
      await tester.pump();

      await tester.tap(find.text('Add as friend'));
      await tester.pump();

      expect(controller.addFriendCalled, isTrue);
    });

    testWidgets('tapping Send invite calls '
        'controller.openInviteShareSheet', (tester) async {
      final controller = FakeMatchAndInviteController(
        const MatchAndInviteNoMatch(contactDisplayName: 'Priya Sharma'),
      );

      await tester.pumpWidget(_buildTestApp(fakeController: controller));
      await tester.pump();

      await tester.tap(find.text('Send invite'));
      await tester.pump();

      expect(controller.openInviteShareSheetCalled, isTrue);
    });

    testWidgets('tapping Retry calls controller.performLookup', (tester) async {
      final controller = FakeMatchAndInviteController(
        const MatchAndInviteError(message: 'Something went wrong'),
      );

      await tester.pumpWidget(_buildTestApp(fakeController: controller));
      await tester.pump();

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(controller.performLookupCalled, isTrue);
    });

    testWidgets(
      'Added state pops the route, shows the confirmation snackbar, and '
      'invalidates the added friend profile cache (D5/D6)',
      (tester) async {
        final controller = FakeMatchAndInviteController(
          const MatchAndInviteMatchFound(
            displayName: 'Priya Sharma',
            photoUrl: null,
            otherUserId: 'uid-xyz',
          ),
        );

        // Counts how many times the added friend's profile is resolved.
        // The screen's `ref.invalidate(userProfileProvider('uid-xyz'))`
        // disposes the cached value; the persistent Home consumer below
        // re-watches it, so a successful invalidation produces a second
        // resolve (D6).
        var profileResolveCount = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              matchAndInviteControllerProvider.overrideWith((_) => controller),
              userProfileProvider('uid-xyz').overrideWith((ref) async {
                profileResolveCount++;
                return null;
              }),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Home'),
                      // Keeps userProfileProvider('uid-xyz') alive so an
                      // invalidate triggers an observable refetch.
                      Consumer(
                        builder: (context, ref, _) {
                          ref.watch(userProfileProvider('uid-xyz'));
                          return const SizedBox.shrink();
                        },
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MatchAndInviteScreen(),
                          ),
                        ),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        // The match-and-invite screen is on top of Home.
        expect(find.text('Add Friend'), findsOneWidget);

        final resolvesBeforeAdd = profileResolveCount;

        // Drive the success transition the screen listens for.
        controller.setState(
          const MatchAndInviteAdded(
            friendshipId: 'uid-aaa_uid-xyz',
            otherUserId: 'uid-xyz',
            displayName: 'Priya Sharma',
          ),
        );
        await tester.pumpAndSettle();

        // D5: the route popped back to Home.
        expect(find.text('Add Friend'), findsNothing);
        expect(find.text('Home'), findsOneWidget);

        // D5: a confirmation snackbar names the new friend.
        expect(find.text('Priya Sharma added as a friend'), findsOneWidget);

        // D6: the added friend's cached profile was invalidated, forcing a
        // fresh resolve so the friends list shows their name immediately.
        expect(profileResolveCount, greaterThan(resolvesBeforeAdd));
      },
    );
  });
}
