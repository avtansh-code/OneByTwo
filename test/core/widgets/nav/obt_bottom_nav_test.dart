// OBTBottomNav widget tests — design-system primitive (components.md §2).
//
// Covers the spec-ratified contract:
//   - five tabs render in the canonical order with outlined-vs-filled
//     icons swapping on selection
//   - the active tab uses Theme.of(context).colorScheme.primary
//   - tapping any tab invokes onTabSelected with the correct index
//   - each tap target measures >= 48x48 dp (accessibility floor)
//   - Semantics nodes carry isSelected on the active tab (the platform
//     accessibility framework turns this into the spoken "Selected"
//     suffix)
//   - the static tab list (tabs) is the single source of truth for
//     labels, icons, and telemetry tokens.

// ignore_for_file: cascade_invocations

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/widgets/nav/obt_bottom_nav.dart';

Widget _host({
  required int currentIndex,
  required ValueChanged<int> onTabSelected,
}) {
  return MaterialApp(
    home: Scaffold(
      body: const Center(child: Text('body')),
      bottomNavigationBar: OBTBottomNav(
        currentIndex: currentIndex,
        onTabSelected: onTabSelected,
      ),
    ),
  );
}

void main() {
  group('OBTBottomNav — tab list contract', () {
    test('exposes exactly 5 tabs in the spec-ratified order', () {
      expect(OBTBottomNav.tabs.length, 5);
      expect(OBTBottomNav.tabs[0].label, 'Home');
      expect(OBTBottomNav.tabs[1].label, 'Friends');
      expect(OBTBottomNav.tabs[2].label, 'Groups');
      expect(OBTBottomNav.tabs[3].label, 'Activity');
      expect(OBTBottomNav.tabs[4].label, 'Profile');
    });

    test('every tab carries an outlined and a filled icon', () {
      for (final tab in OBTBottomNav.tabs) {
        expect(tab.outlinedIcon, isA<IconData>());
        expect(tab.filledIcon, isA<IconData>());
        expect(
          tab.outlinedIcon,
          isNot(equals(tab.filledIcon)),
          reason: 'outlined and filled icons must differ for ${tab.label}',
        );
      }
    });

    test('every tab carries a telemetry-safe lowercase label', () {
      for (final tab in OBTBottomNav.tabs) {
        expect(tab.telemetryLabel, equals(tab.telemetryLabel.toLowerCase()));
        expect(tab.telemetryLabel.contains(' '), isFalse);
        expect(tab.telemetryLabel.isNotEmpty, isTrue);
      }
    });

    test('telemetry labels match the spec tokens', () {
      expect(OBTBottomNav.tabs.map((t) => t.telemetryLabel).toList(), <String>[
        'home',
        'friends',
        'groups',
        'activity',
        'profile',
      ]);
    });
  });

  group('OBTBottomNav — render contract', () {
    testWidgets('renders 5 tabs with the spec-ratified labels', (tester) async {
      await tester.pumpWidget(_host(currentIndex: 0, onTabSelected: (_) {}));

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(nav.items.length, 5);
      expect(nav.type, BottomNavigationBarType.fixed);

      final labels = nav.items.map((i) => i.label).toList();
      expect(labels, <String>[
        'Home',
        'Friends',
        'Groups',
        'Activity',
        'Profile',
      ]);
    });

    testWidgets('active tab (index 0) shows the filled Home icon', (
      tester,
    ) async {
      await tester.pumpWidget(_host(currentIndex: 0, onTabSelected: (_) {}));

      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(nav.currentIndex, 0);
      // activeIcon is the filled variant; the inactive (icon) slot holds
      // the outlined variant.
      final homeItem = nav.items[0];
      expect((homeItem.activeIcon as Icon).icon, Icons.home);
      expect((homeItem.icon as Icon).icon, Icons.home_outlined);
    });

    testWidgets('every tab item has matching outlined / filled icon pair', (
      tester,
    ) async {
      await tester.pumpWidget(_host(currentIndex: 2, onTabSelected: (_) {}));

      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      for (var i = 0; i < OBTBottomNav.tabs.length; i++) {
        final tab = OBTBottomNav.tabs[i];
        final item = nav.items[i];
        expect((item.activeIcon as Icon).icon, tab.filledIcon);
        expect((item.icon as Icon).icon, tab.outlinedIcon);
      }
    });

    testWidgets('selected colour resolves to Theme.colorScheme.primary', (
      tester,
    ) async {
      await tester.pumpWidget(_host(currentIndex: 0, onTabSelected: (_) {}));

      final BuildContext context = tester.element(
        find.byType(BottomNavigationBar),
      );
      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(nav.selectedItemColor, Theme.of(context).colorScheme.primary);
      expect(
        nav.unselectedItemColor,
        Theme.of(context).colorScheme.onSurfaceVariant,
      );
    });
  });

  group('OBTBottomNav — interaction', () {
    testWidgets('tapping Activity invokes onTabSelected(3)', (tester) async {
      final captured = <int>[];
      await tester.pumpWidget(
        _host(currentIndex: 0, onTabSelected: captured.add),
      );

      await tester.tap(find.text('Activity'));
      await tester.pump();

      expect(captured, <int>[3]);
    });

    testWidgets('tapping each tab fires the callback with its index', (
      tester,
    ) async {
      final captured = <int>[];
      // Start with currentIndex: 0; the test taps tabs 1..4 in order.
      await tester.pumpWidget(
        _host(currentIndex: 0, onTabSelected: captured.add),
      );

      for (var i = 1; i < 5; i++) {
        await tester.tap(find.text(OBTBottomNav.tabs[i].label));
        await tester.pump();
      }

      expect(captured, <int>[1, 2, 3, 4]);
    });
  });

  group('OBTBottomNav — accessibility', () {
    testWidgets('every tab tap region meets the 48 dp minimum on both axes', (
      tester,
    ) async {
      await tester.pumpWidget(_host(currentIndex: 0, onTabSelected: (_) {}));

      for (final tab in OBTBottomNav.tabs) {
        final size = tester.getSize(find.text(tab.label));
        // The Material BottomNavigationBar default item height is >= 56 dp
        // and the tap target wraps the full item; per AC-9 we only require
        // a 48 dp floor on each axis. The text widget itself may be
        // smaller than 48 dp; we therefore measure the surrounding
        // InkResponse / GestureDetector tap area.
        final inkResponse = find.ancestor(
          of: find.text(tab.label),
          matching: find.byType(InkResponse),
        );
        expect(
          inkResponse,
          findsAtLeastNWidgets(1),
          reason:
              'BottomNavigationBar items must use InkResponse for tap '
              'feedback (Material default).',
        );
        final tapSize = tester.getSize(inkResponse.first);
        expect(
          tapSize.height,
          greaterThanOrEqualTo(48.0),
          reason:
              '${tab.label} tap target height was ${tapSize.height} '
              'but spec requires >= 48 dp (text size was ${size.height}).',
        );
        expect(
          tapSize.width,
          greaterThanOrEqualTo(48.0),
          reason:
              '${tab.label} tap target width was ${tapSize.width} '
              'but spec requires >= 48 dp.',
        );
      }
    });

    testWidgets('active tab carries isSelected: true in Semantics', (
      tester,
    ) async {
      await tester.pumpWidget(_host(currentIndex: 2, onTabSelected: (_) {}));

      // BottomNavigationBar wraps each item in a Semantics node with
      // isSelected toggled for the active tab. Walk up from the Groups
      // label until we find a node that carries the flag.
      final groupsSemantics = tester.getSemantics(find.text('Groups'));
      SemanticsNode? node = groupsSemantics;
      var selected = false;
      while (node != null) {
        if (node.flagsCollection.isSelected == Tristate.isTrue) {
          selected = true;
          break;
        }
        node = node.parent;
      }
      expect(
        selected,
        isTrue,
        reason:
            'Active tab must carry isSelected: true for accessibility '
            'frameworks to announce "Selected".',
      );
    });
  });

  group('OBTBottomNav — Haldi token reskin (DC-02)', () {
    testWidgets('tab labels use the Hanken caption (bodySmall) with the '
        'scheme colours', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: const Center(child: Text('body')),
            bottomNavigationBar: OBTBottomNav(
              currentIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(BottomNavigationBar));
      final theme = Theme.of(context);
      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(
        nav.selectedLabelStyle,
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
      );
      expect(
        nav.unselectedLabelStyle,
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    });
  });
}
