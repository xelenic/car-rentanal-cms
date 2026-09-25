import 'package:driver_app/models/hire.dart';
import 'package:driver_app/models/hire_page.dart';
import 'package:driver_app/models/hire_tab.dart';
import 'package:driver_app/models/tab_hires.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 25, 10);

var _id = 0;

Hire _hire(String status, {DateTime? startTime, bool tracking = false}) => Hire(
      id: ++_id,
      tourType: 'drop_pickup',
      tourTypeLabel: 'Hire $_id',
      hireFullValue: 100,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
      status: status,
      startTime: startTime,
      isTracking: tracking,
    );

HirePage _page(List<Hire> items, {int? total}) => HirePage(items: items, total: total ?? items.length);

void main() {
  group('buildHomeTabs', () {
    test('Today and Scheduled are the open hires split by the driver\'s date; totals are what was loaded', () {
      final today = _hire('pending');
      final evening = _hire('pending', startTime: DateTime(2026, 9, 25, 18));
      final tomorrow = _hire('pending', startTime: DateTime(2026, 9, 26, 9));

      final tabs = buildHomeTabs(
        open: _page([tomorrow, today, evening]),
        completed: _page(const []),
        cancelled: _page(const []),
        now: _now,
      );

      expect(tabs[HireTab.today]!.items, [evening, today]); // scheduled first, unscheduled last
      expect(tabs[HireTab.today]!.total, 2);
      expect(tabs[HireTab.scheduled]!.items, [tomorrow]);
      expect(tabs[HireTab.scheduled]!.total, 1);
    });

    test('Completed and Cancelled use the server\'s exact total — even though only a few are loaded', () {
      final tabs = buildHomeTabs(
        open: _page(const []),
        completed: _page([_hire('completed'), _hire('completed'), _hire('completed'), _hire('completed'), _hire('completed')], total: 37),
        cancelled: _page([_hire('cancelled')], total: 4),
        now: _now,
      );

      expect(tabs[HireTab.completed]!.items, hasLength(5));
      expect(tabs[HireTab.completed]!.total, 37);
      expect(tabs[HireTab.cancelled]!.total, 4);
    });

    test('a server that ignores the status filter sends every status: only what belongs in the tab is kept and counted', () {
      final everything = [_hire('completed'), _hire('cancelled'), _hire('pending'), _hire('completed')];

      final tabs = buildHomeTabs(
        open: _page(everything, total: 4),
        completed: _page(everything, total: 4), // 4 is the total of ALL hires here — not of completed ones
        cancelled: _page(everything, total: 4),
        now: _now,
      );

      expect(tabs[HireTab.completed]!.items, hasLength(2));
      expect(tabs[HireTab.completed]!.total, 2);
      expect(tabs[HireTab.cancelled]!.items, hasLength(1));
      expect(tabs[HireTab.cancelled]!.total, 1);
      expect(tabs[HireTab.today]!.items, hasLength(1)); // the pending one
    });

    test('empty responses give empty tabs', () {
      final tabs = buildHomeTabs(open: _page(const []), completed: _page(const []), cancelled: _page(const []), now: _now);

      for (final tab in HireTab.values) {
        expect(tabs[tab]!.items, isEmpty);
        expect(tabs[tab]!.total, 0);
      }
    });

    test('a running hire is listed first under Today', () {
      final waiting = _hire('pending', startTime: DateTime(2026, 9, 25, 8));
      final running = _hire('started', tracking: true);

      final tabs = buildHomeTabs(open: _page([waiting, running]), completed: _page(const []), cancelled: _page(const []), now: _now);

      expect(tabs[HireTab.today]!.items, [running, waiting]);
    });
  });

  group('the API pages', () {
    test('report which page they are and how many there are', () {
      final page = HirePage.fromJson({
        'data': const <Object>[],
        'meta': {'total': 12, 'current_page': 2, 'last_page': 3},
      });

      expect(page.currentPage, 2);
      expect(page.lastPage, 3);
      expect(page.hasMore, isTrue);
    });

    test('the last page has no more, and a server that does not page reports a single page', () {
      final last = HirePage.fromJson({'data': const <Object>[], 'meta': {'total': 12, 'current_page': 3, 'last_page': 3}});
      final unpaged = HirePage.fromJson({'data': const <Object>[]});

      expect(last.hasMore, isFalse);
      expect(unpaged.currentPage, 1);
      expect(unpaged.lastPage, 1);
      expect(unpaged.hasMore, isFalse);
    });
  });

  test('each tab maps to the API status group that holds its hires', () {
    expect(HireTab.today.apiStatus, 'open');
    expect(HireTab.scheduled.apiStatus, 'open');
    expect(HireTab.completed.apiStatus, 'completed');
    expect(HireTab.cancelled.apiStatus, 'cancelled');
    expect(HireTab.values.where((t) => t.isHistory), [HireTab.completed, HireTab.cancelled]);
    expect(kHomeTabLimit, 5);
  });
}
