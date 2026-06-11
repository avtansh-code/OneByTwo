// AuthenticatedShell widget tests — the IndexedStack host for the 5
// primary tabs (Home / Friends / Groups / Activity / Profile).
//
// The tests use the @visibleForTesting `tabContentOverride` parameter
// to inject lightweight stub widgets in place of the real tab content
// (FriendsListScreen, ActivityFeedScreen, ProfileScreen) so each test
// asserts the SHELL contract without entangling with each tab feature's
// provider graph. The home + groups placeholders are simple enough
// that the shell mounts them directly in the production tab list.
//
// Covers:
//   - AC-1   shell renders tab 0 (Home) on initial mount
//   - AC-2-5 tapping each tab swaps the visible content
//   - AC-6   IndexedStack preserves state across tab switches
//   - AC-7   bottom nav is a BottomNavigationBar with 5 items
//   - AC-11  Android back-button on non-zero tab snaps to tab 0
//   - AC-12  Android back-button on tab 0 lets the system pop
//   - AC-13  push-over-shell pattern (a child route covers the bottom nav)
//   - AC-15  telemetry payload contains only tab_index + tab_label
//            (no UID-derived parameters)
//   - AC-18  shell Scaffold has appBar: null

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/widgets/nav/obt_bottom_nav.dart';
import 'package:onebytwo/core/widgets/nav/obt_floating_action_button.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/shell/application/shell_telemetry.dart';
import 'package:onebytwo/features/shell/presentation/authenticated_shell.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> events =
      <({String name, Map<String, Object>? parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }
}

/// A tab-content stub that mounts a Scaffold with a unique title so the
/// test can assert which tab is currently visible.
class _TabStub extends StatefulWidget {
  const _TabStub({required this.label, super.key});
  final String label;

  @override
  State<_TabStub> createState() => _TabStubState();
}

class _TabStubState extends State<_TabStub> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tab: ${widget.label}')),
      body: Center(child: Text('content of ${widget.label}')),
    );
  }
}

List<Widget> _stubTabs() {
  return const <Widget>[
    _TabStub(key: ValueKey('tab-0'), label: 'home'),
    _TabStub(key: ValueKey('tab-1'), label: 'friends'),
    _TabStub(key: ValueKey('tab-2'), label: 'groups'),
    _TabStub(key: ValueKey('tab-3'), label: 'activity'),
    _TabStub(key: ValueKey('tab-4'), label: 'profile'),
  ];
}

Widget _buildShell({
  _FakeAnalyticsService? analytics,
  List<Widget>? tabContentOverride,
}) {
  final fakeAnalytics = analytics ?? _FakeAnalyticsService();
  return ProviderScope(
    overrides: <Override>[
      analyticsServiceProvider.overrideWithValue(fakeAnalytics),
    ],
    child: MaterialApp(
      home: AuthenticatedShell(tabContentOverride: tabContentOverride),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AuthenticatedShell — initial mount (AC-1, AC-18)', () {
    testWidgets('renders Home tab content with bottom nav visible', (
      tester,
    ) async {
      await tester.pumpWidget(_buildShell(tabContentOverride: _stubTabs()));
      await tester.pump();

      // Home stub is visible.
      expect(find.text('content of home'), findsOneWidget);
      // OBTBottomNav is mounted in the bottomNavigationBar slot.
      expect(find.byType(OBTBottomNav), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('shell Scaffold has appBar: null (AC-18)', (tester) async {
      await tester.pumpWidget(_buildShell(tabContentOverride: _stubTabs()));
      await tester.pump();

      // The shell wraps tab content in its OWN Scaffold (no AppBar).
      // Find the Scaffold that is a direct descendant of AuthenticatedShell
      // (its build returns the shell Scaffold; the stubs each carry their
      // own inner Scaffold).
      final shellScaffold = tester.widget<Scaffold>(
        find
            .ancestor(
              of: find.byType(IndexedStack),
              matching: find.byType(Scaffold),
            )
            .first,
      );
      expect(shellScaffold.appBar, isNull);
    });
  });

  group('AuthenticatedShell — tab switching (AC-2..AC-5)', () {
    testWidgets('tapping each tab swaps the visible content', (tester) async {
      await tester.pumpWidget(_buildShell(tabContentOverride: _stubTabs()));
      await tester.pump();

      Future<void> tapAndAssert(String label, String expectedContent) async {
        await tester.tap(find.text(label));
        await tester.pump();
        // IndexedStack keeps every child mounted but only paints the
        // active one — assert visibility via the IndexedStack.index.
        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.children.length, 5);
        expect(stack.index, isNotNull);
        // The bottom nav's currentIndex must match the stack index.
        final nav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(nav.currentIndex, stack.index);
        // The active child's content text is rendered.
        expect(find.text(expectedContent), findsOneWidget);
      }

      await tapAndAssert('Friends', 'content of friends');
      await tapAndAssert('Groups', 'content of groups');
      await tapAndAssert('Activity', 'content of activity');
      await tapAndAssert('Profile', 'content of profile');
      await tapAndAssert('Home', 'content of home');
    });
  });

  group('AuthenticatedShell — IndexedStack state preservation (AC-6)', () {
    testWidgets('inactive tabs retain their State instances across switches', (
      tester,
    ) async {
      await tester.pumpWidget(_buildShell(tabContentOverride: _stubTabs()));
      await tester.pump();

      // IndexedStack wraps inactive children in Visibility.maintain
      // (Offstage internally) so finders must pass skipOffstage: false
      // to reach the inactive Friends tab from the active Home tab.
      final friendsBeforeFinder = find.byKey(
        const ValueKey('tab-1'),
        skipOffstage: false,
      );
      final friendsStateBefore = tester.state<_TabStubState>(
        friendsBeforeFinder,
      );
      final identityBefore = identityHashCode(friendsStateBefore);

      // Switch to Profile.
      await tester.tap(find.text('Profile'));
      await tester.pump();

      // Switch back to Friends.
      await tester.tap(find.text('Friends'));
      await tester.pump();

      // Same State instance — IndexedStack did not dispose it.
      final friendsAfter = tester.state<_TabStubState>(
        find.byKey(const ValueKey('tab-1'), skipOffstage: false),
      );
      expect(identityHashCode(friendsAfter), identityBefore);
    });
  });

  group('AuthenticatedShell — telemetry (AC-2..AC-5, AC-15)', () {
    testWidgets(
      'tapping a tab fires bottom_nav_tab_selected with index + label',
      (tester) async {
        final analytics = _FakeAnalyticsService();
        await tester.pumpWidget(
          _buildShell(analytics: analytics, tabContentOverride: _stubTabs()),
        );
        await tester.pump();

        await tester.tap(find.text('Friends'));
        await tester.pump();

        expect(analytics.events, hasLength(1));
        final event = analytics.events.single;
        expect(event.name, bottomNavTabSelectedEvent);
        expect(event.parameters, isNotNull);
        expect(event.parameters![tabIndexParam], 1);
        expect(event.parameters![tabLabelParam], 'friends');
      },
    );

    testWidgets('every tab tap produces the correct {index, label} pair', (
      tester,
    ) async {
      final analytics = _FakeAnalyticsService();
      await tester.pumpWidget(
        _buildShell(analytics: analytics, tabContentOverride: _stubTabs()),
      );
      await tester.pump();

      const expected = <(int, String)>[
        (1, 'friends'),
        (2, 'groups'),
        (3, 'activity'),
        (4, 'profile'),
        (0, 'home'),
      ];
      for (final pair in expected) {
        final label = OBTBottomNav.tabs[pair.$1].label;
        await tester.tap(find.text(label));
        await tester.pump();
      }

      expect(analytics.events, hasLength(expected.length));
      for (var i = 0; i < expected.length; i++) {
        final got = analytics.events[i];
        expect(got.name, bottomNavTabSelectedEvent);
        expect(got.parameters![tabIndexParam], expected[i].$1);
        expect(got.parameters![tabLabelParam], expected[i].$2);
      }
    });

    testWidgets(
      'telemetry payload contains ONLY tab_index and tab_label (PII guard)',
      (tester) async {
        final analytics = _FakeAnalyticsService();
        await tester.pumpWidget(
          _buildShell(analytics: analytics, tabContentOverride: _stubTabs()),
        );
        await tester.pump();

        await tester.tap(find.text('Profile'));
        await tester.pump();

        final params = analytics.events.single.parameters!;
        // Exactly the two whitelisted keys — no userId, no uid, no
        // friendship_id, no friendship_id_hash.
        expect(params.keys.toSet(), <String>{tabIndexParam, tabLabelParam});
        const forbidden = <String>[
          'userId',
          'uid',
          'friendship_id',
          'friendship_id_hash',
        ];
        for (final key in forbidden) {
          expect(
            params.containsKey(key),
            isFalse,
            reason:
                'PII guard (ADR-0013): telemetry payload must not carry $key',
          );
        }
      },
    );
  });

  group('AuthenticatedShell — PopScope back-button (AC-11, AC-12)', () {
    testWidgets(
      'back-button on non-zero tab snaps to tab 0 without firing telemetry',
      (tester) async {
        final analytics = _FakeAnalyticsService();
        await tester.pumpWidget(
          _buildShell(analytics: analytics, tabContentOverride: _stubTabs()),
        );
        await tester.pump();

        // Move to Activity (index 3).
        await tester.tap(find.text('Activity'));
        await tester.pump();
        var stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, 3);

        // Capture telemetry count before the back invocation so we can
        // assert it does NOT grow due to the back-driven switch.
        final eventCountBefore = analytics.events.length;

        // Invoke the system back button. The shell's PopScope intercepts.
        final didPop = await tester.binding
            .handlePopRoute(); // returns true if a handler consumed
        expect(didPop, isTrue, reason: 'PopScope must consume the pop');
        await tester.pump();

        // We are now back on tab 0 (Home).
        stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, 0);
        final nav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(nav.currentIndex, 0);

        // No new telemetry event for the back-driven switch.
        expect(analytics.events.length, eventCountBefore);
      },
    );

    testWidgets('back-button on tab 0 lets the system pop (canPop: true)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildShell(tabContentOverride: _stubTabs()));
      await tester.pump();

      // Tab 0 is already active on mount. canPop is true => the system
      // handles the back gesture (i.e. would close the app on a real
      // device; in the test environment handlePopRoute returns false
      // because there is no further route to pop on the root navigator).
      final didPop = await tester.binding.handlePopRoute();
      await tester.pump();

      expect(
        didPop,
        isFalse,
        reason:
            'canPop: true on tab 0 — the PopScope does NOT intercept; '
            'the root navigator has no further route to pop so the '
            'test binding returns false (matches the real-device '
            'behaviour where the OS closes the app).',
      );
    });
  });

  group('AuthenticatedShell — push-over-shell pattern (AC-13)', () {
    testWidgets('a pushed MaterialPageRoute paints over the bottom nav', (
      tester,
    ) async {
      await tester.pumpWidget(_buildShell(tabContentOverride: _stubTabs()));
      await tester.pump();

      // Push a new route programmatically — mirror of the SCR-26 ->
      // SCR-27 push pattern.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Center(child: Text('pushed route'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The pushed Scaffold is visible; the shell's BottomNavigationBar
      // is no longer reachable from the screen (it's still in the
      // widget tree under the shell, but the route stack hides it).
      expect(find.text('pushed route'), findsOneWidget);
      // The shell's tab content is no longer painted.
      expect(find.text('content of home'), findsNothing);

      // Pop the route — we return to the shell with tab 0 still active.
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('content of home'), findsOneWidget);
      expect(find.byType(OBTBottomNav), findsOneWidget);
    });
  });

  group('AuthenticatedShell — persistent FAB (FR-HD-04 AC-1)', () {
    testWidgets('Scaffold.floatingActionButton is non-null and is an '
        'OBTFloatingActionButton on every primary tab (parameterised 0..4)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildShell(tabContentOverride: _stubTabs()));
      await tester.pumpAndSettle();

      for (var i = 0; i < OBTBottomNav.tabs.length; i++) {
        if (i != 0) {
          await tester.tap(find.text(OBTBottomNav.tabs[i].label));
          await tester.pumpAndSettle();
        }

        // The shell's own Scaffold is the ancestor of the IndexedStack
        // (the tab content widgets each carry their own inner
        // Scaffold which we must not pick up).
        final shellScaffold = tester.widget<Scaffold>(
          find
              .ancestor(
                of: find.byType(IndexedStack),
                matching: find.byType(Scaffold),
              )
              .first,
        );
        expect(
          shellScaffold.floatingActionButton,
          isNotNull,
          reason: 'tab $i: Scaffold.floatingActionButton must be non-null',
        );
        expect(
          shellScaffold.floatingActionButton,
          isA<OBTFloatingActionButton>(),
          reason:
              'tab $i: Scaffold.floatingActionButton must be an '
              'OBTFloatingActionButton (design-system primitive)',
        );

        // Defence-in-depth: the FAB is also reachable in the widget
        // tree at the shell level.
        expect(find.byType(OBTFloatingActionButton), findsOneWidget);
      }
    });
  });
}
