import 'package:admin_app/screens/driver_detail_screen.dart';
import 'package:admin_app/models/driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

Future<void> _openDeposit(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  final driver = Driver.fromJson(server.drivers.first);
  await tester.pumpWidget(MaterialApp(
    home: DriverDetailScreen(driver: driver, user: server.adminUser),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('tab-deposit')));
  await tester.pumpAndSettle();
}

FakeServer _server({Map<String, dynamic>? driverDeposit}) {
  final server = FakeServer(drivers: [driverJson(id: 1, name: 'ZZZ Test Nimal')]);
  if (driverDeposit != null) server.driverDeposit = driverDeposit;
  return server;
}

void main() {
  testWidgets('says so when there is no deposit activity this month', (tester) async {
    await _openDeposit(tester, _server());

    expect(find.text('No deposit activity'), findsOneWidget);
  });

  testWidgets('shows the deposit breakdown and balance for the month', (tester) async {
    final server = _server(
      driverDeposit: defaultDriverDepositJson(
        hireFullValueTotal: 1000,
        cashTotal: 1000,
        creditTotal: 0,
        depositAmount: 1000,
        transferredTotal: 0,
        balance: 1000,
        netSalaryPayable: 160,
        finalNetPayable: -840,
      ),
    );
    await _openDeposit(tester, server);

    expect(find.byKey(const Key('driver-deposit-body')), findsOneWidget);
    expect(find.text('Deposit Amount'), findsOneWidget);
    expect(find.text('Rs. 1,000.00'), findsWidgets); // deposit amount + balance
    expect(find.text('Net Payable Salary'), findsOneWidget);
    expect(find.text('-Rs. 840.00'), findsOneWidget);
  });

  testWidgets('shows what has already been transferred, reducing the balance', (tester) async {
    final server = _server(
      driverDeposit: defaultDriverDepositJson(
        depositAmount: 1000,
        transferredTotal: 400,
        balance: 600,
      ),
    );
    await _openDeposit(tester, server);

    expect(find.text('Already Transferred'), findsOneWidget);
    expect(find.text('-Rs. 400.00'), findsOneWidget);
    expect(find.text('Rs. 600.00'), findsOneWidget);
  });

  testWidgets('lists arrears loans and opens the deduction schedule on tap', (tester) async {
    final server = _server(
      driverDeposit: defaultDriverDepositJson(
        depositAmount: 300,
        balance: 300,
        arrearsLoans: [
          driverArrearsLoanJson(
            id: 5,
            amount: 300,
            deductionType: 'installments',
            deductionTypeLabel: 'Split across upcoming months',
            // A year away from "now" on purpose, so these deduction months
            // never collide with the month-stepper header's current label.
            deductions: [
              {'year': DateTime.now().year + 1, 'month': 1, 'amount': 150},
              {'year': DateTime.now().year + 1, 'month': 2, 'amount': 150},
            ],
          ),
        ],
      ),
    );
    await _openDeposit(tester, server);

    expect(find.text('Arrears Loans'), findsOneWidget);
    expect(find.text('Split across upcoming months'), findsOneWidget);

    await tester.tap(find.text('Rs. 300.00').last);
    await tester.pumpAndSettle();

    expect(find.text('Arrears Loan Schedule'), findsOneWidget);
    expect(find.text('January ${DateTime.now().year + 1}'), findsOneWidget);
    expect(find.text('February ${DateTime.now().year + 1}'), findsOneWidget);
  });

  testWidgets('stepping to the previous month asks for that period', (tester) async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final server = _server();
    await _openDeposit(tester, server);

    await tester.tap(find.byKey(const Key('driver-deposit-month-prev')));
    await tester.pumpAndSettle();

    final requests = server.requestsTo('/api/admin/drivers/1/deposit');
    expect(requests.last.url.queryParameters['year'], '${lastMonth.year}');
    expect(requests.last.url.queryParameters['month'], '${lastMonth.month}');
  });
}
