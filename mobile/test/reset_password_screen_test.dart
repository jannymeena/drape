import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/modules/auth/screens/reset_password_screen.dart';
import 'package:mobile/shared/widgets/drape_button.dart';

/// Renders [ResetPasswordScreen] under a ProviderScope. These cases never reach
/// the network — they cover the token guard and client-side validation that run
/// before any API call.
Widget _host(String? token) => ProviderScope(
      child: MaterialApp(home: ResetPasswordScreen(token: token)),
    );

void main() {
  final resetButton = find.widgetWithText(DrapeButton, 'Reset password');

  testWidgets('missing token shows the invalid-link state', (tester) async {
    await tester.pumpWidget(_host(null));

    expect(find.text('Link expired or invalid'), findsOneWidget);
    expect(find.text('Request a new link'), findsOneWidget);
    expect(find.text('Choose a new password'), findsNothing);
  });

  testWidgets('a token shows the new-password form', (tester) async {
    await tester.pumpWidget(_host('reset-tok-123'));

    expect(find.text('Choose a new password'), findsOneWidget);
    expect(resetButton, findsOneWidget);
  });

  testWidgets('mismatched passwords are rejected before any network call',
      (tester) async {
    await tester.pumpWidget(_host('reset-tok-123'));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'password1');
    await tester.enterText(fields.at(1), 'password2');
    await tester.tap(resetButton);
    await tester.pump();

    expect(find.text("Passwords don't match."), findsOneWidget);
  });

  testWidgets('empty fields are rejected before any network call',
      (tester) async {
    await tester.pumpWidget(_host('reset-tok-123'));

    await tester.tap(resetButton);
    await tester.pump();

    expect(find.text('Enter and confirm your new password.'), findsOneWidget);
  });
}
