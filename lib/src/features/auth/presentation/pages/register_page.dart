import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../shared/providers/ui_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../providers/auth_providers.dart';
import 'otp_verification_page.dart';

const _obscurePasswordKey = 'register-password';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final error = await ref.read(authControllerProvider.notifier).register(
          email: email,
          password: password,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: Role.customer,
        );

    if (!mounted) {
      return;
    }

    if (error != null) {
      _showError(error);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OtpVerificationPage(email: email, password: password),
      ),
    );
  }

  /// Google accounts arrive verified, so this path skips the OTP screen that
  /// email signup goes through — the session comes back straight away.
  Future<void> _signUpWithGoogle() async {
    FocusScope.of(context).unfocus();

    final error =
        await ref.read(authControllerProvider.notifier).signInWithGoogle();

    if (!mounted || error == null) {
      return;
    }

    _showError(error);
  }

  void _showError(String message) {
    AppTopAlert.show(context, message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authSubmissionLoadingProvider);
    final isGoogleLoading = ref.watch(googleSubmissionLoadingProvider);
    final colors = context.appColors;
    final obscurePassword = ref.watch(obscureTextProvider(_obscurePasswordKey));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.spacingXl,
                          AppDimensions.spacing2xl,
                          AppDimensions.spacingXl,
                          AppDimensions.spacingLg,
                        ),
                        child: Column(
                          children: [
                            AppBrandTitle(
                              logoSize: 46,
                              textStyle:
                                  Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: AppDimensions.spacingLg),
                            Text(
                              AppStrings.createAccountTitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: AppDimensions.spacingSm),
                            Text(
                              AppStrings.createAccountSubtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingXl,
                        ),
                        child: const _AccountTypeSelector(),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppDimensions.spacingXl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Offered above the form: it is the shorter route
                            // to an account, and the form below is long.
                            GoogleSignInButton(
                              label: AppStrings.signUpWithGoogle,
                              onPressed: isLoading ? null : _signUpWithGoogle,
                              isLoading: isGoogleLoading,
                            ),
                            const SizedBox(height: AppDimensions.spacingXl),
                            const AuthDivider(label: AppStrings.authDividerOr),
                            const SizedBox(height: AppDimensions.spacingXl),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final useColumns = constraints.maxWidth >= 480;
                                if (!useColumns) {
                                  return Column(children: _nameFields());
                                }

                                return Row(
                                  children: [
                                    Expanded(child: _firstNameField()),
                                    const SizedBox(
                                      width: AppDimensions.spacingLg,
                                    ),
                                    Expanded(child: _lastNameField()),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: AppDimensions.spacingLg),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final useColumns = constraints.maxWidth >= 480;
                                if (!useColumns) {
                                  return Column(
                                    children: [
                                      _emailField(),
                                      const SizedBox(
                                        height: AppDimensions.spacingLg,
                                      ),
                                      _phoneField(),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: _emailField()),
                                    const SizedBox(
                                      width: AppDimensions.spacingLg,
                                    ),
                                    Expanded(child: _phoneField()),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: AppDimensions.spacingLg),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: obscurePassword,
                              decoration: InputDecoration(
                                labelText: AppStrings.password,
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    ref
                                        .read(
                                          obscureTextProvider(
                                            _obscurePasswordKey,
                                          ).notifier,
                                        )
                                        .update((value) => !value);
                                  },
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: AppDimensions.spacing2xl),
                            AppButton(
                              label: _buttonLabel(isLoading && !isGoogleLoading),
                              onPressed: isLoading ? null : _submit,
                              isLoading: isLoading && !isGoogleLoading,
                              isExpanded: true,
                            ),
                          ],
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          border: Border(top: BorderSide(color: colors.border)),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(AppDimensions.radiusLarge),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.spacingXl),
                          child: Column(
                            children: [
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    AppStrings.alreadyHaveAccount,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(color: colors.textSecondary),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text(AppStrings.signIn),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimensions.spacingSm),
                              Text(
                                AppStrings.termsAgreement,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _buttonLabel(bool isLoading) {
    return isLoading
        ? AppStrings.creatingAccount
        : AppStrings.createCustomerAccount;
  }

  List<Widget> _nameFields() {
    return [
      _firstNameField(),
      const SizedBox(height: AppDimensions.spacingLg),
      _lastNameField(),
    ];
  }

  Widget _firstNameField() {
    return TextFormField(
      controller: _firstNameController,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: AppStrings.firstName,
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
      validator: _validateRequired,
    );
  }

  Widget _lastNameField() {
    return TextFormField(
      controller: _lastNameController,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: AppStrings.lastName,
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
      validator: _validateRequired,
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: AppStrings.email),
      validator: _validateEmail,
    );
  }

  Widget _phoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: AppStrings.phone),
      validator: _validateRequired,
    );
  }
}


String? _validateRequired(String? value) {
  if ((value ?? '').trim().isEmpty) {
    return AppStrings.requiredFieldValidation;
  }
  return null;
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return AppStrings.enterEmailValidation;
  }
  if (!email.contains('@') || !email.contains('.')) {
    return AppStrings.validEmailValidation;
  }
  return null;
}

String? _validatePassword(String? value) {
  if ((value ?? '').length < 6) {
    return AppStrings.passwordValidation;
  }
  return null;
}

/// The Customer / Business pair at the top of the form.
///
/// Customer is permanently selected: the app only creates customer accounts.
/// Business is kept as a visible, tappable option rather than hidden, because
/// an owner arriving here needs to be told where to go — tapping it opens the
/// website instead of changing the form.
class _AccountTypeSelector extends StatelessWidget {
  const _AccountTypeSelector();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingXs),
        child: Row(
          children: [
            Expanded(
              child: _AccountTypeButton(
                label: AppStrings.customer,
                icon: Icons.person_outline_rounded,
                isSelected: true,
                // Already the only option; tapping it changes nothing.
                onPressed: () {},
              ),
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Expanded(
              child: _AccountTypeButton(
                label: AppStrings.business,
                icon: Icons.business_center_outlined,
                isSelected: false,
                trailingIcon: Icons.open_in_new_rounded,
                onPressed: () => _openWebsite(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse(AppConfig.websiteUrl);

    // Tried in order of preference. `externalApplication` hands off to the
    // browser, which is what is wanted here; `platformDefault` and
    // `inAppBrowserView` cover devices where no app claims the https intent
    // outright, so a refusal from one mode is not the end of the attempt.
    for (final mode in const [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
      LaunchMode.inAppBrowserView,
    ]) {
      try {
        if (await launchUrl(uri, mode: mode)) {
          return;
        }
      } catch (_) {
        // Try the next mode rather than giving up on the first throw.
      }
    }

    if (!context.mounted) {
      return;
    }

    // Every mode refused — there is genuinely no browser to hand off to. The
    // address goes to the clipboard so the owner is not left at a dead end.
    await Clipboard.setData(const ClipboardData(text: AppConfig.websiteUrl));
    if (context.mounted) {
      AppTopAlert.show(context, AppStrings.businessSignupLinkCopied);
    }
  }
}

class _AccountTypeButton extends StatelessWidget {
  const _AccountTypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
    this.trailingIcon,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  /// Shown after the label to signal that this option leaves the app.
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: isSelected ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: isSelected ? Border.all(color: colors.border) : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? colors.primary : colors.textSecondary,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isSelected
                            ? colors.primary
                            : colors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: AppDimensions.spacingXs),
                Icon(trailingIcon, size: 14, color: colors.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
