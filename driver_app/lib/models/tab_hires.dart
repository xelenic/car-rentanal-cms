import 'hire.dart';
import 'hire_page.dart';
import 'hire_tab.dart';

/// What one Home tab holds: its hires in display order, and how many there
/// are in all (which can be more than were loaded — the rest are behind "More").
class TabHires {
  final List<Hire> items;
  final int total;

  const TabHires({required this.items, required this.total});

  static const empty = TabHires(items: [], total: 0);
}

/// One history tab's (Completed or Cancelled) [TabHires] from its
/// status-filtered page — used both by [buildHomeTabs] and on its own, to
/// refresh just that tab after its own date filter changes without touching
/// the others.
///
/// Uses the server's exact total — unless the server ignored the status
/// filter (an older one), in which case the page holds hires of every status
/// and only what is actually in this tab can be counted.
TabHires tabHiresFromHistoryPage(HireTab tab, HirePage page, {DateTime? now}) {
  final items = hiresForTab(page.items, tab, now: now);
  final filteredByServer = page.items.every((hire) => hireTabOf(hire, now: now) == tab);

  return TabHires(items: items, total: filteredByServer ? page.total : items.length);
}

/// Builds the four Home tabs from three status-filtered responses.
///
/// Today and Scheduled both come from the open hires, split by the driver's own
/// date.
Map<HireTab, TabHires> buildHomeTabs({
  required HirePage open,
  required HirePage completed,
  required HirePage cancelled,
  DateTime? now,
}) {
  TabHires fromOpen(HireTab tab) {
    final items = hiresForTab(open.items, tab, now: now);
    return TabHires(items: items, total: items.length);
  }

  return {
    HireTab.today: fromOpen(HireTab.today),
    HireTab.scheduled: fromOpen(HireTab.scheduled),
    HireTab.completed: tabHiresFromHistoryPage(HireTab.completed, completed, now: now),
    HireTab.cancelled: tabHiresFromHistoryPage(HireTab.cancelled, cancelled, now: now),
  };
}
