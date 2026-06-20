// FR-SE-09 AC-3 cross-launch cooldown render test.
//
// Proves the provider -> card binding end-to-end after a simulated
// restart: a future `nextAllowedAt` persisted in a previous session
// (seeded directly on the KeyValueStore) hydrates `reminderCooldownProvider`
// on the FIRST build of a fresh ProviderScope, so the receiving-direction
// OBTSettleUpCard renders the disabled-with-countdown state without any
// `set()` call. Mirrors the production binding in
// `_ReceivingDirectionCard.build` (friend_detail_screen.dart): the card's
// `nextAllowedAt` is `ref.watch(reminderCooldownProvider(friendshipId))`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/persistence/preference_keys.dart';
import 'package:onebytwo/core/services/key_value_store.dart';
import 'package:onebytwo/features/friends/presentation/widgets/obt_settle_up_card.dart';
import 'package:onebytwo/features/reminders/application/reminder_cooldown_provider.dart';

const _friendshipId = 'uid-a_uid-b';

/// A minimal host that reproduces the production binding: the card's
/// `nextAllowedAt` is driven by `reminderCooldownProvider`.
class _CooldownBoundCard extends ConsumerWidget {
  const _CooldownBoundCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cooldown = ref.watch(reminderCooldownProvider(_friendshipId));
    return OBTSettleUpCard(
      payerDisplayName: 'Priya',
      payerPhotoUrl: null,
      payeeDisplayName: 'You',
      payeePhotoUrl: null,
      suggestedAmountPaise: 50000,
      onSettleUp: () {},
      isReceivingDirection: true,
      nextAllowedAt: cooldown,
      onSendReminder: () {},
    );
  }
}

Future<void> _pump(WidgetTester tester, KeyValueStore store) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: Scaffold(body: _CooldownBoundCard())),
    ),
  );
}

FilledButton _sendReminderButton(WidgetTester tester) {
  return tester.widget<FilledButton>(find.byType(FilledButton));
}

void main() {
  group('FR-SE-09 AC-3 — cooldown hydrates the card after a restart', () {
    testWidgets('a future cooldown persisted in a previous session renders '
        'the disabled-with-countdown state on first build', (tester) async {
      final store = InMemoryKeyValueStore();
      // A value persisted ~5 hours ahead in a previous session.
      final future = DateTime.now().add(const Duration(hours: 5));
      await store.setString(
        PreferenceKeys.reminderCooldown(_friendshipId),
        future.toIso8601String(),
      );

      await _pump(tester, store);

      // The Send Reminder CTA is present but disabled (cooling), with the
      // live countdown caption — driven purely by provider hydration.
      expect(find.text('Send Reminder'), findsOneWidget);
      expect(_sendReminderButton(tester).onPressed, isNull);
      expect(find.textContaining('Next reminder in'), findsOneWidget);
    });

    testWidgets('a fresh install (empty store) renders the enabled CTA with '
        'no countdown', (tester) async {
      await _pump(tester, InMemoryKeyValueStore());

      expect(find.text('Send Reminder'), findsOneWidget);
      expect(_sendReminderButton(tester).onPressed, isNotNull);
      expect(find.textContaining('Next reminder'), findsNothing);
    });

    testWidgets('an elapsed cooldown (expiry guard) renders the enabled CTA '
        'with no countdown after a restart', (tester) async {
      final store = InMemoryKeyValueStore();
      // A clearly-past value that must hydrate as null (expiry guard).
      await store.setString(
        PreferenceKeys.reminderCooldown(_friendshipId),
        DateTime.utc(2000).toIso8601String(),
      );

      await _pump(tester, store);

      expect(_sendReminderButton(tester).onPressed, isNotNull);
      expect(find.textContaining('Next reminder'), findsNothing);
    });
  });
}
