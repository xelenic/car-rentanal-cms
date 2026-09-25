import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/available_periods.dart';
import '../models/hire.dart';
import '../models/hire_page.dart';
import '../models/hire_tab.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/period_dropdown.dart';
import '../widgets/tour_tabs.dart';

/// Loads a page of the driver's hires — see [ApiClient.fetchHires].
typedef FetchHires = Future<HirePage> Function({int? year, int? month, String? status, int page, int? perPage});

/// Loads the periods that have hires — see [ApiClient.fetchAvailablePeriods].
typedef FetchPeriods = Future<AvailablePeriods> Function({String? status});

/// The whole list behind a Home tab's "More" button, on its own page.
///
/// It opens on **this month** and can be filtered by year and month (only the
/// periods that have hires of this kind are offered, plus the current one).
/// Long lists load a page at a time, with a "Load more" button.
class TourListScreen extends StatefulWidget {
  final HireTab tab;

  /// Today's date — sets "this month" and the Today/Scheduled split. Only tests
  /// set it.
  final DateTime? now;

  /// Only tests replace these (the defaults ask the server).
  final FetchHires? fetchHires;
  final FetchPeriods? fetchPeriods;

  const TourListScreen({super.key, required this.tab, this.now, this.fetchHires, this.fetchPeriods});

  @override
  State<TourListScreen> createState() => _TourListScreenState();
}

class _TourListScreenState extends State<TourListScreen> {
  late final DateTime _now = widget.now ?? DateTime.now();

  int? _year;
  int? _month;
  AvailablePeriods? _periods;

  final List<Hire> _loaded = [];
  int _page = 0;
  int _lastPage = 1;
  int _total = 0;

  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  Object? _moreError;

  /// Bumped on every reload so a slow response to an old filter can't land
  /// on top of the current one.
  int _generation = 0;

  /// A page of open hires can hold none for this tab (its Today ones may sit on
  /// the next page) — how many pages to look through before showing "none".
  static const int _maxAutoPages = 10;

  @override
  void initState() {
    super.initState();
    _year = _now.year;
    _month = _now.month;
    _loadPeriods();
    _reload();
  }

  FetchHires get _fetchHires => widget.fetchHires ?? ApiClient.instance.fetchHires;
  FetchPeriods get _fetchPeriods => widget.fetchPeriods ?? ApiClient.instance.fetchAvailablePeriods;

  bool get _isDefaultPeriod => _year == _now.year && _month == _now.month;

  List<Hire> get _shown => hiresForTab(_loaded, widget.tab, now: _now);

  Future<void> _loadPeriods() async {
    try {
      final periods = await _fetchPeriods(status: widget.tab.apiStatus);
      if (mounted) setState(() => _periods = periods);
    } catch (_) {
      // Without them the filter offers just the current period — still usable.
    }
  }

  /// Starts again from the first page with the current filters.
  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _moreError = null;
      _loaded.clear();
      _page = 0;
      _lastPage = 1;
      _total = 0;
    });

    try {
      var pagesRead = 0;
      do {
        if (!await _readNextPage(generation)) return;
        pagesRead++;
        // Open hires are split into Today / Scheduled here, so a page can hold
        // none of this tab's — keep looking rather than say "none" too early.
      } while (!widget.tab.isHistory && _shown.isEmpty && _page < _lastPage && pagesRead < _maxAutoPages);
    } catch (e) {
      if (generation == _generation && mounted) setState(() => _error = e);
    } finally {
      if (generation == _generation && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });

    try {
      await _readNextPage(generation);
    } catch (e) {
      if (generation == _generation && mounted) setState(() => _moreError = e);
    } finally {
      if (generation == _generation && mounted) setState(() => _loadingMore = false);
    }
  }

  /// Reads the next page and adds it. False when the filters changed meanwhile
  /// (the answer is stale and was dropped).
  Future<bool> _readNextPage(int generation) async {
    final page = await _fetchHires(
      year: _year,
      month: _month,
      status: widget.tab.apiStatus,
      page: _page + 1,
    );
    if (generation != _generation || !mounted) return false;

    setState(() {
      final known = _loaded.map((hire) => hire.id).toSet();
      _loaded.addAll(page.items.where((hire) => !known.contains(hire.id)));
      _page = page.currentPage;
      _lastPage = page.lastPage;
      _total = page.total;
    });
    return true;
  }

  void _setYear(int? year) {
    _year = year;
    _month = null; // picking a year means the whole year until a month is chosen
    _reload();
  }

  void _setMonth(int? month) {
    _month = month;
    _reload();
  }

  void _resetToThisMonth() {
    _year = _now.year;
    _month = _now.month;
    _reload();
  }

  List<int> get _yearOptions => {...?_periods?.years, _now.year}.toList()..sort((a, b) => b.compareTo(a));

  List<int> _monthOptions(int? year) {
    if (year == null) return const [];
    return {...?_periods?.monthsFor(year), if (year == _now.year) _now.month}.toList()..sort((a, b) => b.compareTo(a));
  }

  /// "September 2026", "2025" or "all time".
  String get _periodLabel {
    if (_year == null) return 'all time';
    if (_month == null) return '$_year';
    return DateFormat.yMMMM().format(DateTime(_year!, _month!));
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final count = widget.tab.isHistory ? _total : shown.length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.tab.title)),
      body: RefreshIndicator(
        color: AppColors.neon,
        backgroundColor: AppColors.surface,
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: PeriodDropdown(
                    hint: 'All years',
                    value: _year,
                    items: _yearOptions,
                    labelBuilder: (year) => '$year',
                    onChanged: _setYear,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PeriodDropdown(
                    hint: 'All months',
                    value: _month,
                    items: _monthOptions(_year),
                    labelBuilder: (month) => DateFormat.MMMM().format(DateTime(2000, month)),
                    onChanged: _year == null ? null : _setMonth,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _loading && _loaded.isEmpty
                        ? 'Loading…'
                        : '$count ${count == 1 ? 'tour' : 'tours'} · $_periodLabel',
                    key: const Key('tour-list-summary'),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                if (!_isDefaultPeriod)
                  TextButton(
                    key: const Key('tour-list-this-month'),
                    onPressed: _resetToThisMonth,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.neonDeep,
                    ),
                    child: const Text('This month', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading && _loaded.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.neon)),
              )
            else if (_error != null && _loaded.isEmpty)
              _ErrorBox(message: _error.toString(), onRetry: _reload)
            else ...[
              HireListOrEmpty(
                hires: shown,
                emptyText: 'No ${widget.tab.noun}${_year == null ? '' : ' in $_periodLabel'}.',
                onReturn: _reload,
              ),
              if (_moreError != null) _ErrorBox(message: _moreError.toString(), onRetry: _loadMore),
              if (_page < _lastPage)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('tour-list-load-more'),
                    onPressed: _loadingMore ? null : _loadMore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.neonDeep,
                      side: const BorderSide(color: AppColors.neon),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: _loadingMore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neon),
                          )
                        : const Text('Load more', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          const SizedBox(height: 6),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
