/// Route path constants for GoRouter.
///
/// Paths correspond one-to-one with [RouteNames]. Path parameters use
/// the `:param` syntax recognised by GoRouter.
abstract final class RoutePaths {
  /// `/splash`
  static const String splash = '/splash';

  /// `/welcome`
  static const String welcome = '/welcome';

  /// `/welcome/phone`
  static const String phoneInput = 'phone';

  /// `/welcome/phone/otp`
  static const String otpVerification = 'otp';

  // Fix: Profile setup moved to root level so the `/welcome/*` → home redirect
  // for authenticated users does not block new users from reaching this screen.
  // Previously at `/welcome/profile-setup`, any authenticated user was
  // immediately redirected to home before they could set up their profile.
  /// `/profile-setup`
  static const String profileSetup = '/profile-setup';

  /// `/` — root path for the home shell.
  static const String home = '/';

  /// `/groups/:groupId`
  static const String groupDetail = '/groups/:groupId';

  /// `/groups/create`
  static const String createGroup = '/groups/create';

  /// `/groups/:groupId/settings`
  static const String groupSettings = '/groups/:groupId/settings';

  /// `/expenses/add`
  static const String addExpense = '/expenses/add';

  /// `/expenses/:expenseId`
  static const String expenseDetail = '/expenses/:expenseId';

  /// `/friends/:friendId`
  static const String friendDetail = '/friends/:friendId';

  /// `/friends/add`
  static const String addFriend = '/friends/add';

  /// `/settle-up`
  static const String settleUp = '/settle-up';

  /// `/activity`
  static const String activityFeed = '/activity';

  /// `/analytics`
  static const String analytics = '/analytics';

  /// `/search`
  static const String search = '/search';

  /// `/notifications`
  static const String notifications = '/notifications';

  /// `/settings`
  static const String settings = '/settings';

  /// `/settings/profile`
  static const String profileEdit = '/settings/profile';
}
