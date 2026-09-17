import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/providers/ui_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../providers/auth_providers.dart';

const _newPasswordKey = 'reset-new-password';
const _confirmPasswordKey = 'reset-confirm-password';

/// Step two of the reset: the emailed code plus the new password.
///
/// This endpoint issues no session, so a success returns to the login screen
/// rather than signing the user in.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({
    required this.emailOrUsername,
    required this.email,
    super.key,
  });

  /// Exactly what the user typed on the previous screen. The reset endpoint is
  /// keyed on the same value, so a username must be sent back as a username.
  final String emailOrUsername;

  /// The address the server said it sent the code to, shown so the user knows
  /// which inbox to open.
  final String email;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final error = await ref.read(authControllerProvider.notifier).resetPassword(
          emailOrUsername: widget.emailOrUsername,
          otp: _otpController.text.trim(),
          newPassword: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    // Unwind both reset screens so Back cannot return to a spent code.
    Navigator.of(context).popUntil((route) => route.isFirst);
    _showMessage(AppStrings.passwordResetSuccess);
  }

  Future<void> _resendCode() async {
    final outcome = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(widget.emailOrUsername);

    if (!mounted) {
      return;
    }

    _showMessage(
      outcome.isSent
          ? (outcome.message?.isNotEmpty ?? false
              ? outcome.message!
              : AppStrings.resetCodeSentTo(widget.email))
          : outcome.error!,
      isError: !outcome.isSent,
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    AppTopAlert.show(context, message, isError: isError);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authSubmissionLoadingProvider);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final obscurePassword = ref.watch(obscureTextProvider(_newPasswordKey));
    final obscureConfirm = ref.watch(obscureTextProvider(_confirmPasswordKey));

    return Scaffold(
      appBar: AppBar(),
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
                    Icon(
                      Icons.mark_email_read_outlined,
                      color: colors.primary,
                      size: 48,
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    Text(
                      AppStrings.resetPasswordTitle,
                      style: textTheme.headlineMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      AppStrings.resetCodeSentTo(widget.email),
                      style: textTheme.bodyLarge?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing3xl),
                    TextFormField(
                      controller: _otpController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: AppStrings.resetCode,
                        prefixIcon: Icon(Icons.password_rounded),
                        counterText: '',
                      ),
                      validator: (value) {
                        final otp = (value ?? '').trim();
                        if (otp.length != 6) {
                          return AppStrings.otpValidation;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !isLoading,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: AppStrings.newPassword,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => ref
                              .read(
                                obscureTextProvider(_newPasswordKey).notifier,
                              )
                              .update((value) => !value),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    TextFormField(
                      controller: _confirmController,
                      enabled: !isLoading,
                      obscureText: obscureConfirm,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: AppStrings.confirmPassword,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => ref
                              .read(
                                obscureTextProvider(
                                  _confirmPasswordKey,
                                ).notifier,
                              )
                              .update((value) => !value),
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return AppStrings.passwordsDoNotMatch;
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => isLoading ? null : _submit(),
                    ),
                    const SizedBox(height: AppDimensions.spacing2xl),
                    AppButton(
                      label: isLoading
                          ? AppStrings.updatingPassword
                          : AppStrings.updatePassword,
                      onPressed: isLoading ? null : _submit,
                      isLoading: isLoading,
                      isExpanded: true,
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    AppButton(
                      label: AppStrings.resendCode,
                      onPressed: isLoading ? null : _resendCode,
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

String? _validatePassword(String? value) {
  if ((value ?? '').length < 6) {
    return AppStrings.passwordValidation;
  }
  return null;
}
