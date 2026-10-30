import 'package:driver_app/models/hire.dart';
import 'package:driver_app/screens/hire_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Hire _hire({String? customerName = 'Amal Perera', String? customerPhone = '0712345678'}) => Hire(
      id: 7,
      customerName: customerName,
      customerPhone: customerPhone,
      tourType: 'drop_pickup',
      tourTypeLabel: 'Drop and Pickup',
      fromLocation: 'Colombo Fort',
      toLocation: 'Ella',
      hireFullValue: 95,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
    );

/// Records every tel: link the screen tries to open.
class _Launches {
  _Launches({this.succeed = true});

  final bool succeed;
  final urls = <Uri>[];

  Future<bool> call(Uri url) async {
    urls.add(url);
    return succeed;
  }
}

Future<void> _show(WidgetTester tester, Hire hire, {_Launches? launches}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: HireDetailScreen(hire: hire, launchPhoneUrl: launches?.call),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _hide(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

// Run as iOS so the Android-only background service isn't involved.
final _iosOnly = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  testWidgets('shows the customer\'s name and phone', (tester) async {
    await _show(tester, _hire());

    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Amal Perera'), findsOneWidget);
    expect(find.text('0712345678'), findsOneWidget);

    await _hide(tester);
  }, variant: _iosOnly);

  testWidgets('tapping Call Customer dials the customer\'s number', (tester) async {
    final launches = _Launches();
    await _show(tester, _hire(), launches: launches);

    await tester.tap(find.byKey(const Key('call-customer')));
    await tester.pump();

    expect(launches.urls, hasLength(1));
    expect(launches.urls.single.scheme, 'tel');
    expect(launches.urls.single.path, '0712345678');

    await _hide(tester);
  }, variant: _iosOnly);

  testWidgets('shows a snack bar when the dialer can\'t be opened', (tester) async {
    await _show(tester, _hire(), launches: _Launches(succeed: false));

    await tester.tap(find.byKey(const Key('call-customer')));
    await tester.pump();

    expect(find.text('Could not open the dialer.'), findsOneWidget);

    await _hide(tester);
  }, variant: _iosOnly);

  testWidgets('no Customer section or Call button when there is no customer on record', (tester) async {
    await _show(tester, _hire(customerName: null, customerPhone: null));

    expect(find.text('Customer'), findsNothing);
    expect(find.byKey(const Key('call-customer')), findsNothing);

    await _hide(tester);
  }, variant: _iosOnly);

  testWidgets('shows the name with no Call button when there is no phone on record', (tester) async {
    await _show(tester, _hire(customerPhone: null));

    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Amal Perera'), findsOneWidget);
    expect(find.byKey(const Key('call-customer')), findsNothing);

    await _hide(tester);
  }, variant: _iosOnly);
}
