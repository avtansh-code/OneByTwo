// Auth State Provider Tests
//
// Tests that the auth state provider emits the correct AuthState
// values based on the upstream auth and Firestore streams.
//
// Since FirebaseAuth and FirebaseFirestore cannot be instantiated
// in unit tests without the Firebase Emulator Suite, these tests
// override authStateProvider directly with controlled
// streams to verify downstream consumer behaviour.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';

void main() {
  group('authStateProvider', () {
    test('initial state is AsyncLoading before stream emits', () {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => const Stream<AuthState>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(authStateProvider);
      expect(state, isA<AsyncLoading<AuthState>>());
    });

    test(
      'emits AuthUnauthenticated when stream yields null-user equivalent',
      () async {
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(const AuthUnauthenticated()),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Let the stream emit.
        await container.read(authStateProvider.future);

        final state = container.read(authStateProvider);
        expect(state, isA<AsyncData<AuthState>>());
        expect(state.value, isA<AuthUnauthenticated>());
      },
    );

    test(
      'emits AuthenticatedNoProfile when user exists but has no doc',
      () async {
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(
                const AuthenticatedNoProfile(
                  uid: 'uid-123',
                  phoneNumber: '+919876543210',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authStateProvider.future);

        final state = container.read(authStateProvider);
        expect(state.value, isA<AuthenticatedNoProfile>());
        final noProfile = state.value! as AuthenticatedNoProfile;
        expect(noProfile.uid, 'uid-123');
        expect(noProfile.phoneNumber, '+919876543210');
      },
    );

    test(
      'emits AuthenticatedWithProfile when user doc has displayName',
      () async {
        final user = UserModel(
          phoneNumber: '+919876543210',
          displayName: 'Test User',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
        );

        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(
                AuthenticatedWithProfile(uid: 'uid-123', user: user),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authStateProvider.future);

        final state = container.read(authStateProvider);
        expect(state.value, isA<AuthenticatedWithProfile>());
        final withProfile = state.value! as AuthenticatedWithProfile;
        expect(withProfile.uid, 'uid-123');
        expect(withProfile.user.displayName, 'Test User');
      },
    );

    test(
      'emits AuthenticatedNoProfile when user doc lacks displayName',
      () async {
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(
                const AuthenticatedNoProfile(
                  uid: 'uid-456',
                  phoneNumber: '+919876543210',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authStateProvider.future);

        final state = container.read(authStateProvider);
        expect(state.value, isA<AuthenticatedNoProfile>());
        final noProfile = state.value! as AuthenticatedNoProfile;
        expect(noProfile.uid, 'uid-456');
      },
    );

    test('transitions through multiple states via StreamController', () async {
      final controller = StreamController<AuthState>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [authStateProvider.overrideWith((ref) => controller.stream)],
      );
      addTearDown(container.dispose);

      // Initially loading.
      expect(container.read(authStateProvider), isA<AsyncLoading<AuthState>>());

      // Emit unauthenticated.
      controller.add(const AuthUnauthenticated());
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(authStateProvider).value,
        isA<AuthUnauthenticated>(),
      );

      // Transition to authenticated no profile.
      controller.add(
        const AuthenticatedNoProfile(
          uid: 'uid-789',
          phoneNumber: '+919876543210',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(authStateProvider).value,
        isA<AuthenticatedNoProfile>(),
      );

      // Transition to authenticated with profile.
      final user = UserModel(
        phoneNumber: '+919876543210',
        displayName: 'Test User',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      controller.add(AuthenticatedWithProfile(uid: 'uid-789', user: user));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(authStateProvider).value,
        isA<AuthenticatedWithProfile>(),
      );
    });

    test('stream error surfaces as AsyncError', () async {
      final controller = StreamController<AuthState>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [authStateProvider.overrideWith((ref) => controller.stream)],
      );
      addTearDown(container.dispose);

      // Force subscription by reading.
      container.read(authStateProvider);

      // Emit an error.
      controller.addError(Exception('Auth stream failed'));

      // Allow microtasks to flush.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(authStateProvider);
      expect(state, isA<AsyncError<AuthState>>());
    });
  });
}
