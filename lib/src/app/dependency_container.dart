import 'service_locator.dart';

class DependencyContainer {
  const DependencyContainer._();

  static Future<void> create() {
    return configureDependencies();
  }
}
