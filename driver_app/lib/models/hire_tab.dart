import 'hire.dart';

/// The four tabs of the driver's "Assigned Tours" list.
enum HireTab {
  /// Work to do now: hires assigned today, hires scheduled for today, and
  /// anything still open that isn't scheduled for a later day (a hire left
  /// over from an earlier day must not vanish from every tab).
  today('Today', "Today's Tours", 'tours for today', 'No tours for today.', 'open'),

  /// Upcoming hires — open ones scheduled for a day after today.
  scheduled('Scheduled', 'Scheduled Tours', 'scheduled tours', 'No upcoming scheduled tours.', 'open'),

  /// Finished hires.
  completed('Completed', 'Completed Tours', 'completed tours', 'Completed tours will show up here.', 'completed'),

  /// Hires the driver cancelled.
  cancelled('Cancelled', 'Cancelled Tours', 'cancelled tours', 'Cancelled tours will show up here.', 'cancelled');

  /// The tab's name, and the title of its full list page.
  final String label;
  final String title;

  /// What its hires are called in a sentence ("No cancelled tours in …").
  final String noun;

  /// What the Home tab says when it is empty.
  final String emptyText;

  /// The API's status group for this tab — Today and Scheduled are both "open"
  /// hires, told apart on the phone by the driver's own date.
  final String apiStatus;

  const HireTab(this.label, this.title, this.noun, this.emptyText, this.apiStatus);

  /// Finished or cancelled hires pile up over the months, so these tabs are
  /// always worth a "More" button (with a month filter), even when few fit.
  bool get isHistory => this == HireTab.completed || this == HireTab.cancelled;
}

/// How many hires each Home tab shows before "More".
const int kHomeTabLimit = 5;

DateTime _dayOf(DateTime moment) => DateTime(moment.year, moment.month, moment.day);

/// Which tab a hire belongs to. [now] is only for tests.
HireTab hireTabOf(Hire hire, {DateTime? now}) {
  if (hire.isCancelled) return HireTab.cancelled;
  if (hire.isCompleted) return HireTab.completed;

  final start = hire.startTime?.toLocal();
  final today = _dayOf(now ?? DateTime.now());

  if (start != null && _dayOf(start).isAfter(today)) return HireTab.scheduled;
  return HireTab.today;
}

/// The hires of [tab], in the order a driver wants them: a running hire
/// first, then by when they're scheduled (soonest first); finished and
/// cancelled hires stay newest first, as the server sends them.
List<Hire> hiresForTab(List<Hire> hires, HireTab tab, {DateTime? now}) {
  final inTab = [for (final hire in hires) if (hireTabOf(hire, now: now) == tab) hire];

  if (tab == HireTab.completed || tab == HireTab.cancelled) return inTab;

  int bySchedule(Hire a, Hire b) {
    final aStart = a.startTime, bStart = b.startTime;
    if (aStart == null && bStart == null) return 0;
    if (aStart == null) return 1; // unscheduled after scheduled
    if (bStart == null) return -1;
    return aStart.compareTo(bStart);
  }

  // Dart's sort isn't stable, so break every tie by the original position.
  final position = {for (var i = 0; i < inTab.length; i++) inTab[i]: i};
  inTab.sort((a, b) {
    if (tab == HireTab.today && a.isTracking != b.isTracking) return a.isTracking ? -1 : 1;

    final scheduled = bySchedule(a, b);
    return scheduled != 0 ? scheduled : position[a]!.compareTo(position[b]!);
  });

  return inTab;
}
