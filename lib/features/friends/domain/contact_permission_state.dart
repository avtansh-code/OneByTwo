/// Permission states for device contact access.
enum ContactPermissionState {
  /// Permission has not been requested yet.
  notDetermined,

  /// Permission has been granted.
  granted,

  /// Permission has been denied (can still re-prompt on Android).
  denied,

  /// Permission permanently denied (Android "don't ask again"; iOS denied).
  deniedPermanently,
}
