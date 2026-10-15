import 'package:admin_app/models/admin_user.dart';
import 'package:admin_app/screens/hire_detail_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

AdminUser _user({bool update = true}) => AdminUser(
      id: 1,
      name: 'ZZZ Test Admin',
      email: 'zzz@example.test',
      canCreateHires: true,
      canUpdateHires: update,
      canDeleteHires: true,
    );

FakeServer _creditHireServer({num full = 10000, num paidAmount = 0, List<Map<String, dynamic>>? payments}) =>
    FakeServer(hires: {
      1: [
        hireJson(
          id: 11,
          vehicleId: 1,
          customer: 'ZZZ Test Customer',
          startTime: '2026-09-29T18:09:00+00:00',
          full: full,
          paymentType: 'credit',
          paidAmount: paidAmount,
          payments: payments,
        ),
      ],
    });

Future<void> _openHire(WidgetTester tester, FakeServer server, {AdminUser? user}) async {
  tester.view.physicalSize = const Size(412, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(
    theme: buildAdminAppTheme(),
    home: HireDetailScreen(hireId: 11, user: user ?? _user()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows Claim Payment for an unpaid credit hire', (tester) async {
    await _openHire(tester, _creditHireServer());

    expect(find.text('Unpaid'), findsOneWidget);
    expect(find.byKey(const Key('claim-payment')), findsOneWidget);
  });

  testWidgets('hides Claim Payment from someone without hires.update', (tester) async {
    await _openHire(tester, _creditHireServer(), user: _user(update: false));

    expect(find.byKey(const Key('claim-payment')), findsNothing);
  });

  testWidgets('hides Claim Payment once fully paid', (tester) async {
    await _openHire(tester, _creditHireServer(full: 10000, paidAmount: 10000));

    expect(find.text('Fully Paid'), findsOneWidget);
    expect(find.byKey(const Key('claim-payment')), findsNothing);
  });

  testWidgets('shows past payments in the history list', (tester) async {
    await _openHire(
      tester,
      _creditHireServer(
        full: 10000,
        paidAmount: 4000,
        payments: [hirePaymentJson(id: 1, amount: 4000, paidAt: '2026-09-15', notes: 'Bank transfer')],
      ),
    );

    expect(find.text('Rs. 4,000.00'), findsWidgets); // "Paid so far" + the history row
    expect(find.text('Bank transfer'), findsOneWidget);
  });

  group('claiming a payment', () {
    testWidgets('opens prefilled with the full balance', (tester) async {
      await _openHire(tester, _creditHireServer(full: 10000));

      await tester.tap(find.byKey(const Key('claim-payment')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(find.byKey(const Key('claim-payment-amount')));
      expect(field.controller!.text, '10000');
    });

    testWidgets('records a partial payment and updates the balance and status shown', (tester) async {
      final server = _creditHireServer(full: 10000);
      await _openHire(tester, server);

      await tester.tap(find.byKey(const Key('claim-payment')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('claim-payment-amount')), '4000');
      await tester.enterText(find.byKey(const Key('claim-payment-notes')), 'Cash handed over');
      await tester.tap(find.byKey(const Key('save-claim-payment')));
      await tester.pumpAndSettle();

      expect(server.claimedPayments.single.hireId, 11);
      expect(server.claimedPayments.single.body['amount'], 4000.0);
      expect(server.claimedPayments.single.body['notes'], 'Cash handed over');
      expect(find.text('Partially Paid'), findsOneWidget);
      expect(find.text('Rs. 6,000.00'), findsOneWidget); // balance remaining
      expect(find.text('Payment recorded.'), findsOneWidget);
    });

    testWidgets('recording the full balance says so and hides the button', (tester) async {
      final server = _creditHireServer(full: 10000);
      await _openHire(tester, server);

      await tester.tap(find.byKey(const Key('claim-payment')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-claim-payment')));
      await tester.pumpAndSettle();

      expect(find.text('Fully Paid'), findsOneWidget);
      expect(find.byKey(const Key('claim-payment')), findsNothing);
      expect(find.text('Payment recorded — fully paid.'), findsOneWidget);
    });

    testWidgets('rejects an amount over the balance remaining', (tester) async {
      await _openHire(tester, _creditHireServer(full: 10000));

      await tester.tap(find.byKey(const Key('claim-payment')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('claim-payment-amount')), '10001');
      await tester.tap(find.byKey(const Key('save-claim-payment')));
      await tester.pumpAndSettle();

      expect(find.text('Can\'t exceed the balance remaining.'), findsOneWidget);
    });

    testWidgets('shows the server\'s reason and stays open when it refuses', (tester) async {
      final server = _creditHireServer(full: 10000);
      server.failMethods['POST'] = 422;
      await _openHire(tester, server);

      await tester.tap(find.byKey(const Key('claim-payment')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-claim-payment')));
      await tester.pumpAndSettle();

      expect(find.text('The server said no.'), findsOneWidget);
      expect(find.byKey(const Key('claim-payment-amount')), findsOneWidget); // sheet still open
    });
  });

  group('removing a payment', () {
    testWidgets('asks first, then removes it and restores the balance', (tester) async {
      final server = _creditHireServer(
        full: 10000,
        paidAmount: 4000,
        payments: [hirePaymentJson(id: 1, amount: 4000, paidAt: '2026-09-15')],
      );
      await _openHire(tester, server);

      await tester.tap(find.byKey(const Key('delete-payment-1')));
      await tester.pumpAndSettle();
      expect(find.text('Remove this payment?'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(server.deletedPayments, [(hireId: 11, paymentId: 1)]);
      expect(find.text('Unpaid'), findsOneWidget);
      expect(find.text('Rs. 10,000.00'), findsWidgets); // balance restored to full value
    });

    testWidgets('"Keep it" changes nothing', (tester) async {
      final server = _creditHireServer(
        full: 10000,
        paidAmount: 4000,
        payments: [hirePaymentJson(id: 1, amount: 4000, paidAt: '2026-09-15')],
      );
      await _openHire(tester, server);

      await tester.tap(find.byKey(const Key('delete-payment-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(server.deletedPayments, isEmpty);
      expect(find.text('Partially Paid'), findsOneWidget);
    });

    testWidgets('hides the delete button from someone without hires.update', (tester) async {
      await _openHire(
        tester,
        _creditHireServer(
          full: 10000,
          paidAmount: 4000,
          payments: [hirePaymentJson(id: 1, amount: 4000, paidAt: '2026-09-15')],
        ),
        user: _user(update: false),
      );

      expect(find.byKey(const Key('delete-payment-1')), findsNothing);
    });
  });
}
