import 'package:flutter/foundation.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';

/// Sealed union representing the application's authentication state.
///
/// Used by the auth gate to determine which screen to display.
/// The four states map to the routing logic documented in
/// `docs/design/04-wireframes/auth-flow.md` section 1 (Splash Screen).
@immutable
sealed class AuthState {
  /// Creates an [AuthState].
  const AuthState();
}

/// Auth state is being determined (cold-start loading).
///
/// The splash screen is shown during this state. A 3-second widget-level
/// timer triggers a "Having trouble?" recovery option if this state
/// persists too long.
final class AuthLoading extends AuthState {
  /// Creates an [AuthLoading].
  const AuthLoading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AuthLoading;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// No authenticated Firebase user exists.
///
/// The phone entry screen is shown.
final class AuthUnauthenticated extends AuthState {
  /// Creates an [AuthUnauthenticated].
  const AuthUnauthenticated();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AuthUnauthenticated;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// A Firebase user exists but has no complete Firestore profile.
///
/// The profile setup screen is shown so the user can enter their
/// display name (FR-AU-06).
final class AuthenticatedNoProfile extends AuthState {
  /// Creates an [AuthenticatedNoProfile].
  const AuthenticatedNoProfile({required this.uid, this.phoneNumber});

  /// The authenticated user's UID.
  final String uid;

  /// The user's verified phone number in E.164 format.
  final String? phoneNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticatedNoProfile &&
          uid == other.uid &&
          phoneNumber == other.phoneNumber;

  @override
  int get hashCode => Object.hash(uid, phoneNumber);
}

/// A Firebase user exists with a complete Firestore profile.
///
/// The home screen is shown.
final class AuthenticatedWithProfile extends AuthState {
  /// Creates an [AuthenticatedWithProfile].
  const AuthenticatedWithProfile({required this.uid, required this.user});

  /// The authenticated user's UID.
  final String uid;

  /// The user's Firestore profile document.
  final UserModel user;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticatedWithProfile && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
