import 'package:driver_app/models/hire.dart';
import 'package:driver_app/models/hire_page.dart';
import 'package:driver_app/models/hire_tab.dart';
import 'package:driver_app/models/tab_hires.dart';
import 'package:driver_app/widgets/tour_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 25, 10);

Hire _hire(
  String label, {
  String status = 'pending',
  DateTime? startTime,
  DateTime? cancelledAt,
  bool tracking = false,
}) =>
    Hire(
      id: label.hashCode & 0xffff,
      tourType: 'drop_pickup',
      tourTypeLabel: label,
      hireFullValue: 100,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
      status: status,
      startTime: startTime,
      cancelledAt: cancelledAt,
      isTracking: tracking,
    );

/// The four tabs as Home builds them.
Map<HireTab, TabHires> _tabs({
  List<Hire> open = const [],
  List<Hire> completed = const [],
  int? completedTotal,
  List<Hire> cancelled = const [],
  int? cancelledTotal,
}) =>
    buildHomeTabs(
      open: HirePage(items: open, total: open.length),
      completed: HirePage(items: completed, total: completedTotal ?? completed.length),
      cancelled: HirePage(items: cancelled, total: cancelledTotal ?? cancelled.length),
      now: _now,
    );

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
    );

Finder _tile(String name) => find.byKey(Key('tour-tab-$name'));
Finder _more(String name) => find.byKey(Key('tour-more-$name'));

/// The count shown on a tab tile (the number above its name).
String _countOn(WidgetTester tester, String name) {
  final texts = tester.widgetList<Text>(find.descendant(of: _tile(name), matching: find.byType(Text))).toList();
  return texts.first.data!;
}

List<Hire> _many(String prefix, int n, {String status = 'pending', DateTime? startTime}) =>
    [for (var i = 1; i <= n; i++) _hire('$prefix $i', status: status, startTime: startTime)];

void main() {
  group('the four tabs', () {
    testWidgets('are Today, Scheduled, Completed and Cancelled, each with its count', (tester) async {
      final tabs = _tabs(
        open: [
          _hire('Assigned today'),
          _hire('Evening tour', startTime: DateTime(2026, 9, 25, 18)),
          _hire('Running now', status: 'started', tracking: true),
          _hire('Tomorrow', startTime: DateTime(2026, 9, 26, 8, 30)),
          _hire('Next week', startTime: DateTime(2026, 10, 2, 9)),
        ],
        completed: _many('Done', 3, status: 'completed'),
        cancelled: [_hire('Called off', status: 'cancelled')],
      );

      await tester.pumpWidget(_app(TourTabs(tabs: tabs, now: _now)));

      expect(find.text('Assigned Tours'), findsOneWidget);
      for (final label in ['Today', 'Scheduled', 'Completed', 'Cancelled']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(_countOn(tester, 'today'), '3');
      expect(_countOn(tester, 'scheduled'), '2');
      expect(_countOn(tester, 'completed'), '3');
      expect(_countOn(tester, 'cancelled'), '1');
    });

    testWidgets('a history tab\'s count is the true total, not just the few loaded', (tester) async {
      final tabs = _tabs(completed: _many('Done', 5, status: 'completed'), completedTotal: 37, cancelledTotal: 0);

      await tester.pumpWidget(_app(TourTabs(tabs: tabs, now: _now)));

      expect(_countOn(tester, 'completed'), '37');
    });

    testWidgets('open on Today, running hire first', (tester) async {
      final tabs = _tabs(open: [
        _hire('Assigned today'),
        _hire('Evening tour', startTime: DateTime(2026, 9, 25, 18)),
        _hire('Running now', status: 'started', tracking: true),
        _hire('Tomorrow', startTime: DateTime(2026, 9, 26, 8, 30)),
      ]);

      await tester.pumpWidget(_app(TourTabs(tabs: tabs, now: _now)));

      expect(find.text('Running now'), findsOneWidget);
      expect(find.text('Evening tour'), findsOneWidget);
      expect(find.text('Assigned today'), findsOneWidget);
      expect(find.text('Tomorrow'), findsNothing);

      double y(String label) => tester.getTopLeft(find.text(label)).dy;
      expect(y('Running now'), lessThan(y('Evening tour')));
      expect(y('Evening tour'), lessThan(y('Assigned today')));
    });

    testWidgets('Scheduled shows the upcoming hires with their schedule; Cancelled says when', (tester) async {
      final tabs = _tabs(
        open: [
          _hire('Next week', startTime: DateTime(2026, 10, 2, 9)),
          _hire('Tomorrow', startTime: DateTime(2026, 9, 26, 8, 30)),
        ],
        cancelled: [_hire('Called off', status: 'cancelled', cancelledAt: DateTime(2026, 9, 24, 15, 40))],
      );
      await tester.pumpWidget(_app(TourTabs(tabs: tabs, now: _now)));

      await tester.tap(_tile('scheduled'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Tomorrow')).dy, lessThan(tester.getTopLeft(find.text('Next week')).dy));
      expect(find.text('Scheduled Sep 26, 8:30 AM'), findsOneWidget);

      await tester.tap(_tile('cancelled'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelled Sep 24, 3:40 PM'), findsOneWidget);
    });

    testWidgets('an empty tab says so, in its own words', (tester) async {
      await tester.pumpWidget(_app(TourTabs(tabs: _tabs(open: [_hire('Only today')]), now: _now)));

      for (final (tab, message) in [
        ('scheduled', 'No upcoming scheduled tours.'),
        ('completed', 'Completed tours will show up here.'),
        ('cancelled', 'Cancelled tours will show up here.'),
      ]) {
        await tester.tap(_tile(tab));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget, reason: tab);
      }
    });

    testWidgets('keeps the chosen tab when the tabs are refreshed', (tester) async {
      await tester.pumpWidget(_app(TourTabs(tabs: _tabs(cancelled: [_hire('Called off', status: 'cancelled')]), now: _now)));
      await tester.tap(_tile('cancelled'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_app(TourTabs(
        tabs: _tabs(cancelled: [_hire('Called off', status: 'cancelled'), _hire('Another', status: 'cancelled')]),
        now: _now,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Another'), findsOneWidget);
      expect(_countOn(tester, 'cancelled'), '2');
    });
  });

  group('five at a time, then More', () {
    testWidgets('a tab shows only its first five hires', (tester) async {
      await tester.pumpWidget(_app(TourTabs(tabs: _tabs(open: _many('Job', 8)), now: _now)));

      for (var i = 1; i <= 5; i++) {
        expect(find.text('Job $i'), findsOneWidget, reason: 'Job $i');
      }
      for (var i = 6; i <= 8; i++) {
        expect(find.text('Job $i'), findsNothing, reason: 'Job $i');
      }
      expect(_countOn(tester, 'today'), '8'); // the count still says how many there are
    });

    testWidgets('exactly five, or fewer, need no More on Today and Scheduled', (tester) async {
      await tester.pumpWidget(_app(TourTabs(tabs: _tabs(open: _many('Job', 5)), now: _now)));
      expect(find.byType(HireListOrEmpty), findsOneWidget);
      expect(_more('today'), findsNothing);

      await tester.pumpWidget(_app(TourTabs(tabs: _tabs(open: _many('Job', 2)), now: _now)));
      expect(_more('today'), findsNothing);
    });

    testWidgets('six or more show More below the list', (tester) async {
      await tester.pumpWidget(_app(TourTabs(tabs: _tabs(open: _many('Job', 6)), now: _now)));

      expect(_more('today'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      // it sits below the last card
      expect(tester.getTopLeft(_more('today')).dy, greaterThan(tester.getTopLeft(find.text('Job 5')).dy));
    });

    testWidgets('Completed and Cancelled always offer More when they have any hires — that is where the month filter is', (tester) async {
      final tabs = _tabs(completed: _many('Done', 2, status: 'completed'), cancelled: [_hire('Called off', status: 'cancelled')]);
      await tester.pumpWidget(_app(TourTabs(tabs: tabs, now: _now)));

      await tester.tap(_tile('completed'));
      await tester.pumpAndSettle();
      expect(_more('completed'), findsOneWidget);

      await tester.tap(_tile('cancelled'));
      await tester.pumpAndSettle();
      expect(_more('cancelled'), findsOneWidget);
    });

    testWidgets('but not when there is nothing in that tab at all', (tester) async {
      await tester.pumpWidget(_app(TourTabs(tabs: _tabs(), now: _now)));

      for (final tab in ['today', 'scheduled', 'completed', 'cancelled']) {
        await tester.tap(_tile(tab));
        await tester.pumpAndSettle();
        expect(_more(tab), findsNothing, reason: tab);
      }
    });

    testWidgets('More opens that tab\'s own list page', (tester) async {
      HireTab? opened;
      await tester.pumpWidget(_app(TourTabs(
        tabs: _tabs(completed: _many('Done', 3, status: 'completed')),
        now: _now,
        listPageBuilder: (tab) {
          opened = tab;
          return Scaffold(appBar: AppBar(title: Text('LIST OF ${tab.name}')));
        },
      )));

      await tester.tap(_tile('completed'));
      await tester.pumpAndSettle();
      await tester.tap(_more('completed'));
      await tester.pumpAndSettle();

      expect(opened, HireTab.completed);
      expect(find.text('LIST OF completed'), findsOneWidget);
    });

    testWidgets('coming back from the list reports a change, so Home can refresh', (tester) async {
      var changes = 0;
      await tester.pumpWidget(_app(TourTabs(
        tabs: _tabs(open: _many('Job', 7)),
        now: _now,
        onChanged: () => changes++,
        listPageBuilder: (tab) => Scaffold(appBar: AppBar(title: const Text('LIST'))),
      )));

      await tester.tap(_more('today'));
      await tester.pumpAndSettle();
      expect(changes, 0);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(changes, 1);
    });
  });
}
