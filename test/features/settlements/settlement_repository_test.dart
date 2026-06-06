// SettlementRepository read-path tests (FR-FR-04).
//
// Tests the new `SettlementRepository.watchByContext({contextType,
// contextId})` stream that powers the settlements section of the
// Friend Detail timeline. Mirrors the friendship_repository_watch_test
// pattern (PR #35) and the expense_repository_test pattern (PR #38):
// inject a `FakeSettlementStore` rather than pull in
// `fake_cloud_firestore`.
//
// PR #42 is the first client surface that reads settlements. FR-SE-08
// will pair with this on the write side.
//
// These tests are written BEFORE the implementation exists.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

class FakeSettlementStore implements SettlementStore {
  final StreamController<List<SettlementDoc>> _controller =
      StreamController<List<SettlementDoc>>.broadcast();
  String? lastWatchedContextType;
  String? lastWatchedContextId;

  void emit(List<SettlementDoc> docs) => _controller.add(docs);
  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) {
    lastWatchedContextType = contextType;
    lastWatchedContextId = contextId;
    return _controller.stream;
  }

  Future<void> close() => _controller.close();
}

SettlementDoc _doc({
  required String id,
  String fromUserId = 'uid-from',
  String toUserId = 'uid-to',
  int amountPaise = 5000,
  String contextType = 'friendship',
  String contextId = 'uid-from_uid-to',
  DateTime? date,
  bool deleted = false,
  DateTime? createdAt,
}) {
  return SettlementDoc(
    settlementId: id,
    fromUserId: fromUserId,
    toUserId: toUserId,
    amountPaise: amountPaise,
    contextType: contextType,
    contextId: contextId,
    date: date ?? DateTime(2026, 6),
    note: null,
    method: 'manual',
    verificationStatus: 'unverified',
    currency: 'INR',
    createdAt: createdAt ?? DateTime(2026, 6, 1, 12),
    deleted: deleted,
  );
}

void main() {
  late FakeSettlementStore store;
  late SettlementRepository repository;

  setUp(() {
    store = FakeSettlementStore();
    repository = SettlementRepository(store: store);
  });

  tearDown(() async {
    await store.close();
  });

  group('SettlementRepository.watchByContext', () {
    test('queries with the supplied contextType + contextId', () async {
      repository.watchByContext(
        contextType: 'friendship',
        contextId: 'uid-a_uid-b',
      );
      await Future<void>.delayed(Duration.zero);

      expect(store.lastWatchedContextType, 'friendship');
      expect(store.lastWatchedContextId, 'uid-a_uid-b');
    });

    test('emits an empty list when the underlying stream emits []', () async {
      final stream = repository.watchByContext(
        contextType: 'friendship',
        contextId: 'fid',
      );
      final emissions = <List<SettlementDoc>>[];
      final sub = stream.listen(emissions.add);

      store.emit(const []);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, hasLength(1));
      expect(emissions.first, isEmpty);

      await sub.cancel();
    });

    test('preserves the underlying ordering (Firestore date desc)', () async {
      final stream = repository.watchByContext(
        contextType: 'friendship',
        contextId: 'fid',
      );
      final emissions = <List<SettlementDoc>>[];
      final sub = stream.listen(emissions.add);

      final newest = _doc(id: 'sid-1', date: DateTime(2026, 6, 5));
      final middle = _doc(id: 'sid-2', date: DateTime(2026, 6, 3));
      final oldest = _doc(id: 'sid-3', date: DateTime(2026, 6));

      store.emit([newest, middle, oldest]);
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last.map((d) => d.settlementId).toList(), [
        'sid-1',
        'sid-2',
        'sid-3',
      ]);

      await sub.cancel();
    });

    test('soft-deleted entries are excluded from the projected list', () async {
      final stream = repository.watchByContext(
        contextType: 'friendship',
        contextId: 'fid',
      );
      final emissions = <List<SettlementDoc>>[];
      final sub = stream.listen(emissions.add);

      store.emit([
        _doc(id: 'sid-live-1', date: DateTime(2026, 6, 5)),
        _doc(id: 'sid-deleted', date: DateTime(2026, 6, 4), deleted: true),
        _doc(id: 'sid-live-2', date: DateTime(2026, 6, 3)),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last.map((d) => d.settlementId).toList(), [
        'sid-live-1',
        'sid-live-2',
      ]);

      await sub.cancel();
    });

    test('propagates stream errors as AsyncError downstream', () async {
      final stream = repository.watchByContext(
        contextType: 'friendship',
        contextId: 'fid',
      );
      final errors = <Object>[];
      final sub = stream.listen((_) {}, onError: errors.add);

      store.emitError(Exception('Firestore boom'));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.first, isException);

      await sub.cancel();
    });

    test('emits a new list when a settlement is added', () async {
      final stream = repository.watchByContext(
        contextType: 'friendship',
        contextId: 'fid',
      );
      final emissions = <List<SettlementDoc>>[];
      final sub = stream.listen(emissions.add);

      final first = _doc(id: 'sid-1', date: DateTime(2026, 6));
      store.emit([first]);
      await Future<void>.delayed(Duration.zero);

      final second = _doc(id: 'sid-2', date: DateTime(2026, 6, 2));
      store.emit([second, first]);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, hasLength(2));
      expect(emissions[0], hasLength(1));
      expect(emissions[1], hasLength(2));
      expect(emissions[1].map((d) => d.settlementId).toList(), [
        'sid-2',
        'sid-1',
      ]);

      await sub.cancel();
    });
  });

  group('logSettlementParseFailure (observability sink)', () {
    test('is a SettlementParseFailureSink', () {
      // ignore: omit_local_variable_types
      const SettlementParseFailureSink sink = logSettlementParseFailure;
      expect(sink, isA<SettlementParseFailureSink>());
    });

    test('does not throw on representative parse-failure messages', () {
      expect(
        () => logSettlementParseFailure(
          'settlement sid-1: amountPaise is not a positive integer; '
          'dropped',
        ),
        returnsNormally,
      );
    });

    test('accepts an empty message without throwing', () {
      expect(() => logSettlementParseFailure(''), returnsNormally);
    });
  });
}
