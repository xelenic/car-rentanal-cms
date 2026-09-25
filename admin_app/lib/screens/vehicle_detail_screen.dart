import 'package:flutter/material.dart';

import '../models/hire.dart';
import '../models/hire_tab.dart';
import '../models/reference_data.dart';
import '../models/vehicle.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/hire_card.dart';
import '../widgets/state_views.dart';
import '../widgets/vehicle_card.dart';
import 'create_hire_screen.dart';
import 'hire_detail_screen.dart';

/// One vehicle: its numbers up top, its hires below split into tabs (All,
/// Today, Scheduled, Completed, Cancelled), and a button to book a new hire
/// for it.
class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicle, this.canCreateHires = false});

  /// What the dashboard already knew — shown straight away while a fresh copy loads.
  final Vehicle vehicle;
  final bool canCreateHires;

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: HireTab.values.length, vsync: this);
  late Vehicle _vehicle = widget.vehicle;

  /// Bumped to make every tab load again from the top (after a hire is created).
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _reloadVehicle();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Refreshes the numbers and tab counts. A failure keeps what's shown.
  Future<void> _reloadVehicle() async {
    try {
      final fresh = await ApiClient.instance.fetchVehicle(_vehicle.id);
      if (mounted) setState(() => _vehicle = fresh);
    } catch (_) {
      // Keep the numbers we have.
    }
  }

  Future<void> _newHire() async {
    final created = await Navigator.of(context).push<Hire>(
      MaterialPageRoute(
        builder: (_) => CreateHireScreen(vehicle: NamedOption(id: _vehicle.id, name: _vehicle.model)),
      ),
    );
    if (created == null || !mounted) return;

    setState(() => _epoch++);
    _tabs.animateTo(HireTab.values.indexOf(tabOfNewHire(created)));
    _reloadVehicle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_vehicle.model)),
      floatingActionButton: widget.canCreateHires
          ? FloatingActionButton.extended(
              key: const Key('new-hire'),
              onPressed: _newHire,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Hire'),
            )
          : null,
      body: Column(
        children: [
          _VehicleHeader(vehicle: _vehicle),
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
                for (final tab in HireTab.values)
                  Tab(
                    key: Key('tab-${tab.apiValue}'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tab.label),
                        const SizedBox(width: 6),
                        _CountBadge(count: _vehicle.stats.counts.of(tab), color: hireTabColor(tab)),
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
                for (final tab in HireTab.values)
                  _VehicleHiresTab(
                    key: ValueKey('${tab.apiValue}-$_epoch'),
                    vehicleId: _vehicle.id,
                    tab: tab,
                    onChanged: _reloadVehicle,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The vehicle's model facts and money totals, kept short so the lists below
/// get the screen.
class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final stats = vehicle.stats;

    return Container(
      key: const Key('vehicle-header'),
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${countOf(vehicle.seats, 'seat')} · ${countOf(vehicle.pax, 'passenger')}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Pill(label: vehicle.condition, color: conditionColor(vehicle.condition)),
              if (stats.counts.running > 0)
                Pill(
                  label: '${stats.counts.running} running now',
                  color: AppColors.info,
                  icon: Icons.play_circle_fill_rounded,
                ),
            ],
          ),
          if (vehicle.description != null) ...[
            const SizedBox(height: 6),
            Text(
              vehicle.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('Hires', '${stats.hireCount}'),
              _stat('Hire value', formatRsShort(stats.hireFullValueTotal)),
              _stat('Our value', formatRsShort(stats.ourHireValueTotal)),
              _stat('Commission', formatRsShort(stats.commissionTotal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
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
class _VehicleHiresTab extends StatefulWidget {
  const _VehicleHiresTab({
    super.key,
    required this.vehicleId,
    required this.tab,
    required this.onChanged,
  });

  final int vehicleId;
  final HireTab tab;

  /// Called after a pull-to-refresh or a visit to a hire, so the vehicle's
  /// numbers follow.
  final VoidCallback onChanged;

  @override
  State<_VehicleHiresTab> createState() => _VehicleHiresTabState();
}

class _VehicleHiresTabState extends State<_VehicleHiresTab> with AutomaticKeepAliveClientMixin {
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
      final page = await ApiClient.instance.fetchVehicleHires(widget.vehicleId, tab: widget.tab);
      if (!mounted) return;
      setState(() {
        _hires = page.hires;
        _hasMore = page.hasMore;
        _page = page.currentPage;
      });
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
      final page = await ApiClient.instance.fetchVehicleHires(
        widget.vehicleId,
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

  Future<void> _refresh() async {
    await _load(silent: true);
    widget.onChanged();
  }

  Future<void> _open(Hire hire) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HireDetailScreen(hireId: hire.id)),
    );
    if (!mounted) return;
    _refresh();
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
      return RefreshIndicator(
        onRefresh: _refresh,
        child: EmptyState(title: widget.tab.emptyTitle, message: widget.tab.emptyText),
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
