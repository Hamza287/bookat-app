class AppConfig {
  const AppConfig._();

  static const baseUrl = String.fromEnvironment(
    'BOOKAT_API_BASE_URL',
    defaultValue: 'https://api-bookat.tsgtech.co/api',
  );

  static const useMockData = bool.fromEnvironment(
    'BOOKAT_USE_MOCK_DATA',
    defaultValue: false,
  );
}
