// GroupsComingSoonTab widget tests (DC-05 shell tab-2 swap).
//
// The former bespoke `GroupsListPlaceholder` is deleted (AC-3 — removed,
// not converted); tab 2 now composes the shared Haldi `OBTEmptyState`.
// These tests pin the "coming soon" copy, the shared-component
// composition, the accessible header, and the absence of the stale
// "Coming in Sprint 3" copy — in light and dark.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';
import 'package:onebytwo/features/shell/presentation/groups_coming_soon_tab.dart';

import '../../support/widget_test_harness.dart';

void main() {
  group('GroupsComingSoonTab', () {
    testWidgets('composes the shared OBTEmptyState with the coming-soon copy', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const GroupsComingSoonTab(),
        wrapInScaffold: false,
      );

      expect(find.byType(OBTEmptyState), findsOneWidget);
      expect(find.text('Groups — coming soon'), findsOneWidget);
      // The stale bespoke-stub copy must be gone.
      expect(find.textContaining('Coming in Sprint 3'), findsNothing);
    });

    testWidgets('owns a Groups app-bar header and exposes no CTA', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const GroupsComingSoonTab(),
        wrapInScaffold: false,
      );

      expect(find.widgetWithText(AppBar, 'Groups'), findsOneWidget);
      // Sprint-4 Groups is not yet actionable: the empty-state has no CTA.
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('renders in dark mode without overflow', (tester) async {
      await pumpThemed(
        tester,
        const GroupsComingSoonTab(),
        brightness: Brightness.dark,
        wrapInScaffold: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Groups — coming soon'), findsOneWidget);
    });
  });
}
