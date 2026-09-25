import 'package:admin_app/models/admin_user.dart';
import 'package:admin_app/models/hire.dart';
import 'package:admin_app/models/hire_period.dart';
import 'package:admin_app/models/hire_tab.dart';
import 'package:admin_app/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

Hire _hire({String status = 'pending', String? start}) =>
    Hire.fromJson(hireJson(id: 1, status: status, startTime: start));

void main() {
  group('Vehicle.fromJson', () {
    test('reads the vehicle and its numbers', () {
      final vehicle = Vehicle.fromJson(vehicleJson(
        id: 3,
        model: 'ZZZ Test Bus',
        condition: 'Excellent',
        seats: 30,
        pax: 28,
        description: 'ZZZ roomy',
        stats: vehicleStatsJson(
          hireCount: 5,
          full: 12500.5,
          our: 10000,
          monthCount: 2,
          monthFull: 3000,
          all: 7,
          today: 1,
          scheduled: 2,
          completed: 3,
          cancelled: 1,
          running: 1,
        ),
      ));

      expect(vehicle.id, 3);
      expect(vehicle.model, 'ZZZ Test Bus');
      expect(vehicle.condition, 'Excellent');
      expect(vehicle.seats, 30);
      expect(vehicle.pax, 28);
      expect(vehicle.description, 'ZZZ roomy');
      expect(vehicle.stats.hireCount, 5);
      expect(vehicle.stats.hireFullValueTotal, 12500.5);
      expect(vehicle.stats.ourHireValueTotal, 10000);
      expect(vehicle.stats.commissionTotal, 2500.5);
      expect(vehicle.stats.monthHireCount, 2);
      expect(vehicle.stats.monthHireFullValueTotal, 3000);
      expect(vehicle.stats.counts.running, 1);
    });

    test('counts are looked up per tab', () {
      final counts = Vehicle.fromJson(vehicleJson(
        id: 1,
        stats: vehicleStatsJson(all: 9, today: 4, scheduled: 2, completed: 2, cancelled: 1),
      )).stats.counts;

      expect({for (final tab in HireTab.values) tab: counts.of(tab)}, {
        HireTab.all: 9,
        HireTab.today: 4,
        HireTab.scheduled: 2,
        HireTab.completed: 2,
        HireTab.cancelled: 1,
      });
    });

    test('copes with a vehicle that has no stats or a blank description', () {
      final vehicle = Vehicle.fromJson({'id': 1, 'model': 'ZZZ', 'condition': 'New', 'seats': 2, 'pax': 2, 'description': '  '});

      expect(vehicle.description, isNull);
      expect(vehicle.stats.hireCount, 0);
      expect(vehicle.stats.counts.all, 0);
    });

    test('takes money that arrives as a string', () {
      final stats = VehicleStats.fromJson({'hire_full_value_total': '1200.50', 'counts': {'all': '3'}});

      expect(stats.hireFullValueTotal, 1200.5);
      expect(stats.counts.all, 3);
    });
  });

  test('VehiclePage reads the vehicles and the paging', () {
    final page = VehiclePage.fromJson({
      'data': [vehicleJson(id: 1)],
      'meta': {'current_page': 1, 'last_page': 3},
    });

    expect(page.vehicles, hasLength(1));
    expect(page.hasMore, isTrue);
  });

  test('AdminUser reads what the user may do, and defaults it off for an older server', () {
    final newer = AdminUser.fromJson({
      'id': 1, 'name': 'A', 'email': 'a@x.test',
      'can_create_hires': true, 'can_update_hires': true, 'can_delete_hires': true,
      'can_view_vehicles': true, 'can_create_vehicles': true,
    });
    final older = AdminUser.fromJson({'id': 1, 'name': 'A', 'email': 'a@x.test', 'can_create_hires': true});

    expect(newer.canCreateVehicles, isTrue);
    expect(newer.canViewVehicles, isTrue);
    expect(newer.canUpdateHires, isTrue);
    expect(newer.canDeleteHires, isTrue);
    expect(older.canCreateVehicles, isFalse);
    expect(older.canViewVehicles, isFalse);
    expect(older.canUpdateHires, isFalse);
    expect(older.canDeleteHires, isFalse);
  });

  group('a hire\'s times', () {
    test('start and end are read as the clock time that was entered, whatever zone the phone is in', () {
      final hire = Hire.fromJson({
        ...hireJson(id: 1),
        'start_time': '2026-09-29T18:09:00+00:00',
        'end_time': '2026-10-01T07:30:00.000000Z',
      });

      expect(hire.startTime, DateTime(2026, 9, 29, 18, 9));
      expect(hire.endTime, DateTime(2026, 10, 1, 7, 30));
      expect(hire.startTime!.isUtc, isFalse);
    });

    test('also read a time without an offset or seconds', () {
      final hire = Hire.fromJson({...hireJson(id: 1), 'start_time': '2026-09-29 18:09'});

      expect(hire.startTime, DateTime(2026, 9, 29, 18, 9));
    });

    test('an unset time stays unset', () {
      expect(Hire.fromJson(hireJson(id: 1)).startTime, isNull);
    });

    test('a real instant, like when a hire was cancelled, is still shown in the phone\'s zone', () {
      final hire = Hire.fromJson({...hireJson(id: 1), 'cancelled_at': '2026-09-24T12:31:00+00:00'});

      expect(hire.cancelledAt, DateTime.utc(2026, 9, 24, 12, 31).toLocal());
    });

    test('a saved-then-reloaded time does not drift', () {
      // What the form sends is the local clock time without an offset; the
      // server hands back the same digits labelled UTC.
      final entered = DateTime(2026, 9, 29, 18, 9);
      final sent = entered.toIso8601String(); // 2026-09-29T18:09:00.000
      final reloaded = Hire.fromJson({...hireJson(id: 1), 'start_time': '${sent.substring(0, 19)}+00:00'});

      expect(reloaded.startTime, entered);
    });
  });

  test('a hire carries its package id for the edit form', () {
    expect(Hire.fromJson(hireJson(id: 1, packageId: 4)).packageId, 4);
    expect(Hire.fromJson(hireJson(id: 1)).packageId, isNull);
  });

  group('HirePeriod', () {
    test('is labelled by month and year, or just the year', () {
      expect(const HirePeriod(2026, 9).label, 'September 2026');
      expect(const HirePeriod(2026).label, '2026');
    });

    test('becomes the API\'s query parameters', () {
      expect(const HirePeriod(2026, 9).query, {'year': '2026', 'month': '9'});
      expect(const HirePeriod(2026).query, {'year': '2026'});
    });

    test('is equal to the same period', () {
      expect(const HirePeriod(2026, 9), const HirePeriod(2026, 9));
      expect(const HirePeriod(2026, 9), isNot(const HirePeriod(2026, 8)));
      expect(const HirePeriod(2026, 9), isNot(const HirePeriod(2026)));
    });
  });

  group('PeriodOptions', () {
    test('reads the years and each year\'s months', () {
      final options = PeriodOptions.fromJson({
        'years': [2026, 2025],
        'months_by_year': {'2026': [9, 8], '2025': [12]},
      });

      expect(options.years, [2026, 2025]);
      expect(options.monthsOf(2026), [9, 8]);
      expect(options.monthsOf(2025), [12]);
      expect(options.monthsOf(2024), isEmpty);
    });

    test('reads a vehicle with no hires', () {
      final options = PeriodOptions.fromJson({'years': [], 'months_by_year': {}});

      expect(options.years, isEmpty);
      expect(options.monthsByYear, isEmpty);
    });
  });

  group('Hire cancellation fields', () {
    test('are read for a cancelled hire', () {
      final hire = Hire.fromJson({
        ...hireJson(id: 4, status: 'cancelled', cancelReason: 'ZZZ plans changed'),
        'cancelled_at': '2026-09-11T10:00:00+00:00',
      });

      expect(hire.isCancelled, isTrue);
      expect(hire.cancelReason, 'ZZZ plans changed');
      expect(hire.cancelledAt, isNotNull);
    });

    test('are absent on a normal hire', () {
      final hire = _hire();

      expect(hire.isCancelled, isFalse);
      expect(hire.cancelledAt, isNull);
    });
  });

  group('tabOfNewHire', () {
    final now = DateTime(2026, 9, 16, 12);

    test('a hire for later today is Today', () {
      expect(tabOfNewHire(_hire(start: '2026-09-16T20:00:00'), now: now), HireTab.today);
    });

    test('a hire with no date is Today', () {
      expect(tabOfNewHire(_hire(), now: now), HireTab.today);
    });

    test('a hire dated tomorrow or later is Scheduled', () {
      expect(tabOfNewHire(_hire(start: '2026-09-17T00:00:00'), now: now), HireTab.scheduled);
      expect(tabOfNewHire(_hire(start: '2026-12-01T09:00:00'), now: now), HireTab.scheduled);
    });

    test('an overdue hire is still Today', () {
      expect(tabOfNewHire(_hire(start: '2026-09-01T09:00:00'), now: now), HireTab.today);
    });

    test('finished hires go to their own tabs', () {
      expect(tabOfNewHire(_hire(status: 'completed'), now: now), HireTab.completed);
      expect(tabOfNewHire(_hire(status: 'cancelled'), now: now), HireTab.cancelled);
    });
  });
}
