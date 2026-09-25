import 'package:driver_app/models/hire.dart';
import 'package:driver_app/models/hire_tab.dart';
import 'package:flutter_test/flutter_test.dart';

// "Now" for every test: Sep 25, 2026, 10:00 (local).
final _now = DateTime(2026, 9, 25, 10);

var _nextId = 1;

Hire _hire({
  String status = 'pending',
  DateTime? startTime,
  bool tracking = false,
  String label = '',
}) {
  final id = _nextId++;

  return Hire(
    id: id,
    tourType: 'drop_pickup',
    tourTypeLabel: label.isEmpty ? 'Hire $id' : label,
    hireFullValue: 100,
    paymentType: 'cash',
    paymentTypeLabel: 'Cash',
    status: status,
    startTime: startTime,
    isTracking: tracking,
    trackingStartedAt: tracking ? DateTime(2026, 9, 25, 8) : null,
  );
}

HireTab _tab(Hire hire) => hireTabOf(hire, now: _now);

List<int> _ids(List<Hire> hires) => hires.map((h) => h.id).toList();

void main() {
  group('hireTabOf', () {
    test('a hire assigned with no schedule is for today', () {
      expect(_tab(_hire()), HireTab.today);
    });

    test('a hire scheduled for today — earlier or later in the day — is for today', () {
      expect(_tab(_hire(startTime: DateTime(2026, 9, 25, 7))), HireTab.today);
      expect(_tab(_hire(startTime: DateTime(2026, 9, 25, 17))), HireTab.today);
      expect(_tab(_hire(startTime: DateTime(2026, 9, 25, 23, 59))), HireTab.today);
    });

    test('a hire scheduled for a later day is Scheduled — from the first minute of tomorrow', () {
      expect(_tab(_hire(startTime: DateTime(2026, 9, 26))), HireTab.scheduled);
      expect(_tab(_hire(startTime: DateTime(2026, 9, 26, 9, 30))), HireTab.scheduled);
      expect(_tab(_hire(startTime: DateTime(2026, 12, 1))), HireTab.scheduled);
    });

    test('a hire still open from an earlier day is still today\'s work, not lost from every tab', () {
      expect(_tab(_hire(startTime: DateTime(2026, 9, 20, 9))), HireTab.today);
    });

    test('a hire that is running is for today', () {
      expect(_tab(_hire(status: 'started', tracking: true)), HireTab.today);
    });

    test('completed and cancelled hires go to their own tabs', () {
      expect(_tab(_hire(status: 'completed')), HireTab.completed);
      expect(_tab(_hire(status: 'cancelled')), HireTab.cancelled);
    });

    test('status wins over the schedule: a cancelled or completed hire is never "Scheduled" or "Today"', () {
      expect(_tab(_hire(status: 'cancelled', startTime: DateTime(2026, 10, 1))), HireTab.cancelled);
      expect(_tab(_hire(status: 'cancelled', startTime: DateTime(2026, 9, 25, 15))), HireTab.cancelled);
      expect(_tab(_hire(status: 'completed', startTime: DateTime(2026, 10, 1))), HireTab.completed);
    });

    test('every hire lands in exactly one tab', () {
      final hires = [
        _hire(),
        _hire(startTime: DateTime(2026, 9, 25, 12)),
        _hire(startTime: DateTime(2026, 9, 27)),
        _hire(status: 'started', tracking: true),
        _hire(status: 'completed'),
        _hire(status: 'cancelled'),
      ];

      final all = [for (final tab in HireTab.values) ...hiresForTab(hires, tab, now: _now)];

      expect(all.length, hires.length);
      expect(_ids(all).toSet(), _ids(hires).toSet());
    });
  });

  group('hiresForTab', () {
    test('Today puts the running hire first, then by schedule, unscheduled last', () {
      final unscheduled = _hire();
      final evening = _hire(startTime: DateTime(2026, 9, 25, 18));
      final running = _hire(status: 'started', tracking: true, startTime: DateTime(2026, 9, 25, 12));
      final morning = _hire(startTime: DateTime(2026, 9, 25, 8));

      final today = hiresForTab([unscheduled, evening, running, morning], HireTab.today, now: _now);

      expect(_ids(today), _ids([running, morning, evening, unscheduled]));
    });

    test('hires that tie keep the order the server sent them in', () {
      final a = _hire(), b = _hire(), c = _hire();

      expect(_ids(hiresForTab([b, c, a], HireTab.today, now: _now)), _ids([b, c, a]));
    });

    test('Scheduled lists the soonest first', () {
      final later = _hire(startTime: DateTime(2026, 10, 3, 9));
      final sooner = _hire(startTime: DateTime(2026, 9, 26, 14));
      final soonest = _hire(startTime: DateTime(2026, 9, 26, 8));

      expect(_ids(hiresForTab([later, sooner, soonest], HireTab.scheduled, now: _now)), _ids([soonest, sooner, later]));
    });

    test('Completed and Cancelled stay newest first, as sent', () {
      final first = _hire(status: 'completed'), second = _hire(status: 'completed');
      final c1 = _hire(status: 'cancelled'), c2 = _hire(status: 'cancelled');

      expect(_ids(hiresForTab([first, c1, second, c2], HireTab.completed, now: _now)), _ids([first, second]));
      expect(_ids(hiresForTab([first, c1, second, c2], HireTab.cancelled, now: _now)), _ids([c1, c2]));
    });

    test('an empty list gives empty tabs', () {
      for (final tab in HireTab.values) {
        expect(hiresForTab(const [], tab, now: _now), isEmpty);
      }
    });
  });

  test('the tabs are in the order the driver asked for, each with a name and an empty message', () {
    expect(HireTab.values.map((t) => t.label), ['Today', 'Scheduled', 'Completed', 'Cancelled']);
    for (final tab in HireTab.values) {
      expect(tab.emptyText, isNotEmpty);
    }
  });
}
