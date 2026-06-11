// `bottom_nav_tab_selected` telemetry constants contract.
//
// These constants are the single source of truth that the
// AuthenticatedShell uses when firing the per-tab-tap analytics event.
// The corresponding row in `docs/design/07-technical/telemetry-plan.md`
// §1.8 Cross-Cutting Events MUST match these values exactly.
//
// Per ADR-0013: no UID-derived parameters on this event family. The
// PII-leak grep in shell_boundary_contract_test.dart enforces the
// negative-space invariant.

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/shell/application/shell_telemetry.dart';

void main() {
  group('shell telemetry — event names', () {
    test('bottomNavTabSelectedEvent has the canonical name', () {
      expect(bottomNavTabSelectedEvent, 'bottom_nav_tab_selected');
    });

    test('fabTappedEvent has the canonical name', () {
      expect(fabTappedEvent, 'fab_tapped');
    });

    test('expenseContextSelectedEvent has the canonical name', () {
      expect(expenseContextSelectedEvent, 'expense_context_selected');
    });
  });

  group('shell telemetry — parameter keys', () {
    test('tabIndexParam is "tab_index"', () {
      expect(tabIndexParam, 'tab_index');
    });

    test('tabLabelParam is "tab_label"', () {
      expect(tabLabelParam, 'tab_label');
    });

    test('sourceTabParam is "source_tab"', () {
      expect(sourceTabParam, 'source_tab');
    });

    test('contextTypeParam is "context_type"', () {
      expect(contextTypeParam, 'context_type');
    });
  });

  group('shell telemetry — context-type tokens (FR-HD-04)', () {
    test('contextTypeFriend is "friend"', () {
      expect(contextTypeFriend, 'friend');
    });

    test('contextTypeGroup is "group"', () {
      expect(contextTypeGroup, 'group');
    });

    test('every token is lowercase and contains no whitespace', () {
      const tokens = <String>[contextTypeFriend, contextTypeGroup];
      for (final token in tokens) {
        expect(token, equals(token.toLowerCase()));
        expect(token.contains(' '), isFalse);
        expect(token.isNotEmpty, isTrue);
      }
    });
  });

  group('shell telemetry — tab label tokens', () {
    test('the five tokens match the design-system spec', () {
      expect(tabLabelHome, 'home');
      expect(tabLabelFriends, 'friends');
      expect(tabLabelGroups, 'groups');
      expect(tabLabelActivity, 'activity');
      expect(tabLabelProfile, 'profile');
    });

    test('every token is lowercase and contains no whitespace', () {
      const tokens = <String>[
        tabLabelHome,
        tabLabelFriends,
        tabLabelGroups,
        tabLabelActivity,
        tabLabelProfile,
      ];
      for (final token in tokens) {
        expect(token, equals(token.toLowerCase()));
        expect(token.contains(' '), isFalse);
        expect(token.isNotEmpty, isTrue);
      }
    });
  });

  group('shell telemetry — PII guard (defence-in-depth)', () {
    test('no constant declared here matches a UID-derived parameter name', () {
      const forbidden = <String>[
        'userId',
        'uid',
        'friendship_id',
        'friendship_id_hash',
      ];
      const allConstants = <String>[
        bottomNavTabSelectedEvent,
        tabIndexParam,
        tabLabelParam,
        tabLabelHome,
        tabLabelFriends,
        tabLabelGroups,
        tabLabelActivity,
        tabLabelProfile,
        fabTappedEvent,
        expenseContextSelectedEvent,
        sourceTabParam,
        contextTypeParam,
        contextTypeFriend,
        contextTypeGroup,
      ];
      for (final c in allConstants) {
        for (final f in forbidden) {
          expect(
            c,
            isNot(equals(f)),
            reason:
                '$c must not equal $f — telemetry payloads carry only '
                'tab_index (int) and tab_label (safe enum string).',
          );
        }
      }
    });
  });
}
