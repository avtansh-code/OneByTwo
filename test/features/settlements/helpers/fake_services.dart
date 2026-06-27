// Shared settlements test fakes — reused by the DC-08 reskin gate
// (settlements_haldi_reskin_test.dart) and the golden scaffold
// (dc08_settlements_golden_test.dart) so neither file redefines a
// `Fake…`/`Noop…` per file (the DC-07 review lesson).

import 'dart:async';

import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

/// Recording [AnalyticsService] that captures every emitted event so a test
/// can assert single-fire telemetry without a real Firebase Analytics.
class RecordingAnalytics implements AnalyticsService {
  /// Every event logged during the test, in order.
  final List<({String name, Map<String, Object>? parameters})> events =
      <({String name, Map<String, Object>? parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  /// Count of events with [name].
  int countOf(String name) => events.where((e) => e.name == name).length;
}

/// Configurable fake [SettlementRepository]. Defaults to an empty history
/// and a successful create. Seed [history] / set [keepLoading] / set
/// [streamError] to drive each list state, and inspect [capturedDoc] /
/// [createCount] to assert the write.
class FakeSettlementRepository implements SettlementRepository {
  /// Creates a [FakeSettlementRepository] seeded with [history].
  FakeSettlementRepository({
    this.history = const <SettlementDoc>[],
    this.keepLoading = false,
  });

  /// The list emitted by [watchByContext].
  List<SettlementDoc> history;

  /// When true, [watchByContext] returns a never-emitting stream so the
  /// screen stays in its loading (skeleton) state.
  final bool keepLoading;

  /// When non-null, [watchByContext] emits this error (drives the error
  /// state). Takes precedence over [keepLoading] / [history].
  Object? streamError;

  /// The last document passed to [createSettlement].
  SettlementDoc? capturedDoc;

  /// Number of [createSettlement] calls.
  int createCount = 0;

  /// The id returned by a successful [createSettlement].
  String returnSettlementId = 'sid-test';

  @override
  Future<String> createSettlement({required SettlementDoc doc}) async {
    createCount += 1;
    capturedDoc = doc;
    return returnSettlementId;
  }

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) {
    if (streamError != null) {
      return Stream<List<SettlementDoc>>.error(streamError!);
    }
    return keepLoading
        ? Stream<List<SettlementDoc>>.fromFuture(
            Completer<List<SettlementDoc>>().future,
          )
        : Stream<List<SettlementDoc>>.value(history);
  }
}

/// Builds a [SettlementDoc] for tests. `fromUserId`/`toUserId` drive the
/// sent/received direction; everything else takes a sensible default.
SettlementDoc fakeSettlement({
  required String id,
  required DateTime date,
  int amountPaise = 50000,
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
    contextId: 'uid-me_uid-friend',
    date: date,
    note: note,
    method: 'manual',
    verificationStatus: 'unverified',
    currency: 'INR',
    createdAt: date,
    deleted: false,
  );
}
