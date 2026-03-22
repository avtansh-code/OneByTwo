import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';
import 'package:one_by_two/data/remote/auth/firebase_auth_source.dart';
import 'package:one_by_two/data/repositories/auth_repository_impl.dart';

class MockFirebaseAuthSource extends Mock implements FirebaseAuthSource {}

void main() {
  late MockFirebaseAuthSource mockAuthSource;
  late AuthRepositoryImpl repository;

  setUp(() {
    mockAuthSource = MockFirebaseAuthSource();
    repository = AuthRepositoryImpl(mockAuthSource);
  });

  group('AuthRepositoryImpl', () {
    // ── sendOtp ─────────────────────────────────────────────────────────

    group('sendOtp', () {
      test(
        'should return Success with verificationId when source succeeds',
        () async {
          // Arrange
          when(
            () => mockAuthSource.sendOtp(any()),
          ).thenAnswer((_) async => 'verification-id-abc');

          // Act
          final result = await repository.sendOtp('+919876543210');

          // Assert
          expect(result.isSuccess, isTrue);
          expect(
            (result as Success<String>).data,
            equals('verification-id-abc'),
          );
          verify(() => mockAuthSource.sendOtp('+919876543210')).called(1);
        },
      );

      test(
        'should return Failure with AuthException when source throws AuthException',
        () async {
          // Arrange
          when(() => mockAuthSource.sendOtp(any())).thenThrow(
            const AuthException('Rate limited', code: 'too-many-requests'),
          );

          // Act
          final result = await repository.sendOtp('+919876543210');

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<String>;
          expect(failure.exception, isA<AuthException>());
          expect(failure.exception.code, equals('too-many-requests'));
          expect(failure.exception.message, equals('Rate limited'));
        },
      );

      test(
        'should return Failure with UnknownException for unexpected errors',
        () async {
          // Arrange
          when(
            () => mockAuthSource.sendOtp(any()),
          ).thenThrow(Exception('Unexpected'));

          // Act
          final result = await repository.sendOtp('+919876543210');

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<String>;
          expect(failure.exception, isA<UnknownException>());
          final unknown = failure.exception as UnknownException;
          expect(unknown.originalError, isA<Exception>());
        },
      );
    });

    // ── verifyOtp ───────────────────────────────────────────────────────

    group('verifyOtp', () {
      test('should return Success with uid when source succeeds', () async {
        // Arrange
        when(
          () => mockAuthSource.verifyOtp(
            verificationId: any(named: 'verificationId'),
            otp: any(named: 'otp'),
          ),
        ).thenAnswer((_) async => 'user-uid-123');

        // Act
        final result = await repository.verifyOtp(
          verificationId: 'vid-abc',
          otp: '123456',
        );

        // Assert
        expect(result.isSuccess, isTrue);
        expect((result as Success<String>).data, equals('user-uid-123'));
        verify(
          () => mockAuthSource.verifyOtp(
            verificationId: 'vid-abc',
            otp: '123456',
          ),
        ).called(1);
      });

      test(
        'should return Failure with AuthException when OTP is invalid',
        () async {
          // Arrange
          when(
            () => mockAuthSource.verifyOtp(
              verificationId: any(named: 'verificationId'),
              otp: any(named: 'otp'),
            ),
          ).thenThrow(
            const AuthException(
              'Invalid OTP',
              code: 'invalid-verification-code',
            ),
          );

          // Act
          final result = await repository.verifyOtp(
            verificationId: 'vid',
            otp: '000000',
          );

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<String>;
          expect(failure.exception, isA<AuthException>());
          expect(failure.exception.code, equals('invalid-verification-code'));
        },
      );

      test(
        'should return Failure with UnknownException for unexpected errors',
        () async {
          // Arrange
          when(
            () => mockAuthSource.verifyOtp(
              verificationId: any(named: 'verificationId'),
              otp: any(named: 'otp'),
            ),
          ).thenThrow(Exception('Something went wrong'));

          // Act
          final result = await repository.verifyOtp(
            verificationId: 'vid',
            otp: '123456',
          );

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<UnknownException>());
        },
      );
    });

    // ── signOut ─────────────────────────────────────────────────────────

    group('signOut', () {
      test('should return Success when source succeeds', () async {
        // Arrange
        when(() => mockAuthSource.signOut()).thenAnswer((_) async {});

        // Act
        final result = await repository.signOut();

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockAuthSource.signOut()).called(1);
      });

      test(
        'should return Failure with AuthException when source throws AuthException',
        () async {
          // Arrange
          when(() => mockAuthSource.signOut()).thenThrow(
            const AuthException('Sign-out failed', code: 'sign-out-error'),
          );

          // Act
          final result = await repository.signOut();

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<void>;
          expect(failure.exception, isA<AuthException>());
          expect(failure.exception.code, equals('sign-out-error'));
        },
      );

      test(
        'should return Failure with UnknownException for unexpected errors',
        () async {
          // Arrange
          when(
            () => mockAuthSource.signOut(),
          ).thenThrow(Exception('Unexpected'));

          // Act
          final result = await repository.signOut();

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<UnknownException>());
        },
      );
    });

    // ── deleteAccount ───────────────────────────────────────────────────

    group('deleteAccount', () {
      test('should return Success when source succeeds', () async {
        // Arrange
        when(() => mockAuthSource.deleteAccount()).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteAccount();

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockAuthSource.deleteAccount()).called(1);
      });

      test(
        'should return Failure with AuthException when source throws AuthException',
        () async {
          // Arrange
          when(() => mockAuthSource.deleteAccount()).thenThrow(
            const AuthException(
              'Re-authentication required',
              code: 'requires-recent-login',
            ),
          );

          // Act
          final result = await repository.deleteAccount();

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<void>;
          expect(failure.exception, isA<AuthException>());
          expect(failure.exception.code, equals('requires-recent-login'));
        },
      );

      test(
        'should return Failure with AuthException when no user is signed in',
        () async {
          // Arrange
          when(() => mockAuthSource.deleteAccount()).thenThrow(
            const AuthException(
              'No authenticated user to delete',
              code: 'no-user',
            ),
          );

          // Act
          final result = await repository.deleteAccount();

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<void>;
          expect(failure.exception, isA<AuthException>());
          expect(failure.exception.code, equals('no-user'));
        },
      );

      test(
        'should return Failure with UnknownException for unexpected errors',
        () async {
          // Arrange
          when(
            () => mockAuthSource.deleteAccount(),
          ).thenThrow(Exception('Crash'));

          // Act
          final result = await repository.deleteAccount();

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<UnknownException>());
        },
      );
    });

    // ── authStateChanges ────────────────────────────────────────────────

    group('authStateChanges', () {
      test('should forward stream from source', () {
        // Arrange
        when(
          () => mockAuthSource.authStateChanges(),
        ).thenAnswer((_) => Stream.fromIterable(['uid-1', null, 'uid-2']));

        // Act
        final stream = repository.authStateChanges();

        // Assert
        expect(stream, emitsInOrder(['uid-1', null, 'uid-2']));
      });

      test('should emit null when user is signed out', () {
        // Arrange
        when(
          () => mockAuthSource.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        // Act
        final stream = repository.authStateChanges();

        // Assert
        expect(stream, emits(isNull));
      });

      test('should emit uid when user is signed in', () {
        // Arrange
        when(
          () => mockAuthSource.authStateChanges(),
        ).thenAnswer((_) => Stream.value('user-uid'));

        // Act
        final stream = repository.authStateChanges();

        // Assert
        expect(stream, emits('user-uid'));
      });
    });

    // ── currentUserId ───────────────────────────────────────────────────

    group('currentUserId', () {
      test('should return uid from source when user is signed in', () {
        // Arrange
        when(() => mockAuthSource.currentUserId).thenReturn('user-uid-123');

        // Act
        final uid = repository.currentUserId;

        // Assert
        expect(uid, equals('user-uid-123'));
      });

      test('should return null from source when no user is signed in', () {
        // Arrange
        when(() => mockAuthSource.currentUserId).thenReturn(null);

        // Act
        final uid = repository.currentUserId;

        // Assert
        expect(uid, isNull);
      });
    });
  });
}
