// Basic smoke test for the login screen — testing it directly (rather than
// through main()'s splash gate) avoids depending on flutter_secure_storage's
// platform channel, which has no mock handler in the widget-test harness.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/screens/login_screen.dart';
import 'package:admin_app/theme/app_theme.dart';

void main() {
  testWidgets('login screen shows email/password fields and a sign-in button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAdminAppTheme(),
      home: const LoginScreen(),
    ));

    expect(find.text('Admin Panel'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
