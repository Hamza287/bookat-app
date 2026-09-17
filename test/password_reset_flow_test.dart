import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/errors/failure.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/domain/entities/password_reset.dart';
import 'package:bookat/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:bookat/src/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walks the reset the way a user does: from the login screen, through the
/// identifier screen, to the code and new password — checking that every step
/// tells the user what happened.
void main() {
  late _FakeRepository repository;

  Future<void> pumpLogin(WidgetTester tester) async {
    repository = _FakeRepository();

    final container = ProviderContainer(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openForgotPassword(WidgetTester tester) async {
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
  }

  /// Requests a code, then lets the confirmation alert time out.
  ///
  /// The alert banner is dismissed before continuing so later assertions see
  /// the screen, not the banner.
  Future<void> sendCode(WidgetTester tester, String identifier) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or username'),
      identifier,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset code'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Future<void> fillReset(
    WidgetTester tester, {
    required String otp,
    required String password,
    required String confirm,
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reset code'),
      otp,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      password,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      confirm,
    );
  }

  testWidgets('login offers a forgot-password entry point', (tester) async {
    await pumpLogin(tester);

    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('carries the typed email into the reset screen', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'hamzaibrahimflutter@gmail.com',
    );
    await openForgotPassword(tester);

    expect(find.text('Reset your password'), findsOneWidget);
    // Pre-filled, so the user does not retype what they already entered.
    expect(
      find.widgetWithText(TextFormField, 'hamzaibrahimflutter@gmail.com'),
      findsOneWidget,
    );
  });

  testWidgets('requires an identifier before sending', (tester) async {
    await pumpLogin(tester);
    await openForgotPassword(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Send reset code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email or username.'), findsOneWidget);
    expect(repository.requestCount, 0);
  });

  testWidgets('alerts that the code was sent', (tester) async {
    await pumpLogin(tester);
    await openForgotPassword(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or username'),
      'a@b.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset code'));
    await tester.pump();

    // The server's own confirmation, as a banner from the top rather than a
    // SnackBar docked over the buttons at the bottom.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(
      find.text('Password reset OTP has been sent to your email address.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed send alerts and stays on the same screen',
      (tester) async {
    await pumpLogin(tester);
    await openForgotPassword(tester);

    repository.requestError = 'No account found for that email.';

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or username'),
      'nobody@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset code'));
    await tester.pumpAndSettle();

    expect(find.text('No account found for that email.'), findsOneWidget);
    // Errors get the error icon, not the success tick.
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    // Not advanced, so the address can be corrected.
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Enter your new password'), findsNothing);
  });

  testWidgets('sends the code then completes the reset', (tester) async {
    await pumpLogin(tester);
    await openForgotPassword(tester);
    await sendCode(tester, 'hamza287');

    expect(repository.requestCount, 1);
    // A username was typed, but the screen names the inbox the server reported.
    expect(repository.lastIdentifier, 'hamza287');
    expect(find.textContaining('hamzaibrahimflutter@gmail.com'), findsWidgets);

    await fillReset(
      tester,
      otp: '223027',
      password: 'Hamza@287',
      confirm: 'Hamza@287',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
    await tester.pumpAndSettle();

    expect(repository.lastOtp, '223027');
    expect(repository.lastNewPassword, 'Hamza@287');
    // The identifier must stay the username the reset was started with.
    expect(repository.lastIdentifier, 'hamza287');

    // No session is issued, so the user lands back on sign-in — with an alert.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      find.text('Password updated. Sign in with your new password.'),
      findsOneWidget,
    );
  });

  testWidgets('mismatched passwords are caught before any request',
      (tester) async {
    await pumpLogin(tester);
    await openForgotPassword(tester);
    await sendCode(tester, 'a@b.com');

    await fillReset(
      tester,
      otp: '223027',
      password: 'Hamza@287',
      confirm: 'Different1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
    await tester.pumpAndSettle();

    expect(find.text('Both passwords must match.'), findsOneWidget);
    expect(repository.resetCount, 0);
  });

  testWidgets('a rejected code alerts and stays put', (tester) async {
    await pumpLogin(tester);
    await openForgotPassword(tester);
    await sendCode(tester, 'a@b.com');

    repository.resetError = 'Invalid or expired OTP';

    await fillReset(
      tester,
      otp: '000000',
      password: 'Hamza@287',
      confirm: 'Hamza@287',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid or expired OTP'), findsOneWidget);
    // Still on the reset screen so the code can be corrected.
    expect(find.text('Enter your new password'), findsOneWidget);
  });

  testWidgets('resend asks for another code without leaving the screen',
      (tester) async {
    await pumpLogin(tester);
    await openForgotPassword(tester);
    await sendCode(tester, 'a@b.com');

    expect(repository.requestCount, 1);

    // Sits below the fold in the default test window.
    final resend = find.widgetWithText(TextButton, 'Resend code');
    await tester.ensureVisible(resend);
    await tester.pumpAndSettle();
    await tester.tap(resend);
    await tester.pumpAndSettle();

    expect(repository.requestCount, 2);
    expect(find.text('Enter your new password'), findsOneWidget);
    // Resending confirms too, rather than looking like nothing happened.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}

class _FakeRepository implements AuthRepository {
  int requestCount = 0;
  int resetCount = 0;
  String? lastIdentifier;
  String? lastOtp;
  String? lastNewPassword;
  String? resetError;
  String? requestError;

  @override
  Future<Result<PasswordResetRequest>> requestPasswordReset({
    required String emailOrUsername,
  }) async {
    if (requestError != null) {
      return Fail(ServerFailure(message: requestError!));
    }

    requestCount++;
    lastIdentifier = emailOrUsername;
    return const Success(
      PasswordResetRequest(
        email: 'hamzaibrahimflutter@gmail.com',
        message: 'Password reset OTP has been sent to your email address.',
      ),
    );
  }

  @override
  Future<Result<PasswordResetConfirmation>> resetPassword({
    required String emailOrUsername,
    required String otp,
    required String newPassword,
  }) async {
    if (resetError != null) {
      return Fail(ServerFailure(message: resetError!));
    }

    resetCount++;
    lastIdentifier = emailOrUsername;
    lastOtp = otp;
    lastNewPassword = newPassword;
    return const Success(
      PasswordResetConfirmation(message: 'Password reset successful.'),
    );
  }

  /// The login screen reads the stored session on start; there is none.
  @override
  Future<AuthSession?> readSession() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}
