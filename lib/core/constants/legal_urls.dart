/// Canonical legal-document URLs.
///
/// SRS section 5.5 / section 10 require a privacy policy and terms of
/// service to be linked from the onboarding screen and the profile. They
/// are hosted under the `onebytwo.app` domain (mirroring the support
/// address in `RemoteConfigKeys`). Opened through the
/// `urlLauncherServiceProvider` system handler — never a specific
/// messaging app (Invariant 3 N/A: this is an outbound link, not sharing).
abstract final class LegalUrls {
  /// The terms-of-service document.
  static const String termsOfService = 'https://onebytwo.app/terms';

  /// The privacy-policy document.
  static const String privacyPolicy = 'https://onebytwo.app/privacy';
}
