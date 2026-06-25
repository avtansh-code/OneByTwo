// D8 regression: a `ProviderScope` applied via `MaterialApp.builder` (which
// wraps the root Navigator) must be inherited by modals pushed on the root
// Navigator — e.g. the add-expense context picker.
//
// Before the fix the per-arm scope lived inside `MaterialApp.home`, below the
// root Navigator, so a root-Navigator modal could not see it and
// `currentUserIdProvider` threw `UnimplementedError`, surfacing as
// "Something went wrong loading your friends" in the picker (issue #102).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/features/friends/application/friends_list_provider.dart';

void main() {
  testWidgets(
    'a modal on the root Navigator inherits a builder-applied ProviderScope '
    'override of currentUserIdProvider (D8)',
    (tester) async {
      late BuildContext navContext;

      await tester.pumpWidget(
        // The root scope intentionally does NOT override
        // `currentUserIdProvider` — mirroring the production root
        // `ProviderScope`, where the unscoped provider throws.
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                navContext = context;
                return const Scaffold();
              },
            ),
            // Production structure (lib/main.dart): the per-arm override is
            // applied here, wrapping the root Navigator — NOT inside `home`.
            builder: (context, child) => ProviderScope(
              overrides: [
                currentUserIdProvider.overrideWithValue('uid-under-test'),
              ],
              child: child!,
            ),
          ),
        ),
      );

      // Push a modal on the root Navigator (the default for
      // `showModalBottomSheet`) that reads the scoped provider.
      String? readUid;
      Object? thrown;
      unawaited(
        showModalBottomSheet<void>(
          context: navContext,
          builder: (_) => Consumer(
            builder: (context, ref, _) {
              try {
                readUid = ref.watch(currentUserIdProvider);
              } on Object catch (e) {
                thrown = e;
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        thrown,
        isNull,
        reason:
            'currentUserIdProvider must resolve inside a root-Navigator modal '
            'via the builder-applied scope (regressed if the scope moves back '
            'into MaterialApp.home).',
      );
      expect(readUid, 'uid-under-test');
    },
  );
}
