import 'hire.dart';

/// The tabs on a vehicle's page. The split matches the server's
/// (Hire::scopeTab) and the driver app's: today's list also holds hires with
/// no date and ones that are overdue or running, scheduled is tomorrow on.
enum HireTab {
  all('All', 'all', 'No hires yet', 'Hires assigned to this vehicle will show up here.'),
  today('Today', 'today', 'Nothing for today', 'No hires are due today, and none are running.'),
  scheduled('Scheduled', 'scheduled', 'Nothing scheduled', 'Hires booked for a later day will show up here.'),
  completed('Completed', 'completed', 'No completed hires', 'Finished hires will show up here.'),
  cancelled('Cancelled', 'cancelled', 'No cancelled hires', 'Cancelled hires will show up here.');

  const HireTab(this.label, this.apiValue, this.emptyTitle, this.emptyText);

  final String label;

  /// The `tab` query value the API understands.
  final String apiValue;

  final String emptyTitle;
  final String emptyText;
}

/// The tab a freshly created hire will be listed under — used to jump there
/// after "New Hire", so the admin sees it. Mirrors the server's rule: a hire
/// dated tomorrow or later is Scheduled, anything else still to do is Today.
HireTab tabOfNewHire(Hire hire, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final startOfTomorrow = DateTime(reference.year, reference.month, reference.day + 1);
  final start = hire.startTime;

  if (hire.status == 'completed') return HireTab.completed;
  if (hire.status == 'cancelled') return HireTab.cancelled;
  if (start != null && !start.isBefore(startOfTomorrow)) return HireTab.scheduled;
  return HireTab.today;
}
