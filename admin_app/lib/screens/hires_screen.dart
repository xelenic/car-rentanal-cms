import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_user.dart';
import '../models/dashboard_summary.dart';
import '../models/hire.dart';
import '../models/hire_tab.dart';
import '../models/reference_data.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/hire_card.dart';
import '../widgets/state_views.dart';
import '../widgets/vehicle_style.dart';
import 'hire_detail_screen.dart';
import 'hire_form_screen.dart';

/// One combination of the filter sheet's selections — driver, vehicle,
/// customer and a scheduled-date range, all optional and independent.
class _HireFilters {
  const _HireFilters({this.driverId, this.vehicleId, this.customerId, this.dateFrom, this.dateTo});

  final int? driverId;
  final int? vehicleId;
  final int? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  bool get isEmpty =>
      driverId == null && vehicleId == null && customerId == null && dateFrom == null && dateTo == null;

  int get activeCount => [driverId, vehicleId, customerId, dateFrom, dateTo].where((v) => v != null).length;
}

/// Every hire across the whole fleet, one tap away from the home screen —
/// unlike before, where a hire was only reachable by drilling into the
/// specific vehicle it belonged to. Same search + "Upcoming only" + paginated
/// list pattern as VehiclesDashboardScreen; booking a hire here opens
/// HireFormScreen with no vehicle pre-selected (its vehicle picker handles
/// that already).
class HiresScreen extends StatefulWidget {
  const HiresScreen({super.key, this.user});

  final AdminUser? user;

  @override
  State<HiresScreen> createState() => _HiresScreenState();
}

class _HiresScreenState extends State<HiresScreen> with SingleTickerProviderStateMixin {
  // "Overview" leads (and is the default tab, index 0), then one tab per
  // HireTab — same leading-info-tab-first pattern as the Customer/Driver
  // detail pages' own Details/Hires tabs.
  late final TabController _tabs = TabController(length: HireTab.values.length + 1, vsync: this);

  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _upcomingOnly = false;
  _HireFilters _filters = const _HireFilters();
  ReferenceData? _reference;
  DashboardSummary? _summary;
  bool _summaryLoading = true;
  String? _summaryError;
  Map<String, int> _tabCounts = const {};

  /// Bumped whenever the search, "Upcoming" toggle or filter sheet changes,
  /// so every tab reloads from the top with the new combination.
  int _epoch = 0;

  bool get _searching => _searchController.text.trim().isNotEmpty;
  bool get _filtering => _searching || _upcomingOnly || !_filters.isEmpty;
  bool get _canCreate => widget.user?.canCreateHires ?? false;

  @override
  void initState() {
    super.initState();
    _loadReference();
    _loadSummary();
  }

  /// Populates the filter sheet's driver/vehicle/customer dropdowns. Best
  /// effort — if this fails, the sheet still opens, just without options.
  Future<void> _loadReference() async {
    try {
      final reference = await ApiClient.instance.fetchReferenceData();
      if (mounted) setState(() => _reference = reference);
    } catch (_) {
      // Ignored — filters degrade gracefully.
    }
  }

  /// This month's company-wide totals — the same figures as the Overview
  /// page, independent of whatever tab or driver/vehicle/customer/date
  /// filter the hire lists are narrowed to. Shown on its own "Overview" tab
  /// rather than the hire lists, which have nothing to do with it failing
  /// or still loading.
  Future<void> _loadSummary() async {
    setState(() {
      _summaryLoading = true;
      _summaryError = null;
    });

    try {
      final summary = await ApiClient.instance.fetchDashboard();
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (e) {
      if (mounted) setState(() => _summaryError = e.message);
    } catch (_) {
      if (mounted) setState(() => _summaryError = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _reloadTabs() => setState(() => _epoch++);

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    setState(() {}); // the clear button follows the text
    _debounce = Timer(const Duration(milliseconds: 400), _reloadTabs);
  }

  void _toggleUpcoming() {
    setState(() => _upcomingOnly = !_upcomingOnly);
    _reloadTabs();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_HireFilters>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _HireFiltersSheet(reference: _reference, initial: _filters),
    );
    if (result != null && mounted) {
      setState(() {
        _filters = result;
        _epoch++;
      });
    }
  }

  Future<void> _bookHire() async {
    final created = await Navigator.of(context).push<Hire>(
      MaterialPageRoute(builder: (_) => const HireFormScreen()),
    );
    if (created == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hire #${created.id} booked.')));
    setState(() => _epoch++);
    // +1 — Overview is the leading tab, so every HireTab sits one index later.
    _tabs.animateTo(1 + HireTab.values.indexOf(tabOfNewHire(created)));
  }

  /// Every tab's hire count comes back on every tab's own fetch (the server
  /// computes them together regardless of which tab asked), so whichever
  /// tab loads first — or reloads — keeps the TabBar's badges current.
  void _onTabCounts(Map<String, int> counts) {
    if (mounted) setState(() => _tabCounts = counts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hires'),
        actions: [
          IconButton(
            key: const Key('hire-filters'),
            tooltip: 'Filter',
            icon: Badge(
              isLabelVisible: _filters.activeCount > 0,
              label: Text('${_filters.activeCount}'),
              smallSize: 8,
              child: const Icon(Icons.filter_list_rounded),
            ),
            onPressed: _openFilters,
          ),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              key: const Key('new-hire'),
              onPressed: _bookHire,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Hire'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('hire-search'),
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by customer or description…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searching
                          ? IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _debounce?.cancel();
                                _reloadTabs();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  key: const Key('upcoming-only'),
                  label: const Text('Upcoming'),
                  selected: _upcomingOnly,
                  onSelected: (_) => _toggleUpcoming(),
                  showCheckmark: false,
                  selectedColor: AppColors.surfaceElevated,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: _upcomingOnly ? AppColors.primary : AppColors.border),
                  labelStyle: TextStyle(
                    color: _upcomingOnly ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              dividerColor: AppColors.border,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              tabs: [
                const Tab(key: Key('tab-overview'), text: 'Overview'),
                for (final tab in HireTab.values)
                  Tab(
                    key: Key('tab-${tab.apiValue}'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tab.label),
                        const SizedBox(width: 6),
                        _CountBadge(count: _tabCounts[tab.apiValue] ?? 0, color: hireTabColor(tab)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _HiresOverviewTab(
                  loading: _summaryLoading,
                  error: _summaryError,
                  summary: _summary,
                  onRetry: _loadSummary,
                ),
                for (final tab in HireTab.values)
                  _HiresListTab(
                    key: ValueKey('${tab.apiValue}-$_epoch'),
                    tab: tab,
                    search: _searchController.text.trim(),
                    upcoming: _upcomingOnly,
                    filtering: _filtering,
                    driverId: _filters.driverId,
                    vehicleId: _filters.vehicleId,
                    customerId: _filters.customerId,
                    dateFrom: _filters.dateFrom,
                    dateTo: _filters.dateTo,
                    user: widget.user,
                    onTabCounts: _onTabCounts,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    final shade = active ? color : AppColors.textMuted;

    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: shade.withValues(alpha: active ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: shade),
      ),
    );
  }
}

/// One tab's list of hires: loads its first page when first shown, keeps
/// what it loaded while the other tabs are visited, and pages as you scroll.
/// Same search/upcoming/driver/vehicle/customer/date filters as every tab,
/// just split by status — mirrors VehicleDetailScreen's own per-tab list.
class _HiresListTab extends StatefulWidget {
  const _HiresListTab({
    super.key,
    required this.tab,
    required this.search,
    required this.upcoming,
    required this.filtering,
    required this.onTabCounts,
    this.driverId,
    this.vehicleId,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.user,
  });

  final HireTab tab;
  final String search;
  final bool upcoming;

  /// Whether any search/upcoming/driver/vehicle/customer/date filter is
  /// active — the "All" tab's empty state tells "nothing matches" apart
  /// from "nothing booked yet" with this; the other tabs' own fixed
  /// messages (Today/Scheduled/Completed/Cancelled) don't need the
  /// distinction.
  final bool filtering;

  final int? driverId;
  final int? vehicleId;
  final int? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final AdminUser? user;

  /// Every tab's count, straight off this tab's own response — see
  /// _HiresScreenState._onTabCounts().
  final ValueChanged<Map<String, int>> onTabCounts;

  @override
  State<_HiresListTab> createState() => _HiresListTabState();
}

class _HiresListTabState extends State<_HiresListTab> with AutomaticKeepAliveClientMixin {
  List<Hire> _hires = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });

    try {
      final page = await ApiClient.instance.fetchHires(
        search: widget.search,
        upcoming: widget.upcoming,
        driverId: widget.driverId,
        vehicleId: widget.vehicleId,
        customerId: widget.customerId,
        dateFrom: widget.dateFrom,
        dateTo: widget.dateTo,
        tab: widget.tab,
      );
      if (!mounted) return;
      setState(() {
        _hires = page.hires;
        _hasMore = page.hasMore;
        _page = page.currentPage;
      });
      widget.onTabCounts(page.summary.tabCounts);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach the server. Pull down to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final page = await ApiClient.instance.fetchHires(
        search: widget.search,
        upcoming: widget.upcoming,
        driverId: widget.driverId,
        vehicleId: widget.vehicleId,
        customerId: widget.customerId,
        dateFrom: widget.dateFrom,
        dateTo: widget.dateTo,
        tab: widget.tab,
        page: _page + 1,
      );
      if (!mounted) return;
      final known = _hires.map((h) => h.id).toSet();
      setState(() {
        _hires = [..._hires, ...page.hires.where((h) => !known.contains(h.id))];
        _hasMore = page.hasMore;
        _page = page.currentPage;
      });
    } catch (_) {
      // Silent — scrolling to the end again retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() => _load(silent: true);

  Future<void> _open(Hire hire) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HireDetailScreen(hireId: hire.id, user: widget.user)),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ErrorState(message: _error!, onRetry: _load),
      );
    }

    if (_hires.isEmpty) {
      // HireTab's own emptyTitle/emptyText were written for one vehicle's
      // page ("Hires assigned to this vehicle…") — fine as-is for the four
      // status tabs here too, but "All" needs fleet-wide wording instead,
      // and (since "All" alone carries every other filter) its own
      // search/filter-aware message.
      final isAll = widget.tab == HireTab.all;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: EmptyState(
          icon: Icons.event_note_outlined,
          title: isAll ? (widget.filtering ? 'No hires match' : 'No hires yet') : widget.tab.emptyTitle,
          message: isAll
              ? (widget.filtering ? 'Try a different search or filter.' : 'Hires you book will show up here.')
              : widget.tab.emptyText,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 240) {
            _loadMore();
          }
          return false;
        },
        child: ListView.separated(
          key: PageStorageKey('hires-${widget.tab.apiValue}'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: _hires.length + (_hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index >= _hires.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              );
            }
            final hire = _hires[index];
            return HireCard(hire: hire, onTap: () => _open(hire));
          },
        ),
      ),
    );
  }
}

/// The Hires page's own "Overview" tab — this month's profit summary, loaded
/// once up front rather than per hire-status tab, since it has nothing to do
/// with which status is being browsed.
class _HiresOverviewTab extends StatelessWidget {
  const _HiresOverviewTab({required this.loading, required this.error, required this.summary, required this.onRetry});

  final bool loading;
  final String? error;
  final DashboardSummary? summary;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return ErrorState(message: error!, onRetry: onRetry);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [_HiresSummaryCard(summary: summary!)],
    );
  }
}

/// This month's company-wide totals — the same figures as the Overview page
/// — so a quick profit check doesn't require leaving the Hires list. Always
/// the current month, independent of whatever the list below is filtered to.
class _HiresSummaryCard extends StatelessWidget {
  const _HiresSummaryCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final loss = summary.profitTotal < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          key: const Key('hires-summary-profit'),
          color: AppColors.primary,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'My Profit · ${summary.periodLabel}',
                  style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatRsExact(summary.profitTotal),
                      key: const Key('hires-summary-profit-value'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: loss ? const Color(0xFFFFC9C9) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _HiresStatTile(
                  label: 'Total Our Hire Value',
                  value: formatRsShort(summary.ourHireValueTotal),
                  icon: Icons.account_balance_outlined,
                  color: const Color(0xFF2A78D6),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _HiresStatTile(
                  label: 'Total Full Value',
                  value: formatRsShort(summary.hireFullValueTotal),
                  icon: Icons.receipt_long_outlined,
                  color: const Color(0xFFB3810A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _HiresStatTile(
                  label: 'Total Expenses',
                  value: formatRsShort(summary.expensesTotal),
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _HiresStatTile(
                  label: 'Total Driver Salary',
                  value: formatRsShort(summary.salaryTotal),
                  icon: Icons.payments_outlined,
                  color: const Color(0xFFC95A26),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HiresStatTile extends StatelessWidget {
  const _HiresStatTile({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Driver / vehicle / customer / scheduled-date-range filters, all optional
/// and independent — returns the chosen combination on "Apply", or null if
/// dismissed without applying.
class _HireFiltersSheet extends StatefulWidget {
  const _HireFiltersSheet({required this.reference, required this.initial});

  final ReferenceData? reference;
  final _HireFilters initial;

  @override
  State<_HireFiltersSheet> createState() => _HireFiltersSheetState();
}

class _HireFiltersSheetState extends State<_HireFiltersSheet> {
  late int? _driverId = widget.initial.driverId;
  late int? _vehicleId = widget.initial.vehicleId;
  late int? _customerId = widget.initial.customerId;
  late DateTime? _dateFrom = widget.initial.dateFrom;
  late DateTime? _dateTo = widget.initial.dateTo;

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = (isFrom ? _dateFrom : _dateTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => isFrom ? _dateFrom = picked : _dateTo = picked);
  }

  void _clearAll() {
    setState(() {
      _driverId = null;
      _vehicleId = null;
      _customerId = null;
      _dateFrom = null;
      _dateTo = null;
    });
  }

  void _apply() {
    Navigator.of(context).pop(_HireFilters(
      driverId: _driverId,
      vehicleId: _vehicleId,
      customerId: _customerId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final reference = widget.reference;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter hires', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 14),
              if (reference == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                DropdownButtonFormField<int>(
                  key: const Key('filter-driver'),
                  initialValue: _driverId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Driver'),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('All drivers')),
                    ...reference.drivers.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                  ],
                  onChanged: (value) => setState(() => _driverId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: const Key('filter-vehicle'),
                  initialValue: _vehicleId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Vehicle'),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('All vehicles')),
                    ...reference.vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name))),
                  ],
                  onChanged: (value) => setState(() => _vehicleId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: const Key('filter-customer'),
                  initialValue: _customerId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Customer'),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('All customers')),
                    ...reference.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (value) => setState(() => _customerId = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        fieldKey: const Key('filter-date-from'),
                        label: 'From',
                        value: _dateFrom,
                        onTap: () => _pickDate(isFrom: true),
                        onClear: () => setState(() => _dateFrom = null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        fieldKey: const Key('filter-date-to'),
                        label: 'To',
                        value: _dateTo,
                        onTap: () => _pickDate(isFrom: false),
                        onClear: () => setState(() => _dateTo = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('filter-clear'),
                        onPressed: _clearAll,
                        child: const Text('Clear all'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('filter-apply'),
                        onPressed: _apply,
                        child: const Text('Apply filters'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.fieldKey, required this.label, required this.value, required this.onTap, required this.onClear});

  final Key fieldKey;
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: fieldKey,
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value != null
              ? IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today_rounded, size: 18),
        ),
        child: Text(
          value != null ? DateFormat('d MMM y').format(value!) : 'Any date',
          style: TextStyle(color: value != null ? AppColors.textPrimary : AppColors.textMuted, fontSize: 14),
        ),
      ),
    );
  }
}
