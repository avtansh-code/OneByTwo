import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:one_by_two/data/remote/auth/firebase_auth_source.dart';
import 'package:one_by_two/data/remote/firestore/user_firestore_source.dart';
import 'package:one_by_two/data/repositories/auth_repository_impl.dart';
import 'package:one_by_two/data/repositories/user_repository_impl.dart';
import 'package:one_by_two/domain/entities/app_locale.dart';
import 'package:one_by_two/domain/entities/notification_prefs.dart';
import 'package:one_by_two/domain/entities/user.dart';
import 'package:one_by_two/domain/repositories/auth_repository.dart';
import 'package:one_by_two/domain/repositories/user_repository.dart';
import 'package:one_by_two/domain/usecases/auth/send_otp_use_case.dart';
import 'package:one_by_two/domain/usecases/auth/sign_out_use_case.dart';
import 'package:one_by_two/domain/usecases/auth/verify_otp_use_case.dart';
import 'package:one_by_two/domain/usecases/user/create_user_use_case.dart';

part 'auth_providers.g.dart';

// ---------------------------------------------------------------------------
// Firebase instance providers
// ---------------------------------------------------------------------------

/// Provides the singleton [FirebaseAuth] instance.
///
/// All authentication operations in the app flow through this provider,
/// making it easy to override in tests with a mock [FirebaseAuth].
@riverpod
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

/// Provides the singleton [FirebaseFirestore] instance.
///
/// All Firestore operations in the app flow through this provider,
/// making it easy to override in tests with a mock [FirebaseFirestore].
@riverpod
FirebaseFirestore firebaseFirestore(Ref ref) => FirebaseFirestore.instance;

// ---------------------------------------------------------------------------
// Data source providers
// ---------------------------------------------------------------------------

/// Provides a [FirebaseAuthSource] wired to the app's [FirebaseAuth] instance.
///
/// This is the single data source for all phone-based OTP authentication
/// operations. It is constructed with the [FirebaseAuth] from
/// [firebaseAuthProvider].
@riverpod
FirebaseAuthSource firebaseAuthSource(Ref ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return FirebaseAuthSource(auth);
}

/// Provides a [UserFirestoreSource] wired to the app's [FirebaseFirestore]
/// instance.
///
/// This is the single data source for all user document CRUD operations
/// against the `users/{uid}` Firestore collection. It is constructed with
/// the [FirebaseFirestore] from [firebaseFirestoreProvider].
@riverpod
UserFirestoreSource userFirestoreSource(Ref ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return UserFirestoreSource(firestore);
}

// ---------------------------------------------------------------------------
// Repository providers
// ---------------------------------------------------------------------------

/// Provides the [AuthRepository] implementation backed by Firebase Auth.
///
/// This is the domain-facing contract for authentication operations.
/// The concrete [AuthRepositoryImpl] delegates to [FirebaseAuthSource].
@riverpod
AuthRepository authRepository(Ref ref) {
  final authSource = ref.watch(firebaseAuthSourceProvider);
  return AuthRepositoryImpl(authSource);
}

/// Provides the [UserRepository] implementation backed by Firestore.
///
/// This is the domain-facing contract for user profile CRUD operations.
/// The concrete [UserRepositoryImpl] delegates to [UserFirestoreSource].
@riverpod
UserRepository userRepository(Ref ref) {
  final userSource = ref.watch(userFirestoreSourceProvider);
  return UserRepositoryImpl(userSource);
}

// ---------------------------------------------------------------------------
// Auth state provider
// ---------------------------------------------------------------------------

/// Stream provider that emits the current user's UID or `null`.
///
/// Listens to [AuthRepository.authStateChanges] which fires immediately
/// with the current auth state and then on every subsequent change
/// (sign-in, sign-out, token refresh).
///
/// Widgets can use this to determine whether to show the auth flow
/// or the main app shell:
///
/// ```dart
/// final authState = ref.watch(authStateProvider);
/// authState.when(
///   data: (uid) => uid != null ? HomeScreen() : LoginScreen(),
///   loading: () => SplashScreen(),
///   error: (e, st) => ErrorScreen(),
/// );
/// ```
@riverpod
Stream<String?> authState(Ref ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
}

// ---------------------------------------------------------------------------
// Current user provider
// ---------------------------------------------------------------------------

/// Stream provider that watches the authenticated user's Firestore document.
///
/// Returns `null` when:
/// - No user is signed in (auth state is `null`).
/// - The user document does not yet exist in Firestore (new sign-up).
///
/// Automatically re-subscribes when the auth state changes (e.g., after
/// sign-out and sign-in with a different account).
@riverpod
Stream<User?> currentUser(Ref ref) {
  final authState = ref.watch(authStateProvider).valueOrNull;
  if (authState == null) return Stream.value(null);

  final userRepo = ref.watch(userRepositoryProvider);
  return userRepo.watchUser(authState);
}

// ---------------------------------------------------------------------------
// Send OTP notifier
// ---------------------------------------------------------------------------

/// Async notifier that manages the OTP-sending workflow.
///
/// ## State
/// - **Initial:** `AsyncData(null)` — no OTP has been requested yet.
/// - **Loading:** `AsyncLoading` — OTP request is in flight.
/// - **Success:** `AsyncData(verificationId)` — OTP sent; the verification ID
///   is needed by [VerifyOtpNotifier] to complete sign-in.
/// - **Error:** `AsyncError(exception)` — OTP sending failed (invalid number,
///   rate limit, network error, etc.).
///
/// Call [sendOtp] with an E.164-formatted Indian phone number to initiate
/// the flow.
@riverpod
class SendOtpNotifier extends _$SendOtpNotifier {
  @override
  FutureOr<String?> build() => null;

  /// Sends an OTP to [phoneNumber] via Firebase Phone Auth.
  ///
  /// [phoneNumber] must be in E.164 format (e.g., `+919876543210`).
  /// The [SendOtpUseCase] validates the format before calling the
  /// repository.
  ///
  /// On success, state becomes `AsyncData(verificationId)`.
  /// On failure, state becomes `AsyncError(exception)`.
  Future<void> sendOtp(String phoneNumber) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final useCase = SendOtpUseCase(repo);
    final result = await useCase.call(phoneNumber);
    state = result.when(
      success: (verificationId) => AsyncData(verificationId),
      failure: (exception) => AsyncError(exception, StackTrace.current),
    );
  }
}

// ---------------------------------------------------------------------------
// Verify OTP notifier
// ---------------------------------------------------------------------------

/// Async notifier that manages the OTP-verification workflow.
///
/// ## State
/// - **Initial:** `AsyncData(null)` — no verification attempt yet.
/// - **Loading:** `AsyncLoading` — verification is in progress.
/// - **Success:** `AsyncData(uid)` — OTP verified; the user is now signed in
///   and `uid` is their Firebase Auth UID.
/// - **Error:** `AsyncError(exception)` — verification failed (wrong code,
///   expired, etc.).
///
/// Call [verifyOtp] with the `verificationId` from [SendOtpNotifier] and
/// the 6-digit OTP entered by the user.
@riverpod
class VerifyOtpNotifier extends _$VerifyOtpNotifier {
  @override
  FutureOr<String?> build() => null;

  /// Verifies the [otp] against the given [verificationId].
  ///
  /// [verificationId] is the ID returned by [SendOtpNotifier.sendOtp].
  /// [otp] must be exactly 6 numeric digits.
  ///
  /// On success, state becomes `AsyncData(uid)` where `uid` is the
  /// authenticated user's Firebase Auth UID.
  /// On failure, state becomes `AsyncError(exception)`.
  Future<void> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final useCase = VerifyOtpUseCase(repo);
    final result = await useCase.call(verificationId: verificationId, otp: otp);
    state = result.when(
      success: (uid) => AsyncData(uid),
      failure: (exception) => AsyncError(exception, StackTrace.current),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile setup notifier
// ---------------------------------------------------------------------------

/// Async notifier that handles creating a new user profile in Firestore.
///
/// ## State
/// - **Initial:** `AsyncData(null)` — no profile creation attempted.
/// - **Loading:** `AsyncLoading` — profile creation is in progress.
/// - **Success:** `AsyncData(null)` — profile created successfully.
/// - **Error:** `AsyncError(exception)` — profile creation failed.
///
/// Call [createProfile] after successful OTP verification to create the
/// user document in the `users/{uid}` Firestore collection.
@riverpod
class ProfileSetupNotifier extends _$ProfileSetupNotifier {
  @override
  FutureOr<void> build() => null;

  /// Creates a new user profile document in Firestore.
  ///
  /// [uid] is the Firebase Auth UID from [VerifyOtpNotifier].
  /// [name] is the user's display name (must not be empty).
  /// [phone] is the user's phone number in E.164 format.
  /// [email] is an optional email address.
  /// [avatarUrl] is an optional HTTPS URL to the user's avatar image.
  ///
  /// Returns `true` if the profile was created successfully, `false`
  /// otherwise. The notifier state is also updated accordingly.
  Future<bool> createProfile({
    required String uid,
    required String name,
    required String phone,
    String? email,
    String? avatarUrl,
  }) async {
    state = const AsyncLoading();
    final userRepo = ref.read(userRepositoryProvider);
    final useCase = CreateUserUseCase(userRepo);

    final user = User(
      id: uid,
      name: name,
      phone: phone,
      email: email,
      avatarUrl: avatarUrl,
      language: AppLocale.en,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      fcmTokens: const [],
      notificationPrefs: const NotificationPrefs(),
      isDeleted: false,
    );

    final result = await useCase.call(user);
    return result.when(
      success: (_) {
        state = const AsyncData(null);
        return true;
      },
      failure: (exception) {
        state = AsyncError(exception, StackTrace.current);
        return false;
      },
    );
  }
}

// ---------------------------------------------------------------------------
// User exists provider
// ---------------------------------------------------------------------------

/// Future provider that checks whether a user profile exists in Firestore.
///
/// Returns `true` if a document exists at `users/{uid}`, `false` otherwise.
/// Falls back to `false` if the Firestore check fails (e.g., offline with
/// no cache).
///
/// This provider is family-scoped on [uid], so each unique UID gets its
/// own cached result.
@riverpod
Future<bool> userExists(Ref ref, String uid) async {
  final userRepo = ref.watch(userRepositoryProvider);
  final result = await userRepo.userExists(uid);
  return result.when(success: (exists) => exists, failure: (_) => false);
}

// ---------------------------------------------------------------------------
// Sign out notifier
// ---------------------------------------------------------------------------

/// Async notifier that manages the sign-out workflow.
///
/// ## State
/// - **Initial:** `AsyncData(null)` — idle.
/// - **Loading:** `AsyncLoading` — sign-out is in progress.
/// - **Success:** `AsyncData(null)` — sign-out completed. The
///   [authStateProvider] will subsequently emit `null`, triggering
///   navigation to the login screen.
/// - **Error:** `AsyncError(exception)` — sign-out failed.
///
/// Call [signOut] to sign out the currently authenticated user.
@riverpod
class SignOutNotifier extends _$SignOutNotifier {
  @override
  FutureOr<void> build() => null;

  /// Signs out the currently authenticated user.
  ///
  /// Delegates to [SignOutUseCase] which calls [AuthRepository.signOut].
  /// On success, the [authStateProvider] stream will emit `null`,
  /// causing the router to redirect to the login screen.
  Future<void> signOut() async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final useCase = SignOutUseCase(repo);
    final result = await useCase.call();
    state = result.when(
      success: (_) => const AsyncData(null),
      failure: (exception) => AsyncError(exception, StackTrace.current),
    );
  }
}
