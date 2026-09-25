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

/// Builds the four Home tabs from three status-filtered responses.
///
/// Today and Scheduled both come from the open hires, split by the driver's own
/// date. Completed and Cancelled use the server's exact total — unless the
/// server ignored the status filter (an older one), in which case the page holds
/// hires of every status and only what is actually in this tab can be counted.
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

  TabHires fromHistory(HireTab tab, HirePage page) {
    final items = hiresForTab(page.items, tab, now: now);
    final filteredByServer = page.items.every((hire) => hireTabOf(hire, now: now) == tab);

    return TabHires(items: items, total: filteredByServer ? page.total : items.length);
  }

  return {
    HireTab.today: fromOpen(HireTab.today),
    HireTab.scheduled: fromOpen(HireTab.scheduled),
    HireTab.completed: fromHistory(HireTab.completed, completed),
    HireTab.cancelled: fromHistory(HireTab.cancelled, cancelled),
  };
}
