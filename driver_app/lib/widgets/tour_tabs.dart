import 'package:flutter/material.dart';

import '../models/hire.dart';
import '../models/hire_tab.dart';
import '../models/tab_hires.dart';
import '../screens/tour_list_screen.dart';
import '../theme/app_theme.dart';
import 'hire_route_card.dart';

/// The driver's "Assigned Tours", in four tabs — Today, Scheduled, Completed
/// and Cancelled (see [hireTabOf] for which hire lands where). Each tab shows
/// its first [kHomeTabLimit] hires; a "More" button opens the whole list on its
/// own page ([TourListScreen]), where it can be filtered by month.
class TourTabs extends StatefulWidget {
  final Map<HireTab, TabHires> tabs;

  /// Today's date, for the Today/Scheduled split. Only tests set it.
  final DateTime? now;

  /// Called after the driver returns from a hire or from a full list — what
  /// they did there (cancel, complete, …) may have changed what the tabs hold.
  final VoidCallback? onChanged;

  /// Builds the full-list page a tab's "More" button opens. Only tests replace
  /// it (the default is [TourListScreen]).
  final Widget Function(HireTab tab)? listPageBuilder;

  const TourTabs({
    super.key,
    required this.tabs,
    this.now,
    this.onChanged,
    this.listPageBuilder,
  });

  @override
  State<TourTabs> createState() => _TourTabsState();
}

class _TourTabsState extends State<TourTabs> {
  HireTab _tab = HireTab.today;

  TabHires _hiresOf(HireTab tab) => widget.tabs[tab] ?? TabHires.empty;

  /// "More" leads to the rest of the tab's hires — and, for Completed and
  /// Cancelled, to the month filter that reaches back through the history,
  /// so they always have one.
  bool _hasMore(HireTab tab) {
    final hires = _hiresOf(tab);
    return hires.total > kHomeTabLimit || (tab.isHistory && hires.total > 0);
  }

  Future<void> _openMore(HireTab tab) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.listPageBuilder?.call(tab) ?? TourListScreen(tab: tab, now: widget.now),
      ),
    );
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hires = _hiresOf(_tab);
    final shown = hires.items.take(kHomeTabLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.assignment_outlined, color: AppColors.neon, size: 18),
            SizedBox(width: 8),
            Text(
              'Assigned Tours',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final tab in HireTab.values) ...[
              if (tab != HireTab.today) const SizedBox(width: 8),
              Expanded(
                child: _TabTile(
                  tab: tab,
                  count: _hiresOf(tab).total,
                  selected: tab == _tab,
                  onTap: () => setState(() => _tab = tab),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        HireListOrEmpty(
          key: ValueKey('tour-list-${_tab.name}'),
          hires: shown,
          emptyText: _tab.emptyText,
          onReturn: widget.onChanged,
        ),
        if (_hasMore(_tab))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('tour-more-${_tab.name}'),
                onPressed: () => _openMore(_tab),
                icon: const Icon(Icons.expand_more, size: 20),
                label: const Text('More'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.neonDeep,
                  side: const BorderSide(color: AppColors.neon),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One tab: how many hires it holds, over its name.
class _TabTile extends StatelessWidget {
  final HireTab tab;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TabTile({required this.tab, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = tab == HireTab.cancelled ? AppColors.danger : AppColors.neon;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: Key('tour-tab-${tab.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? color : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tab.label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list of hire cards, or a short message when there are none.
class HireListOrEmpty extends StatelessWidget {
  final List<Hire> hires;
  final String emptyText;

  /// Passed to each card — see [HireRouteCard.onReturn].
  final VoidCallback? onReturn;

  const HireListOrEmpty({super.key, required this.hires, required this.emptyText, this.onReturn});

  @override
  Widget build(BuildContext context) {
    if (hires.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          emptyText,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }

    return Column(
      children: [
        for (final hire in hires)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: HireRouteCard(hire: hire, onReturn: onReturn),
          ),
      ],
    );
  }
}
