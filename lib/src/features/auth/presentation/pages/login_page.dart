import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/providers/ui_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../providers/auth_providers.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

const _obscurePasswordKey = 'login-password';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final error = await ref.read(authControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (error != null) {
      _showError(error);
      return;
    }

    FocusScope.of(context).unfocus();
  }

  Future<void> _signInWithGoogle() async {
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

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
    );
  }

  void _openForgotPassword() {
    // Carry over whatever is already typed so the identifier is not retyped.
    final typed = _emailController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordPage(
          initialIdentifier: typed.isEmpty ? null : typed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authSubmissionLoadingProvider);
    final isGoogleLoading = ref.watch(googleSubmissionLoadingProvider);
    final obscurePassword = ref.watch(obscureTextProvider(_obscurePasswordKey));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacingXl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AuthHeader(
                      title: AppStrings.loginTitle,
                      subtitle: AppStrings.loginSubtitle,
                    ),
                    const SizedBox(height: AppDimensions.spacing3xl),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: AppStrings.email,
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: AppStrings.password,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            ref
                                .read(
                                  obscureTextProvider(_obscurePasswordKey).notifier,
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
                      onFieldSubmitted: (_) => isLoading ? null : _submit(),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppButton(
                        label: AppStrings.forgotPassword,
                        onPressed: isLoading ? null : _openForgotPassword,
                        type: AppButtonType.text,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    AppButton(
                      label: isLoading && !isGoogleLoading
                          ? AppStrings.signingIn
                          : AppStrings.signIn,
                      onPressed: isLoading ? null : _submit,
                      isLoading: isLoading && !isGoogleLoading,
                      isExpanded: true,
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),
                    const AuthDivider(label: AppStrings.authDividerOr),
                    const SizedBox(height: AppDimensions.spacingXl),
                    GoogleSignInButton(
                      label: AppStrings.continueWithGoogle,
                      onPressed: isLoading ? null : _signInWithGoogle,
                      isLoading: isGoogleLoading,
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    AppButton(
                      label: AppStrings.createAccount,
                      onPressed: isLoading ? null : _openRegister,
                      type: AppButtonType.text,
                      isExpanded: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBrandTitle(
          logoSize: 42,
          textStyle: textTheme.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        Text(
          title,
          style: textTheme.headlineMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Text(
          subtitle,
          style: textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
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
