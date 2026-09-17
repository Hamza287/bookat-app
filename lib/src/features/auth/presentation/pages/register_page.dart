import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../shared/providers/ui_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../providers/auth_providers.dart';
import 'otp_verification_page.dart';

const _obscurePasswordKey = 'register-password';

final _selectedRoleProvider =
    StateProvider.autoDispose<Role>((_) => Role.customer);

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
          role: ref.read(_selectedRoleProvider),
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

  void _showError(String message) {
    final colors = context.appColors;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: colors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authSubmissionLoadingProvider);
    final colors = context.appColors;
    final selectedRole = ref.watch(_selectedRoleProvider);
    final obscurePassword = ref.watch(obscureTextProvider(_obscurePasswordKey));
    final isBusiness = selectedRole == Role.businessAdmin;

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
                        child: _AccountTypeSelector(
                          selectedRole: selectedRole,
                          onChanged: (role) {
                            ref.read(_selectedRoleProvider.notifier).state = role;
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppDimensions.spacingXl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                              label: _buttonLabel(isLoading, isBusiness),
                              onPressed: isLoading ? null : _submit,
                              isLoading: isLoading,
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

  String _buttonLabel(bool isLoading, bool isBusiness) {
    if (isLoading) {
      return isBusiness
          ? AppStrings.creatingBusinessAccount
          : AppStrings.creatingAccount;
    }

    return isBusiness
        ? AppStrings.createBusinessAccount
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

class _AccountTypeSelector extends StatelessWidget {
  const _AccountTypeSelector({
    required this.selectedRole,
    required this.onChanged,
  });

  final Role selectedRole;
  final ValueChanged<Role> onChanged;

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
                isSelected: selectedRole == Role.customer,
                onPressed: () => onChanged(Role.customer),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Expanded(
              child: _AccountTypeButton(
                label: AppStrings.business,
                icon: Icons.business_center_outlined,
                isSelected: selectedRole == Role.businessAdmin,
                onPressed: () => onChanged(Role.businessAdmin),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTypeButton extends StatelessWidget {
  const _AccountTypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

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
            ],
          ),
        ),
      ),
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
