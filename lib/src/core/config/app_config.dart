class AppConfig {
  const AppConfig._();

  static const baseUrl = String.fromEnvironment(
    'BOOKAT_API_BASE_URL',
    defaultValue: 'https://api-bookat.tsgtech.co/api',
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
