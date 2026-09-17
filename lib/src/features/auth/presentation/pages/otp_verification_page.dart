import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../business_admin/presentation/pages/business_admin_home_page.dart';
import '../../../booking/presentation/pages/home_page.dart';
import '../providers/auth_providers.dart';

class OtpVerificationPage extends ConsumerStatefulWidget {
  const OtpVerificationPage({
    required this.email,
    required this.password,
    super.key,
  });

  final String email;
  final String password;

  @override
  ConsumerState<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final error = await ref.read(authControllerProvider.notifier).verifyOtpAndLogin(
          email: widget.email,
          password: widget.password,
          otp: _otpController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    if (error != null) {
      final colors = context.appColors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: colors.error),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final session = ref.read(authControllerProvider).valueOrNull;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => switch (session?.user.role) {
          Role.businessAdmin => const BusinessAdminHomePage(),
          _ => const HomePage(),
        },
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authSubmissionLoadingProvider);
    final colors = context.appColors;

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
                      AppStrings.verifyEmailTitle,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      AppStrings.otpSentToEmail(widget.email),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppDimensions.spacing3xl),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: AppStrings.verificationCode,
                        prefixIcon: Icon(Icons.password_rounded),
                        counterText: '',
                      ),
                      validator: (value) {
                        final otp = value?.trim() ?? '';
                        if (otp.length != 6) {
                          return AppStrings.otpValidation;
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => isLoading ? null : _submit(),
                    ),
                    const SizedBox(height: AppDimensions.spacing2xl),
                    AppButton(
                      label: isLoading
                          ? AppStrings.verifying
                          : AppStrings.verifyAndContinue,
                      onPressed: isLoading ? null : _submit,
                      isLoading: isLoading,
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
