import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';

/// App-scoped dependency-injection provider for the [PhoneAuthRepository].
///
/// Lives in `lib/core/providers/` (outside the auth feature tree) because it
/// is consumed across features (auth, profile sign-out, account deletion).
/// See `docs/design/07-technical/state-management.md` section 4.
///
/// Override in tests with a fake implementation to avoid Firebase
/// initialisation.
final phoneAuthRepositoryProvider = Provider<PhoneAuthRepository>(
  (ref) => FirebasePhoneAuthRepository(),
);
