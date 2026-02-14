/// Application-wide constants
class AppConstants {
  AppConstants._();
  
  /// Application name
  static const String appName = 'OneByTwo';
  
  /// Application tagline
  static const String appTagline = 'Split expenses. Not friendships.';
  
  /// Currency symbol (Indian Rupee)
  static const String currencySymbol = '₹';
  
  /// Currency code
  static const String currencyCode = 'INR';
  
  /// Default country code for phone numbers
  static const String defaultCountryCode = '+91';
  
  /// Minimum expense amount in paise (₹1 = 100 paise)
  static const int minExpenseAmount = 100; // ₹1
  
  /// Maximum expense amount in paise (₹10,00,000 = 100000000 paise)
  static const int maxExpenseAmount = 100000000; // ₹10,00,000
  
  /// Minimum group size
  static const int minGroupSize = 2;
  
  /// Maximum group size
  static const int maxGroupSize = 50;
  
  /// Maximum description length
  static const int maxDescriptionLength = 200;
  
  /// Maximum group name length
  static const int maxGroupNameLength = 50;
  
  /// Date format for display (DD MMM YYYY)
  static const String dateFormat = 'dd MMM yyyy';
  
  /// Date time format for display (DD MMM YYYY, HH:MM)
  static const String dateTimeFormat = 'dd MMM yyyy, HH:mm';
  
  /// Time format for display (HH:MM)
  static const String timeFormat = 'HH:mm';
  
  /// Phone number length (without country code)
  static const int phoneNumberLength = 10;
  
  /// OTP length
  static const int otpLength = 6;
  
  /// OTP resend timeout (seconds)
  static const int otpResendTimeout = 30;
  
  /// Profile picture max size (5 MB in bytes)
  static const int maxProfilePictureSize = 5 * 1024 * 1024;
  
  /// Receipt image max size (10 MB in bytes)
  static const int maxReceiptImageSize = 10 * 1024 * 1024;
  
  /// Network timeout (seconds)
  static const int networkTimeout = 30;
  
  /// Cache expiry duration (hours)
  static const int cacheExpiryHours = 24;
  
  /// Pagination page size
  static const int pageSize = 20;
  
  /// Animation duration (milliseconds)
  static const int animationDuration = 300;
  
  /// Debounce duration for search (milliseconds)
  static const int searchDebounceDuration = 500;
}
