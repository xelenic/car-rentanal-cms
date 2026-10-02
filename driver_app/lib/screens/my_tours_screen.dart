import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/available_periods.dart';
import '../models/hire_tab.dart';
import '../models/tab_hires.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/period_dropdown.dart';
import '../widgets/tour_tabs.dart';

/// The driver's assigned tours, on their own page — what used to sit inline
/// on Home: Today, Scheduled, Completed and Cancelled, each with its first
/// few hires and a "More" button to the rest.
class MyToursScreen extends StatefulWidget {
  const MyToursScreen({super.key});

  @override
  State<MyToursScreen> createState() => _MyToursScreenState();
}

class _MyToursScreenState extends State<MyToursScreen> {
  Map<HireTab, TabHires>? _tabs;
  bool _loading = true;
  Object? _error;

  // Completed is the one tab with its own month filter, picked right here on
  // the summary — Today/Scheduled stay current (open work), and Cancelled
  // stays on the current month too; both are reachable further back via
  // their own "More" page.
  int? _completedYear;
  int? _completedMonth;
  AvailablePeriods? _completedPeriods;
  bool _completedBusy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _completedYear = now.year;
    _completedMonth = now.month;
    _reload(initial: true);
    _loadCompletedPeriods();
  }

  Future<void> _loadCompletedPeriods() async {
    try {
      final periods = await ApiClient.instance.fetchAvailablePeriods(status: 'completed');
      if (mounted) setState(() => _completedPeriods = periods);
    } catch (_) {
      // Without them the filter offers just the current period — still usable.
    }
  }

  /// Reloads every tab. Used for the first load, pull-to-refresh, and after
  /// the driver returns from a hire or a full list — what they did there
  /// (cancel, complete, …) may have moved hires between tabs. Keeps the
  /// tabs mounted throughout (no blank "loading" gap) so the selected tab
  /// and its filter survive the refresh.
  Future<void> _reload({bool initial = false}) async {
    setState(() {
      if (initial) _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final results = await Future.wait([
        ApiClient.instance.fetchHires(status: 'open', year: now.year, month: now.month),
        ApiClient.instance.fetchHires(
          status: 'completed',
          year: _completedYear,
          month: _completedMonth,
          perPage: kHomeTabLimit,
        ),
        ApiClient.instance.fetchHires(status: 'cancelled', year: now.year, month: now.month, perPage: kHomeTabLimit),
      ]);
      if (!mounted) return;
      setState(() => _tabs = buildHomeTabs(open: results[0], completed: results[1], cancelled: results[2]));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Re-fetches just the Completed tab after its own filter changes — the
  /// other tabs are untouched and keep showing what they already have.
  Future<void> _reloadCompleted() async {
    setState(() => _completedBusy = true);
    try {
      final page = await ApiClient.instance.fetchHires(
        status: 'completed',
        year: _completedYear,
        month: _completedMonth,
        perPage: kHomeTabLimit,
      );
      if (!mounted) return;
      setState(() {
        _tabs = {...?_tabs, HireTab.completed: tabHiresFromHistoryPage(HireTab.completed, page)};
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _completedBusy = false);
    }
  }

  void _setCompletedYear(int? year) {
    setState(() {
      _completedYear = year;
      _completedMonth = null; // picking a year means the whole year until a month is chosen
    });
    _reloadCompleted();
  }

  void _setCompletedMonth(int? month) {
    setState(() => _completedMonth = month);
    _reloadCompleted();
  }

  void _refreshQuietly() {
    if (mounted) unawaited(_reload());
  }

  List<int> get _completedYearOptions =>
      {...?_completedPeriods?.years, DateTime.now().year}.toList()..sort((a, b) => b.compareTo(a));

  List<int> _completedMonthOptions(int? year) {
    if (year == null) return const [];
    final now = DateTime.now();
    return {...?_completedPeriods?.monthsFor(year), if (year == now.year) now.month}.toList()
      ..sort((a, b) => b.compareTo(a));
  }

  Widget? _filterFor(HireTab tab) {
    if (tab != HireTab.completed) return null;

    return Row(
      key: const Key('completed-filter'),
      children: [
        Expanded(
          child: PeriodDropdown(
            hint: 'Year',
            value: _completedYear,
            items: _completedYearOptions,
            labelBuilder: (year) => '$year',
            onChanged: _completedBusy ? null : _setCompletedYear,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PeriodDropdown(
            hint: 'Month',
            value: _completedMonth,
            items: _completedMonthOptions(_completedYear),
            labelBuilder: (month) => DateFormat.MMMM().format(DateTime(2000, month)),
            onChanged: _completedBusy || _completedYear == null ? null : _setCompletedMonth,
          ),
        ),
        if (_completedBusy) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neon),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tours')),
      body: RefreshIndicator(
        color: AppColors.neon,
        backgroundColor: AppColors.surface,
        onRefresh: _reload,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.neon))
            : _error != null && _tabs == null
                ? ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 160),
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        _error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      TourTabs(tabs: _tabs ?? const {}, onChanged: _refreshQuietly, filterBuilder: _filterFor),
                    ],
                  ),
      ),
    );
  }
}
