import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/constants.dart';
import '../core/enums/app_enums.dart';
import 'dependency_providers.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/business_admin/presentation/pages/business_admin_home_page.dart';
import '../features/booking/presentation/pages/home_page.dart';
import '../shared/widgets/widgets.dart';
import 'app_theme.dart';
import 'theme_mode_provider.dart';

class BookatApp extends ConsumerWidget {
  const BookatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    void registerDeviceToken(String? token) {
      final session = ref.read(authControllerProvider).valueOrNull;
      if (session == null || token == null || token.isEmpty) {
        return;
      }

      ref.read(notificationTokenRegistrationServiceProvider).registerToken(
            accessToken: session.accessToken,
            token: token,
          );
    }

    // A device is registered once both halves — a session and a token — exist,
    // so listen for whichever arrives last.
    ref.listen(authControllerProvider, (_, _) {
      registerDeviceToken(ref.read(fcmDeviceTokenProvider).valueOrNull);
    });
    ref.listen(fcmDeviceTokenProvider, (_, next) {
      registerDeviceToken(next.valueOrNull);
    });
    ref.listen(fcmTokenRefreshProvider, (_, next) {
      // Register the rotated token straight away, and refresh the cached one so
      // later registrations don't resend the value FCM just rotated out.
      registerDeviceToken(next.valueOrNull);
      ref.invalidate(fcmDeviceTokenProvider);
    });

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: authState.when(
        loading: () => const _AppLoadingPage(),
        error: (_, _) => const LoginPage(),
        data: (session) {
          if (session == null) {
            return const LoginPage();
          }

          return switch (session.user.role) {
            Role.businessAdmin => const BusinessAdminHomePage(),
            _ => const HomePage(),
          };
        },
      ),
    );
  }
}

class _AppLoadingPage extends StatelessWidget {
  const _AppLoadingPage();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppShimmerBox(
                    width: 42,
                    height: 42,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMedium,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  const AppShimmerBox(width: 120, height: 24),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing3xl),
              AppShimmerBox(
                width: double.infinity,
                height: 58,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
              const SizedBox(height: AppDimensions.spacing3xl),
              AppShimmerBox(
                width: 220,
                height: 28,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: colors.background),
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(
                      height: AppDimensions.spacingMd,
                    ),
                    itemBuilder: (_, _) => const _AppLoadingCard(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppLoadingCard extends StatelessWidget {
  const _AppLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppShimmerBox(width: double.infinity, height: 150),
        SizedBox(height: AppDimensions.spacingMd),
        AppShimmerBox(width: 180, height: 22),
        SizedBox(height: AppDimensions.spacingSm),
        AppShimmerBox(width: 260, height: 16),
      ],
    );
  }
}
