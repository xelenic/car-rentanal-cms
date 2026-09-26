import 'package:admin_app/models/admin_user.dart';
import 'package:admin_app/screens/expense_categories_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

AdminUser _user({bool create = true, bool update = true, bool delete = true}) => AdminUser(
      id: 1,
      name: 'ZZZ Test Admin',
      email: 'zzz@example.test',
      canCreateHires: true,
      canViewMyExpenses: true,
      canCreateMyExpenses: create,
      canUpdateMyExpenses: update,
      canDeleteMyExpenses: delete,
    );

/// The nine starting categories, with two expenses filed under Rent.
FakeServer _server() => FakeServer(expenses: [
      expenseJson(id: 1, category: 'rent', date: '2026-09-01'),
      expenseJson(id: 2, category: 'rent', date: '2026-01-05'),
    ]);

Future<void> _show(WidgetTester tester, FakeServer server, {AdminUser? user}) async {
  tester.view.physicalSize = const Size(412, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(theme: buildAdminAppTheme(), home: ExpenseCategoriesScreen(user: user ?? _user())));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every category A to Z with how many expenses are filed under it', (tester) async {
    await _show(tester, _server());

    for (final name in ['Fuel', 'Insurance', 'Marketing', 'Office & Supplies', 'Others', 'Personal', 'Rent', 'Taxes & Licences', 'Utilities']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.descendant(of: find.byKey(const Key('category-rent')), matching: find.text('2 expenses')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('category-fuel')), matching: find.text('0 expenses')), findsOneWidget);
    expect(tester.getTopLeft(find.text('Fuel')).dy, lessThan(tester.getTopLeft(find.text('Utilities')).dy));
  });

  testWidgets('shows the server\'s message and retries', (tester) async {
    final server = _server()..failWith = 500;
    tester.view.physicalSize = const Size(412, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await server.install();
    await tester.pumpWidget(MaterialApp(theme: buildAdminAppTheme(), home: ExpenseCategoriesScreen(user: _user())));
    await tester.pumpAndSettle();

    expect(find.text('The server said no.'), findsOneWidget);

    server.failWith = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);
  });

  group('adding', () {
    testWidgets('makes the category, clears the box and shows it in the list', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.enterText(find.byKey(const Key('category-name-field')), 'ZZZ Bank charges');
      await tester.tap(find.byKey(const Key('add-category')));
      await tester.pumpAndSettle();

      expect(server.createdCategories, ['ZZZ Bank charges']);
      expect(find.byKey(const Key('category-zzz-bank-charges')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('category-zzz-bank-charges')), matching: find.text('0 expenses')), findsOneWidget);
      expect(find.text('ZZZ Bank charges added.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('category-name-field'))).controller!.text, '');
    });

    testWidgets('can be done from the keyboard', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.enterText(find.byKey(const Key('category-name-field')), 'ZZZ Stationery');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(server.createdCategories, ['ZZZ Stationery']);
    });

    testWidgets('will not send an empty name', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('add-category')));
      await tester.pumpAndSettle();

      expect(server.createdCategories, isEmpty);
      expect(find.text('Type a name first'), findsOneWidget);
    });

    testWidgets('explains, next to the box, why a name was refused', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.enterText(find.byKey(const Key('category-name-field')), 'rent');
      await tester.tap(find.byKey(const Key('add-category')));
      await tester.pumpAndSettle();

      expect(find.text('A category with this name already exists.'), findsOneWidget);
      expect(server.createdCategories, isEmpty);
      expect(tester.widget<TextField>(find.byKey(const Key('category-name-field'))).controller!.text, 'rent'); // kept for fixing
    });

    testWidgets('is not offered to someone who may not create', (tester) async {
      await _show(tester, _server(), user: _user(create: false));

      expect(find.byKey(const Key('category-name-field')), findsNothing);
      expect(find.byKey(const Key('add-category')), findsNothing);
    });
  });

  group('renaming', () {
    testWidgets('opens a box with the current name', (tester) async {
      await _show(tester, _server());

      await tester.tap(find.byKey(const Key('rename-fuel')));
      await tester.pumpAndSettle();

      expect(find.text('Rename category'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('rename-field'))).controller!.text, 'Fuel');
    });

    testWidgets('saves the new name and shows it', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('rename-fuel')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('rename-field')), 'Petrol');
      await tester.tap(find.byKey(const Key('save-rename')));
      await tester.pumpAndSettle();

      expect(server.renamedCategories, [(id: 1, name: 'Petrol')]);
      expect(find.text('Petrol'), findsOneWidget);
      expect(find.text('Fuel'), findsNothing);
      expect(find.text('Renamed to Petrol.'), findsOneWidget);
    });

    testWidgets('keeps the box open with the reason when the name is taken', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('rename-fuel')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('rename-field')), 'RENT');
      await tester.tap(find.byKey(const Key('save-rename')));
      await tester.pumpAndSettle();

      expect(find.text('A category with this name already exists.'), findsOneWidget);
      expect(find.text('Rename category'), findsOneWidget); // still open
      expect(server.renamedCategories, isEmpty);
    });

    testWidgets('an emptied name is not sent', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('rename-fuel')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('rename-field')), '   ');
      await tester.tap(find.byKey(const Key('save-rename')));
      await tester.pumpAndSettle();

      expect(find.text('Type a name'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'PUT'), isEmpty);
    });

    testWidgets('Cancel changes nothing', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('rename-fuel')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('rename-field')), 'Petrol');

      await tester.tap(find.byKey(const Key('cancel-rename')));
      await tester.pumpAndSettle();

      expect(server.renamedCategories, isEmpty);
      expect(find.text('Fuel'), findsOneWidget);
    });

    testWidgets('a category in use can still be renamed', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('rename-rent')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('rename-field')), 'Premises');
      await tester.tap(find.byKey(const Key('save-rename')));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byKey(const Key('category-rent')), matching: find.text('Premises')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('category-rent')), matching: find.text('2 expenses')), findsOneWidget);
    });

    testWidgets('is not offered to someone who may not update', (tester) async {
      await _show(tester, _server(), user: _user(update: false));

      expect(find.byKey(const Key('rename-fuel')), findsNothing);
    });
  });

  group('deleting', () {
    testWidgets('asks first, then removes an unused category', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('delete-fuel')));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Fuel"?'), findsOneWidget);
      expect(server.deletedCategories, isEmpty);

      await tester.tap(find.byKey(const Key('confirm-delete-category')));
      await tester.pumpAndSettle();

      expect(server.deletedCategories, [1]);
      expect(find.byKey(const Key('category-fuel')), findsNothing);
      expect(find.text('Fuel deleted.'), findsOneWidget);
    });

    testWidgets('"Keep it" changes nothing', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('delete-fuel')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('keep-category')));
      await tester.pumpAndSettle();

      expect(server.deletedCategories, isEmpty);
      expect(find.byKey(const Key('category-fuel')), findsOneWidget);
    });

    testWidgets('is disabled for a category with expenses filed under it', (tester) async {
      final server = _server();
      await _show(tester, server);

      final button = tester.widget<IconButton>(find.byKey(const Key('delete-rent')));
      expect(button.onPressed, isNull);
      expect(button.tooltip, 'In use — move or delete its expenses first');

      await tester.tap(find.byKey(const Key('delete-rent')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Delete "Rent"?'), findsNothing);
      expect(server.deletedCategories, isEmpty);
    });

    testWidgets('shows the server\'s reason if it refuses anyway', (tester) async {
      final server = _server();
      await _show(tester, server);
      server.failMethods['DELETE'] = 422;
      await tester.tap(find.byKey(const Key('delete-fuel')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-delete-category')));
      await tester.pumpAndSettle();

      expect(find.text('The server said no.'), findsOneWidget);
      expect(find.byKey(const Key('category-fuel')), findsOneWidget);
    });

    testWidgets('is not offered to someone who may not delete', (tester) async {
      await _show(tester, _server(), user: _user(delete: false));

      expect(find.byKey(const Key('delete-fuel')), findsNothing);
    });
  });
}
