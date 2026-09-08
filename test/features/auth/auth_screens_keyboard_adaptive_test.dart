import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/auth/presentation/login_screen.dart';
import 'package:merkado_go/features/auth/presentation/signup_screen.dart';
import 'package:merkado_go/features/auth/presentation/forgot_password_screen.dart';

void main() {
  group('Auth Screens Keyboard Adaptive Layout Tests', () {
    testWidgets('LoginScreen adapts cleanly when soft keyboard appears', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Normal state (keyboard closed)
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Login to Access Your'), findsOneWidget);

      // Simulate keyboard opening (bottom inset = 340px)
      tester.view.viewInsets = const FakeViewPadding(bottom: 340.0);
      addTearDown(tester.view.resetViewInsets);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Login to Access Your'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SignupScreen adapts cleanly when soft keyboard appears', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SignupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Normal state (keyboard closed)
      expect(find.byType(SignupScreen), findsOneWidget);
      expect(find.text('Create Account to'), findsOneWidget);

      // Simulate keyboard opening (bottom inset = 340px)
      tester.view.viewInsets = const FakeViewPadding(bottom: 340.0);
      addTearDown(tester.view.resetViewInsets);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SignupScreen), findsOneWidget);
      expect(find.text('Create Account to'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ForgotPasswordScreen adapts cleanly when soft keyboard appears', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Normal state (keyboard closed)
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.text('Forgot Your Password?'), findsOneWidget);

      // Simulate keyboard opening (bottom inset = 340px)
      tester.view.viewInsets = const FakeViewPadding(bottom: 340.0);
      addTearDown(tester.view.resetViewInsets);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.text('Forgot Your Password?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
