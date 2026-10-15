import 'package:admin_app/screens/driver_detail_screen.dart';
import 'package:admin_app/models/driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

final _now = DateTime.now();

Future<void> _openExpenses(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  final driver = Driver.fromJson(server.drivers.first);
  await tester.pumpWidget(MaterialApp(
    home: DriverDetailScreen(driver: driver, user: server.adminUser),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('tab-expenses')));
  await tester.pumpAndSettle();
}

FakeServer _serverWithOneExpense({String category = 'fuel', num amount = 1500}) {
  final createdAt = DateTime(_now.year, _now.month, 10).toIso8601String();
  return FakeServer(
    drivers: [driverJson(id: 1, name: 'ZZZ Test Nimal')],
    driverExpenses: {
      1: [driverExpenseJson(id: 10, category: category, amount: amount, createdAt: createdAt)],
    },
  );
}

void main() {
  testWidgets('lists this driver\'s expenses for the month, with category and amount', (tester) async {
    await _openExpenses(tester, _serverWithOneExpense());

    expect(find.text('Fuel'), findsOneWidget);
    expect(find.text('Rs. 1,500.00'), findsOneWidget);
    expect(find.byKey(const Key('driver-expenses-summary')), findsOneWidget);
  });

  testWidgets('says so when there are none this month', (tester) async {
    await _openExpenses(tester, FakeServer(drivers: [driverJson(id: 1, name: 'ZZZ Test Nimal')]));

    expect(find.text('No expenses this month'), findsOneWidget);
  });

  testWidgets('hides edit and delete from someone without the permissions', (tester) async {
    final server = _serverWithOneExpense()
      ..canUpdateHires = false
      ..canDeleteHires = false;
    await _openExpenses(tester, server);

    expect(find.byKey(const Key('edit-expense-10')), findsNothing);
    expect(find.byKey(const Key('delete-expense-10')), findsNothing);
  });

  group('editing', () {
    testWidgets('saves a changed category and amount, and updates the card and total', (tester) async {
      final server = _serverWithOneExpense()..canUpdateHires = true;
      await _openExpenses(tester, server);

      await tester.tap(find.byKey(const Key('edit-expense-10')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit-expense-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vehicle Repair').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('edit-expense-amount')), '2000');
      await tester.tap(find.byKey(const Key('save-expense-edit')));
      await tester.pumpAndSettle();

      expect(server.savedDriverExpenses.single.id, 10);
      expect(server.savedDriverExpenses.single.body['category'], 'repair');
      expect(find.text('Vehicle Repair'), findsOneWidget);
      expect(find.text('Rs. 2,000.00'), findsWidgets); // card amount + updated total
    });
  });

  group('deleting', () {
    testWidgets('asks for confirmation, then removes the expense', (tester) async {
      final server = _serverWithOneExpense()..canDeleteHires = true;
      await _openExpenses(tester, server);

      await tester.tap(find.byKey(const Key('delete-expense-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(server.deletedDriverExpenses, [10]);
      expect(find.text('Fuel'), findsNothing);
      expect(find.text('No expenses this month'), findsOneWidget);
    });

    testWidgets('"Keep it" changes nothing', (tester) async {
      final server = _serverWithOneExpense()..canDeleteHires = true;
      await _openExpenses(tester, server);

      await tester.tap(find.byKey(const Key('delete-expense-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(server.deletedDriverExpenses, isEmpty);
      expect(find.text('Fuel'), findsOneWidget);
    });
  });
}
