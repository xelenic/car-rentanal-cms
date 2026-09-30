import 'package:admin_app/screens/customers_tab.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

Future<void> _show(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(theme: buildAdminAppTheme(), home: CustomersTab(user: server.adminUser)));
  await tester.pumpAndSettle();
}

FakeServer _list() => FakeServer(customers: [
      customerJson(id: 1, name: 'ZZZ Test Zebra', phone: '0771111111'),
      customerJson(id: 2, name: 'ZZZ Test Apple', phone: '0772222222', email: 'zzz.apple@example.test'),
    ]);

void main() {
  testWidgets('lists customers with name and phone', (tester) async {
    await _show(tester, _list());

    expect(find.text('ZZZ Test Zebra'), findsOneWidget);
    expect(find.text('0771111111'), findsOneWidget);
    expect(find.text('ZZZ Test Apple'), findsOneWidget);
  });

  testWidgets('searches the list', (tester) async {
    final server = _list();
    await _show(tester, server);

    await tester.enterText(find.byKey(const Key('customer-search')), 'Apple');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(server.requestsTo('/api/admin/customers').last.url.queryParameters['search'], 'Apple');
    expect(find.text('ZZZ Test Apple'), findsOneWidget);
    expect(find.text('ZZZ Test Zebra'), findsNothing);
  });

  testWidgets('offers Add Customer to someone allowed to add one', (tester) async {
    await _show(tester, _list()..canCreateCustomers = true);

    expect(find.byKey(const Key('add-customer')), findsOneWidget);
  });

  testWidgets('hides Add Customer from someone who may not add customers', (tester) async {
    await _show(tester, _list()..canCreateCustomers = false);

    expect(find.byKey(const Key('add-customer')), findsNothing);
  });

  testWidgets('invites you to add the first customer when there are none', (tester) async {
    await _show(tester, FakeServer());

    expect(find.text('No customers yet'), findsOneWidget);
  });

  group('adding a customer', () {
    Future<void> openForm(WidgetTester tester, FakeServer server) async {
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-customer')));
      await tester.pumpAndSettle();
    }

    testWidgets('creates one with just a name and phone', (tester) async {
      final server = _list();
      await openForm(tester, server);

      await tester.enterText(find.byKey(const Key('customer-name')), 'ZZZ New Customer');
      await tester.enterText(find.byKey(const Key('customer-phone')), '0779999999');
      await tester.ensureVisible(find.byKey(const Key('save-customer')));
      await tester.tap(find.byKey(const Key('save-customer')));
      await tester.pumpAndSettle();

      expect(server.createdCustomers.single['name'], 'ZZZ New Customer');
      expect(find.byKey(const Key('customer-name')), findsNothing); // back on the list
      expect(find.text('ZZZ New Customer added.'), findsOneWidget);
      expect(find.text('ZZZ New Customer'), findsOneWidget);
    });

    testWidgets('will not submit an empty form', (tester) async {
      final server = _list();
      await openForm(tester, server);

      await tester.ensureVisible(find.byKey(const Key('save-customer')));
      await tester.tap(find.byKey(const Key('save-customer')));
      await tester.pumpAndSettle();

      expect(server.createdCustomers, isEmpty);
      expect(find.text('Required'), findsNWidgets(2)); // name, phone
    });
  });

  group('a customer\'s page', () {
    Future<void> openCustomer(
      WidgetTester tester,
      FakeServer server, {
      bool canUpdateCustomers = false,
      bool canDeleteCustomers = false,
    }) async {
      server
        ..canUpdateCustomers = canUpdateCustomers
        ..canDeleteCustomers = canDeleteCustomers;
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('customer-card-1')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the customer\'s details', (tester) async {
      await openCustomer(tester, _list());

      expect(find.text('ZZZ Test Zebra'), findsWidgets); // title + tile
      expect(find.text('0771111111'), findsOneWidget);
    });

    testWidgets('offers no menu to someone who may neither edit nor delete', (tester) async {
      await openCustomer(tester, _list());

      expect(find.byKey(const Key('customer-menu')), findsNothing);
    });

    testWidgets('editing saves changes', (tester) async {
      await openCustomer(tester, _list(), canUpdateCustomers: true);

      await tester.tap(find.byKey(const Key('customer-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('customer-name')), 'ZZZ Renamed Customer');
      await tester.ensureVisible(find.byKey(const Key('save-customer')));
      await tester.tap(find.byKey(const Key('save-customer')));
      await tester.pumpAndSettle();

      expect(find.text('ZZZ Renamed Customer'), findsWidgets);
      expect(find.text('ZZZ Renamed Customer updated.'), findsOneWidget);
    });

    testWidgets('deleting asks for confirmation, then pops the page', (tester) async {
      final server = _list();
      await openCustomer(tester, server, canDeleteCustomers: true);

      await tester.tap(find.byKey(const Key('customer-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete-customer')));
      await tester.pumpAndSettle();

      expect(server.deletedCustomers, [1]);
      expect(find.text('ZZZ Test Zebra'), findsNothing); // popped, and gone from the list
    });

    testWidgets('shows the server\'s reason when a customer with hires can\'t be deleted', (tester) async {
      final server = _list();
      await openCustomer(tester, server, canDeleteCustomers: true);
      server.failWith = 422;

      await tester.tap(find.byKey(const Key('customer-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete-customer')));
      await tester.pumpAndSettle();

      expect(find.text('The server said no.'), findsOneWidget);
      expect(find.text('ZZZ Test Zebra'), findsWidgets); // still here
    });
  });
}
