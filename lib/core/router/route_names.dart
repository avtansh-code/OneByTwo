/// Route name constants for GoRouter navigation.
///
/// All route names are defined here to avoid magic strings throughout the app.
/// Use these constants with `GoRouter.goNamed()` or `context.goNamed()`.
abstract final class RouteNames {
  /// Splash / loading screen shown during app initialisation.
  static const String splash = 'splash';

  /// Welcome / onboarding screen for unauthenticated users.
  static const String welcome = 'welcome';

  /// Phone number input screen (auth step 1).
  static const String phoneInput = 'phone-input';

  /// OTP verification screen (auth step 2).
  static const String otpVerification = 'otp-verification';

  /// Profile setup screen for new users (auth step 3).
  static const String profileSetup = 'profile-setup';

  /// Main home screen with bottom navigation.
  static const String home = 'home';

  /// Group detail screen. Requires `groupId` path parameter.
  static const String groupDetail = 'group-detail';

  /// Create new group screen.
  static const String createGroup = 'create-group';

  /// Group settings screen. Requires `groupId` path parameter.
  static const String groupSettings = 'group-settings';

  /// Add expense screen. Optionally scoped to a group via query parameter.
  static const String addExpense = 'add-expense';

  /// Expense detail screen. Requires `expenseId` path parameter.
  static const String expenseDetail = 'expense-detail';

  /// Friend detail screen. Requires `friendId` path parameter.
  static const String friendDetail = 'friend-detail';

  /// Add friend screen.
  static const String addFriend = 'add-friend';

  /// Settle up screen. Optionally scoped to a friend or group.
  static const String settleUp = 'settle-up';

  /// Activity feed screen.
  static const String activityFeed = 'activity-feed';

  /// Analytics / spending insights screen.
  static const String analytics = 'analytics';

  /// Search screen.
  static const String search = 'search';

  /// Notifications screen.
  static const String notifications = 'notifications';

  /// Settings screen.
  static const String settings = 'settings';

  /// Profile edit screen.
  static const String profileEdit = 'profile-edit';
}
