// Settlement history provider tests (FR-SE-08 / SCR-24).
//
// Verifies that settlementHistoryProvider:
//   - resolves to the repository's watchByContext stream;
//   - applies the 50-item cap over the upstream list;
//   - threads the (contextType, contextId) family key to the repo;
//   - has a value-equality family-key contract on SettlementHistoryArgs;
//   - drops its subscription on invalidation (re-subscribes on next read).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/settlements/application/settlement_history_provider.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

SettlementDoc _settlement(int index) {
  return SettlementDoc(
    settlementId: 'sid-$index',
    fromUserId: 'uid-me',
    toUserId: 'uid-friend',
    amountPaise: 1000 + index,
    contextType: 'friendship',
    contextId: 'uid-friend_uid-me',
    date: DateTime(2025).add(Duration(days: index)),
    note: null,
    method: 'manual',
    verificationStatus: 'unverified',
    currency: 'INR',
    createdAt: DateTime(2025).add(Duration(days: index)),
    deleted: false,
  );
}

class FakeSettlementRepository implements SettlementRepository {
  FakeSettlementRepository(this._factory);

  final Stream<List<SettlementDoc>> Function() _factory;

  int watchCallCount = 0;
  String? lastContextType;
  String? lastContextId;

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) {
    watchCallCount += 1;
    lastContextType = contextType;
    lastContextId = contextId;
    return _factory();
  }

  @override
  Future<String> createSettlement({required SettlementDoc doc}) async {
    throw UnimplementedError('history provider never writes');
  }
}

void main() {
  const args = SettlementHistoryArgs(
    contextType: 'friendship',
    contextId: 'uid-friend_uid-me',
  );

  group('SettlementHistoryArgs family-key contract', () {
    test('equal args are == and share a hashCode', () {
      const a = SettlementHistoryArgs(
        contextType: 'friendship',
        contextId: 'uid-friend_uid-me',
      );
      const b = SettlementHistoryArgs(
        contextType: 'friendship',
        contextId: 'uid-friend_uid-me',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing contextId or contextType breaks equality', () {
      const base = SettlementHistoryArgs(
        contextType: 'friendship',
        contextId: 'uid-friend_uid-me',
      );
      expect(
        base,
        isNot(
          equals(
            const SettlementHistoryArgs(
              contextType: 'friendship',
              contextId: 'other-id',
            ),
          ),
        ),
      );
      expect(
        base,
        isNot(
          equals(
            const SettlementHistoryArgs(
              contextType: 'group',
              contextId: 'uid-friend_uid-me',
            ),
          ),
        ),
      );
    });
  });

  group('settlementHistoryProvider', () {
    test('resolves to the repository watchByContext stream', () async {
      final repo = FakeSettlementRepository(
        () => Stream.value([_settlement(0), _settlement(1)]),
      );
      final container = ProviderContainer(
        overrides: [settlementRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        settlementHistoryProvider(args).future,
      );

      expect(result, hasLength(2));
      expect(repo.lastContextType, 'friendship');
      expect(repo.lastContextId, 'uid-friend_uid-me');
    });

    test('applies the 50-item cap over a 76-item upstream list', () async {
      final upstream = List.generate(76, _settlement);
      final repo = FakeSettlementRepository(() => Stream.value(upstream));
      final container = ProviderContainer(
        overrides: [settlementRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        settlementHistoryProvider(args).future,
      );

      expect(result, hasLength(settlementHistoryItemCap));
      expect(result, hasLength(50));
      // The cap keeps the FIRST 50 (the repository already orders
      // date-desc, so these are the most recent).
      expect(result.first.settlementId, 'sid-0');
      expect(result.last.settlementId, 'sid-49');
    });

    test('a sub-cap list passes through unchanged', () async {
      final upstream = List.generate(3, _settlement);
      final repo = FakeSettlementRepository(() => Stream.value(upstream));
      final container = ProviderContainer(
        overrides: [settlementRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        settlementHistoryProvider(args).future,
      );

      expect(result, hasLength(3));
    });

    test('invalidation re-subscribes to the repository', () async {
      final repo = FakeSettlementRepository(
        () => Stream.value([_settlement(0)]),
      );
      final container = ProviderContainer(
        overrides: [settlementRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(settlementHistoryProvider(args).future);
      expect(repo.watchCallCount, 1);

      container.invalidate(settlementHistoryProvider(args));
      await container.read(settlementHistoryProvider(args).future);

      expect(repo.watchCallCount, 2);
    });
  });
}
