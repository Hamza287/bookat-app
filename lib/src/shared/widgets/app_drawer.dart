import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme_mode_provider.dart';
import '../../core/constants/constants.dart';
import '../../core/enums/app_enums.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import 'app_top_alert.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/booking/presentation/pages/my_bookings_page.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);

    return Drawer(
      backgroundColor: colors.surface,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerProfile(session: session),
            Divider(height: 1, color: colors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.spacingMd,
                ),
                children: [
                  _DrawerSectionLabel(label: AppStrings.account),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingMd,
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.event_note_rounded,
                        color: colors.primary,
                      ),
                      title: Text(
                        AppStrings.myBookings,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMedium,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MyBookingsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  _DrawerSectionLabel(label: AppStrings.appearance),
                  _ThemeModeTile(
                    groupValue: themeMode,
                    onChanged: (value) => _setTheme(ref, value),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: ListTile(
                leading: Icon(Icons.logout_rounded, color: colors.error),
                title: Text(
                  AppStrings.logout,
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                onTap: () => _confirmLogout(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setTheme(WidgetRef ref, ThemeMode value) {
    ref.read(themeModeProvider.notifier).setTheme(value);
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogColors = dialogContext.appColors;

        return AlertDialog(
          backgroundColor: dialogColors.surface,
          title: const Text(AppStrings.logoutTitle),
          content: const Text(AppStrings.logoutMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(AppStrings.logout),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !context.mounted) {
      return;
    }

    Navigator.of(context).pop();
    await ref.read(authControllerProvider.notifier).logout();

    if (!context.mounted) {
      return;
    }

    AppTopAlert.show(context, AppStrings.logoutSuccess);
  }
}

class _DrawerProfile extends StatelessWidget {
  const _DrawerProfile({required this.session});

  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final user = session?.user;
    final name = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : AppStrings.profile;
    final email = user?.email ?? AppStrings.account;
    final role = user == null ? AppStrings.account : _roleLabel(user.role);
    final isVerified = user?.isVerified ?? false;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _initials(name),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Wrap(
            spacing: AppDimensions.spacingSm,
            runSpacing: AppDimensions.spacingSm,
            children: [
              _ProfileBadge(label: role, icon: Icons.badge_outlined),
              _ProfileBadge(
                label: isVerified ? AppStrings.verified : AppStrings.notVerified,
                icon: isVerified
                    ? Icons.verified_outlined
                    : Icons.info_outline_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return AppStrings.appName.substring(0, 1);
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _roleLabel(Role role) {
    return switch (role) {
      Role.customer => AppStrings.customer,
      Role.businessAdmin => AppStrings.business,
      Role.staff => AppStrings.staff,
      Role.superAdmin => AppStrings.admin,
    };
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.primary),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingXl,
        AppDimensions.spacingMd,
        AppDimensions.spacingXl,
        AppDimensions.spacingSm,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.groupValue,
    required this.onChanged,
  });

  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      child: ListTile(
        leading: Icon(Icons.contrast_rounded, color: colors.primary),
        title: Text(
          AppStrings.appearance,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        trailing: _ThemeCupertinoToggle(
          groupValue: groupValue,
          onChanged: onChanged,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
    );
  }
}

class _ThemeCupertinoToggle extends StatelessWidget {
  const _ThemeCupertinoToggle({
    required this.groupValue,
    required this.onChanged,
  });

  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = groupValue == ThemeMode.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingXs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeIconButton(
              icon: CupertinoIcons.sun_max,
              isSelected: !isDark,
              onPressed: () => onChanged(ThemeMode.light),
            ),
            _ThemeIconButton(
              icon: CupertinoIcons.moon,
              isSelected: isDark,
              onPressed: () => onChanged(ThemeMode.dark),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeIconButton extends StatelessWidget {
  const _ThemeIconButton({
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return CupertinoButton(
      minSize: 0,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 36,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? colors.textOnPrimary : colors.textSecondary,
        ),
      ),
    );
  }
}
