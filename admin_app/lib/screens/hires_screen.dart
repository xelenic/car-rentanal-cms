import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_user.dart';
import '../models/hire.dart';
import '../models/reference_data.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/hire_card.dart';
import '../widgets/state_views.dart';
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

class _HiresScreenState extends State<HiresScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Hire> _hires = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;
  bool _upcomingOnly = false;
  _HireFilters _filters = const _HireFilters();
  ReferenceData? _reference;

  /// Bumped on every fresh load, so a slow answer to an old search or filter
  /// can't overwrite a newer one.
  int _generation = 0;

  bool get _searching => _searchController.text.trim().isNotEmpty;
  bool get _filtering => _searching || _upcomingOnly || !_filters.isEmpty;
  bool get _canCreate => widget.user?.canCreateHires ?? false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadReference();
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

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });

    try {
      final page = await ApiClient.instance.fetchHires(
        search: _searchController.text.trim(),
        upcoming: _upcomingOnly,
        driverId: _filters.driverId,
        vehicleId: _filters.vehicleId,
        customerId: _filters.customerId,
        dateFrom: _filters.dateFrom,
        dateTo: _filters.dateTo,
        page: 1,
      );
      if (!mounted || generation != _generation) return;

      setState(() {
        _hires = page.hires;
        _hasMore = page.hasMore;
        _page = page.currentPage;
      });
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);

    try {
      final page = await ApiClient.instance.fetchHires(
        search: _searchController.text.trim(),
        upcoming: _upcomingOnly,
        driverId: _filters.driverId,
        vehicleId: _filters.vehicleId,
        customerId: _filters.customerId,
        dateFrom: _filters.dateFrom,
        dateTo: _filters.dateTo,
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _hires = [..._hires, ...page.hires];
        _hasMore = page.hasMore;
        _page = page.currentPage;
      });
    } catch (_) {
      // Silent — scrolling to the end again retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    setState(() {}); // the clear button follows the text
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _toggleUpcoming() {
    setState(() => _upcomingOnly = !_upcomingOnly);
    _load();
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
      setState(() => _filters = result);
      _load();
    }
  }

  Future<void> _bookHire() async {
    final created = await Navigator.of(context).push<Hire>(
      MaterialPageRoute(builder: (_) => const HireFormScreen()),
    );
    if (created == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hire #${created.id} booked.')));
    _load(silent: true);
  }

  Future<void> _open(Hire hire) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HireDetailScreen(hireId: hire.id, user: widget.user)),
    );
    if (mounted) _load(silent: true);
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
                                _load();
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
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ErrorState(message: _error!, onRetry: _load),
      );
    }

    if (_hires.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: EmptyState(
          icon: Icons.event_note_outlined,
          title: _filtering ? 'No hires match' : 'No hires yet',
          message: _filtering
              ? 'Try a different search or filter.'
              : (_canCreate ? 'Book the first hire to see it here.' : 'Hires will show up here.'),
          action: !_filtering && _canCreate
              ? ElevatedButton.icon(
                  onPressed: _bookHire,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Hire'),
                )
              : null,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 240) {
            _loadMore();
          }
          return false;
        },
        child: ListView.separated(
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
