import 'package:flutter/material.dart';

import '../core/constants/constants.dart';
import '../features/booking/domain/usecases/search_businesses.dart';
import '../features/booking/presentation/pages/home_page.dart';
import 'app_theme.dart';
import 'service_locator.dart';

class BookatApp extends StatelessWidget {
  const BookatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: HomePage(searchBusinesses: serviceLocator<SearchBusinesses>()),
    );
  }
}
