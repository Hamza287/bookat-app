class AppConfig {
  const AppConfig._();

  static const baseUrl = String.fromEnvironment(
    'BOOKAT_API_BASE_URL',
    defaultValue: 'https://api-bookat.tsgtech.co/api',
  );

  /// Public site. Business accounts are created here rather than in the app,
  /// so the signup screen links out to it.
  static const websiteUrl = String.fromEnvironment(
    'BOOKAT_WEBSITE_URL',
    defaultValue: 'https://bookat.tsgtech.co',
  );

  /// OAuth *web* client id for Google sign-in.
  ///
  /// Normally left empty: the platform plugins read it from
  /// google-services.json / GoogleService-Info.plist. Set it only to override
  /// what those files carry.
  static const googleServerClientId = String.fromEnvironment(
    'BOOKAT_GOOGLE_SERVER_CLIENT_ID',
  );

  static const mediaBaseUrl = String.fromEnvironment(
    'BOOKAT_MEDIA_BASE_URL',
    defaultValue: 'https://bookat.tsgtech.co',
  );

  static const useMockData = bool.fromEnvironment(
    'BOOKAT_USE_MOCK_DATA',
    defaultValue: false,
  );
}
