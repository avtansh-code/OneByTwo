// SettleUpBottomSheet widget tests (FR-SE-05 / SCR-23; DC-08 rebuild).
//
// The sheet is rebuilt onto the shared OBTSettleUpSheet (DC-03). These
// tests pin the host wiring the component does not own: the controller
// state machine -> OBTSettleUpSheet prop mapping, the single-fire
// `settle_up_screen_viewed` telemetry, the validation feedback, the
// record/error flow, and the in-sheet success moment that replaces the old
// auto-dismiss + "Settlement recorded." snackbar.
//
// The OBTSettleUpSheet is a min-height (non-scrolling) Column, so every
// test pumps on the 390x844 Haldi reference frame (mirroring
// obt_settle_up_sheet_test.dart) so the "Record payment" CTA is on-screen.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/application/settle_up_telemetry.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
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

/// Pumps the sheet on the 390x844 Haldi reference frame so the non-scrolling
/// OBTSettleUpSheet body (header + amount + UPI slot + CTA) is fully on-screen.
Future<void> _pumpSheet(
  WidgetTester tester, {
  required FakeSettlementRepository repo,
  required FakeAnalyticsService analytics,
  int suggestedAmountPaise = _suggested,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _buildSubject(
      repo: repo,
      analytics: analytics,
      suggestedAmountPaise: suggestedAmountPaise,
    ),
  );
  await tester.pumpAndSettle();
}

/// Drains the success auto-dismiss timer (`_successDismissDelay` = 1400 ms)
/// so it does not linger past test teardown.
Future<void> _drainDismiss(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1500));
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
      await _pumpSheet(tester, repo: repo, analytics: analytics);
      expect(find.textContaining('Bina'), findsWidgets);
    });

    testWidgets('renders the suggested amount echo (amountHero)', (
      tester,
    ) async {
      await _pumpSheet(tester, repo: repo, analytics: analytics);
      expect(find.textContaining(formatInrFromPaise(_suggested)), findsWidgets);
    });

    testWidgets('renders the Record payment button', (tester) async {
      await _pumpSheet(tester, repo: repo, analytics: analytics);
      expect(
        find.widgetWithText(FilledButton, 'Record payment'),
        findsOneWidget,
      );
    });

    testWidgets('fires settle_up_screen_viewed exactly once on first paint', (
      tester,
    ) async {
      await _pumpSheet(tester, repo: repo, analytics: analytics);
      expect(analytics.countOf(SettleUpTelemetry.screenViewed), 1);
    });

    testWidgets('settle_up_screen_viewed does not re-fire on rebuild', (
      tester,
    ) async {
      await _pumpSheet(tester, repo: repo, analytics: analytics);
      await tester.pumpAndSettle();
      expect(analytics.countOf(SettleUpTelemetry.screenViewed), 1);
    });
  });

  group('Amount editing', () {
    testWidgets('typing a partial amount keeps record enabled', (tester) async {
      await _pumpSheet(tester, repo: repo, analytics: analytics);

      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '30');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await tester.pumpAndSettle();
      expect(repo.called, isTrue);
      expect(repo.capturedDoc!.amountPaise, 3000);
      await _drainDismiss(tester);
    });

    testWidgets('typing 0 blocks save and shows the inline error', (
      tester,
    ) async {
      await _pumpSheet(tester, repo: repo, analytics: analytics);

      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '0');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await tester.pump();
      expect(repo.called, isFalse);
      expect(find.text('Amount must be greater than zero.'), findsOneWidget);
    });

    testWidgets('typing an amount > suggested blocks save with error', (
      tester,
    ) async {
      await _pumpSheet(tester, repo: repo, analytics: analytics);

      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '70');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await tester.pump();
      expect(repo.called, isFalse);
      expect(
        find.textContaining('cannot exceed the outstanding balance'),
        findsOneWidget,
      );
    });
  });

  group('Save success path (in-sheet success moment)', () {
    testWidgets('Record payment → success moment + repository called', (
      tester,
    ) async {
      repo.returnSettlementId = 'sid-1';
      await _pumpSheet(tester, repo: repo, analytics: analytics);

      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await tester.pumpAndSettle();

      expect(repo.called, isTrue);
      // The DC-03 success moment replaces the old "Settlement recorded."
      // snackbar (the AC-1 "high five" copy is superseded by the shipped
      // component copy per the Architect reconcile).
      expect(find.text('Payment recorded'), findsOneWidget);
      expect(find.text('Settlement recorded.'), findsNothing);
      expect(analytics.countOf(SettleUpTelemetry.settlementRecorded), 1);
      await _drainDismiss(tester);
    });

    testWidgets('success hides the editable form (no Record payment button)', (
      tester,
    ) async {
      await _pumpSheet(tester, repo: repo, analytics: analytics);

      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilledButton, 'Record payment'),
        findsNothing,
        reason: 'the success moment replaces the editable form',
      );
      await _drainDismiss(tester);
    });

    testWidgets(
      'doc shape: amountPaise == suggested, fromUserId == currentUid',
      (tester) async {
        await _pumpSheet(tester, repo: repo, analytics: analytics);

        await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
        await tester.pumpAndSettle();

        final doc = repo.capturedDoc!;
        expect(doc.amountPaise, _suggested);
        expect(doc.fromUserId, _currentUid);
        expect(doc.toUserId, _otherUid);
        expect(doc.contextType, 'friendship');
        expect(doc.contextId, _friendshipId);
        await _drainDismiss(tester);
      },
    );
  });

  group('Save failure paths', () {
    testWidgets('permission-denied shows the danger snackbar', (tester) async {
      repo.throwError = const SettlementCreateError(
        type: SettlementCreateErrorType.permissionDenied,
      );
      await _pumpSheet(tester, repo: repo, analytics: analytics);

      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
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
      await _pumpSheet(tester, repo: repo, analytics: analytics);

      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
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
    testWidgets('the record button exposes its label', (tester) async {
      await _pumpSheet(tester, repo: repo, analytics: analytics);

      expect(
        find.bySemanticsLabel(RegExp(r'^Record payment$')),
        findsAtLeastNWidgets(1),
        reason: 'the record button must expose its label',
      );
    });

    testWidgets('the inert "Pay via UPI" slot is announced disabled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpSheet(tester, repo: repo, analytics: analytics);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Pay via UPI. Coming soon.')),
        isSemantics(hasEnabledState: true, isEnabled: false),
        reason: 'the UPI slot is inert — announced disabled, not wired',
      );
      handle.dispose();
    });
  });
}
