// SettleUpController state-machine tests (FR-SE-05).
//
// Tests SettleUpController — the Riverpod 2.x StateNotifier that drives
// the Settle Up bottom sheet, owns telemetry emission for the
// settlement_recorded / settle_up_error / settle_up_validation_failed
// events, and is the sole client-side producer of settlement writes via
// the injected SettlementRepository.
//
// Mirrors test/features/expenses/add_expense_controller_test.dart's
// FakeRepository / FakeAnalyticsService pattern (PR #38).
//
// Written test-first; will fail to compile until the Step B
// implementation lands.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/application/settle_up_controller.dart';
import 'package:onebytwo/features/settlements/application/settle_up_state.dart';
import 'package:onebytwo/features/settlements/application/settle_up_telemetry.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settle_up_draft.dart';
import 'package:onebytwo/features/settlements/domain/settlement_create_error.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeSettlementRepository implements SettlementRepository {
  SettlementDoc? capturedDoc;
  String returnSettlementId = 'sid-test';
  SettlementCreateError? throwError;
  Exception? throwUnknown;
  bool called = false;

  @override
  Future<String> createSettlement({required SettlementDoc doc}) async {
    called = true;
    capturedDoc = doc;
    if (throwError != null) {
      throw throwError!;
    }
    if (throwUnknown != null) {
      throw throwUnknown!;
    }
    return returnSettlementId;
  }

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) {
    return const Stream<List<SettlementDoc>>.empty();
  }
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

  Map<String, Object>? lastParamsFor(String name) =>
      loggedEvents.lastWhere((e) => e.name == name).parameters;

  bool hasEvent(String name) => loggedEvents.any((e) => e.name == name);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _friendshipId = 'uid-friend_uid-me';
const _currentUid = 'uid-me';
const _otherUid = 'uid-friend';
const _otherDisplayName = 'Bina';
const _suggested = 5000;

SettleUpController _buildController({
  required FakeSettlementRepository repo,
  required FakeAnalyticsService analytics,
  int suggestedAmountPaise = _suggested,
  DateTime? clock,
}) {
  return SettleUpController(
    friendshipId: _friendshipId,
    currentUserUid: _currentUid,
    otherUserUid: _otherUid,
    otherDisplayName: _otherDisplayName,
    suggestedAmountPaise: suggestedAmountPaise,
    repository: repo,
    analytics: analytics,
    clock: () => clock ?? DateTime(2026, 6, 5, 12),
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

  group('Initial state', () {
    test('starts in SettleUpEditing with amount pre-filled to suggested', () {
      final controller = _buildController(repo: repo, analytics: analytics);
      final state = controller.state;
      expect(state, isA<SettleUpEditing>());
      final editing = state as SettleUpEditing;
      expect(editing.draft.suggestedAmountPaise, _suggested);
      expect(editing.draft.amountPaise, _suggested);
      expect(editing.draft.note, isNull);
      expect(editing.validationErrors, isEmpty);
    });

    test('date defaults to clock value', () {
      final controller = _buildController(
        repo: repo,
        analytics: analytics,
        clock: DateTime(2026, 6, 5, 12),
      );
      final state = controller.state as SettleUpEditing;
      expect(state.draft.date, DateTime(2026, 6, 5, 12));
    });

    test('SettleUpArgs equality', () {
      const a = SettleUpArgs(
        friendshipId: 'fid',
        currentUserUid: 'me',
        otherUserUid: 'friend',
        suggestedAmountPaise: 5000,
        otherDisplayName: 'Bina',
      );
      const b = SettleUpArgs(
        friendshipId: 'fid',
        currentUserUid: 'me',
        otherUserUid: 'friend',
        suggestedAmountPaise: 5000,
        otherDisplayName: 'Bina',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Setters', () {
    test('setAmount updates the draft amount', () {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setAmount(3000);
      final state = controller.state as SettleUpEditing;
      expect(state.draft.amountPaise, 3000);
      expect(state.validationErrors, isEmpty);
    });

    test('setAmount > suggested surfaces validation error', () {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setAmount(6000);
      final state = controller.state as SettleUpEditing;
      expect(state.validationErrors['amount'], isNotNull);
      expect(state.validationErrors['amount'], contains('cannot exceed'));
    });

    test('setAmount == 0 surfaces "must be greater than zero"', () {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setAmount(0);
      final state = controller.state as SettleUpEditing;
      expect(
        state.validationErrors['amount'],
        'Amount must be greater than zero.',
      );
    });

    test('setAmount back to valid clears the error', () {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setAmount(6000);
      controller.setAmount(4000);
      final state = controller.state as SettleUpEditing;
      expect(state.validationErrors.containsKey('amount'), isFalse);
    });

    test('setDate updates the draft date', () {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setDate(DateTime(2026, 6, 3));
      final state = controller.state as SettleUpEditing;
      expect(state.draft.date, DateTime(2026, 6, 3));
    });

    test('setNote updates the draft note', () {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setNote('Pizza');
      final state = controller.state as SettleUpEditing;
      expect(state.draft.note, 'Pizza');
      expect(state.validationErrors, isEmpty);
    });

    test('setNote > 200 chars surfaces validation error', () {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setNote('a' * 201);
      final state = controller.state as SettleUpEditing;
      expect(
        state.validationErrors['note'],
        'Note must be 200 characters or fewer.',
      );
    });

    test('setNote with null clears the note (no error)', () {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setNote('Pizza');
      controller.setNote(null);
      final state = controller.state as SettleUpEditing;
      expect(state.draft.note, isNull);
      expect(state.validationErrors, isEmpty);
    });
  });

  group('save() happy path', () {
    test('transitions Editing → Saving → SettleUpSuccess', () async {
      repo.returnSettlementId = 'sid-generated';
      final controller = _buildController(repo: repo, analytics: analytics);
      final states = <SettleUpState>[];
      controller.addListener(states.add, fireImmediately: false);

      await controller.save();

      expect(repo.called, isTrue);
      expect(states.first, isA<SettleUpSaving>());
      expect(states.last, isA<SettleUpSuccess>());
      final success = states.last as SettleUpSuccess;
      expect(success.settlementId, 'sid-generated');
    });

    test('passes the doc with the correct shape to the repository', () async {
      final controller = _buildController(
        repo: repo,
        analytics: analytics,
        clock: DateTime(2026, 6, 5, 12),
      );
      controller.setAmount(3000);
      controller.setNote('Pizza');
      await controller.save();

      final doc = repo.capturedDoc!;
      expect(doc.fromUserId, _currentUid);
      expect(doc.toUserId, _otherUid);
      expect(doc.amountPaise, 3000);
      expect(doc.note, 'Pizza');
      expect(doc.contextType, 'friendship');
      expect(doc.contextId, _friendshipId);
      expect(doc.method, 'manual');
      expect(doc.verificationStatus, 'unverified');
      expect(doc.currency, 'INR');
      expect(doc.deleted, isFalse);
    });

    test('canonicalises empty note to null on save', () async {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setNote('   ');
      await controller.save();
      expect(repo.capturedDoc!.note, isNull);
    });

    test('fires settlement_recorded exactly once with the payload',
        () async {
      repo.returnSettlementId = 'sid-1';
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setAmount(3000); // partial
      await controller.save();

      expect(analytics.countOf(SettleUpTelemetry.settlementRecorded), 1);
      final params =
          analytics.lastParamsFor(SettleUpTelemetry.settlementRecorded)!;
      expect(params[SettleUpTelemetry.paramContextType], 'friendship');
      expect(params[SettleUpTelemetry.paramIsPartial], true);
      expect(params[SettleUpTelemetry.paramAmountRange], isA<String>());
      expect(
        params[SettleUpTelemetry.paramFriendshipIdHash],
        equals(hashFriendshipId(_friendshipId)),
      );
      expect(
        params[SettleUpTelemetry.paramSettlementIdHash],
        equals(hashId('sid-1')),
      );
    });

    test('full settlement is_partial == false', () async {
      final controller = _buildController(repo: repo, analytics: analytics);
      // amount == suggested → not partial
      await controller.save();
      final params =
          analytics.lastParamsFor(SettleUpTelemetry.settlementRecorded)!;
      expect(params[SettleUpTelemetry.paramIsPartial], false);
    });
  });

  group('save() failure — permission-denied', () {
    test('transitions Saving → SettleUpError(permissionDenied)', () async {
      repo.throwError = const SettlementCreateError(
        type: SettlementCreateErrorType.permissionDenied,
      );
      final controller = _buildController(repo: repo, analytics: analytics);

      await controller.save();

      expect(controller.state, isA<SettleUpError>());
      final err = controller.state as SettleUpError;
      expect(err.errorType, SettlementCreateErrorType.permissionDenied);
      expect(
        err.message,
        "Couldn't record the settlement. Please try again.",
      );
    });

    test('fires settle_up_error { error_code: permission_denied }',
        () async {
      repo.throwError = const SettlementCreateError(
        type: SettlementCreateErrorType.permissionDenied,
      );
      final controller = _buildController(repo: repo, analytics: analytics);
      await controller.save();

      expect(analytics.countOf(SettleUpTelemetry.errorEvent), 1);
      final params = analytics.lastParamsFor(SettleUpTelemetry.errorEvent)!;
      expect(params[SettleUpTelemetry.paramErrorCode], 'permission_denied');
      expect(params[SettleUpTelemetry.paramContextType], 'friendship');
      expect(
        params[SettleUpTelemetry.paramFriendshipIdHash],
        equals(hashFriendshipId(_friendshipId)),
      );
    });
  });

  group('save() failure — network', () {
    test('transitions Saving → SettleUpError(network) + telemetry', () async {
      repo.throwError = const SettlementCreateError(
        type: SettlementCreateErrorType.network,
      );
      final controller = _buildController(repo: repo, analytics: analytics);
      await controller.save();

      final err = controller.state as SettleUpError;
      expect(err.errorType, SettlementCreateErrorType.network);
      expect(err.message, contains("offline"));

      final params = analytics.lastParamsFor(SettleUpTelemetry.errorEvent)!;
      expect(params[SettleUpTelemetry.paramErrorCode], 'network');
    });
  });

  group('save() failure — unknown', () {
    test('non-typed exception → unknown branch', () async {
      repo.throwUnknown = Exception('boom');
      final controller = _buildController(repo: repo, analytics: analytics);
      await controller.save();

      final err = controller.state as SettleUpError;
      expect(err.errorType, SettlementCreateErrorType.unknown);

      final params = analytics.lastParamsFor(SettleUpTelemetry.errorEvent)!;
      expect(params[SettleUpTelemetry.paramErrorCode], 'unknown');
    });
  });

  group('save() validation failure path', () {
    test('save with amount==0 is a no-op + fires settle_up_validation_failed',
        () async {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setAmount(0);
      await controller.save();

      expect(repo.called, isFalse);
      expect(controller.state, isA<SettleUpEditing>());
      expect(
        analytics.countOf(SettleUpTelemetry.validationFailed),
        1,
      );
      final params =
          analytics.lastParamsFor(SettleUpTelemetry.validationFailed)!;
      expect(params[SettleUpTelemetry.paramField], 'amount');
    });

    test('save with note > 200 chars is a no-op + fires validation_failed',
        () async {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setNote('a' * 201);
      await controller.save();

      expect(repo.called, isFalse);
      expect(
        analytics.countOf(SettleUpTelemetry.validationFailed),
        1,
      );
      final params =
          analytics.lastParamsFor(SettleUpTelemetry.validationFailed)!;
      expect(params[SettleUpTelemetry.paramField], 'note');
    });
  });

  group('SettleUpTelemetry.amountRangeFor', () {
    test('matches the 4-bucket spec from telemetry-plan.md', () {
      expect(SettleUpTelemetry.amountRangeFor(10000), 'under_500');
      expect(SettleUpTelemetry.amountRangeFor(50000), '500_5000');
      expect(SettleUpTelemetry.amountRangeFor(499999), '500_5000');
      expect(SettleUpTelemetry.amountRangeFor(500000), '5000_25000');
      expect(SettleUpTelemetry.amountRangeFor(2499999), '5000_25000');
      expect(SettleUpTelemetry.amountRangeFor(2500000), 'over_25000');
      expect(SettleUpTelemetry.amountRangeFor(100000000), 'over_25000');
    });
  });

  group('Settle Up controller retry after failure', () {
    test('retry from SettleUpError transitions back to Saving → Success',
        () async {
      repo.throwError = const SettlementCreateError(
        type: SettlementCreateErrorType.network,
      );
      final controller = _buildController(repo: repo, analytics: analytics);
      await controller.save();
      expect(controller.state, isA<SettleUpError>());

      // Clear failure; the user taps "Retry" on the snackbar which
      // calls save() again.
      repo.throwError = null;
      repo.returnSettlementId = 'sid-retry';
      await controller.save();
      expect(controller.state, isA<SettleUpSuccess>());
    });
  });
}
