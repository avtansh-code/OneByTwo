/// Application environment configuration
enum AppEnvironment {
  /// Development environment
  dev('dev'),
  
  /// Staging environment
  staging('staging'),
  
  /// Production environment
  prod('prod');
  
  const AppEnvironment(this.name);
  
  final String name;
}

/// Application configuration that reads from build flavor
/// 
/// This class provides environment-specific configuration values.
/// Set the environment using --dart-define=ENV=dev|staging|prod
class AppConfig {
  AppConfig._();
  
  /// Current app environment
  static AppEnvironment get environment {
    const envString = String.fromEnvironment('ENV', defaultValue: 'dev');
    return switch (envString) {
      'prod' => AppEnvironment.prod,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.dev,
    };
  }
  
  /// Is this a debug build
  static bool get isDebug {
    var isDebugMode = false;
    assert(
      () {
        isDebugMode = true;
        return true;
      }(),
      'Debug mode check',
    );
    return isDebugMode;
  }
  
  /// Is this a production environment
  static bool get isProduction => environment == AppEnvironment.prod;
  
  /// Is this a development environment
  static bool get isDevelopment => environment == AppEnvironment.dev;
  
  /// Is this a staging environment
  static bool get isStaging => environment == AppEnvironment.staging;
  
  /// Enable verbose logging
  static bool get enableVerboseLogging => isDebug || isDevelopment;
  
  /// Enable Firebase Crashlytics
  static bool get enableCrashlytics => !isDebug && (isProduction || isStaging);
  
  /// Enable Firebase Analytics
  static bool get enableAnalytics => !isDebug && (isProduction || isStaging);
  
  /// Sync queue processing interval (milliseconds)
  static int get syncQueueInterval => switch (environment) {
    AppEnvironment.prod => 5000,      // 5 seconds
    AppEnvironment.staging => 3000,   // 3 seconds
    AppEnvironment.dev => 10000,      // 10 seconds for easier debugging
  };
  
  /// Maximum retry attempts for sync operations
  static int get maxSyncRetries => 3;
  
  /// Local database name
  static String get databaseName => 'one_by_two.db';
  
  /// Local database version
  static int get databaseVersion => 1;
}
