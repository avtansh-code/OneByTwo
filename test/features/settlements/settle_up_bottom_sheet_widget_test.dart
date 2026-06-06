// SettleUpBottomSheet widget tests (FR-SE-05 / SCR-23).
//
// Tests the SCR-23 bottom-sheet UI: state rendering, validation
// feedback, telemetry side-effects via the injected controller, and
// snackbar behaviour on Success / SettleUpError.
//
// Mirrors test/features/expenses/add_expense_bottom_sheet_widget_test.dart
// — uses a ProviderScope with overridden analytics service and a fake
// settlement repository injected via Riverpod overrides.
//
// Written test-first; will fail to compile until the Step C
// implementation lands.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/application/settle_up_controller.dart';
import 'package:onebytwo/features/settlements/application/settle_up_telemetry.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_create_error.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';
import 'package:onebytwo/features/settlements/presentation/settle_up_bottom_sheet.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeSettlementRepository implements SettlementRepository {
  SettlementDoc? capturedDoc;
  String returnSettlementId = 'sid-test';
  SettlementCreateError? throwError;
  bool called = false;

  @override
  Future<String> createSettlement({required SettlementDoc doc}) async {
    called = true;
    capturedDoc = doc;
    if (throwError != null) {
      throw throwError!;
    }
    return returnSettlementId;
  }

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) => const Stream<List<SettlementDoc>>.empty();
}

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
}

// ---------------------------------------------------------------------------
// Subject builder
// ---------------------------------------------------------------------------

const _friendshipId = 'uid-friend_uid-me';
const _currentUid = 'uid-me';
const _otherUid = 'uid-friend';
const _otherName = 'Bina';
const _suggested = 5000;

Widget _buildSubject({
  required FakeSettlementRepository repo,
  required FakeAnalyticsService analytics,
  int suggestedAmountPaise = _suggested,
}) {
  return ProviderScope(
    overrides: [
      settlementRepositoryProvider.overrideWithValue(repo),
      analyticsServiceProvider.overrideWithValue(analytics),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SettleUpBottomSheet(
          friendshipId: _friendshipId,
          currentUserUid: _currentUid,
          otherUserUid: _otherUid,
          otherDisplayName: _otherName,
          suggestedAmountPaise: suggestedAmountPaise,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeSettlementRepository repo;
  late FakeAnalyticsService analytics;

  setUp(() {
    repo = FakeSettlementRepository();
    analytics = FakeAnalyticsService();
  });

  group('Initial render', () {
    testWidgets('renders the friend display name in the header', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pump();
      expect(find.textContaining('Bina'), findsWidgets);
    });

    testWidgets('renders the suggested amount echo', (tester) async {
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pump();
      expect(find.text(formatInrFromPaise(_suggested)), findsWidgets);
    });

    testWidgets('renders the Record Settlement button', (tester) async {
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pump();
      expect(find.text('Record Settlement'), findsOneWidget);
    });

    testWidgets('fires settle_up_screen_viewed exactly once on first paint', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();
      expect(analytics.countOf(SettleUpTelemetry.screenViewed), 1);
    });

    testWidgets('settle_up_screen_viewed does not re-fire on rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(analytics.countOf(SettleUpTelemetry.screenViewed), 1);
    });
  });

  group('Amount editing', () {
    testWidgets('typing a partial amount keeps the Save button enabled', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pump();

      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '30');
      await tester.pump();

      // Tap save; assert the repository was called (the button is
      // enabled).
      await tester.tap(find.text('Record Settlement'));
      await tester.pumpAndSettle();
      expect(repo.called, isTrue);
      expect(repo.capturedDoc!.amountPaise, 3000);
    });

    testWidgets('typing 0 disables save and shows the inline error', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pump();

      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '0');
      await tester.pump();

      await tester.tap(find.text('Record Settlement'));
      await tester.pump();
      expect(repo.called, isFalse);
      expect(find.text('Amount must be greater than zero.'), findsOneWidget);
    });

    testWidgets('typing an amount > suggested disables save with error', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pump();

      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '70');
      await tester.pump();

      await tester.tap(find.text('Record Settlement'));
      await tester.pump();
      expect(repo.called, isFalse);
      expect(
        find.textContaining('cannot exceed the outstanding balance'),
        findsOneWidget,
      );
    });
  });

  group('Save success path', () {
    testWidgets('Record Settlement → success snackbar + repository called', (
      tester,
    ) async {
      repo.returnSettlementId = 'sid-1';
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Settlement'));
      await tester.pumpAndSettle();

      expect(repo.called, isTrue);
      expect(find.text('Settlement recorded.'), findsOneWidget);
      expect(analytics.countOf(SettleUpTelemetry.settlementRecorded), 1);
    });

    testWidgets(
      'doc shape: amountPaise == suggested, fromUserId == currentUid',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(repo: repo, analytics: analytics),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Record Settlement'));
        await tester.pumpAndSettle();

        final doc = repo.capturedDoc!;
        expect(doc.amountPaise, _suggested);
        expect(doc.fromUserId, _currentUid);
        expect(doc.toUserId, _otherUid);
        expect(doc.contextType, 'friendship');
        expect(doc.contextId, _friendshipId);
      },
    );
  });

  group('Save failure paths', () {
    testWidgets('permission-denied shows the danger snackbar', (
      tester,
    ) async {
      repo.throwError = const SettlementCreateError(
        type: SettlementCreateErrorType.permissionDenied,
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Settlement'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't record the settlement. Please try again."),
        findsOneWidget,
      );
      expect(analytics.countOf(SettleUpTelemetry.errorEvent), 1);
    });

    testWidgets('network failure shows the offline snackbar', (tester) async {
      repo.throwError = const SettlementCreateError(
        type: SettlementCreateErrorType.network,
      );
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Settlement'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "You're offline. The settlement will be recorded when "
          'you reconnect.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Accessibility', () {
    testWidgets('every interactive widget has a semantic label', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pump();

      // Close button + Save button + amount input must all be
      // surfaced to a11y. Verify a Semantics scope exists for each.
      expect(
        find.bySemanticsLabel('Close'),
        findsOneWidget,
        reason: 'close button must expose Close label',
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Record Settlement$')),
        findsAtLeastNWidgets(1),
        reason: 'save button must expose its label',
      );
    });
  });
}
