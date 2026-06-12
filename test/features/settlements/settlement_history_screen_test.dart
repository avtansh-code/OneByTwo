// Settlement History screen widget tests (FR-SE-08 / SCR-24).
//
// Verifies the SCR-24 four-state rendering (loading / populated / empty
// / error), the settlement-row layout contract (date / amount / note /
// avatars / row height), the accessibility labels, the 50-item cap, and
// the settlement_history_viewed / settlement_history_error single-fire
// telemetry discipline (both events pre-declared in telemetry-plan §1.3).
//
// Tests are written BEFORE the implementation and will fail to compile
// until the production code lands.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/application/settlement_history_telemetry.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';
import 'package:onebytwo/features/settlements/presentation/settlement_history_screen.dart';

class FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }

  int countOf(String name) => loggedEvents.where((e) => e.name == name).length;

  Map<String, Object>? lastParamsFor(String name) =>
      loggedEvents.lastWhere((e) => e.name == name).parameters;
}

class FakeSettlementRepository implements SettlementRepository {
  FakeSettlementRepository(this._factory);

  final Stream<List<SettlementDoc>> Function() _factory;
  int watchCallCount = 0;

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) {
    watchCallCount += 1;
    return _factory();
  }

  @override
  Future<String> createSettlement({required SettlementDoc doc}) async {
    throw UnimplementedError('history screen never writes');
  }
}

SettlementDoc _settlement({
  required String id,
  required DateTime date,
  int amountPaise = 5000,
  String fromUserId = 'uid-me',
  String toUserId = 'uid-friend',
  String? note,
}) {
  return SettlementDoc(
    settlementId: id,
    fromUserId: fromUserId,
    toUserId: toUserId,
    amountPaise: amountPaise,
    contextType: 'friendship',
    contextId: 'uid-friend_uid-me',
    date: date,
    note: note,
    method: 'manual',
    verificationStatus: 'unverified',
    currency: 'INR',
    createdAt: date,
    deleted: false,
  );
}

Widget _buildSubject({
  required FakeSettlementRepository repo,
  required FakeAnalyticsService analytics,
  String otherDisplayName = 'Priya',
}) {
  return ProviderScope(
    overrides: [
      settlementRepositoryProvider.overrideWithValue(repo),
      analyticsServiceProvider.overrideWithValue(analytics),
    ],
    child: MaterialApp(
      home: SettlementHistoryScreen(
        contextType: 'friendship',
        contextId: 'uid-friend_uid-me',
        currentUserUid: 'uid-me',
        otherUserUid: 'uid-friend',
        otherDisplayName: otherDisplayName,
      ),
    ),
  );
}

Finder _rowFinder() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('settlement_history_row_'),
);

void main() {
  late FakeAnalyticsService analytics;

  setUp(() {
    analytics = FakeAnalyticsService();
  });

  group('Loading state (AC-3)', () {
    testWidgets('renders a centred CircularProgressIndicator', (tester) async {
      final repo = FakeSettlementRepository(
        () => Stream<List<SettlementDoc>>.fromFuture(
          Completer<List<SettlementDoc>>().future,
        ),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('does NOT fire settlement_history_viewed while loading', (
      tester,
    ) async {
      final repo = FakeSettlementRepository(
        () => Stream<List<SettlementDoc>>.fromFuture(
          Completer<List<SettlementDoc>>().future,
        ),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pump();

      expect(analytics.countOf(SettlementHistoryTelemetry.viewedEvent), 0);
    });
  });

  group('Populated state (AC-1)', () {
    List<SettlementDoc> threeDateDesc() => [
      _settlement(id: 's-1', date: DateTime(2025, 3, 25)),
      _settlement(id: 's-2', date: DateTime(2025, 3, 18)),
      _settlement(id: 's-3', date: DateTime(2025, 2, 2)),
    ];

    testWidgets('renders all settlements as rows', (tester) async {
      final repo = FakeSettlementRepository(
        () => Stream.value(threeDateDesc()),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(_rowFinder(), findsNWidgets(3));
    });

    testWidgets('renders rows in date-descending order', (tester) async {
      final repo = FakeSettlementRepository(
        () => Stream.value(threeDateDesc()),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      final y25 = tester.getTopLeft(find.text('25 Mar 2025')).dy;
      final y18 = tester.getTopLeft(find.text('18 Mar 2025')).dy;
      final y02 = tester.getTopLeft(find.text('02 Feb 2025')).dy;
      expect(y25, lessThan(y18));
      expect(y18, lessThan(y02));
    });
  });

  group('Empty state (AC-2)', () {
    testWidgets('renders the canonical empty placeholder and NO Retry', (
      tester,
    ) async {
      final repo = FakeSettlementRepository(
        () => Stream.value(const <SettlementDoc>[]),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(find.text('No settlements yet'), findsOneWidget);
      expect(
        find.text('Once you settle up, it will appear here.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('Error state (AC-4)', () {
    Stream<List<SettlementDoc>> errorStream() =>
        Stream<List<SettlementDoc>>.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        );

    testWidgets('renders the canonical error placeholder with Retry', (
      tester,
    ) async {
      final repo = FakeSettlementRepository(errorStream);
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text('We could not load settlement history. Please try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    });

    testWidgets('tapping Retry re-subscribes to the provider', (tester) async {
      final repo = FakeSettlementRepository(errorStream);
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();
      expect(repo.watchCallCount, 1);

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(repo.watchCallCount, 2);
    });
  });

  group('50-item cap (AC-5)', () {
    testWidgets('a 76-item stream renders 50 rows and logs item_count 50', (
      tester,
    ) async {
      final upstream = List.generate(
        76,
        (i) => _settlement(
          id: 's-$i',
          date: DateTime(2025).add(Duration(days: i)),
        ),
      );
      final repo = FakeSettlementRepository(() => Stream.value(upstream));
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(find.byType(ListView));
      final delegate = listView.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.childCount, 50);

      expect(
        analytics.lastParamsFor(
          SettlementHistoryTelemetry.viewedEvent,
        )?[SettlementHistoryTelemetry.paramItemCount],
        50,
      );
    });
  });

  group('Settlement-row layout (AC-6 / AC-7 / AC-8 / AC-9 / AC-10)', () {
    testWidgets('AC-6 date renders as dd MMM yyyy', (tester) async {
      final repo = FakeSettlementRepository(
        () =>
            Stream.value([_settlement(id: 's-1', date: DateTime(2025, 3, 25))]),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(find.text('25 Mar 2025'), findsOneWidget);
    });

    testWidgets('AC-7 amount renders via formatInrFromPaise', (tester) async {
      final repo = FakeSettlementRepository(
        () => Stream.value([
          _settlement(
            id: 's-1',
            date: DateTime(2025, 3, 25),
            amountPaise: 80000,
          ),
        ]),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(find.text(formatInrFromPaise(80000)), findsOneWidget);
      expect(find.text('₹800.00'), findsOneWidget);
    });

    testWidgets('AC-8 note is visible when non-null', (tester) async {
      final repo = FakeSettlementRepository(
        () => Stream.value([
          _settlement(
            id: 's-1',
            date: DateTime(2025, 3, 25),
            note: 'GPay transfer',
          ),
        ]),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(find.text('GPay transfer'), findsOneWidget);
    });

    testWidgets('AC-8 note widget is absent when null', (tester) async {
      final repo = FakeSettlementRepository(
        () =>
            Stream.value([_settlement(id: 's-1', date: DateTime(2025, 3, 25))]),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      // The only text nodes are the date and the amount; no note line.
      expect(find.text('GPay transfer'), findsNothing);
    });

    testWidgets('AC-9 two avatars with payer/payee initials + an arrow', (
      tester,
    ) async {
      final repo = FakeSettlementRepository(
        () =>
            Stream.value([_settlement(id: 's-1', date: DateTime(2025, 3, 25))]),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(find.byType(CircleAvatar), findsNWidgets(2));
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      // Payer is the current user ("You" -> "Y"); payee is the friend
      // ("Priya" -> "P").
      expect(find.text('Y'), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
    });

    testWidgets('AC-10 row height is at least 64 dp', (tester) async {
      final repo = FakeSettlementRepository(
        () =>
            Stream.value([_settlement(id: 's-1', date: DateTime(2025, 3, 25))]),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(tester.getSize(_rowFinder()).height, greaterThanOrEqualTo(64));
    });
  });

  group('Accessibility (AC-11 / AC-12)', () {
    testWidgets('AC-11 screen title is a semantic header', (tester) async {
      final repo = FakeSettlementRepository(
        () => Stream.value(const <SettlementDoc>[]),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.text('Settlement History'),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.header ?? false),
          ),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('AC-12 settlement-row semantic label (with note)', (
      tester,
    ) async {
      final repo = FakeSettlementRepository(
        () => Stream.value([
          _settlement(
            id: 's-1',
            date: DateTime(2025, 3, 25),
            amountPaise: 80000,
            note: 'GPay transfer',
          ),
        ]),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          'You paid Priya rupees 800.00 on 25 Mar 2025. Note: GPay transfer.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('AC-12 settlement-row semantic label (no note)', (
      tester,
    ) async {
      final repo = FakeSettlementRepository(
        () => Stream.value([
          _settlement(
            id: 's-1',
            date: DateTime(2025, 3, 25),
            amountPaise: 80000,
          ),
        ]),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          'You paid Priya rupees 800.00 on 25 Mar 2025. Note: no note.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Telemetry (AC-13 / AC-14)', () {
    testWidgets('AC-13 settlement_history_viewed fires once with params', (
      tester,
    ) async {
      final repo = FakeSettlementRepository(
        () => Stream.value([
          _settlement(id: 's-1', date: DateTime(2025, 3, 25)),
          _settlement(id: 's-2', date: DateTime(2025, 3, 18)),
          _settlement(id: 's-3', date: DateTime(2025, 2, 2)),
        ]),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(analytics.countOf(SettlementHistoryTelemetry.viewedEvent), 1);
      final params = analytics.lastParamsFor(
        SettlementHistoryTelemetry.viewedEvent,
      );
      expect(
        params?[SettlementHistoryTelemetry.paramContextType],
        'friendship',
      );
      expect(params?[SettlementHistoryTelemetry.paramItemCount], 3);
    });

    testWidgets('AC-13 does NOT re-fire on a subsequent stream emission', (
      tester,
    ) async {
      final controller = StreamController<List<SettlementDoc>>();
      addTearDown(controller.close);
      final repo = FakeSettlementRepository(() => controller.stream);
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));

      controller.add([_settlement(id: 's-1', date: DateTime(2025, 3, 25))]);
      await tester.pump();
      controller.add([
        _settlement(id: 's-1', date: DateTime(2025, 3, 25)),
        _settlement(id: 's-2', date: DateTime(2025, 3, 18)),
      ]);
      await tester.pump();

      expect(analytics.countOf(SettlementHistoryTelemetry.viewedEvent), 1);
    });

    testWidgets('AC-14 settlement_history_error fires on AsyncError', (
      tester,
    ) async {
      final repo = FakeSettlementRepository(
        () => Stream<List<SettlementDoc>>.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(analytics.countOf(SettlementHistoryTelemetry.errorEvent), 1);
      final params = analytics.lastParamsFor(
        SettlementHistoryTelemetry.errorEvent,
      );
      expect(
        params?[SettlementHistoryTelemetry.paramErrorCode],
        'permission-denied',
      );
      expect(
        params?[SettlementHistoryTelemetry.paramContextType],
        'friendship',
      );
    });

    testWidgets('AC-14 non-Firebase error maps to unknown', (tester) async {
      final repo = FakeSettlementRepository(
        () => Stream<List<SettlementDoc>>.error(Exception('boom')),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(
        analytics.lastParamsFor(
          SettlementHistoryTelemetry.errorEvent,
        )?[SettlementHistoryTelemetry.paramErrorCode],
        'unknown',
      );
    });
  });

  group('Telemetry PII guard (AC-15)', () {
    const forbiddenKeys = <String>[
      'context_id',
      'friendship_id',
      'friendship_id_hash',
      'userId',
      'uid',
    ];
    const piiValues = <String>[
      'uid-friend_uid-me',
      'uid-me',
      'uid-friend',
      'Priya',
    ];

    testWidgets('viewed event carries no PII key or value', (tester) async {
      final repo = FakeSettlementRepository(
        () =>
            Stream.value([_settlement(id: 's-1', date: DateTime(2025, 3, 25))]),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      for (final event in analytics.loggedEvents) {
        final params = event.parameters ?? const <String, Object>{};
        for (final key in forbiddenKeys) {
          expect(params.containsKey(key), isFalse, reason: 'leaked key $key');
        }
        for (final value in params.values) {
          for (final pii in piiValues) {
            expect(
              value.toString().contains(pii),
              isFalse,
              reason: 'leaked PII value $pii',
            );
          }
        }
      }
    });

    testWidgets('error event carries no PII key or value', (tester) async {
      final repo = FakeSettlementRepository(
        () => Stream<List<SettlementDoc>>.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      for (final event in analytics.loggedEvents) {
        final params = event.parameters ?? const <String, Object>{};
        for (final key in forbiddenKeys) {
          expect(params.containsKey(key), isFalse, reason: 'leaked key $key');
        }
        for (final value in params.values) {
          for (final pii in piiValues) {
            expect(
              value.toString().contains(pii),
              isFalse,
              reason: 'leaked PII value $pii',
            );
          }
        }
      }
    });
  });
}
