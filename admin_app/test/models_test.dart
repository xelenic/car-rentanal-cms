import 'package:admin_app/models/admin_user.dart';
import 'package:admin_app/models/hire.dart';
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

  test('VehiclePage reads the paging and the fleet summary', () {
    final page = VehiclePage.fromJson({
      'data': [vehicleJson(id: 1)],
      'meta': {'current_page': 1, 'last_page': 3},
      'summary': {'vehicle_count': 21, 'hire_count': 7, 'hire_full_value_total': 5000, 'our_hire_value_total': 4000, 'commission_total': 1000},
    });

    expect(page.vehicles, hasLength(1));
    expect(page.hasMore, isTrue);
    expect(page.summary.vehicleCount, 21);
    expect(page.summary.commissionTotal, 1000);
  });

  test('AdminUser reads the vehicle permissions, and defaults them off for an older server', () {
    final newer = AdminUser.fromJson({
      'id': 1, 'name': 'A', 'email': 'a@x.test',
      'can_create_hires': true, 'can_view_vehicles': true, 'can_create_vehicles': true,
    });
    final older = AdminUser.fromJson({'id': 1, 'name': 'A', 'email': 'a@x.test', 'can_create_hires': true});

    expect(newer.canCreateVehicles, isTrue);
    expect(newer.canViewVehicles, isTrue);
    expect(older.canCreateVehicles, isFalse);
    expect(older.canViewVehicles, isFalse);
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
