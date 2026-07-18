import 'package:flutter/material.dart';

import 'src/app/bookat_app.dart';
import 'src/app/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();

  runApp(const BookatApp());
}
