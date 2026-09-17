import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/widgets/widgets.dart';
import '../providers/auth_providers.dart';
import 'reset_password_page.dart';

/// Step one of the reset: collect the account identifier and ask the server to
/// email a code.
///
/// The identifier is deliberately not validated as an email — the endpoint
/// accepts a username too, and rejecting anything without an `@` would lock
/// username holders out of their own reset.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({this.initialIdentifier, super.key});

  /// Pre-filled from whatever the user had already typed on the login screen,
  /// so they do not retype it.
  final String? initialIdentifier;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final _identifierController = TextEditingController(
    text: widget.initialIdentifier ?? '',
  );

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final identifier = _identifierController.text.trim();
    final outcome = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(identifier);

    if (!mounted) {
      return;
    }

    if (!outcome.isSent) {
      _showError(outcome.error!);
      return;
    }

    FocusScope.of(context).unfocus();
    // Confirm the send before moving on. The root messenger outlives the push,
    // so this stays visible over the next screen.
    _showSent(
      outcome.message?.isNotEmpty ?? false
          ? outcome.message!
          : AppStrings.resetCodeSentTo(outcome.email!),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResetPasswordPage(
          emailOrUsername: identifier,
          email: outcome.email!,
        ),
      ),
    );
  }

  void _showError(String message) {
    AppTopAlert.show(context, message, isError: true);
  }

  void _showSent(String message) {
    AppTopAlert.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authSubmissionLoadingProvider);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

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
                      Icons.lock_reset_rounded,
                      color: colors.primary,
                      size: 48,
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    Text(
                      AppStrings.forgotPasswordTitle,
                      style: textTheme.headlineMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      AppStrings.forgotPasswordSubtitle,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing3xl),
                    TextFormField(
                      controller: _identifierController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: AppStrings.emailOrUsername,
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return AppStrings.emailOrUsernameValidation;
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => isLoading ? null : _submit(),
                    ),
                    const SizedBox(height: AppDimensions.spacing2xl),
                    AppButton(
                      label: isLoading
                          ? AppStrings.sendingResetCode
                          : AppStrings.sendResetCode,
                      onPressed: isLoading ? null : _submit,
                      isLoading: isLoading,
                      isExpanded: true,
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    AppButton(
                      label: AppStrings.backToSignIn,
                      onPressed:
                          isLoading ? null : () => Navigator.of(context).pop(),
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
