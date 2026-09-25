import 'dart:async';

import 'package:driver_app/models/available_periods.dart';
import 'package:driver_app/models/hire.dart';
import 'package:driver_app/models/hire_page.dart';
import 'package:driver_app/models/hire_tab.dart';
import 'package:driver_app/screens/tour_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 25, 10);

var _id = 0;

Hire _hire(String label, {String status = 'pending', DateTime? startTime}) => Hire(
      id: ++_id,
      tourType: 'drop_pickup',
      tourTypeLabel: label,
      hireFullValue: 100,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
      status: status,
      startTime: startTime,
    );

List<Hire> _completed(String prefix, int n) => [for (var i = 1; i <= n; i++) _hire('$prefix $i', status: 'completed')];

class _Call {
  final int? year;
  final int? month;
  final String? status;
  final int page;
  _Call(this.year, this.month, this.status, this.page);

  @override
  String toString() => '($year, $month, $status, p$page)';
}

/// A fake server that records every request and answers with [answer].
class _Api {
  final calls = <_Call>[];
  Future<HirePage> Function(_Call call) answer;
  _Api(this.answer);

  Future<HirePage> fetch({int? year, int? month, String? status, int page = 1, int? perPage}) {
    final call = _Call(year, month, status, page);
    calls.add(call);
    return answer(call);
  }
}

final _periods = AvailablePeriods(years: const [2026, 2025], monthsByYear: const {2026: [9, 8], 2025: [12, 6]});

Future<void> _show(
  WidgetTester tester,
  HireTab tab,
  _Api api, {
  AvailablePeriods? periods,
  bool periodsFail = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: TourListScreen(
      tab: tab,
      now: _now,
      fetchHires: api.fetch,
      fetchPeriods: ({String? status}) async {
        if (periodsFail) throw Exception('offline');
        return periods ?? _periods;
      },
    ),
  ));
  await tester.pumpAndSettle();
}

String _summary(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('tour-list-summary'))).data!;

Future<void> _pick(WidgetTester tester, {required int dropdown, required String option}) async {
  await tester.tap(find.byType(DropdownButton<int?>).at(dropdown));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  group('opening', () {
    testWidgets('opens on THIS month, asking the server for exactly that tab\'s hires', (tester) async {
      final api = _Api((call) async => HirePage(items: _completed('Done', 3), total: 3));

      await _show(tester, HireTab.completed, api);

      expect(api.calls.single.year, 2026);
      expect(api.calls.single.month, 9);
      expect(api.calls.single.status, 'completed');
      expect(api.calls.single.page, 1);
      expect(find.text('Completed Tours'), findsOneWidget); // the page title
      expect(_summary(tester), '3 tours · September 2026');
      for (final label in ['Done 1', 'Done 2', 'Done 3']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('each tab has its own title and status group', (tester) async {
      for (final (tab, title, status) in [
        (HireTab.today, "Today's Tours", 'open'),
        (HireTab.scheduled, 'Scheduled Tours', 'open'),
        (HireTab.completed, 'Completed Tours', 'completed'),
        (HireTab.cancelled, 'Cancelled Tours', 'cancelled'),
      ]) {
        final api = _Api((call) async => HirePage(items: const [], total: 0));
        await _show(tester, tab, api);

        expect(find.text(title), findsOneWidget, reason: tab.name);
        expect(api.calls.first.status, status, reason: tab.name);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('shows a spinner until the first page arrives', (tester) async {
      final answer = Completer<HirePage>();
      final api = _Api((call) => answer.future);

      await tester.pumpWidget(MaterialApp(
        home: TourListScreen(tab: HireTab.completed, now: _now, fetchHires: api.fetch, fetchPeriods: ({String? status}) async => _periods),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_summary(tester), 'Loading…');

      answer.complete(HirePage(items: _completed('Done', 1), total: 1));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Done 1'), findsOneWidget);
    });

    testWidgets('an empty month says which month, and offers nothing to load', (tester) async {
      final api = _Api((call) async => HirePage(items: const [], total: 0));

      await _show(tester, HireTab.cancelled, api);

      expect(find.text('No cancelled tours in September 2026.'), findsOneWidget);
      expect(_summary(tester), '0 tours · September 2026');
      expect(find.byKey(const Key('tour-list-load-more')), findsNothing);
    });
  });

  group('Today and Scheduled', () {
    final today = _hire('Today job');
    final evening = _hire('Evening job', startTime: DateTime(2026, 9, 25, 18));
    final tomorrow = _hire('Tomorrow job', startTime: DateTime(2026, 9, 26, 9));
    final later = _hire('Later job', startTime: DateTime(2026, 9, 29, 9));

    testWidgets('both read the open hires; each keeps only its own, in order', (tester) async {
      final api = _Api((call) async => HirePage(items: [later, today, tomorrow, evening], total: 4));

      await _show(tester, HireTab.today, api);
      expect(find.text('Evening job'), findsOneWidget);
      expect(find.text('Today job'), findsOneWidget);
      expect(find.text('Tomorrow job'), findsNothing);
      expect(tester.getTopLeft(find.text('Evening job')).dy, lessThan(tester.getTopLeft(find.text('Today job')).dy));
      expect(_summary(tester), '2 tours · September 2026');
      await tester.pumpWidget(const SizedBox());

      await _show(tester, HireTab.scheduled, api);
      expect(find.text('Tomorrow job'), findsOneWidget);
      expect(find.text('Later job'), findsOneWidget);
      expect(find.text('Today job'), findsNothing);
      expect(tester.getTopLeft(find.text('Tomorrow job')).dy, lessThan(tester.getTopLeft(find.text('Later job')).dy));
    });

    testWidgets('keeps reading pages until this tab has something, rather than saying "none" too early', (tester) async {
      // page 1 holds only scheduled hires; the day's hire is on page 2
      final api = _Api((call) async => call.page == 1
          ? HirePage(items: [tomorrow, later], total: 3, currentPage: 1, lastPage: 2)
          : HirePage(items: [today], total: 3, currentPage: 2, lastPage: 2));

      await _show(tester, HireTab.today, api);

      expect(api.calls.map((c) => c.page), [1, 2]);
      expect(find.text('Today job'), findsOneWidget);
      expect(find.text('No tours for today in September 2026.'), findsNothing);
    });

    testWidgets('and gives up with "none" if no page has one', (tester) async {
      final api = _Api((call) async => call.page == 1
          ? HirePage(items: [tomorrow], total: 2, currentPage: 1, lastPage: 2)
          : HirePage(items: [later], total: 2, currentPage: 2, lastPage: 2));

      await _show(tester, HireTab.today, api);

      expect(api.calls.map((c) => c.page), [1, 2]);
      expect(find.text('No tours for today in September 2026.'), findsOneWidget);
    });
  });

  group('the filter', () {
    testWidgets('lists the years and months that have hires, plus the current period', (tester) async {
      final api = _Api((call) async => HirePage(items: const [], total: 0));
      await _show(tester, HireTab.completed, api);

      // year dropdown: everything reported + "All years"
      await tester.tap(find.byType(DropdownButton<int?>).first);
      await tester.pumpAndSettle();
      expect(find.text('All years'), findsWidgets);
      expect(find.text('2026'), findsWidgets);
      expect(find.text('2025'), findsWidgets);
      await tester.tapAt(const Offset(5, 5)); // close the menu
      await tester.pumpAndSettle();
    });

    testWidgets('choosing another year loads that whole year', (tester) async {
      final api = _Api((call) async => HirePage(items: const [], total: 0));
      await _show(tester, HireTab.completed, api);

      await _pick(tester, dropdown: 0, option: '2025');

      expect(api.calls.last.year, 2025);
      expect(api.calls.last.month, isNull);
      expect(_summary(tester), '0 tours · 2025');
      expect(find.text('No completed tours in 2025.'), findsOneWidget);
    });

    testWidgets('then a month of that year', (tester) async {
      final api = _Api((call) async => HirePage(items: _completed('Old', 2), total: 2));
      await _show(tester, HireTab.completed, api);

      await _pick(tester, dropdown: 0, option: '2025');
      await _pick(tester, dropdown: 1, option: 'December');

      expect(api.calls.last.year, 2025);
      expect(api.calls.last.month, 12);
      expect(_summary(tester), '2 tours · December 2025');
    });

    testWidgets('"All years" shows everything, and the month choice is switched off', (tester) async {
      final api = _Api((call) async => HirePage(items: _completed('Any', 4), total: 4));
      await _show(tester, HireTab.completed, api);

      await _pick(tester, dropdown: 0, option: 'All years');

      expect(api.calls.last.year, isNull);
      expect(api.calls.last.month, isNull);
      expect(_summary(tester), '4 tours · all time');
      expect(tester.widget<DropdownButton<int?>>(find.byType(DropdownButton<int?>).at(1)).onChanged, isNull);
    });

    testWidgets('"This month" appears once the filter has moved, and takes it back', (tester) async {
      final api = _Api((call) async => HirePage(items: const [], total: 0));
      await _show(tester, HireTab.completed, api);
      expect(find.byKey(const Key('tour-list-this-month')), findsNothing); // already on this month

      await _pick(tester, dropdown: 0, option: '2025');
      expect(find.byKey(const Key('tour-list-this-month')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tour-list-this-month')));
      await tester.pumpAndSettle();

      expect(api.calls.last.year, 2026);
      expect(api.calls.last.month, 9);
      expect(find.byKey(const Key('tour-list-this-month')), findsNothing);
      expect(_summary(tester), '0 tours · September 2026');
    });

    testWidgets('the months on offer are only those of the chosen year (plus this month, for this year)', (tester) async {
      final api = _Api((call) async => HirePage(items: const [], total: 0));
      // no hires reported in 2026 at all: this month is still offered
      await _show(tester, HireTab.completed, api, periods: AvailablePeriods(years: const [2025], monthsByYear: const {2025: [12]}));

      await tester.tap(find.byType(DropdownButton<int?>).first);
      await tester.pumpAndSettle();
      expect(find.text('2026'), findsWidgets); // the current year is always there
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<int?>).at(1));
      await tester.pumpAndSettle();
      expect(find.text('September'), findsWidgets); // this month
      expect(find.text('December'), findsNothing); // 2025's month is not offered for 2026
    });

    testWidgets('still works when the list of periods could not be loaded', (tester) async {
      final api = _Api((call) async => HirePage(items: _completed('Done', 1), total: 1));

      await _show(tester, HireTab.completed, api, periodsFail: true);

      expect(find.text('Done 1'), findsOneWidget);
      expect(_summary(tester), '1 tour · September 2026'); // singular
      await _pick(tester, dropdown: 0, option: 'All years');
      expect(api.calls.last.year, isNull);
    });

    testWidgets('an answer for an old filter never lands on top of the new one', (tester) async {
      final slowOld = Completer<HirePage>();
      final api = _Api((call) => call.year == 2026 ? slowOld.future : Future.value(HirePage(items: _completed('Newer', 1), total: 1)));

      await tester.pumpWidget(MaterialApp(
        home: TourListScreen(tab: HireTab.completed, now: _now, fetchHires: api.fetch, fetchPeriods: ({String? status}) async => _periods),
      ));
      await tester.pump(); // this month's request is in flight…

      // …and the driver moves on. (Fixed frames, not pumpAndSettle: the spinner
      // for the still-pending first request never stops animating.)
      await tester.tap(find.byType(DropdownButton<int?>).first);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.tap(find.text('2025').last);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Newer 1'), findsOneWidget);

      slowOld.complete(HirePage(items: _completed('Stale', 3), total: 3)); // the old answer finally arrives
      await tester.pumpAndSettle();

      expect(find.text('Stale 1'), findsNothing);
      expect(find.text('Newer 1'), findsOneWidget);
      expect(_summary(tester), '1 tour · 2025');
    });
  });

  group('paging', () {
    testWidgets('a long list loads a page at a time with a Load more button', (tester) async {
      final api = _Api((call) async {
        if (call.page == 1) return HirePage(items: _completed('A', 3), total: 5, currentPage: 1, lastPage: 2);
        return HirePage(items: _completed('B', 2), total: 5, currentPage: 2, lastPage: 2);
      });

      await _show(tester, HireTab.completed, api);
      expect(find.text('A 1'), findsOneWidget);
      expect(find.text('B 1'), findsNothing);
      expect(_summary(tester), '5 tours · September 2026'); // the true total, before everything is loaded
      expect(find.byKey(const Key('tour-list-load-more')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('tour-list-load-more')));
      await tester.tap(find.byKey(const Key('tour-list-load-more')));
      await tester.pumpAndSettle();

      expect(api.calls.map((c) => c.page), [1, 2]);
      expect(find.text('A 1'), findsOneWidget); // still there
      expect(find.text('B 1'), findsOneWidget);
      expect(find.text('B 2'), findsOneWidget);
      expect(find.byKey(const Key('tour-list-load-more')), findsNothing); // that was the last page
    });

    testWidgets('a hire that shifts onto the next page (a new one arrived meanwhile) is not listed twice', (tester) async {
      final shared = _hire('Shared', status: 'completed');
      final api = _Api((call) async => call.page == 1
          ? HirePage(items: [shared, _hire('Only on 1', status: 'completed')], total: 3, currentPage: 1, lastPage: 2)
          : HirePage(items: [shared, _hire('Only on 2', status: 'completed')], total: 3, currentPage: 2, lastPage: 2));

      await _show(tester, HireTab.completed, api);
      await tester.ensureVisible(find.byKey(const Key('tour-list-load-more')));
      await tester.tap(find.byKey(const Key('tour-list-load-more')));
      await tester.pumpAndSettle();

      expect(find.text('Shared'), findsOneWidget);
      expect(find.text('Only on 2'), findsOneWidget);
    });

    testWidgets('changing the filter starts again from page 1', (tester) async {
      final api = _Api((call) async => HirePage(items: _completed('P${call.page}-', 2), total: 4, currentPage: call.page, lastPage: 2));
      await _show(tester, HireTab.completed, api);
      await tester.ensureVisible(find.byKey(const Key('tour-list-load-more')));
      await tester.tap(find.byKey(const Key('tour-list-load-more')));
      await tester.pumpAndSettle();
      expect(api.calls.last.page, 2);

      await _pick(tester, dropdown: 0, option: '2025');

      expect(api.calls.last.page, 1);
      expect(api.calls.last.year, 2025);
    });
  });

  group('when something goes wrong', () {
    testWidgets('a failed first load shows the error and Try again', (tester) async {
      var fail = true;
      final api = _Api((call) async {
        if (fail) throw Exception('No connection');
        return HirePage(items: _completed('Done', 1), total: 1);
      });

      await _show(tester, HireTab.completed, api);
      expect(find.textContaining('No connection'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Done 1'), findsOneWidget);
      expect(find.textContaining('No connection'), findsNothing);
    });

    testWidgets('a failed Load more keeps what is already listed and offers Try again', (tester) async {
      var failPage2 = true;
      final api = _Api((call) async {
        if (call.page == 1) return HirePage(items: _completed('A', 2), total: 4, currentPage: 1, lastPage: 2);
        if (failPage2) throw Exception('Timed out');
        return HirePage(items: _completed('B', 2), total: 4, currentPage: 2, lastPage: 2);
      });

      await _show(tester, HireTab.completed, api);
      await tester.ensureVisible(find.byKey(const Key('tour-list-load-more')));
      await tester.tap(find.byKey(const Key('tour-list-load-more')));
      await tester.pumpAndSettle();

      expect(find.text('A 1'), findsOneWidget);
      expect(find.textContaining('Timed out'), findsOneWidget);

      failPage2 = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('B 1'), findsOneWidget);
      expect(find.textContaining('Timed out'), findsNothing);
    });
  });
}
